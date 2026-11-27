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
                        }
                    }
                }
            }
        }
    }
}
