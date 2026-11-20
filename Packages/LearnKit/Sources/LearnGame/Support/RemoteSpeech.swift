import Foundation
import LearnCore

/// 云端语音（阿里云 OSS，公共读，可以挂 CDN）：开发者用 speech-pack 生成一次、上传，所有设备按需下载。
///
/// OSS 上每套音色一个目录，目录下是 manifest.json 和按业务分类、以文本命名的音频（见 SpeechCatalog）。
/// 标准配置下载整包 ZIP，校验解压后按「文本 → 路径」播放，之后离线也能使用。
/// App 里不放任何 AccessKey。
enum SpeechRemoteConfig {
    /// 音色目录的地址（manifest.json 所在目录）。
    /// 留空（nil）时不访问云端。
    static let baseURL: URL? = URL(string: "https://learn-games.oss-cn-hangzhou.aliyuncs.com/speech/v1/vv-jenny-r0/")
    static let archive = RemoteSpeech.ArchiveSource(
        url: URL(string: "https://learn-games.oss-cn-hangzhou.aliyuncs.com/speech/v1/vv-jenny-r0.zip")!,
        sha256: "eb19deaac4024c69a2eeb0f49948b51399f38f8b61c6dba158019126bfecec35")
}

enum RemoteSpeechError: LocalizedError {
    case http(Int)
    case badManifest

    var errorDescription: String? {
        switch self {
        case .http(let status): "云端语音下载失败（HTTP \(status)）"
        case .badManifest: "云端语音清单格式不对"
        }
    }
}

/// 云端语音的清单和本机缓存；ZIP 使用完整快照，旧版平铺缓存仍可读取。
@MainActor
final class RemoteSpeech {
    typealias Fetch = @Sendable (URL) async throws -> Data
    typealias DownloadArchive = @Sendable (URL) async throws -> URL

    struct ArchiveSource: Sendable {
        let url: URL
        let sha256: String
    }

    struct Config {
        var baseURL: URL
        var directory: URL
        var fetch: Fetch = { try await RemoteSpeech.download($0) }
        /// nil 保留自定义来源的单文件下载兼容；标准配置使用 ZIP。
        var archive: ArchiveSource?
        /// 返回调用方负责删除的临时文件。
        var downloadArchive: DownloadArchive = { try await RemoteSpeech.downloadArchive($0) }

        /// 按 SpeechRemoteConfig 配置；没配地址时为 nil
        static var standard: Config? {
            SpeechRemoteConfig.baseURL.map {
                Config(baseURL: $0, directory: AppPaths.speechCacheDirectory.appendingPathComponent(RemoteSpeech.folderName),
                       archive: SpeechRemoteConfig.archive)
            }
        }
    }

    /// 本机缓存放在语音缓存目录下的这个子目录里；清理豆包生成的缓存时要跳过它
    nonisolated static let folderName = "remote"

    let baseURL: URL
    let directory: URL
    private let fetch: Fetch
    private let archive: ArchiveSource?
    private let downloadArchive: DownloadArchive
    private var installation: Task<SpeechArchive.Installed, Error>?
    private var audioDirectory: URL
    private(set) var manifest: SpeechManifest?

    init(_ config: Config) {
        baseURL = config.baseURL.hasDirectoryPath ? config.baseURL : config.baseURL.appendingPathComponent("", isDirectory: true)
        directory = config.directory
        fetch = config.fetch
        archive = config.archive
        downloadArchive = config.downloadArchive
        audioDirectory = config.directory
        // 先用上次下载的清单，离线时也能找到已下载的音频
        manifest = SpeechManifest.load(from: manifestFile).map(Self.sanitized)
        if config.archive != nil, let installed = SpeechArchive.current(in: directory) {
            audioDirectory = installed.directory
            manifest = installed.manifest
        }
    }

    private var manifestFile: URL { directory.appendingPathComponent(SpeechManifest.fileName) }

    var voice: String? { manifest?.voice }

    func has(_ text: String) -> Bool { manifest?.path(for: text) != nil }

    /// 已下载到本机的音频
    func localFile(for text: String) -> URL? {
        guard let path = manifest?.path(for: text) else { return nil }
        let url = audioDirectory.appendingPathComponent(path)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// 清单里的句子数、已下载的句子数（设置页显示）
    func counts() -> (downloaded: Int, total: Int) {
        guard let manifest else { return (0, 0) }
        let downloaded = manifest.clips.values.filter {
            FileManager.default.fileExists(atPath: audioDirectory.appendingPathComponent($0).path)
        }.count
        return (downloaded, manifest.clips.count)
    }

    /// 拉取最新清单。音色变了就清掉旧音频，路径变了就删掉不再用到的文件。返回清单是否有变化
    @discardableResult
    func refreshManifest() async throws -> Bool {
        if let archive {
            let oldManifest = manifest
            if let installed = SpeechArchive.current(in: directory, sha256: archive.sha256) {
                audioDirectory = installed.directory
                manifest = installed.manifest
                return oldManifest != manifest
            }
            if installation == nil {
                let download = downloadArchive
                let root = directory
                installation = Task {
                    let file = try await download(archive.url)
                    defer { try? FileManager.default.removeItem(at: file) }
                    try Task.checkCancellation()
                    let extraction = Task.detached(priority: .utility) {
                        try SpeechArchive.install(file, sha256: archive.sha256, in: root)
                    }
                    return try await withTaskCancellationHandler {
                        try await extraction.value
                    } onCancel: {
                        extraction.cancel()
                    }
                }
            }
            defer { installation = nil }
            let installed = try await installation!.value
            audioDirectory = installed.directory
            manifest = installed.manifest
            return true
        }
        let data = try await fetch(baseURL.appendingPathComponent(SpeechManifest.fileName))
        guard let fresh = SpeechManifest.decode(data).map(Self.sanitized) else { throw RemoteSpeechError.badManifest }
        guard fresh != manifest else { return false }
        let voiceChanged = manifest?.voice != fresh.voice
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: manifestFile, options: .atomic)
        manifest = fresh
        removeUnlisted(keepingAny: !voiceChanged)
        return true
    }

    /// 下载一句话的音频到本机缓存
    func download(_ text: String) async throws {
        if archive != nil {
            if localFile(for: text) == nil { _ = try await refreshManifest() }
            return
        }
        guard let path = manifest?.path(for: text) else { return }
        let data = try await fetch(baseURL.appendingPathComponent(path))
        // 下载期间清单换了（换音色等），这份音频已经不对了
        guard manifest?.path(for: text) == path else { return }
        let url = directory.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    func cancelDownload() {
        installation?.cancel()
    }

    /// 删掉清单里没有的音频。keepingAny 为 false 时（换了音色）全部删掉
    private func removeUnlisted(keepingAny: Bool) {
        let listed = keepingAny ? Set(manifest?.clips.values.map { $0 } ?? []) : []
        let root = directory.resolvingSymlinksInPath().path
        let files = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL } ?? []
        for file in files where file.pathExtension == SpeechText.audioExtension {
            let relative = String(file.resolvingSymlinksInPath().path.dropFirst(root.count + 1))
            if !listed.contains(relative) { try? FileManager.default.removeItem(at: file) }
        }
    }

    /// 清单来自网络：去掉绝对路径、带 `..` 的路径，防止写到缓存目录外面
    static func sanitized(_ manifest: SpeechManifest) -> SpeechManifest {
        var result = manifest
        result.clips = manifest.clips.filter { _, path in
            !path.isEmpty && !path.hasPrefix("/") && !path.split(separator: "/").contains("..")
        }
        return result
    }

    nonisolated static func download(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.httpMethod = "GET"
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw RemoteSpeechError.http(http.statusCode)
        }
        return data
    }

    /// 大包下载到磁盘，避免把 ZIP 和解压结果同时留在内存中。
    nonisolated static func downloadArchive(_ url: URL) async throws -> URL {
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 120)
        let (file, response) = try await URLSession.shared.download(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            try? FileManager.default.removeItem(at: file)
            throw RemoteSpeechError.http((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return file
    }
}
