import Foundation
import LearnCore
import Testing
@testable import LearnGame

@MainActor
@Suite("毁灭菇会话恢复")
struct AdventureDoomSessionTests {
    @Test func paidBattleRestoresFuseCooldownAndCraterWithoutChargingAgain() throws {
        let database = try LearnDatabase(url: nil)
        let profile = Profile(name: "爆破测试", grade: .g3, avatar: "🐯")
        try database.saveProfiles([profile])
        var growth = GrowthState()
        growth.coins = 50
        try database.saveGrowthState(growth, profileID: profile.id)
        let model = AppModel(database: database, library: .load(userDirectory: nil),
                             speechLibrary: SpeechLibrary(database: database))
        let session = AdventureSession(levelID: 1, model: model, profileID: profile.id, difficulty: .normal,
                                       deck: ["inkling", "frost", "wallnut", "doomShroom"])
        session.plant("inkling", lane: 4, column: 0)
        session.plant("doomShroom", lane: 2, column: 5)
        session.start()
        session.advance(by: 0.5)
        session.suspend()
        let saved = session.battle
        #expect(session.hud.doomCooldown == 50)
        let restored = AdventureSession(levelID: 1, model: model, profileID: profile.id, difficulty: .normal)
        #expect(restored.battle == saved)
        #expect(restored.battle.doomCharges.count == 1)
        restored.advance(by: 30)
        #expect(restored.battle == saved)
        restored.resume()
        restored.advance(by: 0.5)
        #expect(restored.battle.doomCharges.isEmpty)
        #expect(restored.battle.doomCraters.count == 1)
        #expect(restored.hud.doomCooldown == 49)
        restored.suspend()
        let crater = AdventureSession(levelID: 1, model: model, profileID: profile.id, difficulty: .normal)
        #expect(crater.battle.doomCraters == restored.battle.doomCraters)
        #expect(crater.scene.childNode(withName: "DoomExplosion") == nil)
        #expect(model.growth(for: profile.id).state.coins == 35)
    }
}
