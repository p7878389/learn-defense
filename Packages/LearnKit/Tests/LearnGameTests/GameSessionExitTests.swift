import Foundation
import LearnCore
import Testing
@testable import LearnGame

@MainActor
@Suite("退出未结算对局")
struct GameSessionExitTests {
    private struct Context {
        let database: LearnDatabase
        let session: GameSession
        let recorder: GameRecorder
        let growth: GrowthStore
    }

    private func context(at url: URL? = nil, profileID: UUID = UUID(), start: Bool = true) throws -> Context {
        let database = try LearnDatabase(url: url)
        try database.saveProfiles([Profile(id: profileID, name: "退出测试", grade: .g3, avatar: "🐯")])
        let pack = ContentPack(id: "exit", title: "退出题库", subject: .chinese, grade: .g3,
            units: [ContentUnit(id: "u1", title: "单元", lessons: [Lesson(id: "l1", title: "课文",
                questions: [ChoiceItem(id: "q1", prompt: "选出晨", options: ["晨", "霜", "春"], answer: "晨")])])])
        let config = GameConfig(profileID: profileID, grade: .g3, packIDs: [pack.id], selection: .all, difficulty: .easy)
        let progress = ProgressStore(profileID: profileID, database: database)
        let growth = GrowthStore(profileID: profileID, database: database, catalog: .bundled)
        let recorder = GameRecorder(database: database, profileID: profileID, grade: .g3, difficulty: .easy,
                                    packIDs: [pack.id], selection: .all)
        let session = GameSession(config: config, library: ContentLibrary(packs: [pack]), progress: progress,
                                  speech: Speech(), growth: growth, recorder: recorder)
        #expect(session.scene.plant(.inkling, in: DefenderCell(lane: 0, column: 0)))
        if start { session.startBattle() }
        return Context(database: database, session: session, recorder: recorder, growth: growth)
    }

    private func question(_ session: GameSession) throws -> (EnemySpawn, Question) {
        let enemy = try #require(session.nextEnemy())
        session.scene.spawn(enemy, lane: 0)
        session.selectQuestion(enemy.id)
        return (enemy, try #require(session.current))
    }

    private func answerCorrectly(_ session: GameSession) throws {
        let (enemy, q) = try question(session)
        session.answer(q.answerIndex)
        session.enemyDefeated(enemy.id, at: .zero)
    }

    private func completeRound(_ session: GameSession) {
        while let enemy = session.nextEnemy() { session.enemyDefeated(enemy.id, at: .zero) }
        #expect(session.phase == .resting)
    }

    enum ExitPoint: CaseIterable { case preparing, playing, paused, resting, ultimate }

    @Test(arguments: ExitPoint.allCases)
    func leavingAnUnfinishedGameDoesNotRecordOrSettle(point: ExitPoint) throws {
        let c = try context(start: point != .preparing)
        if point != .preparing { try answerCorrectly(c.session) }
        if point == .paused { c.session.togglePause() }
        if point == .resting { completeRound(c.session) }
        if point == .ultimate {
            c.session.energy = c.session.tuning.ultimateEnergy
            c.session.startUltimate()
            #expect(c.session.ultimate != nil)
        }
        c.session.end()
        c.session.end()
        // 已离开的实例不能被迟到的继续、开局或结算操作重新激活。
        c.session.togglePause()
        c.session.startBattle()
        c.session.finishGame()
        #expect(c.recorder.record == nil && c.session.growthResult == nil)
        #expect(try c.database.games(profileID: c.session.config.profileID).isEmpty)
        #expect(c.growth.state.xp == 0 && c.growth.state.coins == 0 && c.growth.state.stats.gamesPlayed == 0)
        #expect(c.session.scene.gamePaused && !c.session.canStartBattle && !c.session.canUseShop)
        #expect(c.session.nextEnemy() == nil && c.session.ultimate == nil)
    }

    @Test(arguments: [false, true])
    func anExplicitlyFinishedGameKeepsItsResultWhenLeaving(won: Bool) throws {
        let c = try context()
        try answerCorrectly(c.session)
        if won { completeRound(c.session) }
        c.session.finishGame()
        let record = try #require(c.recorder.record)
        let result = try #require(c.session.growthResult)
        c.session.suspend()
        c.session.end()
        c.session.end()
        c.session.finishGame()
        #expect(c.recorder.record == record && c.session.growthResult == result)
        #expect(c.session.phase == (won ? .won : .lost))
        let games = try c.database.games(profileID: c.session.config.profileID)
        #expect(games.count == 1 && games.first?.outcome == (won ? "won" : "lost"))
        #expect(try c.database.answers(gameID: c.recorder.id).count == 1)
        #expect(c.growth.state.stats.gamesPlayed == 1)
    }

    @Test func aRealFailureIsStillRecordedOnce() throws {
        let c = try context()
        for _ in 0..<(c.session.hearts ?? 0) {
            let enemy = try #require(c.session.nextEnemy())
            #expect(c.session.enemyReachedBase(enemy.id))
        }
        #expect(c.session.phase == .lost)
        c.session.end()
        #expect(try c.database.games(profileID: c.session.config.profileID).count == 1)
        #expect(c.growth.state.stats.gamesPlayed == 1)
    }

    @Test func backgroundPausesWithoutSettlingAndOnlyExplicitResumeContinues() throws {
        let c = try context()
        try answerCorrectly(c.session)
        c.session.suspend()
        c.session.suspend()
        #expect(c.session.phase == .paused && c.session.scene.gamePaused)
        #expect(c.recorder.record == nil && c.session.growthResult == nil)
        #expect(try c.database.games(profileID: c.session.config.profileID).isEmpty)
        #expect(c.growth.state.stats.gamesPlayed == 0)
        c.session.togglePause()
        #expect(c.session.phase == .playing && !c.session.scene.gamePaused)
        c.session.end()
        c.session.suspend()
        #expect(c.recorder.record == nil)
    }

    @Test(arguments: [false, true])
    func backgroundPreservesUltimateAndRoundRestBoundaries(ultimate: Bool) throws {
        let c = try context()
        try answerCorrectly(c.session)
        if ultimate {
            c.session.energy = c.session.tuning.ultimateEnergy
            c.session.startUltimate()
            let question = try #require(c.session.ultimate)
            c.session.suspend()
            #expect(c.session.phase == .paused && c.session.ultimate?.id == question.id)
            c.session.togglePause()
            #expect(c.session.phase == .playing && c.session.scene.gamePaused)
            c.session.cancelUltimate()
            #expect(!c.session.scene.gamePaused)
        } else {
            completeRound(c.session)
            c.session.suspend()
            #expect(c.session.phase == .resting && c.session.scene.gamePaused)
            c.session.updateRest(now: Date().addingTimeInterval(1000))
            c.session.continueRound()
            #expect(c.session.phase == .playing && !c.session.scene.gamePaused)
        }
        c.session.end()
        #expect(c.recorder.record == nil && c.session.growthResult == nil)
        #expect(try c.database.games(profileID: c.session.config.profileID).isEmpty)
    }

    @Test func unexpectedCloseKeepsNoHistoryAndTheNextEntryStartsFresh() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("learn.store")
        let profileID = UUID()
        var oldGameID = UUID(), oldConfigID = UUID()
        do {
            let c = try context(at: url, profileID: profileID)
            oldGameID = c.recorder.id
            oldConfigID = c.session.config.id
            try answerCorrectly(c.session)
            let (_, q) = try question(c.session)
            c.session.answer((q.answerIndex + 1) % q.options.count)
            #expect(c.session.phase == .playing && c.recorder.record == nil)
            // 不调用 end() 或 finishGame()，模拟应用意外关闭。
        }
        let reopened = try LearnDatabase(url: url)
        #expect(try reopened.games(profileID: profileID).isEmpty)
        #expect(try reopened.answers(gameID: oldGameID).isEmpty)
        // 保持既有知识点/错题记录，但不能把未结算进度误当作旧档补发成长奖励。
        let correct = try reopened.stats(profileID: profileID).values.reduce(0) { $0 + $1.correct }
        #expect(correct == 1)
        let growth = GrowthStore(profileID: profileID, database: reopened, catalog: .bundled,
                                 legacyCorrectAnswers: { correct })
        #expect(growth.state.xp == 0 && growth.state.coins == 0 && growth.state.stats.gamesPlayed == 0)
        let next = try context(at: url, profileID: profileID, start: false)
        #expect(next.session.config.id != oldConfigID && next.recorder.id != oldGameID)
        #expect(next.session.phase == .preparing && next.session.round == 1)
        #expect(next.session.score == 0 && next.session.energy == 0 && next.session.defeated == 0)
        #expect(next.recorder.answers.isEmpty && next.session.questionIDs.isEmpty)
    }
}
