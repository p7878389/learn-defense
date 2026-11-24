import Foundation
import Testing
@testable import LearnCore

@Suite("幼儿园题阶")
struct PreschoolLadderTests {
    private func generator(grade: Grade = .k3, difficulty: Difficulty = .hard) throws -> QuestionGenerator {
        let packs = ContentLibrary.load(userDirectory: nil).packs(grade: grade, subject: .chinese)
            .sorted { $0.id > $1.id }
        return QuestionGenerator(pool: ItemPool(packs: packs, selection: .all),
                                 settings: GameTuning.make(grade: grade, difficulty: difficulty).generator)
    }

    private func character(_ text: String, in generator: QuestionGenerator) throws -> CharacterItem {
        try #require(generator.pool.characters.first { $0.char == text })
    }

    @Test func levelFollowsStreakAndWrongAnswersResetIt() {
        let progress = ProgressStore()
        let item = LearningItem.character(CharacterItem(char: "水", pinyin: "shuǐ"))
        #expect(PreschoolLadder.level(nil) == 0)
        for expected in [1, 2, 3, 3, 3] {
            progress.record(item, correct: true)
            #expect(PreschoolLadder.level(progress.stats[item.key]) == expected)
        }
        progress.record(item, correct: false)
        #expect(PreschoolLadder.level(progress.stats[item.key]) == 0)
        var corrupt = ItemStats()
        corrupt.streak = -1
        #expect(PreschoolLadder.level(corrupt) == 0)
    }

    @Test func rungsProduceExpectedKinds() throws {
        let gen = try generator()
        let c = try character("水", in: gen)
        var rng = SeededRNG(state: 42)
        let zero = try #require(gen.makeQuestion(for: .character(c), rung: 0, using: &rng))
        #expect(zero.kind == .listenPickChar && zero.input == nil)
        let one = try #require(gen.makeQuestion(for: .character(c), rung: 1, using: &rng))
        #expect(one.kind == .listenFillChar && one.input == nil)
        #expect(one.prompt.contains("□") && !one.prompt.contains(c.char))
        #expect(c.words?.contains(one.promptSpeech ?? "") == true)
        #expect(one.promptSpeech?.replacingOccurrences(of: c.char, with: "□") == one.prompt)
        let two = try #require(gen.makeQuestion(for: .character(c), rung: 2, using: &rng))
        #expect(two.kind == .shapeRiddle && two.input == nil)
        #expect(two.promptSpeech == c.imageHint)
        #expect(two.promptSpeech?.contains(c.char) == false)
        let three = try #require(gen.makeQuestion(for: .character(c), rung: 3, using: &rng))
        let spec = try #require(three.input)
        #expect(spec.isMulti && spec.blanks.map(\.answer) == ["sh", "ui"])
    }

    @Test func fallsBackWhenRungUnavailable() throws {
        let gen = try generator()
        var rng = SeededRNG(state: 7)
        for text in ["手", "交"] {
            let c = try character(text, in: gen)
            let q = try #require(gen.makeQuestion(for: .character(c), rung: 2, using: &rng))
            #expect(q.kind == .listenPickChar)
            #expect(q.input?.blanks.count == 1 && q.input?.isMulti == false)
        }
        let repeated = CharacterItem(char: "妈", pinyin: "mā", words: ["妈妈"])
        let q = try #require(gen.makeQuestion(for: .character(repeated), rung: 1, using: &rng))
        #expect(q.kind == .listenPickChar && q.input == nil)
        let ear = try character("耳", in: gen)
        let fallback = try #require(gen.makeQuestion(for: .character(ear), rung: 3, using: &rng))
        #expect(fallback.kind == .listenFillChar && fallback.input == nil)
        let empty = CharacterItem(char: "水", pinyin: "shuǐ", imageHint: " \n ")
        #expect(try #require(gen.makeQuestion(for: .character(empty), rung: 2, using: &rng)).input?.isMulti == false)
    }

    @Test func difficultyClampsRung() throws {
        for grade in [Grade.k2, .k3] {
            for difficulty in Difficulty.allCases {
                let gen = try generator(grade: grade, difficulty: difficulty)
                let expected: ClosedRange<Int> = difficulty == .easy ? 0...1
                    : (difficulty == .normal ? (grade == .k2 ? 0...2 : 1...2) : 1...3)
                #expect(gen.settings.ladder == expected)
                let c = try character("水", in: gen)
                var rng = SeededRNG(state: 9)
                for streak in 0...5 {
                    var stats = ItemStats()
                    stats.streak = streak
                    let q = try #require(gen.makeQuestion(for: .character(c), stats: streak == 0 ? nil : stats, using: &rng))
                    let rung = min(expected.upperBound, max(expected.lowerBound, streak))
                    #expect(q.kind == [.listenPickChar, .listenFillChar, .shapeRiddle, .listenPickChar][rung])
                    #expect((q.input != nil) == (rung == 3))
                }
            }
        }
    }

    @Test func pictureRungsAndMissingPinyinFallback() throws {
        let gen = try generator(grade: .k2)
        let p = try #require(gen.pool.pictures.first)
        var rng = SeededRNG(state: 11)
        let q = try #require(gen.makeQuestion(for: .picture(p), rung: 1, using: &rng))
        #expect(q.kind == .pictureToWord && q.prompt == p.emoji)
        #expect(q.answer == p.text && q.promptSpeech == nil && q.optionStyle == .text)
        for rung in 2...3 {
            let typed = try #require(gen.makeQuestion(for: .picture(p), rung: rung, using: &rng))
            #expect(typed.input?.blanks.count == 1 && typed.input?.isMulti == false)
            #expect(typed.promptSpeech != nil)
        }
        var missing = p
        missing.pinyin = nil
        let fallback = try #require(gen.makeQuestion(for: .picture(missing), rung: 3, using: &rng))
        #expect(fallback.kind == .pictureToWord && fallback.input == nil)
    }

    @Test func hardPrefersSameRadicalWithoutChangingLegacyInterface() throws {
        let gen = try generator()
        let c = try character("捕", in: gen)
        var rng = SeededRNG(state: 13)
        for _ in 0..<20 {
            let q = try #require(gen.makeQuestion(for: .character(c), rung: 1, using: &rng))
            #expect(q.options.contains { ["捞", "挖", "扶", "批", "搭", "抱"].contains($0) })
        }
        #expect(Radical.of("提手旁，右边是比") == "提手旁")
        #expect(Radical.of(nil) == nil && Radical.of("像一条河流") == nil)
        for grade in [Grade.k3, .g3] {
            var legacy = try generator(grade: grade)
            let item = try #require(legacy.pool.items.first)
            var a = SeededRNG(state: 17), b = a
            legacy.settings.ladder = nil
            let old = try #require(legacy.makeQuestion(for: item, using: &a))
            let new = try #require(legacy.makeQuestion(for: item, stats: nil, using: &b))
            #expect(old.kind == new.kind && old.options == new.options && old.prompt == new.prompt)
            #expect(a.next() == b.next())
        }
    }

    @Test func everyLadderQuestionIsAnswerableAndItsSpeechIsListed() throws {
        let library = ContentLibrary.load(userDirectory: nil)
        let speech = Set(SpeechText.texts(in: library.packs))
        var rng = SeededRNG(state: 19)
        for grade in [Grade.k2, .k3] {
            for difficulty in Difficulty.allCases {
                let gen = try generator(grade: grade, difficulty: difficulty)
                for item in gen.pool.items {
                    for rung in 0...3 {
                        let q = try #require(gen.makeQuestion(for: item, rung: rung, using: &rng))
                        #expect(Set(q.options).count == q.options.count)
                        #expect(q.options.indices.contains(q.answerIndex))
                        #expect(q.options.count <= gen.settings.optionCount)
                        for line in [q.promptSpeech, q.answerSpeech].compactMap({ $0 }) {
                            #expect(speech.contains(line), "未列入语音清单：\(line)")
                        }
                        if let input = q.input {
                            #expect(input.accepts(input.blanks.map(\.answer)))
                            for blank in input.blanks {
                                #expect(input.groups[blank.group].tiles.contains(blank.answer))
                            }
                        } else {
                            #expect(q.options.count >= 2)
                        }
                    }
                }
            }
        }
    }

    @Test func imageAssociationSurvivesRoundTrip() throws {
        let json = #"{"char":"水","pinyin":"shuǐ","image_association":"像中间流淌的河流。"}"#
        let item = try JSONDecoder().decode(CharacterItem.self, from: Data(json.utf8))
        let encoded = try JSONEncoder().encode(item)
        let object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        #expect(object["image_association"] as? String == "像中间流淌的河流。")
        let legacy = try JSONDecoder().decode(CharacterItem.self, from: Data(#"{"char":"水","pinyin":"shuǐ"}"#.utf8))
        #expect(legacy.char == "水")
    }

    @Test func gradeAndDifficultyHaveDistinctBudgetsAndOptions() {
        for (grade, budgets, counts) in [(Grade.k2, [8, 10, 12], [3, 3, 4]), (.k3, [10, 12, 14], [3, 4, 4])] {
            for (index, difficulty) in Difficulty.allCases.enumerated() {
                let tuning = GameTuning.make(grade: grade, difficulty: difficulty)
                #expect(tuning.questions == budgets[index])
                #expect(tuning.generator.optionCount == counts[index])
                #expect(tuning.hearts == nil)
                let armored = tuning.waves.mix.first { $0.kind == .armored }
                #expect((armored?.weight ?? 0) == (grade == .k3 ? Double(index) : 0))
                let strategy: DistractorStrategy = grade == .k2 && difficulty == .easy ? .easy
                    : (grade == .k3 && difficulty == .hard ? .hard : .normal)
                #expect(tuning.generator.strategy == strategy)
                #expect(tuning.generator.showHint == !(grade == .k3 && difficulty == .hard))
            }
        }
    }
}
