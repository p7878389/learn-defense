import AVFoundation
import Foundation
import LearnCore
import Testing
@testable import LearnGame

private final class RecordingSynthesizer: AVSpeechSynthesizer {
    var texts: [String] = []
    override func speak(_ utterance: AVSpeechUtterance) { texts.append(utterance.speechString) }
}

private actor DelayedSpeechServer {
    let manifest: Data
    private var continuation: CheckedContinuation<Data, Never>?
    private var releasedAudio: Data?
    private(set) var waiting = false

    init(text: String, nextText: String? = nil) throws {
        var clips = [text: "voice.mp3"]
        if let nextText { clips[nextText] = "next.mp3" }
        manifest = try SpeechManifest(voice: "test-voice", clips: clips).encoded()
    }

    func fetch(_ url: URL) async -> Data {
        if url.lastPathComponent == SpeechManifest.fileName { return manifest }
        if let releasedAudio { return releasedAudio }
        waiting = true
        return await withCheckedContinuation { continuation = $0 }
    }

    func release(_ audio: Data) {
        releasedAudio = audio
        continuation?.resume(returning: audio)
        continuation = nil
    }
}

@MainActor
@Suite("朗读遵循所选语音来源")
struct SpeechPlaybackTests {
    // 全量场景测试会长时间占用 MainActor；延迟下载用例保留释放时间，不测试网络超时长短。
    @Test(arguments: [Speech.Channel.question, .guidance, .preview])
    func missingDoubaoClipWaitsBeforePlaying(channel: Speech.Channel) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let text = "图中一共有几个红苹果？"
        let server = try DelayedSpeechServer(text: text)
        let remote = RemoteSpeech.Config(baseURL: URL(string: "https://example.com/voice/")!, directory: root,
                                         fetch: { await server.fetch($0) })
        let library = SpeechLibrary(database: nil, settings: nil, premadeDirectories: [], remote: remote)
        let system = RecordingSynthesizer()
        var played: [URL] = []
        let speech = Speech(library: library, synthesizer: system, audioPreparationTimeout: .seconds(120), makePlayer: { url in
            played.append(url)
            return try AVAudioPlayer(data: Data(contentsOf: url))
        })
        defer { speech.stop() }
        speech.speak(text, interrupt: true, channel: channel)
        for _ in 0..<200 {
            if await server.waiting { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(await server.waiting)
        #expect(system.texts.isEmpty, "豆包音频准备期间不应先用系统音色朗读")
        await server.release(AnswerFeedback.wave(correct: true))
        for _ in 0..<200 where played.isEmpty { try await Task.sleep(for: .milliseconds(10)) }
        #expect(played == [root.appendingPathComponent("voice.mp3")])
        #expect(system.texts.isEmpty)
    }

    @Test func stoppingWhilePreparingDoesNotPlayTheOldPrompt() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let server = try DelayedSpeechServer(text: "旧题目")
        let remote = RemoteSpeech.Config(baseURL: URL(string: "https://example.com/voice/")!, directory: root,
                                         fetch: { await server.fetch($0) })
        let library = SpeechLibrary(database: nil, settings: nil, premadeDirectories: [], remote: remote)
        let system = RecordingSynthesizer()
        var played: [URL] = []
        let speech = Speech(library: library, synthesizer: system, audioPreparationTimeout: .seconds(120), makePlayer: { url in
            played.append(url)
            return try AVAudioPlayer(data: Data(contentsOf: url))
        })
        speech.speak("旧题目", interrupt: true)
        for _ in 0..<200 {
            if await server.waiting { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(await server.waiting)
        speech.stop()
        await server.release(AnswerFeedback.wave(correct: true))
        for _ in 0..<200 where library.remoteDownloaded == 0 { try await Task.sleep(for: .milliseconds(10)) }
        try await Task.sleep(for: .milliseconds(100))
        #expect(played.isEmpty)
        #expect(system.texts.isEmpty)
    }

    @Test func systemSourceDoesNotPrepareDoubaoAudio() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let library = SpeechLibrary(database: nil, settings: nil, premadeDirectories: [], remote: nil)
        let system = RecordingSynthesizer()
        let speech = Speech(library: library, synthesizer: system)
        defer { speech.stop() }
        var preferences = ReaderPreferences()
        preferences.source = .system
        speech.apply(preferences)
        speech.speak("只用系统语音", interrupt: true)
        #expect(system.texts == ["只用系统语音"])
        #expect(library.pendingCount == 0)
    }

    @Test func queuedPromptsWaitForPlaybackInOrder() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let text = "第一句提示"
        let server = try DelayedSpeechServer(text: text, nextText: "第二句提示")
        let remote = RemoteSpeech.Config(baseURL: URL(string: "https://example.com/voice/")!, directory: root,
                                         fetch: { await server.fetch($0) })
        let library = SpeechLibrary(database: nil, settings: nil, premadeDirectories: [], remote: remote)
        let system = RecordingSynthesizer()
        var played: [URL] = []
        let speech = Speech(library: library, synthesizer: system, audioPreparationTimeout: .seconds(120), makePlayer: { url in
            played.append(url)
            return try AVAudioPlayer(data: Data(contentsOf: url))
        })
        defer { speech.stop() }
        speech.speak(text, interrupt: true)
        speech.speak("第二句提示", interrupt: false)
        for _ in 0..<200 {
            if await server.waiting { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(played.isEmpty && system.texts.isEmpty)
        await server.release(AnswerFeedback.wave(correct: true))
        for _ in 0..<200 where played.count < 2 { try await Task.sleep(for: .milliseconds(10)) }
        #expect(played == [root.appendingPathComponent("voice.mp3"), root.appendingPathComponent("next.mp3")])
        #expect(system.texts.isEmpty)
    }

    @Test func switchingToSystemCancelsPendingDoubaoPrompt() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let server = try DelayedSpeechServer(text: "切换前的提示")
        let remote = RemoteSpeech.Config(baseURL: URL(string: "https://example.com/voice/")!, directory: root,
                                         fetch: { await server.fetch($0) })
        let library = SpeechLibrary(database: nil, settings: nil, premadeDirectories: [], remote: remote)
        let system = RecordingSynthesizer()
        var played: [URL] = []
        let speech = Speech(library: library, synthesizer: system, audioPreparationTimeout: .seconds(120), makePlayer: { url in
            played.append(url)
            return try AVAudioPlayer(data: Data(contentsOf: url))
        })
        defer { speech.stop() }
        speech.speak("切换前的提示", interrupt: true)
        for _ in 0..<200 {
            if await server.waiting { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        var preferences = ReaderPreferences()
        preferences.source = .system
        speech.apply(preferences)
        speech.speak("切换后的提示", interrupt: true)
        await server.release(AnswerFeedback.wave(correct: true))
        try await Task.sleep(for: .milliseconds(150))
        #expect(played.isEmpty)
        #expect(system.texts == ["切换后的提示"])
    }

    @Test func unavailableDoubaoAudioStillFallsBackToSystem() async throws {
        let library = SpeechLibrary(database: nil, settings: nil, premadeDirectories: [], remote: nil)
        let system = RecordingSynthesizer()
        let speech = Speech(library: library, synthesizer: system)
        defer { speech.stop() }
        speech.speak("没有可用的豆包音频", interrupt: true)
        for _ in 0..<200 where system.texts.isEmpty { try await Task.sleep(for: .milliseconds(10)) }
        #expect(system.texts == ["没有可用的豆包音频"])
    }
}
