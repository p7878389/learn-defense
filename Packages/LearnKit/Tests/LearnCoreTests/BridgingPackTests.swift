import Foundation
import Testing
@testable import LearnCore

@Suite("幼小衔接拼音与数字数学题库")
struct BridgingPackTests {
    static let library = ContentLibrary.load(userDirectory: nil)

    @Test func bridgingPinyinAndMathPacksExistAndCoverGrades() throws {
        #expect(Self.library.issues.isEmpty, "\(Self.library.issues)")

        let pinyin = try #require(Self.library.pack(id: "chinese-bridging-pinyin-k3"))
        #expect(pinyin.grade == .k3 && pinyin.subject == .chinese && pinyin.edition == "幼小衔接")
        #expect(pinyin.units.count == 6)

        let mathK3 = try #require(Self.library.pack(id: "math-bridging-numbers-k3"))
        #expect(mathK3.grade == .k3 && mathK3.subject == .math && mathK3.edition == "幼小衔接")
        #expect(mathK3.units.count == 6)

        let mathK2 = try #require(Self.library.pack(id: "math-numbers-k2"))
        #expect(mathK2.grade == .k2 && mathK2.subject == .math)
        #expect(mathK2.units.count == 4)

        let k3MathPool = ItemPool(packs: [mathK3], selection: .all)
        #expect(k3MathPool.items.count >= 100)
    }

    @Test(arguments: Difficulty.allCases)
    func appleCountingPromptDoesNotSpeakTheAnswer(difficulty: Difficulty) throws {
        let pack = try #require(Self.library.pack(id: "math-numbers-k2"))
        let pool = ItemPool(packs: [pack], selection: .all)
        let item = try #require(pool.items.first { $0.key == "choice:math-numbers-k2/u1/l1:m2_1" })
        let generator = QuestionGenerator(pool: pool, settings: GameTuning.make(grade: .k2, difficulty: difficulty).generator)
        var rng = SeededRNG(state: 31)
        let question = try #require(generator.makeQuestion(for: item, stats: nil, using: &rng))
        let speech = try #require(question.promptSpeech)

        #expect(question.prompt.filter { $0 == "🍎" }.count == 3)
        #expect(question.answer == "3")
        #expect(speech.contains("苹果"))
        #expect(!speech.contains("三") && !speech.contains("3"), "数数题朗读不应提前透露苹果数量：\(speech)")
    }

    @Test func mathAndPinyinQuestionsHaveCleanSpokenPromptsAndValidAnswers() throws {
        for id in ["chinese-bridging-pinyin-k3", "math-bridging-numbers-k3", "math-numbers-k2"] {
            let pack = try #require(Self.library.pack(id: id))
            let listed = Set(SpeechText.texts(in: [pack]))
            for unit in pack.units {
                let unitPool = ItemPool(packs: [pack], selection: .units(["\(pack.id)/\(unit.id)"]))
                #expect(!unitPool.isEmpty, "\(pack.id)/\(unit.id) 不能为空")
                for difficulty in Difficulty.allCases {
                    let gen = QuestionGenerator(pool: unitPool, settings: GameTuning.make(grade: pack.grade, difficulty: difficulty).generator)
                    var rng = SeededRNG(state: 31)
                    for item in unitPool.items {
                        let q = try #require(gen.makeQuestion(for: item, stats: nil, using: &rng))
                        let speech = try #require(q.promptSpeech, "\(item.key) 缺少语音题干")
                        #expect(!speech.contains(" - ") && !speech.contains(" + ") && !speech.contains("○") && !speech.contains("□"),
                                "语音包含易漏读符号：\(speech)")
                        #expect(listed.contains(speech), "语音未列入清单：\(speech)")
                        if q.input == nil {
                            #expect(q.options.count >= 3 && Set(q.options).count == q.options.count)
                            for opt in q.options {
                                #expect(opt.contains { $0.isLetter || $0.isNumber || "<>=".contains($0) }, "选项不应为纯裸 Emoji：\(opt)")
                            }
                        }
                    }
                }
            }
        }
    }
}
