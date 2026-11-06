import Foundation
import Testing
@testable import LearnCore

@Suite("按难度出输入题")
struct AnswerInputTests {
    static let library = ContentLibrary.load(userDirectory: nil)

    func questions(grade: Grade, subject: Subject = .chinese, difficulty: Difficulty, count: Int = 300) -> [Question] {
        let pool = ItemPool(packs: Self.library.packs(grade: grade, subject: subject), selection: .all)
        let generator = QuestionGenerator(pool: pool, settings: GameTuning.make(grade: grade, difficulty: difficulty).generator)
        var rng = SeededRNG(state: 7)
        return (0..<count).compactMap { i in generator.makeQuestion(for: pool.items[i % pool.items.count], using: &rng) }
    }

    @Test func easyIsChoiceOnly() {
        for grade in [Grade.g3, .k2] {
            #expect(questions(grade: grade, difficulty: .easy).allSatisfy { $0.input == nil })
        }
    }

    @Test func normalMixesChoiceWithSingleBlanks() {
        let qs = questions(grade: .g3, difficulty: .normal)
        let typed = qs.compactMap(\.input)
        #expect(typed.count > qs.count / 10)
        #expect(typed.count < qs.count / 2)
        #expect(typed.allSatisfy { !$0.isMulti })
    }

    @Test(arguments: [(Grade.g3, Subject.chinese), (.g3, .english), (.k2, .chinese)])
    func hardUsesSingleAndMultiBlanks(grade: Grade, subject: Subject) {
        let qs = questions(grade: grade, subject: subject, difficulty: .hard)
        let typed = qs.compactMap(\.input)
        // 自定义选择题、太长的单词、凑不出字块的题仍是选择题，其余都是字块题
        let ratio = Double(typed.count) / Double(qs.count)
        #expect(ratio > 0.75, "字块题只占 \(ratio)")
        #expect(typed.contains { $0.isMulti })
        #expect(typed.contains { !$0.isMulti })
    }

    @Test func ultimateStaysChoiceOnHard() {
        let pool = ItemPool(packs: Self.library.packs(grade: .g3, subject: .chinese), selection: .all)
        let generator = QuestionGenerator(pool: pool, settings: GameTuning.make(grade: .g3, difficulty: .hard).generator)
        var rng = SeededRNG(state: 3)
        for _ in 0..<30 {
            #expect(generator.makeUltimateQuestion(using: &rng)?.1.input == nil)
        }
    }

    @Test func pinyinTilesComposeWithTone() {
        let spec = InputSpec(style: .pinyin,
                             blanks: [InputBlank(answer: "ch", group: 0), InputBlank(answer: "en", group: 1), InputBlank(answer: "ˊ", group: 2)],
                             groups: [TileGroup(tiles: ["ch", "c", "sh"]), TileGroup(tiles: ["en", "eng", "in"]), TileGroup(tiles: InputSpec.toneMarks)],
                             hint: "h", isMulti: false)
        #expect(spec.answerText == "chén")
        #expect(spec.compose(["c", "eng", "ˇ"]) == "cěng")
        #expect(spec.accepts(["ch", "en", "ˊ"]))
        #expect(!spec.accepts(["ch", "en", "ˇ"]))
        #expect(!spec.accepts(["ch", "en"]))
        let initialOnly = InputSpec(style: .pinyin, blanks: [InputBlank(answer: "zh")], groups: [TileGroup(tiles: ["zh", "z", "j"])],
                                    hint: "h", isMulti: false)
        #expect(initialOnly.answerText == "zh")
    }

    @Test func charToPinyinSplitsIntoThreeGroups() throws {
        let pool = ItemPool(packs: Self.library.packs(grade: .g3, subject: .chinese), selection: .all)
        let generator = QuestionGenerator(pool: pool, settings: GameTuning.make(grade: .g3, difficulty: .hard).generator)
        var rng = SeededRNG(state: 5)
        var found = false
        for item in pool.items {
            guard case .character = item else { continue }
            for _ in 0..<6 {
                guard let q = generator.makeQuestion(for: item, mode: .single, using: &rng), let spec = q.input,
                      spec.style == .pinyin else { continue }
                found = true
                #expect(spec.groups.last?.title == "声调" || spec.groups.count <= 2)
                #expect(spec.groups.dropLast().allSatisfy { $0.tiles.count == 4 }, "挑战每组 4 选 1")
                #expect(spec.answerText == Pinyin.normalize(q.answer))
            }
        }
        #expect(found)
    }

    @Test func moreTilesOnHarderLevels() throws {
        let pool = ItemPool(packs: Self.library.packs(grade: .g3, subject: .chinese), selection: .all)
        func tileCount(_ difficulty: Difficulty) -> Int {
            let generator = QuestionGenerator(pool: pool, settings: GameTuning.make(grade: .g3, difficulty: difficulty).generator)
            var rng = SeededRNG(state: 9)
            let counts = pool.items.compactMap { item -> Int? in
                guard let spec = generator.makeQuestion(for: item, mode: .single, using: &rng)?.input, spec.style == .hanzi else { return nil }
                return spec.groups[0].tiles.count
            }
            return counts.max() ?? 0
        }
        #expect(tileCount(.normal) == 6)
        #expect(tileCount(.hard) == 8)
    }

    @Test func mixPickDoesNotConsumeRandomnessWhenChoiceOnly() {
        var a = SeededRNG(state: 11), b = SeededRNG(state: 11)
        #expect(AnswerMix.choiceOnly.pick(using: &a) == .choice)
        #expect(a.next() == b.next())
    }

    @Test func typedAnswerIsRecorded() {
        let q = Question(kind: .charToPinyin, itemKey: "k", instruction: "", prompt: "晨", options: ["chén"],
                         optionStyle: .text, answerIndex: 0,
                         input: InputSpec(style: .hanzi, blanks: [InputBlank(answer: "晨")], groups: [TileGroup(tiles: ["晨", "辰"])],
                                          hint: "c", isMulti: false))
        let record = AnswerRecord(question: q, typed: "chen", correct: false, ultimate: false, shownAt: nil, answeredAt: Date())
        #expect(record.chosen == "chen")
        #expect(!record.correct)
        #expect(!record.missed)
        #expect(record.answer == "chén")
    }
}
