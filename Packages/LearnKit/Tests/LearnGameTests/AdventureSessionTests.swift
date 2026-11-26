import Foundation
import LearnCore
import Testing
@testable import LearnGame

@MainActor
@Suite("冒险会话")
struct AdventureSessionTests {
    private func context(count: Int = 12) throws -> (AppModel, GameConfig) {
        let db = try LearnDatabase(url: nil)
        let profile = Profile(name: "冒险测试", grade: .g3, avatar: "🐯")
        try db.saveProfiles([profile])
        var state = GrowthState()
        state.coins = 50
        try db.saveGrowthState(state, profileID: profile.id)
        let questions = (0..<count).map {
            ChoiceItem(id: "q\($0)", prompt: "第\($0)题", options: ["春", "夏", "秋"], answer: "春")
        }
        let pack = ContentPack(id: "study", title: "学习测试", subject: .chinese, grade: .g3,
            units: [ContentUnit(id: "u", title: "单元", lessons: [Lesson(id: "l", title: "课文", questions: questions)])])
        let model = AppModel(database: db, library: ContentLibrary(packs: [pack]),
                             speechLibrary: SpeechLibrary(database: db))
        let config = GameConfig(profileID: profile.id, grade: .g3, packIDs: [pack.id], selection: .all, difficulty: .easy)
        return (model, config)
    }

    @Test func leavingDiscardsBattleAndNextEntryStartsFresh() throws {
        let (model, config) = try context()
        let growth = model.growth(for: config.profileID)
        let session = AdventureSession(levelID: 1, model: model, profileID: config.profileID, difficulty: .easy)
        session.plant("inkling", lane: 0, column: 0)
        #expect(growth.state.coins == 50)
        session.start()
        session.start()
        session.advance(by: 5)
        session.suspend()
        #expect(growth.state.coins == 35)
        #expect(try model.database?.growthState(profileID: config.profileID)?.adventure.active == nil)
        #expect(session.abandon())
        #expect(growth.state.adventure.active == nil)
        #expect(growth.state.adventure.results.first?.seconds == 5)
        let next = AdventureSession(levelID: 1, model: model, profileID: config.profileID, difficulty: .hard)
        #expect(next.battle.id != session.battle.id)
        #expect(next.battle.phase == .preparing && next.battle.elapsed == 0 && next.battle.wave == 1)
        #expect(next.battle.towers.isEmpty && next.battle.enemies.isEmpty)
        #expect(next.battle.difficulty == .hard)
        session.resume()
        session.advance(by: 20)
        #expect(session.battle.elapsed == 5)
        next.plant("inkling", lane: 0, column: 0)
        next.start()
        #expect(growth.state.coins == 20)
    }

    @Test func finishingAndLeavingNeverProduceClassicLearningRewards() throws {
        let (model, config) = try context()
        let growth = model.growth(for: config.profileID)
        let session = AdventureSession(levelID: 1, model: model, profileID: config.profileID, difficulty: .easy)
        for lane in 0..<5 { session.plant("inkling", lane: lane, column: 0) }
        session.start()
        let before = growth.state
        session.advance(by: 600)
        #expect(session.battle.phase == .won)
        #expect(growth.state.adventure.results.count == 1)
        #expect(growth.state.stats == before.stats)
        #expect(growth.state.xp == before.xp)
        #expect(growth.state.coins == 35)
        session.suspend()
        #expect(growth.state.adventure.active == nil)
        #expect(try model.database?.games(profileID: config.profileID).isEmpty == true)
    }

    @Test func sceneKeepsAdvancingAcrossRenderFramesAndStopsWhilePaused() throws {
        let (model, config) = try context()
        let session = AdventureSession(levelID: 1, model: model, profileID: config.profileID, difficulty: .easy)
        session.plant("inkling", lane: 0, column: 0)
        session.start()
        session.scene.update(100)
        for tick in 1...10 { session.scene.update(100 + Double(tick) * 0.1) }
        #expect(session.battle.elapsed >= 0.8)
        session.suspend()
        let paused = session.battle.elapsed
        session.scene.update(200)
        session.scene.update(201)
        #expect(session.battle.elapsed == paused)
        session.resume()
        session.scene.update(300)
        session.scene.update(300.1)
        #expect(session.battle.elapsed > paused)
    }
}
