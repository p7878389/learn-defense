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

    @Test func preparationIsFreeAndRestoredAdventureStartsPausedWithoutCharging() throws {
        let (model, config) = try context()
        let session = AdventureSession(levelID: 1, model: model, profileID: config.profileID, difficulty: .easy)
        session.plant("inkling", lane: 0, column: 0)
        #expect(model.growth(for: config.profileID).state.coins == 50)
        session.start()
        session.start()
        #expect(model.growth(for: config.profileID).state.coins == 35)
        session.advance(by: 5)
        session.suspend()
        let before = session.battle
        session.advance(by: 20)
        #expect(session.battle == before)
        let restored = AdventureSession(levelID: 1, model: model, profileID: config.profileID, difficulty: .easy)
        #expect(restored.battle.phase == .paused)
        #expect(restored.battle.id == session.battle.id)
        restored.resume()
        restored.advance(by: 1)
        #expect(model.growth(for: config.profileID).state.coins == 35)
        #expect(restored.battle.elapsed > before.elapsed)
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
