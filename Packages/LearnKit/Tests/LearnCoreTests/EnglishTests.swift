import Foundation
import SwiftData
import Testing
@testable import LearnCore

@Suite("英语题库")
struct EnglishTests {
    static let library = ContentLibrary.load(userDirectory: nil)

    @Test func unitLevelWordsBecomeOneLesson() throws {
        let json = #"""
        {"schemaVersion":1,"id":"en","title":"en","subject":"english","grade":"g3",
         "units":[
          {"id":"u1","title":"Unit 1","associations":{"daily_scene":"x"},"phonics":"A a",
           "words":[{"word":"hello","phonetic":"/həˈləʊ/","meaning":"喂；你好"}],
           "sentences":[{"sentence":"Hi!","meaning":"嗨！"}]},
          {"id":"u2","title":"Unit 2",
           "lessons":[{"id":"l1","title":"L1","englishWords":[{"word":"pen","meaning":"钢笔"}]}],
           "words":[{"word":"ruler","meaning":"直尺"}]}
         ]}
        """#
        let pack = try ContentLibrary.decode(Data(json.utf8))
        let u1 = pack.units[0]
        #expect(u1.lessons.map(\.id) == ["l1"])
        #expect(u1.lessons[0].title == "Unit 1")
        #expect(u1.lessons[0].englishWords == [EnglishWordItem(word: "hello", phonetic: "/həˈləʊ/", meaning: "喂；你好")])
        #expect(u1.lessons[0].sentences.map(\.sentence) == ["Hi!"])
        // 已有课时，单元下的单词另成一课
        #expect(pack.units[1].lessons.map(\.id) == ["l1", "unit"])
        #expect(ContentLibrary.validate(pack).isEmpty)

        let keys = ItemPool(packs: [pack], selection: .all).items.map(\.key)
        #expect(keys == ["en:hello", "sentence:Hi!", "en:pen", "en:ruler"])
    }

    @Test func bundledEditionsLoad() throws {
        let packs = Self.library.packs(grade: .g3, subject: .english)
        #expect(Set(packs.map(\.id)) == ["english-g3-up-jingtong", "english-g3-up-pep"])
        let pep = try #require(Self.library.pack(id: "english-g3-up-pep"))
        #expect(pep.units.count == 6)
        #expect(pep.units.allSatisfy { $0.lessons.count == 1 })
        let pepItems = ItemPool(packs: [pep], selection: .all).items
        #expect(pepItems.filter { if case .englishWord = $0 { true } else { false } }.count == 70)
        #expect(pepItems.filter { if case .sentence = $0 { true } else { false } }.count == 25)
    }

    @Test func overlappingMeaningsAreNotDistractors() {
        #expect(QuestionGenerator.sharesMeaning("喂；你好", "嗨；你好"))
        #expect(QuestionGenerator.sharesMeaning("岁；旧的", "年；岁"))
        #expect(!QuestionGenerator.sharesMeaning("苹果", "香蕉"))

        let packs = Self.library.packs(grade: .g3, subject: .english)
        let pool = ItemPool(packs: packs, selection: .all)
        let generator = QuestionGenerator(pool: pool, settings: GeneratorSettings(
            optionCount: 4, strategy: .hard, showHint: true, preschool: false))
        let hello = LearningItem.englishWord(EnglishWordItem(word: "hello", phonetic: "/həˈləʊ/", meaning: "喂；你好"))
        var rng = SeededRNG(state: 7)
        var kinds: Set<QuestionKind> = []
        for _ in 0..<60 {
            guard let q = generator.makeQuestion(for: hello, using: &rng) else {
                Issue.record("hello 出不了题")
                return
            }
            kinds.insert(q.kind)
            #expect(!q.options.contains("嗨；你好") && !q.options.contains("hi"), "\(q.options)")
            switch q.kind {
            case .englishToMeaning:
                #expect(q.prompt == "hello" && q.answer == "喂；你好" && q.hint == "/həˈləʊ/")
            case .meaningToEnglish:
                #expect(q.prompt == "喂；你好" && q.answer == "hello")
            case .listenPickEnglish:
                #expect(q.promptSpeech == "hello" && q.answer == "hello")
            default:
                Issue.record("意外的题型 \(q.kind)")
            }
        }
        #expect(kinds == [.englishToMeaning, .meaningToEnglish, .listenPickEnglish])
    }

    @Test func sentenceQuestionAsksForMeaning() throws {
        let packs = Self.library.packs(grade: .g3, subject: .english)
        let pool = ItemPool(packs: packs, selection: .all)
        let generator = QuestionGenerator(pool: pool, settings: GeneratorSettings(
            optionCount: 3, strategy: .easy, showHint: true, preschool: false))
        let item = LearningItem.sentence(SentenceItem(sentence: "How old are you?", meaning: "你几岁了？"))
        var rng = SeededRNG(state: 1)
        let q = try #require(generator.makeQuestion(for: item, using: &rng))
        #expect(q.kind == .sentenceMeaning)
        #expect(q.prompt == "How old are you?" && q.answer == "你几岁了？")
        #expect(q.signText == "？")
        #expect(q.options.count == 3)
    }

    @Test func englishItemsSyncToDatabase() throws {
        let db = try LearnDatabase(url: nil)
        try db.syncContent(Self.library.packs)
        let apple = try db.items(key: "en:apple")
        // 两个版本都有 apple
        #expect(Set(apple.map(\.packID)) == ["english-g3-up-jingtong", "english-g3-up-pep"])
        #expect(apple.allSatisfy { $0.kind == "englishWord" && $0.text == "apple" && $0.pinyin == "/ˈæpl/" })
        #expect(apple.first { $0.packID == "english-g3-up-pep" }?.unitTitle == "Unit 4 Plants around us")
        #expect(try db.packs(grade: .g3, subject: .english).count == 2)
        let sentence = try db.items(key: "sentence:How old are you?")
        #expect(sentence.first?.kind == "sentence")
    }
}
