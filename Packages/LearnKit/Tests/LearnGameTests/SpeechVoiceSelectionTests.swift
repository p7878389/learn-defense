import Foundation
import LearnCore
import Testing
@testable import LearnGame

@MainActor
@Suite("语音缓存按配置音色选择")
struct SpeechVoiceSelectionTests {
    private let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    private let text = "看一看，这是什么？"

    private func writeAudio(in directory: URL, voice: String, content: String) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try SpeechManifest(voice: voice, clips: [text: "clip.mp3"]).encoded()
            .write(to: directory.appendingPathComponent(SpeechManifest.fileName))
        let file = directory.appendingPathComponent("clip.mp3")
        try Data(content.utf8).write(to: file)
        return file
    }

    @Test(arguments: [false, true])
    func configuredVoiceRejectsOtherPremadeAndRemoteVoices(hasOwnCache: Bool) throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let settings = TTSSettings(apiKey: "fixture-key", speaker: "configured-speaker")
        let premade = root.appendingPathComponent("premade")
        let remoteDirectory = root.appendingPathComponent("remote")
        _ = try writeAudio(in: premade, voice: "old-voice", content: "old premade")
        _ = try writeAudio(in: remoteDirectory, voice: "other-remote-voice", content: "other remote")
        let cache = root.appendingPathComponent("cache")
        let ownFile = cache.appendingPathComponent(String(SpeechText.key(for: settings.voiceTag).prefix(12)))
            .appendingPathComponent(SpeechText.fileName(for: text))
        if hasOwnCache {
            try FileManager.default.createDirectory(at: ownFile.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data("configured voice".utf8).write(to: ownFile)
        }
        let remote = RemoteSpeech.Config(baseURL: URL(string: "https://example.com/voice/")!, directory: remoteDirectory)
        let library = SpeechLibrary(database: nil, settings: settings, premadeDirectories: [premade],
                                    cacheDirectory: cache, remote: remote)
        #expect(library.audioFile(for: text) == (hasOwnCache ? ownFile : nil), "不能让其他音色的音频盖过已配置音色")
    }

    @Test func mismatchedPremadeDoesNotPreventConfiguredVoiceGeneration() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let premade = root.appendingPathComponent("premade")
        _ = try writeAudio(in: premade, voice: "old-voice", content: "old premade")
        let library = SpeechLibrary(database: nil, settings: TTSSettings(apiKey: "fixture-key", speaker: "configured-speaker"),
                                    premadeDirectories: [premade], cacheDirectory: root.appendingPathComponent("cache"), remote: nil)
        defer { library.setGenerationEnabled(false) }
        library.prepare([text])
        #expect(library.pendingCount == 1, "缺少所选音色的音频时仍需要生成，不能被旧内置音频拦住")
    }

    @Test func matchingPremadeVoiceRemainsAvailable() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let settings = TTSSettings(apiKey: "fixture-key")
        let premade = root.appendingPathComponent("premade")
        let file = try writeAudio(in: premade, voice: settings.voiceTag, content: "matching voice")
        let library = SpeechLibrary(database: nil, settings: settings, premadeDirectories: [premade],
                                    cacheDirectory: root.appendingPathComponent("cache"), remote: nil)
        #expect(library.audioFile(for: text) == file)
    }
}
