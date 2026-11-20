import Foundation
import CryptoKit
import Testing
import LearnCore
@testable import LearnGame

private final class ArchiveServer: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    var requests: Int { lock.withLock { count } }
    var failFirst = false
    let data = Data(base64Encoded: SpeechArchiveTests.fixtures["valid"]!)!
    var hash: String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }

    func download(_ url: URL) async throws -> URL {
        let attempt = lock.withLock { count += 1; return count }
        if failFirst && attempt == 1 { throw URLError(.notConnectedToInternet) }
        try await Task.sleep(nanoseconds: 50_000_000)
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".zip")
        try data.write(to: file)
        return file
    }
}

@MainActor
struct RemoteSpeechArchiveTests {
    private let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    private func config(_ server: ArchiveServer) -> RemoteSpeech.Config {
        RemoteSpeech.Config(baseURL: URL(string: "https://example.com/voice/")!, directory: root,
                            fetch: { _ in throw URLError(.unsupportedURL) },
                            archive: .init(url: URL(string: "https://example.com/voice.zip")!, sha256: server.hash),
                            downloadArchive: { try await server.download($0) })
    }

    @Test func concurrentRequestsInstallOnceAndRestartNeedsNoNetwork() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let server = ArchiveServer()
        let remote = RemoteSpeech(config(server))
        async let one = remote.refreshManifest()
        async let two = remote.refreshManifest()
        _ = try await (one, two)
        #expect(server.requests == 1)
        #expect(remote.counts().downloaded == 2)
        #expect(try Data(contentsOf: #require(remote.localFile(for: "你好"))) == Data("hello-audio".utf8))
        let reopened = RemoteSpeech(config(server))
        #expect(reopened.localFile(for: "再见") != nil)
        _ = try await reopened.refreshManifest()
        #expect(server.requests == 1)
        try FileManager.default.removeItem(at: #require(reopened.localFile(for: "再见")))
        try await reopened.download("再见")
        #expect(server.requests == 2)
        #expect(reopened.counts().downloaded == 2)
    }

    @Test func cancellationKeepsLegacyFilesAndAllowsRetry() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let server = ArchiveServer()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try SpeechManifest(voice: "legacy", clips: ["旧句": "old.mp3"]).encoded().write(to: root.appendingPathComponent("manifest.json"))
        try Data("old".utf8).write(to: root.appendingPathComponent("old.mp3"))
        let remote = RemoteSpeech(config(server))
        let task = Task { try await remote.refreshManifest() }
        while server.requests == 0 { await Task.yield() }
        remote.cancelDownload()
        do { _ = try await task.value; Issue.record("取消下载应失败") } catch { }
        #expect(remote.localFile(for: "旧句") != nil)
        _ = try await remote.refreshManifest()
        #expect(remote.counts().downloaded == 2)
    }

    @Test func libraryCountsWholePackAndRespectsSystemVoice() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let server = ArchiveServer()
        let library = SpeechLibrary(database: nil, settings: nil, premadeDirectories: [], remote: config(server))
        library.setGenerationEnabled(false)
        library.prepare(["你好"])
        try await Task.sleep(nanoseconds: 70_000_000)
        #expect(server.requests == 0)
        library.setGenerationEnabled(true)
        library.prepare(["你好"])
        for _ in 0..<200 where library.remoteDownloaded != 2 { try await Task.sleep(nanoseconds: 10_000_000) }
        #expect(library.remoteDownloaded == 2)
        #expect(library.remoteTotal == 2)
        #expect(library.audioFile(for: "再见") != nil, "未排队的句子也随整包安装")
        #expect(server.requests == 1)
    }
    @Test func failedDownloadCanBeRetriedImmediately() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let server = ArchiveServer()
        server.failFirst = true
        let library = SpeechLibrary(database: nil, settings: nil, premadeDirectories: [], remote: config(server))
        library.prepare(["你好"])
        for _ in 0..<200 where library.lastError == nil { try await Task.sleep(nanoseconds: 10_000_000) }
        #expect(library.lastError != nil)
        #expect(library.remoteDownloaded == 0)
        library.retryRemote()
        for _ in 0..<200 where library.remoteDownloaded != 2 { try await Task.sleep(nanoseconds: 10_000_000) }
        #expect(library.remoteDownloaded == 2)
        #expect(library.lastError == nil)
        #expect(!library.preparingRemote)
    }

    @Test func switchingOffDuringDownloadStopsAndCanResume() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let server = ArchiveServer()
        let library = SpeechLibrary(database: nil, settings: nil, premadeDirectories: [], remote: config(server))
        library.prepare(["你好"])
        while server.requests == 0 { await Task.yield() }
        library.setGenerationEnabled(false)
        for _ in 0..<200 where library.preparingRemote { try await Task.sleep(nanoseconds: 10_000_000) }
        #expect(library.remoteDownloaded == 0)
        #expect(library.lastError == nil)
        #expect(!library.preparingRemote)
        library.setGenerationEnabled(true)
        library.prepare(["你好"])
        for _ in 0..<200 where library.remoteDownloaded != 2 { try await Task.sleep(nanoseconds: 10_000_000) }
        #expect(library.remoteDownloaded == 2)
    }

}
