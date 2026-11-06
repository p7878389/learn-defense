import Foundation
import Testing
import LearnCore
@testable import LearnGame

@Suite("大招取消")
@MainActor
struct UltimateCancelTests {
    func readySession() -> GameSession {
        let library = ContentLibrary.load(userDirectory: nil)
        let pack = library.packs.first { $0.grade == .g3 }!
        let s = GameSession(config: GameConfig(profileID: UUID(), grade: .g3, packIDs: [pack.id],
                                               selection: .all, difficulty: .normal),
                            library: library, progress: ProgressStore(), speech: Speech(),
                            growth: GrowthStore(catalog: .bundled))
        _ = s.scene.plant(.inkling, in: DefenderCell(lane: 0, column: 0))
        s.startBattle()
        s.energy = s.tuning.ultimateEnergy
        return s
    }

    @Test func cancelBeforeAnsweringKeepsEnergyAndResumes() throws {
        let s = readySession()
        s.startUltimate()
        #expect(s.ultimate != nil)
        #expect(s.scene.gamePaused)
        s.cancelUltimate()
        #expect(s.ultimate == nil)
        #expect(!s.scene.gamePaused)
        #expect(s.energy == s.tuning.ultimateEnergy)
        #expect(s.ultimateReady)
        #expect(s.ultimatesCast == 0)
    }

    @Test func cancelAfterWrongAnswerSpendsEnergy() throws {
        let s = readySession()
        s.startUltimate()
        let question = try #require(s.ultimate)
        let wrong = try #require(question.options.indices.first { $0 != question.answerIndex })
        s.answerUltimate(wrong)
        s.cancelUltimate()
        #expect(s.ultimate == nil)
        #expect(s.energy == 0)
        #expect(!s.ultimateReady)
        #expect(s.mistakes.count == 1)
    }

    @Test func cancelWhilePausedStaysPaused() throws {
        let s = readySession()
        s.startUltimate()
        s.togglePause()
        s.cancelUltimate()
        #expect(s.phase == .paused)
        #expect(s.scene.gamePaused)
        s.togglePause()
        #expect(!s.scene.gamePaused)
    }
}
