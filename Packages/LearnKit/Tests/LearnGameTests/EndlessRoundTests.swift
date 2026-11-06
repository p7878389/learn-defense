import Foundation
import Testing
import SpriteKit
import LearnCore
@testable import LearnGame

@Suite("无限回合")
@MainActor
struct EndlessRoundTests {
    func session(_ difficulty: Difficulty = .normal) -> GameSession {
        let library = ContentLibrary.load(userDirectory: nil)
        let pack = library.packs.first { $0.grade == .g3 }!
        let s = GameSession(config: GameConfig(profileID: UUID(), grade: .g3, packIDs: [pack.id],
                                               selection: .all, difficulty: difficulty),
                            library: library, progress: ProgressStore(), speech: Speech(),
                            growth: GrowthStore(catalog: .bundled))
        _ = s.scene.plant(.inkling, in: DefenderCell(lane: 0, column: 0))
        s.startBattle()
        return s
    }

    @Test func clearingWaveDoesNotSettleGame() throws {
        let s = session()
        while let enemy = s.nextEnemy() { s.enemyDefeated(enemy.id, at: .zero) }
        #expect(s.phase != .won)
        #expect(s.growthResult == nil)
        #expect(s.scene.gamePaused)
    }

    @Test func duplicateDefeatCannotGiveRewardsTwice() throws {
        let s = session()
        let enemy = try #require(s.nextEnemy())
        let before = s.sun
        s.enemyDefeated(enemy.id, at: .zero)
        #expect(s.sun == before + enemy.kind.sunReward)
        s.enemyDefeated(enemy.id, at: .zero)
        #expect(s.defeated == 1)
        #expect(s.sun == before + enemy.kind.sunReward)
    }
    @Test func successiveRoundsGrowAndWaitBeforeContinuing() {
        let s = session()
        let firstBudget = s.roundQuestions
        for number in 1...4 {
            #expect(s.round == number)
            #expect(s.roundQuestions == firstBudget + (number - 1) * 3)
            while let enemy = s.nextEnemy() { s.enemyDefeated(enemy.id, at: .zero) }
            #expect(s.phase == .resting)
            #expect(s.restRemaining == (number <= 3 ? 10 : 15))
            #expect(s.growthResult == nil)
            s.continueRound()
            #expect(s.round == number, "休息不足不能继续")
            s.updateRest(now: Date().addingTimeInterval(100))
            s.continueRound()
            #expect(s.phase == .playing)
            #expect(!s.scene.gamePaused)
            #expect(s.roundResolved == 0)
        }
        s.finishGame()
        let result = s.growthResult
        s.finishGame()
        s.end()
        #expect(s.growthResult == result)
        #expect(s.nextEnemy() == nil)
    }

    @Test func switchingTargetsKeepsWrongChoicesAndPauseBlocksAnswers() throws {
        // 入门只出选择题，这里要点选项
        let s = session(.easy)
        for lane in 1..<s.tuning.lanes { _ = s.scene.plant(.inkling, in: DefenderCell(lane: lane, column: 0)) }
        // 推进真实场景主循环，让两只僵尸入场。
        for tick in 1...140 { s.scene.update(Double(tick) / 10) }
        let ids = s.questionIDs
        #expect(ids.count >= 2)
        let first = try #require(ids.first)
        let second = try #require(ids.last)
        s.selectQuestion(first)
        let question = try #require(s.current)
        let wrong = (question.answerIndex + 1) % question.options.count
        s.answer(wrong)
        #expect(s.wrongPicks.contains(wrong))
        s.selectQuestion(second)
        #expect(s.selectedQuestionID == second)
        s.selectQuestion(first)
        #expect(s.current?.id == question.id)
        #expect(s.wrongPicks.contains(wrong))
        #expect(s.attempted == 1)
        s.togglePause()
        s.selectQuestion(second)
        s.answer(question.answerIndex)
        #expect(s.selectedQuestionID == first)
        #expect(s.attempted == 1)
        s.finishGame()
        #expect(s.growthResult != nil)
        let result = s.growthResult
        s.end()
        #expect(s.growthResult == result)
    }

    @Test func wrongAnswerDoesNotRevealCorrectOption() throws {
        let s = session(.easy)
        let enemy = try #require(s.nextEnemy())
        s.targetChanged(to: enemy.id)
        let q = try #require(s.current)
        let wrong = (q.answerIndex + 1) % q.options.count
        let panel = AnswerPanel(question: q, wrongPicks: [wrong], onAnswer: { _ in }, onReplay: {})
        #expect(panel.state(of: q.answerIndex, in: q) == .normal)
        #expect(panel.state(of: wrong, in: q) == .wrong)
    }

    @Test func sceneResumesSpawningAfterExhaustedWave() throws {
        let s = session()
        var wave: [EnemySpawn] = []
        while let enemy = s.nextEnemy() { wave.append(enemy) }
        // 本回合配额已经用完，让场景记录 spawningFinished。
        for tick in 1...20 { s.scene.update(Double(tick) / 10) }
        for enemy in wave { s.enemyDefeated(enemy.id, at: .zero) }
        s.updateRest(now: Date().addingTimeInterval(100))
        s.continueRound()
        for tick in 21...40 { s.scene.update(Double(tick) / 10) }
        #expect(!s.questionIDs.isEmpty)
        #expect(s.current != nil)
        #expect(s.questionIDs.allSatisfy { $0 > (wave.last?.id ?? 0) })
    }

    @Test func failureSettlesOnceAndRejectsLateDefeats() throws {
        let s = session()
        for _ in 0..<(s.hearts ?? 0) {
            let enemy = try #require(s.nextEnemy())
            #expect(s.enemyReachedBase(enemy.id))
        }
        #expect(s.phase == .lost)
        let result = try #require(s.growthResult)
        let sun = s.sun
        s.enemyDefeated(1, at: .zero)
        s.finishGame()
        s.end()
        #expect(s.sun == sun)
        #expect(s.growthResult == result)
    }

}
