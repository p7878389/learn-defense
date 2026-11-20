import Foundation
import Testing
@testable import LearnCore

@Suite("语音目录规划")
struct SpeechCatalogTests {
    static let packs = ContentLibrary.load(userDirectory: nil).packs

    @Test func coversSameTextsAsSpeechText() {
        let clips = SpeechCatalog.clips(packs: Self.packs, includeGameLines: true)
        let expected = SpeechText.unique(SpeechText.gameLines + SpeechText.texts(in: Self.packs))
        #expect(clips.map(\.text) == expected)
    }

    @Test func pathsAreUniqueReadableAndSafe() {
        let clips = SpeechCatalog.clips(packs: Self.packs, includeGameLines: true)
        let lowered = clips.map { $0.path.lowercased() }
        #expect(Set(lowered).count == clips.count, "不区分大小写时也不能重名")
        for clip in clips {
            #expect(clip.path.hasSuffix(".mp3"))
            #expect(!clip.path.split(separator: "/").contains(".."))
            #expect(!clip.path.contains { "\\:*?\"<>|#%".contains($0) }, "\(clip.path)")
        }
        #expect(clips.first { $0.text == SpeechText.Line.notEnoughSun }?.path == "game/提示语/阳光不够.mp3")
    }

    @Test func packTextsGoToFirstLessonFolder() throws {
        let pack = try #require(Self.packs.first { $0.id == "chinese-g3-up-pep" })
        let unit = try #require(pack.units.first)
        let lesson = try #require(unit.lessons.first)
        let clips = SpeechCatalog.clips(packs: [pack], includeGameLines: false)
        let folder = "packs/chinese-g3-up-pep_\(SpeechCatalog.segment(pack.title))/u1_\(SpeechCatalog.segment(unit.title))/l1_\(lesson.title)/"
        #expect(clips.first?.path.hasPrefix(folder) == true, "\(clips.first?.path ?? "")")
    }

    @Test func unitLevelEnglishLessonUsesUnitFolder() throws {
        let pack = try #require(Self.packs.first { $0.id == "english-g3-up-pep" })
        let clips = SpeechCatalog.clips(packs: [pack], includeGameLines: false)
        let path = try #require(clips.first?.path)
        #expect(path.split(separator: "/").count == 4, "packs/<题库>/<单元>/<文本>.mp3：\(path)")
    }

    @Test func layoutHandlesDuplicatesCollisionsAndLongText() {
        let long = String(repeating: "长", count: 60)
        let clips = SpeechCatalog.layout([
            (folder: "a", texts: ["Apple", " Apple ", "apple", "a/b?", long]),
            (folder: "b", texts: ["Apple", "新的"]),
        ])
        #expect(clips.map(\.text) == ["Apple", "apple", "a/b?", long, "新的"], "重复的文本只存一份")
        #expect(clips[0].path == "a/Apple.mp3")
        #expect(clips[1].path == "a/apple~\(SpeechText.key(for: "apple").prefix(8)).mp3", "大小写不同的文件名要区分开")
        #expect(clips[2].path == "a/a_b_.mp3")
        #expect(clips[3].path == "a/\(String(repeating: "长", count: 40))~\(SpeechText.key(for: long).prefix(8)).mp3")
        #expect(clips[4].path == "b/新的.mp3")
    }

    @Test func segmentCleansNames() {
        #expect(SpeechCatalog.segment("  How old\nare  you? ") == "How old are you_")
        #expect(SpeechCatalog.segment("...") == "_")
        #expect(SpeechCatalog.segment("第一单元 · 校园生活") == "第一单元 · 校园生活")
        #expect(SpeechCatalog.folder(id: "u1", title: "") == "u1")
    }

    @Test func manifestRoundTripsAndRejectsLegacyFormat() throws {
        let manifest = SpeechManifest(voice: "v", clips: ["你好": "game/提示语/你好.mp3"])
        let decoded = try #require(SpeechManifest.decode(manifest.encoded()))
        #expect(decoded == manifest)
        #expect(decoded.path(for: " 你好\n") == "game/提示语/你好.mp3")
        // 旧版清单是「文件名 → 文本」，不认，按 key 文件名查找
        let legacy = try JSONEncoder().encode(["670d9743542cae3ea7ebe36af56bd536.mp3": "你好"])
        #expect(SpeechManifest.decode(legacy) == nil)
    }
}
