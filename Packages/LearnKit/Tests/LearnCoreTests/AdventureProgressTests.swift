import Foundation
import Testing
@testable import LearnCore

@Suite("冒险积分与存档")
struct AdventureProgressTests {
    private func store(coins: Int = 50, profileID: UUID = UUID(), database: LearnDatabase? = nil) throws -> GrowthStore {
        let database = try database ?? LearnDatabase(url: nil)
        var state = GrowthState()
        state.coins = coins
        try database.saveGrowthState(state, profileID: profileID)
        return GrowthStore(profileID: profileID, database: database, catalog: .bundled)
    }

    private func readyBattle() -> AdventureBattle {
        var battle = AdventureBattle(level: AdventureCatalog.levels[0])
        for lane in 0..<5 { _ = battle.plant("inkling", lane: lane, column: 0) }
        _ = battle.start()
        return battle
    }

    @Test func chargesExactlyOnceAndResumesWithoutAnotherCharge() throws {
        let store = try store()
        var battle = readyBattle()
        try store.startAdventure(battle)
        #expect(store.state.coins == 35)
        try store.startAdventure(battle)
        #expect(store.state.coins == 35)
        _ = battle.advance(by: 5)
        battle.pause()
        try store.saveAdventure(battle)
        #expect(store.state.adventure.active?.phase == .paused)
        #expect(store.state.coins == 35)
    }

    @Test func insufficientCoinsAndLockedLevelLeaveWalletUntouched() throws {
        let store = try store(coins: 14)
        #expect(throws: AdventureError.self) { try store.startAdventure(readyBattle()) }
        #expect(store.state.coins == 14)
        #expect(store.state.adventure.active == nil)

        let funded = try self.store()
        var locked = AdventureBattle(level: AdventureCatalog.levels[1])
        _ = locked.plant("inkling", lane: 0, column: 0)
        _ = locked.start()
        #expect(throws: AdventureError.self) { try funded.startAdventure(locked) }
        #expect(funded.state.coins == 50)
    }

    @Test func completedBattleUnlocksNextLevelWithoutClassicRewards() throws {
        let store = try store()
        var battle = readyBattle()
        try store.startAdventure(battle)
        let before = store.state
        _ = battle.advance(by: 600)
        #expect(battle.phase == .won)
        try store.finishAdventure(battle)
        try store.finishAdventure(battle)
        #expect(store.state.coins == 35)
        #expect(store.state.xp == before.xp)
        #expect(store.state.stats == before.stats)
        #expect(store.state.badges == before.badges)
        #expect(store.state.adventure.isUnlocked(2))
        #expect(store.state.adventure.bestStars["1"] == battle.stars)
        #expect(store.state.adventure.results.count == 1)
        #expect(store.state.adventure.active == nil)
    }

    @Test func abandonDoesNotRefundOrUnlockAndCannotOverwriteAnotherRun() throws {
        let store = try store()
        let first = readyBattle()
        try store.startAdventure(first)
        #expect(throws: AdventureError.self) { try store.startAdventure(readyBattle()) }
        #expect(throws: AdventureError.self) { try store.saveAdventure(readyBattle()) }
        try store.abandonAdventure()
        #expect(store.state.coins == 35)
        #expect(!store.state.adventure.isUnlocked(2))
        #expect(store.state.adventure.active == nil)
    }

    @Test func classicEarnedCoinsFundAdventureAndSpendingPreservesDailyAllowance() throws {
        let store = try store(coins: 0)
        let result = try store.settle(GameReport(won: true, difficulty: .easy, questions: 10, firstTryCorrect: 10, stars: 3))
        #expect(result.totalCoins >= 15)
        let balance = store.state.coins
        let allowance = store.state.stats.coinsToday
        try store.startAdventure(readyBattle())
        #expect(store.state.coins == balance - 15)
        #expect(store.state.stats.coinsToday == allowance)
    }

    @Test func oldSaveDefaultsAndDatabaseReopenDiscardsBattleButPreservesWallet() throws {
        let old = try JSONDecoder().decode(GrowthState.self, from: Data(#"{"coins":19,"xp":20}"#.utf8))
        #expect(old.coins == 19)
        #expect(old.adventure.active == nil)
        #expect(old.adventure.isUnlocked(1))
        #expect(!old.adventure.isUnlocked(2))

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("adventure.store")
        let profileID = UUID()
        let battle = readyBattle()
        do {
            let store = try self.store(profileID: profileID, database: LearnDatabase(url: url))
            try store.startAdventure(battle)
        }
        let db = try LearnDatabase(url: url)
        let reopened = GrowthStore(profileID: profileID, database: db, catalog: .bundled)
        #expect(reopened.state.coins == 35)
        #expect(reopened.state.adventure.active == nil)
        let other = GrowthStore(profileID: UUID(), database: db, catalog: .bundled)
        #expect(other.state.adventure.active == nil)
        #expect(other.state.coins == 0)
    }

    @Test func legacyBattleIsIgnoredWhileStarsAndResultsSurvive() throws {
        let store = try store()
        var paid = readyBattle()
        try store.startAdventure(paid)
        _ = paid.advance(by: 600)
        try store.finishAdventure(paid)
        let data = try JSONEncoder().encode(store.state.adventure)
        var legacy = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        legacy["active"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(readyBattle()))
        let decoded = try JSONDecoder().decode(AdventureProgress.self, from: JSONSerialization.data(withJSONObject: legacy))
        #expect(decoded.active == nil)
        #expect(decoded.bestStars == store.state.adventure.bestStars)
        #expect(decoded.results == store.state.adventure.results)
    }

    @Test func existingBackupAndProfileDeletionIncludeAdventureData() throws {
        let database = try LearnDatabase(url: nil)
        let profile = Profile(name: "备份冒险", grade: .g3, avatar: "🐯")
        try database.saveProfiles([profile])
        let store = try self.store(profileID: profile.id, database: database)
        let battle = readyBattle()
        try store.startAdventure(battle)
        let data = try database.backupData(importedPacks: [])
        let archive = try JSONDecoder().decode(SettingsBackup.self, from: data)
        let restoredDB = try LearnDatabase(url: nil)
        try restoredDB.restore(archive)
        let restored = GrowthStore(profileID: profile.id, database: restoredDB, catalog: .bundled)
        #expect(restored.state.adventure.active == nil)
        #expect(restored.state.coins == 35)
        try restoredDB.deletePersonalData(profileID: profile.id)
        #expect(try restoredDB.growthState(profileID: profile.id) == nil)
    }
}
