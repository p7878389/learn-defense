import Foundation
import Testing
@testable import LearnCore

@Suite("开口朗读匹配与多听多说核心逻辑")
struct SpeechMatcherTests {
    @Test func englishWordAndSentenceFuzzyMatching() {
        #expect(SpeechMatcher.matches(spoken: "Apple!", expected: "apple"))
        #expect(SpeechMatcher.matches(spoken: "it is an apple", expected: "apple"))
        #expect(SpeechMatcher.matches(spoken: "aple", expected: "apple"))
        #expect(!SpeechMatcher.matches(spoken: "banana", expected: "apple"))

        #expect(SpeechMatcher.matches(spoken: "How old are you", expected: "How old are you?"))
        #expect(SpeechMatcher.matches(spoken: "how old you", expected: "How old are you?"))
        #expect(!SpeechMatcher.matches(spoken: "good morning", expected: "How old are you?"))
    }

    @Test func chineseHomophoneAndFuzzyMatching() {
        #expect(SpeechMatcher.matches(spoken: "早晨", expected: "早晨"))
        #expect(SpeechMatcher.matches(spoken: "我读陈", expected: "晨"))
        #expect(SpeechMatcher.matches(spoken: "春眠不觉小", expected: "春眠不觉晓"))
        #expect(!SpeechMatcher.matches(spoken: "大象", expected: "苹果"))
    }

    @Test func englishAndPoemQuestionsIncludePromptSpeechAndSpeakTarget() throws {
        let library = ContentLibrary.load(userDirectory: nil)
        let englishPacks = library.packs(grade: .g3, subject: .english)
        let pool = ItemPool(packs: englishPacks, selection: .all)
        let generator = QuestionGenerator(pool: pool, settings: GeneratorSettings(
            optionCount: 3, strategy: .easy, showHint: true, preschool: false))
        var rng = SeededRNG(state: 11)

        let wordItem = LearningItem.englishWord(EnglishWordItem(word: "apple", phonetic: "/ˈæpl/", meaning: "苹果"))
        var sawEnglishToMeaning = false
        for _ in 0..<40 {
            if let q = generator.makeQuestion(for: wordItem, using: &rng), q.kind == .englishToMeaning {
                sawEnglishToMeaning = true
                #expect(q.promptSpeech == "apple")
                #expect(q.speakTarget == "apple")
                #expect(q.isEnglishSpeaking)
            }
        }
        #expect(sawEnglishToMeaning)

        let sentenceItem = LearningItem.sentence(SentenceItem(sentence: "How old are you?", meaning: "你几岁了？"))
        let sq = try #require(generator.makeQuestion(for: sentenceItem, using: &rng))
        #expect(sq.promptSpeech == "How old are you?")
        #expect(sq.speakTarget == "How old are you?")
        #expect(sq.isEnglishSpeaking)
    }

    @Test func adventureVoiceBoostOnlyAppliesWhilePlaying() {
        var battle = AdventureBattle(level: AdventureCatalog.levels[0], difficulty: .normal)
        let beforeStartBoost = battle.grantVoiceBoost()
        #expect(!beforeStartBoost, "准备阶段不能领语音援军")
        let planted = battle.plant("inkling", lane: 2, column: 1)
        #expect(planted)
        let started = battle.start()
        #expect(started)
        let beforeSun = battle.sun
        let beforeEnergy = battle.energy
        let boosted = battle.grantVoiceBoost(sunBonus: 40, energyBonus: 2)
        #expect(boosted)
        #expect(battle.sun == beforeSun + 40)
        #expect(battle.energy == beforeEnergy + 2)
    }
}
