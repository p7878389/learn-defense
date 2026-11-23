import Foundation
import LearnCore
import SwiftData
import Testing
@testable import LearnGame

@MainActor
@Suite("经典结算保存与重试")
struct GamePersistenceTests {
    private func setup() throws -> (LearnDatabase, GrowthStore, GameRecorder, GameSession) {
        let db = try LearnDatabase(url: nil)
        let id = UUID()
        var state = GrowthState(); state.coins = 400
        try db.saveGrowthState(state, profileID: id)
        let pack = ContentPack(id: "persist", title: "保存测试", subject: .chinese, grade: .g3,
            units: [ContentUnit(id: "u1", title: "单元", lessons: [Lesson(id: "l1", title: "课文",
                questions: [ChoiceItem(id: "q1", prompt: "选山", options: ["山", "水"], answer: "山")])])])
        let growth = GrowthStore(profileID: id, database: db, catalog: .bundled)
        let recorder = GameRecorder(database: db, profileID: id, grade: .g3, difficulty: .easy, packIDs: [pack.id], selection: .all)
        let session = GameSession(config: GameConfig(profileID: id, grade: .g3, packIDs: [pack.id], selection: .all, difficulty: .easy),
            library: ContentLibrary(packs: [pack]), progress: ProgressStore(profileID: id, database: db),
            speech: Speech(), growth: growth, recorder: recorder)
        let planted = session.scene.plant(.inkling, in: DefenderCell(lane: 0, column: 0))
        #expect(planted)
        return (db, growth, recorder, session)
    }

    @Test func failedSettlementCanBeRetriedWithoutLosingOrDoublingRewards() throws {
        let (db, growth, recorder, session) = try setup()
        session.startBattle()
        let enemy = try #require(session.nextEnemy())
        session.scene.spawn(enemy, lane: 0)
        session.selectQuestion(enemy.id)
        session.answer(try #require(session.current).answerIndex)
        let row = try #require(try db.context.fetch(FetchDescriptor<StoredGrowth>()).first)
        let original = row.stateData
        row.stateData = Data("damaged".utf8)
        try db.context.save()
        do { try growth.reload() } catch { /* 模拟持久化数据读取失败。 */ }
        session.finishGame()
        #expect(session.phase == .lost && session.settlementError != nil)
        #expect(session.growthResult == nil && recorder.record == nil)
        #expect(try db.games(profileID: recorder.profileID).isEmpty)
        row.stateData = original
        try db.context.save()
        session.retrySettlement()
        let result = try #require(session.growthResult)
        #expect(session.settlementError == nil)
        #expect(growth.state.stats.gamesPlayed == 1 && growth.state.coins == 400 + result.totalCoins)
        let saved = growth.state
        session.retrySettlement()
        session.finishGame()
        #expect(growth.state == saved)
        #expect(try db.games(profileID: recorder.profileID).count == 1)
        #expect(try db.answers(gameID: recorder.id).count == 1)
    }

    @Test func unreadableGrowthKeepsPreparationAndFormationForRetry() throws {
        let (db, growth, _, session) = try setup()
        let row = try #require(try db.context.fetch(FetchDescriptor<StoredGrowth>()).first)
        let original = row.stateData
        row.stateData = Data("damaged".utf8)
        try db.context.save()
        do { try growth.reload() } catch { /* 保留原始存档。 */ }
        session.startBattle()
        #expect(session.phase == .preparing && session.startError != nil)
        #expect(session.scene.plantedCellCount == 1)
        row.stateData = original
        try db.context.save()
        session.startBattle()
        #expect(session.phase == .playing && session.startError == nil)
    }
}
