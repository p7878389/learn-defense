import Foundation
import Testing
@testable import LearnCore

@Suite("导入题库可出题性")
struct PackImportQuestionTests {
    @Test(arguments: [
        Lesson(id: "l1", title: "单字", characters: [CharacterItem(char: "晨", pinyin: "chén")]),
        Lesson(id: "l1", title: "单图", pictures: [PictureItem(text: "苹果", emoji: "🍎")]),
        Lesson(id: "l1", title: "单词", words: [WordItem(text: "早晨", pinyin: "zǎo chén")]),
        Lesson(id: "l1", title: "英语", englishWords: [EnglishWordItem(word: "apple", meaning: "苹果")]),
        Lesson(id: "l1", title: "句子", sentences: [SentenceItem(sentence: "Good morning.", meaning: "早上好。")]),
        Lesson(id: "l1", title: "诗句", poems: [PoemItem(title: "短诗", lines: ["甲乙", "丙丁戊"])]),
        Lesson(id: "l1", title: "选择", questions: [ChoiceItem(prompt: "选字", options: ["晨"], answer: "晨")])
    ])
    func rejectsContentWithoutUsableDistractors(lesson: Lesson) throws {
        let pack = ContentPack(id: "sparse", title: "稀疏题库", subject: .chinese, grade: .k2,
            units: [ContentUnit(id: "u1", title: "第一单元", lessons: [lesson])])
        let manager = PackManager(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        #expect(throws: SettingsError.self) { try manager.preview(JSONEncoder().encode(pack)) }
        #expect(manager.imported().isEmpty)
    }

    @Test func rejectsUnplayableItemEvenAlongsideValidQuestions() throws {
        let pack = ContentPack(id: "mixed", title: "混合题库", subject: .chinese, grade: .k2,
            units: [ContentUnit(id: "u1", title: "第一单元", lessons: [Lesson(id: "l1", title: "一课",
                characters: [CharacterItem(char: "晨", pinyin: "chén"), CharacterItem(char: "霜", pinyin: "shuāng")],
                pictures: [PictureItem(text: "苹果", emoji: "🍎")])])])
        let manager = PackManager(directory: FileManager.default.temporaryDirectory)
        #expect(throws: SettingsError.self) { try manager.preview(JSONEncoder().encode(pack)) }
    }

    @Test func rejectsEmptySelectableUnit() throws {
        let pack = ContentPack(id: "empty-unit", title: "空单元", subject: .chinese, grade: .g3, units: [
            ContentUnit(id: "u1", title: "空单元", lessons: []),
            ContentUnit(id: "u2", title: "有效单元", lessons: [Lesson(id: "l1", title: "一课",
                questions: [ChoiceItem(prompt: "选字", options: ["晨", "霜"], answer: "晨")])])])
        #expect(throws: SettingsError.self) {
            try PackManager(directory: FileManager.default.temporaryDirectory).preview(JSONEncoder().encode(pack))
        }
    }

    @Test func acceptsPreschoolDistractorsFromOtherUnits() throws {
        let pack = ContentPack(id: "cross-unit", title: "跨单元素材", subject: .chinese, grade: .k2, units: [
            ContentUnit(id: "u1", title: "第一单元", lessons: [Lesson(id: "l1", title: "一课",
                characters: [CharacterItem(char: "晨", pinyin: "chén")])]),
            ContentUnit(id: "u2", title: "第二单元", lessons: [Lesson(id: "l1", title: "一课",
                characters: [CharacterItem(char: "霜", pinyin: "shuāng")])])])
        let draft = try PackManager(directory: FileManager.default.temporaryDirectory).preview(JSONEncoder().encode(pack))
        #expect(draft.itemCount == 2)
        for unitID in ["u1", "u2"] {
            let pool = ItemPool(packs: [draft.pack], selection: .units(["cross-unit/\(unitID)"]))
            let generator = QuestionGenerator(pool: pool, settings: GameTuning.make(grade: .k2, difficulty: .easy).generator)
            var rng = SeededRNG(state: 42)
            let item = try #require(pool.items.first)
            let question = try #require(generator.makeQuestion(for: item, using: &rng))
            #expect(Set(question.options) == ["晨", "霜"])
        }
    }

    @Test func acceptsEveryBundledPack() throws {
        let manager = PackManager(directory: FileManager.default.temporaryDirectory)
        for pack in ContentLibrary.load(userDirectory: nil).packs {
            let draft = try manager.preview(JSONEncoder().encode(pack))
            #expect(draft.pack.id == pack.id)
        }
    }
}
