import Foundation
import Testing
import LearnCore
@testable import LearnGame

@Suite("对局里的输入题")
@MainActor
struct InputAnswerTests {
    /// 挑战难度，五条路都种上射手，推进场景让怪物入场，选中一道输入题
    func typedQuestion() throws -> (GameSession, Question, InputSpec) {
        let library = ContentLibrary.load(userDirectory: nil)
        let pack = library.packs.first { $0.grade == .g3 && $0.subject == .chinese }!
        let s = GameSession(config: GameConfig(profileID: UUID(), grade: .g3, packIDs: [pack.id],
                                               selection: .all, difficulty: .hard),
                            library: library, progress: ProgressStore(), speech: Speech(),
                            growth: GrowthStore(catalog: .bundled))
        for lane in 0..<s.tuning.lanes { _ = s.scene.plant(.inkling, in: DefenderCell(lane: lane, column: 0)) }
        s.startBattle()
        for tick in 1...140 { s.scene.update(Double(tick) / 10) }
        for id in s.questionIDs {
            s.selectQuestion(id)
            if let q = s.current, let spec = q.input { return (s, q, spec) }
        }
        throw CancellationError()
    }

    @Test func typingSlowsBattleAndHoldsTarget() throws {
        let (s, _, _) = try typedQuestion()
        let normal = s.speedFactor
        s.setTyping(true)
        #expect(s.typing)
        #expect(s.holdsTarget)
        #expect(abs(s.speedFactor - normal * 0.5) < 0.0001, "拼字块时放慢到一半")
        s.setTyping(false)
        #expect(s.speedFactor == normal)
        s.setTyping(true)
        s.targetChanged(to: nil)
        #expect(!s.typing, "换目标就收起卡片")
    }

    @Test func wrongThenRightInput() throws {
        let (s, question, spec) = try typedQuestion()
        s.setTyping(true)
        s.answerInput(spec.blanks.map { _ in "zzz" })
        #expect(s.wrongPicks.count == 1)
        #expect(s.attempted == 1)
        #expect(s.mistakes.count == 1)
        #expect(s.typing, "答错继续写")
        s.answerInput(spec.blanks.map { _ in "zzz" })
        #expect(s.wrongPicks.count == 2)
        #expect(s.attempted == 1, "同一题只记第一次")
        let score = s.score
        s.answerInput(spec.blanks.map(\.answer))
        #expect(s.score == score + 2)
        #expect(!s.typing)
        #expect(s.current?.id != question.id)
    }

    @Test func firstTryInputScoresAndChargesEnergy() throws {
        let (s, _, spec) = try typedQuestion()
        s.answerInput(spec.blanks.map(\.answer))
        #expect(s.firstTryCorrect == 1)
        #expect(s.energy == 1)
        #expect(s.score == 10)
    }

    @Test func choiceAnswerIgnoredOnInputQuestion() throws {
        let (s, _, _) = try typedQuestion()
        s.answer(0)
        #expect(s.attempted == 0)
    }
}
