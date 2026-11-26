import Foundation
import LearnCore
import Testing
@testable import LearnGame

@MainActor
@Suite("毁灭菇暂停与新局")
struct AdventureDoomSessionTests {
    @Test func pausePreservesFuseButNewGameDiscardsCooldownAndCrater() throws {
        let database = try LearnDatabase(url: nil)
        let profile = Profile(name: "爆破测试", grade: .g3, avatar: "🐯")
        try database.saveProfiles([profile])
        var growth = GrowthState()
        growth.coins = 50
        growth.owned.insert("defender.doomShroom")
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
        session.advance(by: 30)
        #expect(session.battle == saved)
        session.resume()
        session.advance(by: 0.5)
        #expect(session.battle.doomCharges.isEmpty)
        #expect(session.battle.doomCraters.count == 1)
        #expect(session.hud.doomCooldown == 49)
        #expect(session.abandon())
        let next = AdventureSession(levelID: 1, model: model, profileID: profile.id, difficulty: .normal)
        #expect(next.battle.phase == .preparing)
        #expect(next.battle.doomCharges.isEmpty && next.battle.doomCraters.isEmpty)
        #expect(next.hud.doomCooldown == 0)
        #expect(next.scene.childNode(withName: "DoomExplosion") == nil)
        #expect(model.growth(for: profile.id).state.coins == 35)
    }
}
