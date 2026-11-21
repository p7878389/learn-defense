import Foundation
import Testing
import LearnCore
@testable import LearnGame

/// 模拟 OSS：按 URL 返回内容，记下请求过的地址
private final class FakeOSS: @unchecked Sendable {
    private let lock = NSLock()
    private var files: [String: Data] = [:]
    private var requested: [String] = []

    func put(_ path: String, _ data: Data) {
        lock.withLock { files[path] = data }
    }

    var requests: [String] { lock.withLock { requested } }

    func fetch(_ url: URL) throws -> Data {
        let path = url.path.removingPercentEncoding ?? url.path
        return try lock.withLock {
            requested.append(path)
            guard let data = files[path] else { throw RemoteSpeechError.http(404) }
            return data
        }
    }
}

@MainActor
@Suite("语音库：云端下载与本机查找")
struct SpeechLibraryTests {
    private let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    private let base = URL(string: "https://oss.example.com/speech/v1/vv/")!
    private let voice = "seed-tts-2.0/zh/en/0"

    private func makeLibrary(oss: FakeOSS, settings: TTSSettings? = nil, premade: [URL] = []) -> SpeechLibrary {
        let config = RemoteSpeech.Config(
            baseURL: base,
            directory: root.appendingPathComponent("cache/remote"),
            fetch: { try oss.fetch($0) })
        return SpeechLibrary(database: nil, settings: settings, premadeDirectories: premade,
                             cacheDirectory: root.appendingPathComponent("cache"), remote: config)
    }

    private func publish(_ clips: [String: String], to oss: FakeOSS, voice: String? = nil) throws {
        let manifest = SpeechManifest(voice: voice ?? self.voice, clips: clips)
        oss.put("/speech/v1/vv/manifest.json", try manifest.encoded())
        for path in clips.values { oss.put("/speech/v1/vv/\(path)", Data("audio:\(path)".utf8)) }
    }

    /// 后台任务（拉清单、逐条下载）跑完
    private func settle(_ library: SpeechLibrary, until condition: () -> Bool) async {
        for _ in 0..<200 where !condition() {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    @Test func purchaseWaitsForHighQualityAudioAndCachesIt() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let oss = FakeOSS()
        let text = "买到掷石斥候啦，已经加入怪物队伍！"
        try publish([text: "game/purchase.mp3"], to: oss)
        let library = makeLibrary(oss: oss)
        // 全套 SpriteKit 测试会占用 MainActor；此处验证就绪返回，不测试网络时延。
        let ready = await library.audioFileWhenReady(for: text, timeout: .seconds(60))
        let file = try #require(ready)
        #expect(try Data(contentsOf: file) == Data("audio:game/purchase.mp3".utf8))
        #expect(library.audioFile(for: text) == file)
    }

    @Test func cancelledPurchaseDoesNotStartPreparation() async {
        defer { try? FileManager.default.removeItem(at: root) }
        let oss = FakeOSS()
        let library = makeLibrary(oss: oss)
        let task = Task { await library.audioFileWhenReady(for: "购买成功", timeout: .seconds(2)) }
        task.cancel()
        #expect(await task.value == nil)
        #expect(oss.requests.isEmpty)
    }

    @Test func downloadsListedTextsAndPlaysFromLocalCache() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let oss = FakeOSS()
        try publish(["阳光不够": "game/提示语/阳光不够.mp3", "How old are you?": "packs/e/u1/How old are you_.mp3"], to: oss)
        let library = makeLibrary(oss: oss)

        library.prepare(["阳光不够", "How old are you?", "云端没有的句子"])
        await settle(library) { library.remoteDownloaded == 2 && library.pendingCount == 0 }

        #expect(library.remoteTotal == 2)
        #expect(library.remoteDownloaded == 2)
        let file = try #require(library.audioFile(for: "How old are you?"))
        #expect(file.path.hasSuffix("cache/remote/packs/e/u1/How old are you_.mp3"))
        #expect(try Data(contentsOf: file) == Data("audio:packs/e/u1/How old are you_.mp3".utf8))
        #expect(library.audioFile(for: "云端没有的句子") == nil)
        #expect(!oss.requests.contains { $0.contains("云端没有") }, "清单里没有的句子不去请求")

        // 重新打开（离线）：用上次的清单找到已下载的音频
        let offline = makeLibrary(oss: FakeOSS())
        #expect(offline.audioFile(for: "阳光不够") != nil)
        #expect(offline.remoteDownloaded == 2)
    }

    @Test func voiceChangeOnServerClearsOldAudio() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let oss = FakeOSS()
        try publish(["阳光不够": "game/阳光不够.mp3"], to: oss)
        let first = makeLibrary(oss: oss)
        first.prepare(["阳光不够"])
        await settle(first) { first.remoteDownloaded == 1 }
        #expect(first.audioFile(for: "阳光不够") != nil)

        try publish(["阳光不够": "game/阳光不够.mp3"], to: oss, voice: "另一套音色")
        let second = makeLibrary(oss: oss)
        second.prepare([])
        await settle(second) { second.remoteDownloaded == 0 }
        #expect(second.remoteDownloaded == 0)
        #expect(second.audioFile(for: "阳光不够") == nil, "换了音色，旧音频要删掉重新下载")
    }

    @Test func premadeManifestAndLegacyKeyNamesAreBothFound() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let premade = root.appendingPathComponent("premade", isDirectory: true)
        try FileManager.default.createDirectory(at: premade.appendingPathComponent("game"), withIntermediateDirectories: true)
        try SpeechManifest(voice: voice, clips: ["你好": "game/你好.mp3"]).encoded()
            .write(to: premade.appendingPathComponent(SpeechManifest.fileName))
        try Data("a".utf8).write(to: premade.appendingPathComponent("game/你好.mp3"))
        try Data("b".utf8).write(to: premade.appendingPathComponent(SpeechText.fileName(for: "再见")))

        let library = SpeechLibrary(database: nil, settings: nil, premadeDirectories: [premade],
                                    cacheDirectory: root.appendingPathComponent("cache"), remote: nil)
        #expect(library.audioFile(for: "你好")?.lastPathComponent == "你好.mp3")
        #expect(library.audioFile(for: "再见")?.lastPathComponent == SpeechText.fileName(for: "再见"))
        #expect(library.audioFile(for: "没有") == nil)
        #expect(!library.hasRemote && !library.canDownload)
    }

    @Test func nothingIsFetchedWhenDoubaoVoiceIsOff() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let oss = FakeOSS()
        try publish(["阳光不够": "game/阳光不够.mp3"], to: oss)
        let library = makeLibrary(oss: oss, settings: TTSSettings(apiKey: "test-key"))
        library.setGenerationEnabled(false)
        library.prepare(["阳光不够"])
        #expect(library.pendingCount == 0, "选了系统语音时既不下载也不生成")
        #expect(!library.canDownload && !library.canGenerate)
        #expect(oss.requests.isEmpty)
    }
}
