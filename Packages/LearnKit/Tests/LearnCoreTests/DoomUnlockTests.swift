import Foundation
import Testing
@testable import LearnCore

@Suite("毁灭菇永久解锁")
struct DoomUnlockTests {
    @Test func levelAndWalletFailuresNeverSpendPoints() {
        var state = GrowthState()
        state.coins = 600
        #expect(state.purchaseDoomShroom(level: 2) == .locked(level: 3))
        #expect(state.coins == 600)
        #expect(!state.ownsDoomShroom)
        state.coins = 299
        #expect(state.purchaseDoomShroom(level: 3) == .notEnough(short: 1))
        #expect(state.coins == 299)
        #expect(!state.ownsDoomShroom)
    }

    @Test func exactPriceUnlocksPermanentlyAndCannotChargeTwice() throws {
        var state = GrowthState()
        state.coins = 300
        #expect(state.purchaseDoomShroom(level: 3) == .bought)
        #expect(state.coins == 0)
        #expect(state.ownsDoomShroom)
        #expect(state.purchaseDoomShroom(level: 1) == .alreadyOwned)
        let restored = try JSONDecoder().decode(GrowthState.self, from: JSONEncoder().encode(state))
        #expect(restored.ownsDoomShroom)
        #expect(restored.coins == 0)
        #expect(!GrowthState().ownsDoomShroom, "旧档或新孩子不能自动获得功能道具")
    }

    @Test func purchaseSurvivesReopeningAndNeverUnlocksAnotherChild() throws {
        let db = try LearnDatabase(url: nil)
        let first = UUID(), second = UUID()
        var state = GrowthState()
        state.xp = 220
        state.coins = 300
        try db.saveGrowthState(state, profileID: first)
        try db.saveGrowthState(state, profileID: second)
        let store = GrowthStore(profileID: first, database: db, catalog: .bundled)
        #expect(try store.purchaseDoomShroom() == .bought)
        let reopened = GrowthStore(profileID: first, database: db, catalog: .bundled)
        let other = GrowthStore(profileID: second, database: db, catalog: .bundled)
        #expect(reopened.state.ownsDoomShroom)
        #expect(reopened.state.coins == 0)
        #expect(!other.state.ownsDoomShroom)
        #expect(other.state.coins == 300)
    }

    @Test func forgedLockedAdventureDeckCannotSpendEntryFee() throws {
        let db = try LearnDatabase(url: nil)
        let profile = UUID()
        var state = GrowthState(); state.coins = 600
        try db.saveGrowthState(state, profileID: profile)
        let store = GrowthStore(profileID: profile, database: db, catalog: .bundled)
        var battle = AdventureBattle(level: AdventureCatalog.levels[0], deck: ["inkling", "frost", "wallnut", "doomShroom"])
        #expect(battle.plant("inkling", lane: 0, column: 0) == true)
        #expect(battle.start() == true)
        #expect(throws: AdventureError.self) { try store.startAdventure(battle) }
        #expect(store.state.coins == 600)
        #expect(store.state.adventure.active == nil)
    }
}
