import Foundation
import LearnCore
import SpriteKit
import Testing
@testable import LearnGame

@MainActor
@Suite("毁灭菇全地图权限")
struct DoomAvailabilityTests {
    private func model(unlocked: Bool, grade: Grade = .g3, active: AdventureBattle? = nil) throws -> (AppModel, Profile) {
        let db = try LearnDatabase(url: nil)
        let profile = Profile(name: "全地图测试", grade: grade, avatar: "🌱")
        try db.saveProfiles([profile])
        var state = GrowthState()
        state.xp = 220
        state.coins = 600
        state.adventure.active = active
        if unlocked { state.owned.insert("defender.doomShroom") }
        try db.saveGrowthState(state, profileID: profile.id)
        return (AppModel(database: db, library: .load(userDirectory: nil), speechLibrary: SpeechLibrary(database: db)), profile)
    }

    @Test(arguments: [Grade.k2, .g3]) func unlockedDoomCanBePlantedInEveryClassicMap(grade: Grade) throws {
        for map in BattleMap.allCases {
            let (model, profile) = try model(unlocked: true, grade: grade)
            let pack = try #require(model.library.packs.first { $0.grade == grade })
            for difficulty in Difficulty.allCases {
                let session = GameSession(config: GameConfig(profileID: profile.id, grade: grade, packIDs: [pack.id], selection: .all, difficulty: difficulty),
                    library: model.library, progress: ProgressStore(), speech: Speech(), growth: model.growth(for: profile.id), map: map)
                let before = session.sun
                #expect(session.plantable.contains { $0.id == "doomShroom" })
                #expect(session.dropSeed(id: "doomShroom", at: CGPoint(x: 602, y: 270)))
                #expect(session.sun == before - 125)
                let after = session.sun
                #expect(!session.dropSeed(id: "doomShroom", at: CGPoint(x: 685, y: 270)), "冷却时不能在另一格再次购买")
                #expect(session.sun == after)
            }
        }
    }

    @Test func lockedDoomCannotBePlantedEvenWithEnoughSun() throws {
        for map in BattleMap.allCases {
            let (model, profile) = try model(unlocked: false)
            let pack = try #require(model.library.packs.first { $0.grade == .g3 })
            let session = GameSession(config: GameConfig(profileID: profile.id, grade: .g3, packIDs: [pack.id], selection: .all, difficulty: .normal),
                library: model.library, progress: ProgressStore(), speech: Speech(), growth: model.growth(for: profile.id), map: map)
            let before = session.sun
            #expect(!session.plantable.contains { $0.id == "doomShroom" })
            #expect(!session.dropSeed(id: "doomShroom", at: CGPoint(x: 602, y: 270)))
            #expect(session.sun == before)
        }
    }

    @Test func lockedAdventureCannotSelectOrPlantDoom() throws {
        let (model, profile) = try model(unlocked: false)
        let session = AdventureSession(levelID: 1, model: model, profileID: profile.id, difficulty: .normal,
            deck: ["inkling", "frost", "wallnut", "doomShroom"])
        #expect(!session.battle.deck.contains("doomShroom"))
        let before = session.battle.sun
        #expect(!session.plant("doomShroom", lane: 2, column: 5))
        #expect(session.battle.sun == before)
    }

    @Test func legacyBattleKeepsPaidChargeButCannotOfferAnotherLockedDoom() throws {
        var battle = AdventureBattle(level: AdventureCatalog.levels[0], deck: ["inkling", "frost", "wallnut", "doomShroom"])
        #expect(battle.plant("inkling", lane: 0, column: 0) == true)
        #expect(battle.plant("doomShroom", lane: 2, column: 5) == true)
        #expect(battle.start() == true)
        _ = battle.advance(by: 0.5)
        let (model, profile) = try model(unlocked: false, active: battle)
        let session = AdventureSession(levelID: 1, model: model, profileID: profile.id, difficulty: .normal)
        #expect(session.battle.id == battle.id)
        #expect(session.battle.doomCharges.count == 1)
        #expect(!session.plantable.contains { $0.id == "doomShroom" })
        session.resume()
        session.advance(by: 0.5)
        #expect(session.battle.doomCharges.isEmpty)
        #expect(session.battle.doomCraters.count == 1)
        #expect(model.growth(for: profile.id).state.coins == 600)
        #expect(!session.plant("doomShroom", lane: 2, column: 6))
    }

    @Test func blastAwardsOneKillWithoutInventingLearningAnswers() throws {
        let (model, profile) = try model(unlocked: true)
        let pack = try #require(model.library.packs.first { $0.grade == .g3 })
        let session = GameSession(config: GameConfig(profileID: profile.id, grade: .g3, packIDs: [pack.id], selection: .all, difficulty: .normal),
            library: model.library, progress: ProgressStore(), speech: Speech(), growth: model.growth(for: profile.id))
        #expect(session.dropSeed(id: "inkling", at: CGPoint(x: 185, y: 70)))
        #expect(session.dropSeed(id: "doomShroom", at: CGPoint(x: 602, y: 270)))
        session.startBattle()
        let spec = try #require(session.nextEnemy())
        _ = session.scene.spawn(spec, lane: 2, x: 602)
        let before = session.sun
        session.scene.update(100)
        for i in 1...22 { session.scene.update(100 + Double(i) * 0.05) }
        #expect(session.defeated == 1)
        #expect(session.sun == before + spec.kind.sunReward)
        #expect(session.attempted == 0)
        #expect(session.firstTryCorrect == 0)
        for i in 23...28 { session.scene.update(100 + Double(i) * 0.05) }
        #expect(session.defeated == 1)
        #expect(session.sun == before + spec.kind.sunReward)
    }
}
