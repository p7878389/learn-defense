import Foundation
import SwiftData
import Testing
@testable import LearnCore

@Suite("存储可靠性")
struct StorageReliabilityTests {
    enum Failure: Error { case interrupted }

    @Test func settlementCannotAwardAnotherChildInTheSameDatabase() throws {
        let db = try LearnDatabase(url: nil)
        let id = UUID()
        let other = GrowthStore(profileID: UUID(), database: db, catalog: .bundled)
        let recorder = GameRecorder(database: db, profileID: id, grade: .g3, difficulty: .easy, packIDs: [], selection: .all)
        let summary = GameSummary(questions: 1, firstTryCorrect: 1, stars: 1, score: 10,
            enemiesDefeated: 1, bossesDefeated: 0, itemsUsed: 0, ultimatesCast: 0, seconds: 5)
        var rejected = false
        do {
            try recorder.finish(.won, summary: summary, growth: other,
                                report: GameReport(won: true, difficulty: .easy, questions: 1, firstTryCorrect: 1, stars: 1))
        } catch { rejected = true }
        #expect(rejected && recorder.record == nil)
        #expect(other.state.stats.gamesPlayed == 0)
        #expect(try db.games(profileID: id).isEmpty)
    }

    @Test func failedRecorderSaveLeavesItRetryable() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("readonly.store")
        let id = UUID()
        do {
            let writer = try LearnDatabase(url: url)
            var state = GrowthState(); state.coins = 400
            try writer.saveGrowthState(state, profileID: id)
        }
        let db = try LearnDatabase(configuration: ModelConfiguration(schema: LearnDatabase.schema, url: url, allowsSave: false))
        let growth = GrowthStore(profileID: id, database: db, catalog: .bundled)
        let recorder = GameRecorder(database: db, profileID: id, grade: .g3, difficulty: .easy,
                                    packIDs: [], selection: .all)
        let summary = GameSummary(questions: 1, firstTryCorrect: 1, stars: 1, score: 10,
            enemiesDefeated: 1, bossesDefeated: 0, itemsUsed: 0, ultimatesCast: 0, seconds: 5)
        var rejected = false
        do {
            try recorder.finish(.won, summary: summary, growth: growth,
                                report: GameReport(won: true, difficulty: .easy, questions: 1, firstTryCorrect: 1, stars: 1))
        } catch { rejected = true }
        #expect(rejected)
        #expect(recorder.record == nil)
        #expect(try db.games(profileID: recorder.profileID).isEmpty)
        #expect(!db.context.hasChanges)
        #expect(growth.state.xp == 0 && growth.state.coins == 400)
        #expect(try db.growthState(profileID: id)?.coins == 400)
    }

    @Test func repairedGrowthAllowsOneSettlementAfterRetry() throws {
        let db = try LearnDatabase(url: nil)
        let id = UUID()
        var saved = GrowthState(); saved.coins = 400
        try db.saveGrowthState(saved, profileID: id)
        let row = try #require(try db.context.fetch(FetchDescriptor<StoredGrowth>()).first)
        let original = row.stateData
        row.stateData = Data("broken".utf8)
        try db.context.save()
        let growth = GrowthStore(profileID: id, database: db, catalog: .bundled)
        let recorder = GameRecorder(database: db, profileID: id, grade: .g3, difficulty: .easy, packIDs: [], selection: .all)
        let summary = GameSummary(questions: 1, firstTryCorrect: 1, stars: 1, score: 10,
            enemiesDefeated: 1, bossesDefeated: 0, itemsUsed: 0, ultimatesCast: 0, seconds: 5)
        let report = GameReport(won: true, difficulty: .easy, questions: 1, firstTryCorrect: 1, stars: 1)
        do { try recorder.finish(.won, summary: summary, growth: growth, report: report) }
        catch { /* 修复前保留同一局。 */ }
        #expect(recorder.record == nil && growth.loadError != nil)
        row.stateData = original
        try db.context.save()
        try growth.reload()
        let result = try #require(try recorder.finish(.won, summary: summary, growth: growth, report: report))
        let coins = growth.state.coins
        _ = try recorder.finish(.won, summary: summary, growth: growth, report: report)
        #expect(growth.state.stats.gamesPlayed == 1 && growth.state.coins == coins)
        #expect(coins == 400 + result.totalCoins)
        #expect(try db.games(profileID: id).count == 1)
        #expect(try db.games(profileID: id).first?.coins == result.totalCoins)
    }

    @Test func interruptedImportRollsBackFingerprintAndIndexTogether() throws {
        let folders = try ContentLoadTests.Folders()
        let db = try LearnDatabase(url: nil)
        try folders.write("a.json", in: folders.user, id: "p1", title: "原题库")
        _ = try db.loadContent(sources: folders.sources)
        try folders.write("a.json", in: folders.user, id: "p1", title: "替换题库", modified: .now.addingTimeInterval(60))
        do {
            try db.transaction {
                _ = try db.loadContent(sources: folders.sources)
                throw Failure.interrupted
            }
        } catch Failure.interrupted {}
        #expect(try db.packs(grade: .g3, subject: .chinese).map(\.title) == ["原题库"])
        let original = try #require(try db.context.fetch(FetchDescriptor<StoredPackFile>()).first?.data)
        #expect(try ContentLibrary.decode(original).title == "原题库")
        #expect(!db.context.hasChanges)
        #expect(try db.loadContent(sources: folders.sources).packs.map(\.title) == ["替换题库"])
        #expect(try db.packs(grade: .g3, subject: .chinese).map(\.title) == ["替换题库"])
    }

    @Test func unreadableGrowthCannotBeOverwrittenBySettlement() throws {
        let db = try LearnDatabase(url: nil)
        let id = UUID()
        var saved = GrowthState()
        saved.xp = 800
        saved.coins = 600
        saved.owned.insert("defender.doomShroom")
        try db.saveGrowthState(saved, profileID: id)
        let row = try #require(try db.context.fetch(FetchDescriptor<StoredGrowth>()).first)
        let damaged = Data("unreadable growth".utf8)
        row.stateData = damaged
        try db.context.save()
        let store = GrowthStore(profileID: id, database: db, catalog: .bundled)
        var rejected = false
        do { _ = try store.settle(GameReport(won: true, difficulty: .easy, questions: 10, firstTryCorrect: 9, stars: 2)) }
        catch { rejected = true }
        #expect(rejected, "读取失败必须阻止结算，不能用零资产覆盖原记录")
        #expect(row.stateData == damaged)
        #expect(row.xp == 800 && row.coins == 600)
        let item = try #require(GrowthCatalog.bundled.cosmetics.first)
        var blocked = 0
        do { _ = try store.purchase(item) } catch { blocked += 1 }
        do { _ = try store.equip(item) } catch { blocked += 1 }
        do { try store.unequip(key: "defender.inkling") } catch { blocked += 1 }
        do { try store.save() } catch { blocked += 1 }
        #expect(blocked == 4 && row.stateData == damaged)
    }

    @Test func unchangedConfigKeepsItsOriginalSyncTime() throws {
        let db = try LearnDatabase(url: nil)
        try db.syncConfig(.bundled)
        let original = try #require(try db.configFile(named: "pacing.json"))
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        original.syncedAt = date
        try db.context.save()
        try db.syncConfig(.bundled)
        #expect(try db.configFile(named: "pacing.json")?.syncedAt == date)
        #expect(!db.context.hasChanges)
    }

    @Test func changedCatalogUpdatesItsIndexWithoutReplacingPersonalSettings() throws {
        let db = try LearnDatabase(url: nil)
        try db.syncConfig(.bundled)
        try db.saveSetting("保留", named: "personal-test")
        var changed = GrowthCatalog.bundled
        changed.badges[0].coins += 1
        changed.cosmetics[0].price += 10
        try db.syncConfig(changed)
        #expect(try db.badges().first?.coins == changed.badges[0].coins)
        let row = try #require(try db.cosmetics(slot: changed.cosmetics[0].slot).first { $0.id == changed.cosmetics[0].id })
        #expect(row.price == changed.cosmetics[0].price)
        #expect(try db.setting(named: "personal-test", fallback: "") == "保留")
    }
}
