import Foundation
import Testing
@testable import LearnCore

@Suite("同音干扰项过滤与语音配置校验")
struct HomophoneDistractorTests {
    @Test func pinyinToWordExcludesHomophoneDistractorsWhenNonHomophonesExist() throws {
        let pack = ContentPack(
            id: "homophone-words",
            title: "同音词测试",
            subject: .chinese,
            grade: .g3,
            units: [ContentUnit(id: "u", title: "单元", lessons: [Lesson(
                id: "l",
                title: "课文",
                words: [
                    WordItem(text: "公式", pinyin: "gōng shì"),
                    WordItem(text: "攻势", pinyin: "gōng shì"),
                    WordItem(text: "春天", pinyin: "chūn tiān"),
                    WordItem(text: "大海", pinyin: "dà hǎi"),
                ]
            )])]
        )
        let pool = ItemPool(packs: [pack], selection: .all)
        let generator = QuestionGenerator(
            pool: pool,
            settings: GeneratorSettings(optionCount: 3, strategy: .normal, showHint: true, preschool: false)
        )
        let target = try #require(pool.items.first { $0.key == "word:公式" })
        var rng = SeededRNG(state: 7)
        for _ in 0..<20 {
            let q = try #require(generator.makeQuestion(for: target, mode: .choice, using: &rng))
            #expect(q.options.contains("公式"))
            #expect(!q.options.contains("攻势"), "看拼音选词不应把完全同音的词语放进干扰项")
        }
    }

    @Test(arguments: [DistractorStrategy.easy, .normal, .hard])
    func preschoolListenPickCharExcludesExactHomophonesAndFallsBackSafely(strategy: DistractorStrategy) throws {
        let pack = ContentPack(
            id: "homophone-chars",
            title: "同音字测试",
            subject: .chinese,
            grade: .k2,
            units: [ContentUnit(id: "u", title: "单元", lessons: [Lesson(
                id: "l",
                title: "识字",
                characters: [
                    CharacterItem(char: "工", pinyin: "gōng"),
                    CharacterItem(char: "公", pinyin: "gōng"),
                    CharacterItem(char: "水", pinyin: "shuǐ"),
                    CharacterItem(char: "火", pinyin: "huǒ"),
                ]
            )])]
        )
        let pool = ItemPool(packs: [pack], selection: .all)
        let generator = QuestionGenerator(
            pool: pool,
            settings: GeneratorSettings(optionCount: 3, strategy: strategy, showHint: true, preschool: true, ladder: 0...1)
        )
        let target = try #require(pool.items.first { $0.key == "char:工" })
        var rng = SeededRNG(state: 19)
        for _ in 0..<20 {
            let q = try #require(generator.makeQuestion(for: target, stats: nil, using: &rng))
            #expect(q.options.contains("工"))
            #expect(!q.options.contains("公"), "单音听音题不应放入完全同音的干扰字")
        }

        // 极小池只有两个同音字时仍能安全回退生成，不崩溃返回 nil
        let tinyPack = ContentPack(
            id: "tiny",
            title: "微型池",
            subject: .chinese,
            grade: .k2,
            units: [ContentUnit(id: "u", title: "单元", lessons: [Lesson(
                id: "l",
                title: "识字",
                characters: [CharacterItem(char: "工", pinyin: "gōng"), CharacterItem(char: "公", pinyin: "gōng")]
            )])]
        )
        let tinyPool = ItemPool(packs: [tinyPack], selection: .all)
        let tinyGen = QuestionGenerator(
            pool: tinyPool,
            settings: GeneratorSettings(optionCount: 3, strategy: strategy, showHint: true, preschool: true, ladder: 0...1)
        )
        let tinyTarget = try #require(tinyPool.items.first { $0.key == "char:工" })
        #expect(tinyGen.makeQuestion(for: tinyTarget, stats: nil, using: &rng) != nil)
    }

    @Test func ttsSettingsDetectsVersionMismatchBetweenModel1AndUranusSpeakers() {
        var settings = TTSSettings(apiKey: "key")
        #expect(settings.hasModelSpeakerMismatch == false)
        settings.resourceID = "seed-tts-1.0"
        #expect(settings.hasModelSpeakerMismatch == true)
        settings.speaker = "BV001_streaming"
        settings.englishSpeaker = "BV503_streaming"
        #expect(settings.hasModelSpeakerMismatch == false)
    }
}
