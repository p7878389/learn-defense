import Foundation
import LearnCore

/// 预先生成的高质量语音：按文本找音频文件，找不到时在后台从云端（OSS）下载，或用火山引擎生成并缓存。
///
/// 按配置音色查找：已生成的缓存 → 音色匹配的题库自带 / App 内置音频 → 音色匹配的云端缓存。
/// 没有指定音色时仍兼容按 key 文件名保存的旧音频。
/// 都没有时：家长配了自己的豆包账号且音色和云端不同，就用自己的账号生成；否则先从云端下载，云端没有再生成。
/// 缓存以音频文件是否存在为准，数据库里的 StoredSpeechClip 只是索引，方便查询和清理。
@MainActor
final class SpeechLibrary: ObservableObject {
    /// 语音合成账号设置；nil 表示没配置，只用预先生成的音频、云端语音和系统语音
    @Published private(set) var settings: TTSSettings?
    /// 还在排队等待下载或生成的条数
    @Published private(set) var pendingCount = 0
    /// 最近一次下载或生成失败的原因，成功后清空
    @Published private(set) var lastError: String?
    /// 云端语音清单里的句子数、已下载到本机的句子数；没配置云端时都是 0
    @Published private(set) var remoteTotal = 0
    @Published private(set) var remoteDownloaded = 0
    @Published private(set) var preparingRemote = false

    private let database: LearnDatabase?
    private let premadeDirectories: [URL]
    /// 各预先生成目录的清单；nil 表示这个目录没有新版清单
    private let premadeManifests: [SpeechManifest?]
    private let cacheDirectory: URL
    private let remote: RemoteSpeech?
    private var remoteRefreshed = false
    private var lastRefreshAttempt: Date?
    private var refreshing: Task<Void, Never>?
    /// 最近一次要预先准备的文本：云端清单更新后按它重新排队
    private var prepared: [String] = []
    private var waiting: [String] = []
    private var waitingKeys: Set<String> = []
    private var worker: Task<Void, Never>?
    /// 账号或参数有问题：停止生成，等家长改设置（云端下载不受影响）
    private var paused = false
    private var generationEnabled = true

    init(
        database: LearnDatabase?,
        settings: TTSSettings? = TTSKeychain.load(),
        premadeDirectories: [URL] = SpeechLibrary.defaultPremadeDirectories,
        cacheDirectory: URL = AppPaths.speechCacheDirectory,
        remote: RemoteSpeech.Config? = RemoteSpeech.Config.standard
    ) {
        self.database = database
        self.settings = settings
        self.premadeDirectories = premadeDirectories
        self.premadeManifests = premadeDirectories.map {
            SpeechManifest.load(from: $0.appendingPathComponent(SpeechManifest.fileName))
        }
        self.cacheDirectory = cacheDirectory
        self.remote = remote.map(RemoteSpeech.init)
        updateRemoteCounts()
    }

    nonisolated static var defaultPremadeDirectories: [URL] {
        [AppPaths.userPackAudioDirectory] + [Bundle.module.url(forResource: "Speech", withExtension: nil)].compactMap { $0 }
    }

    /// 能用家长的豆包账号生成
    var canGenerate: Bool { generationEnabled && settings?.isUsable == true }
    /// 配置了云端地址
    var hasRemote: Bool { remote != nil }
    /// 能从云端下载：选了豆包语音，且配置了云端地址
    var canDownload: Bool { generationEnabled && hasRemote }

    func setGenerationEnabled(_ enabled: Bool) {
        generationEnabled = enabled
        if !enabled {
            worker?.cancel()
            refreshing?.cancel()
            remote?.cancelDownload()
            lastRefreshAttempt = nil
            waiting.removeAll()
            waitingKeys.removeAll()
            pendingCount = 0
        }
    }

    // MARK: - 查找

    /// 这段文本可以直接播放的音频文件
    func audioFile(for text: String) -> URL? {
        if let file = cachedFile(for: text) ?? premadeFile(for: text) { return file }
        guard configuredVoice == nil || remote?.voice == configuredVoice else { return nil }
        return remote?.localFile(for: text)
    }

    private var configuredVoice: String? {
        guard let settings, settings.isUsable else { return nil }
        return settings.voiceTag
    }

    /// 朗读前短暂等待所选音色；共用下载/豆包生成队列，取消或超时后交给调用方兜底。
    func audioFileWhenReady(for text: String, timeout: Duration = .seconds(8)) async -> URL? {
        guard !Task.isCancelled else { return nil }
        if let file = audioFile(for: text) { return file }
        guard canGenerate || canDownload else { return nil }
        requestSoon(text)
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while clock.now < deadline, !Task.isCancelled {
            if let file = audioFile(for: text) { return file }
            if !preparingRemote, source(for: text) == nil { return nil }
            do { try await Task.sleep(for: .milliseconds(80)) }
            catch { return nil }
        }
        return Task.isCancelled ? nil : audioFile(for: text)
    }

    private func premadeFile(for text: String) -> URL? {
        let legacyName = SpeechText.fileName(for: text)
        let voice = configuredVoice ?? remote?.voice
        for (directory, manifest) in zip(premadeDirectories, premadeManifests) {
            guard voice == nil || manifest?.voice == voice else { continue }
            let candidates = [manifest?.path(for: text), legacyName].compactMap { $0 }
            for path in candidates {
                let url = directory.appendingPathComponent(path)
                if FileManager.default.fileExists(atPath: url.path) { return url }
            }
        }
        return nil
    }

    private func cachedFile(for text: String) -> URL? {
        guard let settings, settings.isUsable else { return nil }
        let url = cacheDirectory.appendingPathComponent(relativePath(for: text, voice: settings.voiceTag))
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// 缓存文件的相对路径：<音色目录>/<文本key>.mp3
    private func relativePath(for text: String, voice: String) -> String {
        "\(voiceFolder(voice))/\(SpeechText.fileName(for: text))"
    }

    private func voiceFolder(_ voice: String) -> String {
        String(SpeechText.key(for: voice).prefix(12))
    }

    /// 当前音色已缓存的条数（设置页显示）
    func cachedCount() -> Int {
        guard let settings else { return 0 }
        let folder = cacheDirectory.appendingPathComponent(voiceFolder(settings.voiceTag), isDirectory: true)
        return ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [])
            .filter { $0.hasSuffix(".\(SpeechText.audioExtension)") }.count
    }

    private func updateRemoteCounts() {
        let counts = remote?.counts() ?? (downloaded: 0, total: 0)
        remoteDownloaded = counts.downloaded
        remoteTotal = counts.total
    }

    // MARK: - 下载、生成

    /// 当前即将朗读的文本：排到最前面尽快下载或生成
    func requestSoon(_ text: String) {
        guard let text = SpeechText.normalize(text) else { return }
        // 清单尚未到达时也记住临时请求，否则刷新完成后只会重排启动时的题库文本。
        if !prepared.contains(text) { prepared.append(text) }
        refreshRemote()
        enqueue([text], first: true)
    }

    /// 预先准备一批文本（题库、固定提示语），已有的跳过
    func prepare(_ texts: [String]) {
        prepared = texts
        refreshRemote()
        enqueue(texts, first: false)
    }

    private enum Source {
        case remote(RemoteSpeech)
        case generate(TTSSettings)
    }

    /// 家长配了自己的豆包账号，且音色和云端不同：用自己的音色，保持前后一致
    private var prefersOwnVoice: Bool {
        guard canGenerate, let settings else { return false }
        return remote?.voice != settings.voiceTag
    }

    private func source(for text: String) -> Source? {
        if prefersOwnVoice, let settings { return paused ? nil : .generate(settings) }
        if let remote, canDownload, remote.has(text) { return .remote(remote) }
        if canGenerate, !paused, let settings { return .generate(settings) }
        return nil
    }

    /// 还需要下载或生成：已有合适的音频、或者没有来源时不用
    private func needsWork(_ text: String) -> Bool {
        if audioFile(for: text) != nil { return false }
        switch source(for: text) {
        case .remote(let remote): return remote.localFile(for: text) == nil
        case .generate: return true
        case nil: return false
        }
    }

    private func enqueue(_ texts: [String], first: Bool) {
        guard canGenerate || canDownload else { return }
        var added: [String] = []
        for text in SpeechText.unique(texts) where needsWork(text) {
            let key = SpeechText.key(for: text)
            if waitingKeys.contains(key) {
                if first, let index = waiting.firstIndex(of: text) { waiting.remove(at: index) } else { continue }
            }
            waitingKeys.insert(key)
            added.append(text)
        }
        guard !added.isEmpty else { return }
        waiting = first ? added + waiting : waiting + added
        pendingCount = waiting.count
        startWorker()
    }

    private func startWorker() {
        guard worker == nil, !waiting.isEmpty, canGenerate || canDownload else { return }
        worker = Task { [weak self] in
            await self?.drain()
        }
    }

    /// 一条一条下载或生成；每条都按当前设置决定来源
    private func drain() async {
        var client: (settings: TTSSettings, tts: VolcengineTTS)?
        var failures = 0
        while !waiting.isEmpty, !Task.isCancelled {
            let text = waiting.removeFirst()
            let key = SpeechText.key(for: text)
            defer {
                waitingKeys.remove(key)
                pendingCount = waiting.count
            }
            guard needsWork(text), let source = source(for: text) else { continue }
            do {
                switch source {
                case .remote(let remote):
                    try await remote.download(text)
                    updateRemoteCounts()
                case .generate(let settings):
                    if client?.settings != settings { client = (settings, VolcengineTTS(settings: settings)) }
                    let audio = try await client!.tts.synthesize(text)
                    // 生成期间家长改了设置：这段音频已经不是当前音色
                    guard self.settings == settings, !Task.isCancelled else { continue }
                    try store(audio, text: text, voice: settings.voiceTag)
                }
                failures = 0
                lastError = nil
            } catch {
                if Task.isCancelled { break }
                lastError = error.localizedDescription
                if (error as? TTSError)?.needsSettingsChange == true {
                    // 账号或参数有问题：之后只下载云端有的，不再生成
                    paused = true
                    continue
                }
                // 云端单个文件缺失不是网络问题，跳过这句继续
                if case RemoteSpeechError.http(404) = error { continue }
                // 连续失败多半是没网：这一轮先停，下次读到或重新进入时再试
                failures += 1
                if failures >= 3 { break }
            }
        }
        if failures >= 3 {
            waiting.removeAll()
            waitingKeys.removeAll()
            pendingCount = 0
        }
        worker = nil
        // 设置换了以后排进来的新任务
        if !waiting.isEmpty { startWorker() }
    }

    /// 家长主动重试不受自动重试间隔限制。
    func retryRemote() {
        guard canDownload, refreshing == nil else { return }
        remoteRefreshed = false
        lastRefreshAttempt = nil
        refreshRemote()
    }

    /// 准备云端语音包（自定义来源拉清单）；自动失败重试间隔一分钟。
    private func refreshRemote() {
        guard let remote, canDownload, !remoteRefreshed, refreshing == nil else { return }
        if let lastRefreshAttempt, Date().timeIntervalSince(lastRefreshAttempt) < 60 { return }
        lastRefreshAttempt = Date()
        preparingRemote = true
        refreshing = Task { [weak self] in
            defer {
                self?.refreshing = nil
                self?.preparingRemote = false
                if Task.isCancelled, self?.canDownload == true { self?.refreshRemote() }
            }
            do {
                let changed = try await remote.refreshManifest()
                guard let self, !Task.isCancelled else { return }
                self.remoteRefreshed = true
                self.lastError = nil
                self.updateRemoteCounts()
                if changed { self.enqueue(self.prepared, first: false) }
            } catch {
                if !Task.isCancelled { self?.lastError = error.localizedDescription }
            }
        }
    }

    private func store(_ audio: Data, text: String, voice: String) throws {
        let relative = relativePath(for: text, voice: voice)
        let url = cacheDirectory.appendingPathComponent(relative)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try audio.write(to: url, options: .atomic)
        do {
            try database?.saveSpeechClip(
                key: SpeechText.key(for: text), voice: voice, text: text, fileName: relative, bytes: audio.count)
        } catch {
            // 索引写失败不影响播放（以文件为准）
            print("语音缓存索引写入失败：\(error)")
        }
    }

    // MARK: - 设置

    /// 保存新设置。换了音色或语速时，删掉旧音色的缓存
    func update(_ newSettings: TTSSettings) -> Bool {
        guard TTSKeychain.save(newSettings) else { return false }
        let oldVoice = settings?.voiceTag
        settings = newSettings
        paused = false
        lastError = nil
        waiting.removeAll()
        waitingKeys.removeAll()
        pendingCount = 0
        if oldVoice != newSettings.voiceTag { removeCache(keepingVoice: newSettings.voiceTag) }
        return true
    }

    /// 清除账号设置和用账号生成的缓存，之后只用预先生成的音频、云端语音和系统语音
    func clear() {
        worker?.cancel()
        TTSKeychain.delete()
        settings = nil
        paused = false
        lastError = nil
        waiting.removeAll()
        waitingKeys.removeAll()
        pendingCount = 0
        removeCache(keepingVoice: nil)
    }

    /// 删掉用账号生成的缓存（云端下载的不动）
    private func removeCache(keepingVoice voice: String?) {
        do {
            try database?.deleteSpeechClips(exceptVoice: voice)
        } catch {
            print("语音缓存索引清理失败：\(error)")
        }
        let keep = voice.map(voiceFolder)
        let folders = (try? FileManager.default.contentsOfDirectory(atPath: cacheDirectory.path)) ?? []
        for folder in folders where folder != keep && folder != RemoteSpeech.folderName {
            try? FileManager.default.removeItem(at: cacheDirectory.appendingPathComponent(folder))
        }
    }
}
