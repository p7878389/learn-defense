import Foundation
import LearnCore
import Testing
@testable import LearnGame

@MainActor
@Suite("大招首答统计")
struct UltimateStatisticsTests {
    private struct Context {
        let database: LearnDatabase
        let session: GameSession
        let progress: ProgressStore
        let growth: GrowthStore
        let recorder: GameRecorder?
    }

    private func context(recording: Bool = true) throws -> Context {
        let database = try LearnDatabase(url: nil)
        let profile = Profile(name: "统计测试", grade: .g3, avatar: "🐯")
        try database.saveProfiles([profile])
        let pack = ContentPack(id: "statistics", title: "统计题库", subject: .chinese, grade: .g3,
            units: [ContentUnit(id: "u1", title: "单元", lessons: [Lesson(id: "l1", title: "课文",
                questions: [ChoiceItem(id: "q1", prompt: "选出晨", options: ["晨", "霜", "春"], answer: "晨")])])])
        let config = GameConfig(profileID: profile.id, grade: .g3, packIDs: [pack.id], selection: .all, difficulty: .easy)
        let progress = ProgressStore(profileID: profile.id, database: database)
        let growth = GrowthStore(profileID: profile.id, database: database, catalog: .bundled)
        let recorder = recording ? GameRecorder(database: database, profileID: profile.id, grade: .g3,
                                                difficulty: .easy, packIDs: [pack.id], selection: .all) : nil
        let session = GameSession(config: config, library: ContentLibrary(packs: [pack]), progress: progress,
                                  speech: Speech(), growth: growth, recorder: recorder)
        #expect(session.scene.plant(.inkling, in: DefenderCell(lane: 0, column: 0)))
        session.startBattle()
        return Context(database: database, session: session, progress: progress, growth: growth, recorder: recorder)
    }

    private func startUltimate(_ session: GameSession) throws -> Question {
        session.energy = session.tuning.ultimateEnergy
        session.startUltimate()
        return try #require(session.ultimate)
    }

    private func answerOrdinaryQuestion(_ session: GameSession) throws {
        let spawn = try #require(session.nextEnemy())
        session.scene.spawn(spawn, lane: 0)
        session.selectQuestion(spawn.id)
        let question = try #require(session.current)
        session.answer(question.answerIndex)
        // 模拟命中动画完成的委托回调，统计测试不依赖渲染时钟。
        session.enemyDefeated(spawn.id, at: .zero)
    }

    private func completeRound(_ session: GameSession) {
        while let enemy = session.nextEnemy() { session.enemyDefeated(enemy.id, at: .zero) }
        #expect(session.phase == .resting)
    }

    @Test(arguments: [true, false])
    func firstTryCorrectCountsWithOrWithoutRecorder(recording: Bool) throws {
        let c = try context(recording: recording)
        let question = try startUltimate(c.session)
        c.session.answerUltimate(question.answerIndex)
        c.session.answerUltimate(question.answerIndex)
        #expect(c.session.attempted == 1)
        #expect(c.session.firstTryCorrect == 1)
        #expect(c.session.accuracy == 1)
        #expect(c.session.score == 30 && c.session.energy == 0 && c.session.ultimatesCast == 1)
        c.session.finishGame()
        #expect(c.growth.state.stats.questionsAnswered == 1)
        #expect(c.growth.state.stats.firstTryCorrect == 1)
        #expect(c.progress.stats[question.itemKey]?.seen == 1)
        if let recorder = c.recorder {
            #expect(recorder.record?.questions == 1)
            #expect(recorder.record?.firstTryCorrect == 1)
            #expect(recorder.answers.count == 1 && recorder.answers.first?.ultimate == true)
        }
    }

    @Test func ordinaryCorrectAndUltimateWrongAgreeAcrossAllConsumers() throws {
        let c = try context()
        try answerOrdinaryQuestion(c.session)
        let question = try startUltimate(c.session)
        c.session.answerUltimate((question.answerIndex + 1) % question.options.count)
        c.session.answerUltimate(question.answerIndex)
        #expect(c.session.attempted == 2 && c.session.firstTryCorrect == 1)
        #expect(c.session.accuracy == 0.5)
        #expect(c.session.score == 10 && c.session.energy == 0 && c.session.ultimatesCast == 0)
        c.session.finishGame()
        c.session.finishGame()
        c.session.end()

        let games = try c.database.games(profileID: c.session.config.profileID)
        #expect(games.count == 1)
        let game = try #require(games.first)
        #expect(game.questions == 2 && game.firstTryCorrect == 1 && game.accuracy == 0.5)
        let recorder = try #require(c.recorder)
        let answers = try c.database.answers(gameID: recorder.id)
        #expect(answers.count == 2 && answers.filter(\.correct).count == 1)
        #expect(answers.map(\.ultimate) == [false, true])
        let kind = try #require(try c.database.kindAccuracy(profileID: c.session.config.profileID).first)
        #expect(kind.answered == 2 && kind.correct == 1 && kind.accuracy == 0.5)
        #expect(c.growth.state.stats.questionsAnswered == 2 && c.growth.state.stats.firstTryCorrect == 1)
        #expect(c.growth.state.stats.gamesPlayed == 1)
        let stats = try #require(c.progress.stats[question.itemKey])
        #expect(stats.seen == 2 && stats.correct == 1 && stats.wrong == 1)
    }

    @Test func repeatedWrongChoicesAndCorrectionCountOnlyFirstAttempt() throws {
        let c = try context()
        let question = try startUltimate(c.session)
        let wrong = question.options.indices.filter { $0 != question.answerIndex }
        c.session.answerUltimate(wrong[0])
        c.session.answerUltimate(wrong[0])
        c.session.answerUltimate(wrong[1])
        c.session.answerUltimate(question.answerIndex)
        c.session.finishGame()
        #expect(c.session.attempted == 1 && c.session.firstTryCorrect == 0)
        #expect(c.session.mistakes.count == 1 && c.session.ultimatesCast == 0)
        #expect(c.recorder?.answers.count == 1)
        #expect(c.recorder?.record?.questions == 1 && c.recorder?.record?.firstTryCorrect == 0)
        #expect(c.progress.stats[question.itemKey]?.seen == 1)
        #expect(c.growth.state.stats.questionsAnswered == 1)
    }

    @Test func invalidOrPausedAnswersAndUnansweredCancelDoNotCount() throws {
        let c = try context()
        let question = try startUltimate(c.session)
        c.session.answerUltimate(-1)
        c.session.answerUltimate(question.options.count)
        c.session.togglePause()
        c.session.answerUltimate(question.answerIndex)
        c.session.togglePause()
        c.session.cancelUltimate()
        #expect(c.session.energy == c.session.tuning.ultimateEnergy)
        c.session.finishGame()
        #expect(c.session.attempted == 0 && c.session.firstTryCorrect == 0)
        #expect(c.recorder?.answers.isEmpty == true && c.recorder?.record?.questions == 0)
        #expect(c.progress.stats.isEmpty)
        #expect(c.growth.state.stats.questionsAnswered == 0 && c.growth.state.stats.gamesPlayed == 0)
    }

    @Test func cancellingAfterWrongAnswerKeepsTheAttempt() throws {
        let c = try context()
        let question = try startUltimate(c.session)
        c.session.answerUltimate((question.answerIndex + 1) % question.options.count)
        c.session.cancelUltimate()
        #expect(c.session.energy == 0)
        c.session.finishGame()
        #expect(c.session.attempted == 1 && c.session.firstTryCorrect == 0)
        #expect(c.recorder?.record?.questions == 1 && c.recorder?.answers.count == 1)
        #expect(c.growth.state.stats.questionsAnswered == 1)
    }

    @Test func roundAccuracyUsesFirstAttemptsFromTheCurrentRound() throws {
        let c = try context()
        try answerOrdinaryQuestion(c.session)
        let first = try startUltimate(c.session)
        c.session.answerUltimate((first.answerIndex + 1) % first.options.count)
        c.session.cancelUltimate()
        completeRound(c.session)
        #expect(c.session.roundAccuracy == 0.5)
        c.session.updateRest(now: Date().addingTimeInterval(1000))
        c.session.continueRound()
        let second = try startUltimate(c.session)
        c.session.answerUltimate((second.answerIndex + 1) % second.options.count)
        c.session.cancelUltimate()
        completeRound(c.session)
        #expect(c.session.roundAccuracy == 0)
        c.session.finishGame()
        #expect(c.session.accuracy == 1.0 / 3.0)
        #expect(c.recorder?.record?.questions == 3 && c.recorder?.record?.firstTryCorrect == 1)
        #expect(c.growth.state.stats.questionsAnswered == 3 && c.growth.state.stats.firstTryCorrect == 1)
    }

    @Test func wrongUltimateAffectsStarsAndPreventsPerfectGame() throws {
        let c = try context()
        for _ in 0..<8 { try answerOrdinaryQuestion(c.session) }
        let question = try startUltimate(c.session)
        c.session.answerUltimate((question.answerIndex + 1) % question.options.count)
        c.session.cancelUltimate()
        completeRound(c.session)
        c.session.finishGame()
        #expect(c.session.accuracy == 8.0 / 9.0)
        #expect(c.session.stars == 2 && c.recorder?.record?.stars == 2)
        #expect(c.growth.state.stats.questionsAnswered == 9 && c.growth.state.stats.firstTryCorrect == 8)
        #expect(c.growth.state.stats.perfectGames == 0 && c.growth.state.stats.threeStarGames == 0)
    }
}
