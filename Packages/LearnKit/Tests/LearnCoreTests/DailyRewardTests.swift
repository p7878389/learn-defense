import Foundation
import Testing
@testable import LearnCore

@Suite("每日积分硬上限")
struct DailyRewardTests {
    @Test func repeatedGamesCannotFarmUnlimitedCoins() throws {
        var state = GrowthState()
        let catalog = GrowthCatalog.bundled
        let date = Date(timeIntervalSince1970: 1_790_000_000)
        let report = GameReport(won: true, difficulty: .hard, questions: 20,
                                firstTryCorrect: 20, stars: 3, date: date)
        for _ in 0..<500 { _ = state.settle(report, catalog: catalog) }
        #expect(state.coins <= 400)
        let restored = try JSONDecoder().decode(GrowthState.self, from: JSONEncoder().encode(state))
        state = restored
        let afterRestart = state.settle(report, catalog: catalog)
        #expect(afterRestart.totalCoins == 0)
        let tomorrow = GameReport(won: true, difficulty: .hard, questions: 20,
                                  firstTryCorrect: 20, stars: 3, date: date.addingTimeInterval(86400))
        #expect(state.settle(tomorrow, catalog: catalog).coins > 0)
    }

    @Test func emptyGameCannotEarnWinOrBadgeRewards() {
        var state = GrowthState()
        let result = state.settle(GameReport(won: true, difficulty: .hard, questions: 0,
                                            firstTryCorrect: 0, stars: 3), catalog: .bundled)
        #expect(result.totalCoins == 0)
        #expect(result.xp == 0)
        #expect(state.stats.gamesWon == 0)
    }
    @Test func oldSaveDefaultsAndSpendingCannotResetAllowance() throws {
        var state = try JSONDecoder().decode(GrowthState.self, from: Data(#"{"coins":50,"stats":{}}"#.utf8))
        #expect(state.stats.coinsToday.isEmpty)
        let date = Date(timeIntervalSince1970: 1_790_000_000)
        let report = GameReport(won: false, difficulty: .easy, questions: 10,
                                firstTryCorrect: 10, stars: 0, date: date)
        for _ in 0..<10 { _ = state.settle(report, catalog: .bundled) }
        #expect(state.stats.coinsToday["answers"] == 100)
        state.coins = 0
        #expect(state.settle(report, catalog: .bundled).coins == 0)
    }

    @Test func oneAnswerOnlyEarnsProportionalAnswerReward() {
        var state = GrowthState()
        let result = state.settle(GameReport(won: false, difficulty: .easy, questions: 1,
                                            firstTryCorrect: 1, stars: 0), catalog: .bundled)
        #expect(result.coins == 3)
        #expect(result.xp == 10)
    }

    @Test func eachSourceIsCappedIndependently() {
        var state = GrowthState()
        let date = Date(timeIntervalSince1970: 1_790_000_000)
        let report = GameReport(won: true, difficulty: .hard, questions: 20,
                                firstTryCorrect: 20, stars: 3, bossesDefeated: 10, enemiesDefeated: 20,
                                itemsUsed: 10, ultimatesCast: 10, date: date)
        for _ in 0..<500 { _ = state.settle(report, catalog: .bundled) }
        #expect(state.stats.coinsToday["answers"] == 100)
        #expect(state.stats.coinsToday["completion"] == 100)
        #expect(state.stats.coinsToday["firstWin"] == 10)
        #expect(state.stats.coinsToday["level"] == 90)
        #expect(state.stats.coinsToday["badge"] == 100)
        #expect(state.coins == 400)
    }

    @Test func databaseReopenKeepsDailyAllowance() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("daily-coins-\(UUID())")
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("learn.store")
        let profileID = UUID()
        let report = GameReport(won: false, difficulty: .easy, questions: 10,
                                firstTryCorrect: 10, stars: 0)
        do {
            let store = GrowthStore(profileID: profileID, database: try LearnDatabase(url: url), catalog: .bundled)
            for _ in 0..<10 { _ = store.settle(report) }
        }
        let reopened = GrowthStore(profileID: profileID, database: try LearnDatabase(url: url), catalog: .bundled)
        #expect(reopened.settle(report).coins == 0)
        #expect(reopened.state.stats.coinsToday["answers"] == 100)
    }

}
