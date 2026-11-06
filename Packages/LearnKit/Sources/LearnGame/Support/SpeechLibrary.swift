import Foundation
import LearnCore

/// 预先生成的高质量语音：按文本找音频文件，找不到时在后台用火山引擎生成并缓存。
///
/// 查找顺序：题库自带（Documents/Packs/Audio）→ App 内置（Resources/Speech）→ 运行时缓存。
/// 缓存以音频文件是否存在为准，数据库里的 StoredSpeechClip 只是索引，方便查询和清理。
@MainActor
final class SpeechLibrary: ObservableObject {
    /// 语音合成账号设置；nil 表示没配置，只用预先生成的音频和系统语音
    @Published private(set) var settings: TTSSettings?
    /// 还在排队等待生成的条数
    @Published private(set) var pendingCount = 0
    /// 最近一次生成失败的原因，成功后清空
    @Published private(set) var lastError: String?

    private let database: LearnDatabase?
    private let premadeDirectories: [URL]
    private let cacheDirectory: URL
    private var waiting: [String] = []
    private var waitingKeys: Set<String> = []
    private var worker: Task<Void, Never>?
    /// 账号或参数有问题：停止生成，等家长改设置
    private var paused = false
    private var generationEnabled = true

    init(
        database: LearnDatabase?,
        settings: TTSSettings? = TTSKeychain.load(),
        premadeDirectories: [URL] = SpeechLibrary.defaultPremadeDirectories,
        cacheDirectory: URL = AppPaths.speechCacheDirectory
    ) {
        self.database = database
        self.settings = settings
        self.premadeDirectories = premadeDirectories
        self.cacheDirectory = cacheDirectory
    }

    nonisolated static var defaultPremadeDirectories: [URL] {
        [AppPaths.userPackAudioDirectory] + [Bundle.module.url(forResource: "Speech", withExtension: nil)].compactMap { $0 }
    }

    var canGenerate: Bool { generationEnabled && settings?.isUsable == true }

    func setGenerationEnabled(_ enabled: Bool) {
        generationEnabled = enabled
        if !enabled {
            worker?.cancel()
            waiting.removeAll()
            waitingKeys.removeAll()
            pendingCount = 0
        }
    }

    // MARK: - 查找

    /// 这段文本可以直接播放的音频文件
    func audioFile(for text: String) -> URL? {
        premadeFile(for: text) ?? cachedFile(for: text)
    }

    private func premadeFile(for text: String) -> URL? {
        let name = SpeechText.fileName(for: text)
        return premadeDirectories
            .map { $0.appendingPathComponent(name) }
            .first { FileManager.default.fileExists(atPath: $0.path) }
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

    // MARK: - 生成

    /// 刚才没找到音频、用系统语音读了的文本：排到最前面尽快生成
    func requestSoon(_ text: String) {
        enqueue([text], first: true)
    }

    /// 预先生成一批文本（题库、固定提示语），已有的跳过
    func prepare(_ texts: [String]) {
        enqueue(texts, first: false)
    }

    private func enqueue(_ texts: [String], first: Bool) {
        guard canGenerate, !paused else { return }
        var added: [String] = []
        for text in SpeechText.unique(texts) where audioFile(for: text) == nil {
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
        guard worker == nil, !waiting.isEmpty, let settings, settings.isUsable else { return }
        worker = Task { [weak self] in
            await self?.drain(with: settings)
        }
    }

    /// 一条一条生成；设置变了就停下，由新设置重新排队
    private func drain(with settings: TTSSettings) async {
        let client = VolcengineTTS(settings: settings)
        var failures = 0
        while !waiting.isEmpty, self.settings == settings, !paused, !Task.isCancelled {
            let text = waiting.removeFirst()
            let key = SpeechText.key(for: text)
            defer {
                waitingKeys.remove(key)
                pendingCount = waiting.count
            }
            do {
                let audio = try await client.synthesize(text)
                guard self.settings == settings, !Task.isCancelled else { break }
                try store(audio, text: text, voice: settings.voiceTag)
                failures = 0
                lastError = nil
            } catch {
                lastError = error.localizedDescription
                if (error as? TTSError)?.needsSettingsChange == true {
                    paused = true
                    break
                }
                // 连续失败多半是没网：这一轮先停，下次读到或重新进入时再试
                failures += 1
                if failures >= 3 { break }
            }
        }
        if paused || failures >= 3 {
            waiting.removeAll()
            waitingKeys.removeAll()
            pendingCount = 0
        }
        worker = nil
        // 设置换了以后排进来的新任务
        if canGenerate, !paused, !waiting.isEmpty { startWorker() }
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

    /// 清除账号设置和全部缓存，之后只用预先生成的音频和系统语音
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

    private func removeCache(keepingVoice voice: String?) {
        do {
            try database?.deleteSpeechClips(exceptVoice: voice)
        } catch {
            print("语音缓存索引清理失败：\(error)")
        }
        let keep = voice.map(voiceFolder)
        let folders = (try? FileManager.default.contentsOfDirectory(atPath: cacheDirectory.path)) ?? []
        for folder in folders where folder != keep {
            try? FileManager.default.removeItem(at: cacheDirectory.appendingPathComponent(folder))
        }
    }
}
