import Foundation
import Testing
@testable import LearnCore

@Suite("积分获取与消耗流水")
struct CoinLedgerTests {
    @Test func recordsSettlementPurchaseDoomAndAdventureWithBalances() throws {
        let catalog = GrowthCatalog.bundled
        let store = GrowthStore(catalog: catalog)
        let now = Date()

        // 1. 经典对局结算（答题 + 过关 + 每日首胜 + 可能的升级/徽章）
        let report = GameReport(won: true, difficulty: .normal, questions: 10, firstTryCorrect: 10, stars: 3, date: now)
        let result = try store.settle(report)
        #expect(result.totalCoins > 0)
        #expect(store.state.totalCoinsEarned == result.totalCoins)
        #expect(store.state.totalCoinsSpent == 0)
        #expect(store.state.coinLedger.first?.balance == store.state.coins)
        #expect(store.state.coinLedger.contains { $0.kind == .answers && $0.delta > 0 })
        #expect(store.state.coinLedger.contains { $0.kind == .completion && $0.delta > 0 })
        #expect(store.state.coinLedger.contains { $0.kind == .firstWin && $0.delta > 0 })

        // 2. 冒险模式入场扣 15 积分
        var battle = AdventureBattle(level: AdventureCatalog.levels[0], difficulty: .normal)
        _ = battle.plant("inkling", lane: 2, column: 1)
        _ = battle.start()
        try store.startAdventure(battle)
        let latest = try #require(store.state.coinLedger.first)
        #expect(latest.kind == .adventureEntry)
        #expect(latest.delta == -AdventureCatalog.entryCost)
        #expect(latest.balance == store.state.coins)
        #expect(store.state.totalCoinsSpent == AdventureCatalog.entryCost)

        // 3. 购买外观与解锁毁灭菇
        var state = store.state
        state.coins = 1000
        if let paidItem = catalog.cosmetics.first(where: { $0.slot.isCollectible && $0.price > 0 && $0.unlockBadge == nil && $0.unlockStat == nil }) {
            let res = state.purchase(paidItem, level: max(10, paidItem.unlockLevel))
            #expect(res == .bought)
            #expect(state.coinLedger.first?.kind == .purchaseCosmetic)
            #expect(state.coinLedger.first?.delta == -paidItem.price)
            #expect(state.coinLedger.first?.balance == state.coins)
        }

        let doomRes = state.purchaseDoomShroom(level: AdventureDoom.unlockLevel)
        #expect(doomRes == .bought)
        #expect(state.coinLedger.first?.kind == .purchaseDoomShroom)
        #expect(state.coinLedger.first?.delta == -AdventureDoom.unlockPrice)
        #expect(state.coinLedger.first?.balance == state.coins)
    }

    @Test func legacyArchiveWithoutCoinLedgerDecodesCleanly() throws {
        let legacyJSON = #"{"version":1,"xp":120,"coins":88,"badges":{},"owned":[],"equipped":{},"stats":{}}"#
        let decoded = try JSONDecoder.growth.decode(GrowthState.self, from: Data(legacyJSON.utf8))
        #expect(decoded.coins == 88)
        #expect(decoded.coinLedger.isEmpty)
    }

    @Test func ledgerCapsAtMaxStoredCountAndSummarizesToday() {
        var state = GrowthState()
        let today = Date()
        for i in 1...(CoinRecord.maxStoredCount + 25) {
            state.coins += 1
            state.appendCoinRecord(kind: .answers, delta: 1, title: "记录 \(i)", date: today)
        }
        #expect(state.coinLedger.count == CoinRecord.maxStoredCount)
        #expect(state.coinLedger.first?.title == "记录 \(CoinRecord.maxStoredCount + 25)")
        let summary = state.dayCoinsSummary(at: today)
        #expect(summary.earned == CoinRecord.maxStoredCount)
        #expect(summary.spent == 0)
    }

    @Test func filtersGroupsAndSummarizesByDirectionRangeAndKind() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 8 * 3600))
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 28, hour: 15, minute: 0)))
        let threeDaysAgo = try #require(calendar.date(byAdding: .day, value: -3, to: now))
        let tenDaysAgo = try #require(calendar.date(byAdding: .day, value: -10, to: now))

        var state = GrowthState()
        state.coins = 50
        state.appendCoinRecord(kind: .answers, delta: 20, title: "十天前答题", date: tenDaysAgo)
        state.coins = 75
        state.appendCoinRecord(kind: .completion, delta: 25, title: "三天前过关", date: threeDaysAgo)
        state.coins = 60
        state.appendCoinRecord(kind: .adventureEntry, delta: -15, title: "三天前冒险", date: threeDaysAgo)
        state.coins = 90
        state.appendCoinRecord(kind: .answers, delta: 30, title: "今天答题", date: now)
        state.coins = 50
        state.appendCoinRecord(kind: .purchaseCosmetic, delta: -40, title: "今天买皮肤", date: now)

        // 1. 今天范围
        let todayGroups = state.groupedCoinRecords(
            query: CoinLedgerQuery(direction: .all, range: .today),
            referenceDate: now,
            calendar: calendar
        )
        #expect(todayGroups.count == 1)
        #expect(todayGroups[0].earned == 30)
        #expect(todayGroups[0].spent == 40)
        #expect(todayGroups[0].records.count == 2)

        // 2. 近 7 天过滤掉 10 天前的记录，按日分组并保持最新在前
        let weekGroups = state.groupedCoinRecords(
            query: CoinLedgerQuery(direction: .all, range: .last7Days),
            referenceDate: now,
            calendar: calendar
        )
        #expect(weekGroups.count == 2)
        #expect(weekGroups[0].records.map(\.title) == ["今天买皮肤", "今天答题"])
        #expect(weekGroups[1].earned == 25)
        #expect(weekGroups[1].spent == 15)

        // 3. 仅获取 + 指定分类，汇总栏仍保留同方向下的全部获取分类以便切换
        let query = CoinLedgerQuery(direction: .income, range: .all, kind: .answers)
        let answerRecords = state.filteredCoinRecords(query: query, referenceDate: now, calendar: calendar)
        #expect(answerRecords.count == 2)
        #expect(CoinLedgerTotals.summarize(answerRecords) == CoinLedgerTotals(earned: 50, spent: 0))

        let incomeSummaries = state.coinKindSummaries(query: query, referenceDate: now, calendar: calendar)
        #expect(incomeSummaries.count == 2)
        #expect(incomeSummaries[0] == CoinLedgerKindSummary(kind: .answers, count: 2, totalAmount: 50))
        #expect(incomeSummaries[1] == CoinLedgerKindSummary(kind: .completion, count: 1, totalAmount: 25))
        #expect(CoinLedgerDirection.expense.matches(kind: .purchaseCosmetic))
        #expect(!CoinLedgerDirection.expense.matches(kind: .answers))
    }

    @Test func dailyCoinAllowancesResetsAcrossCalendarDays() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 8 * 3600))
        let day1 = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 28, hour: 10, minute: 0)))
        let day2 = try #require(calendar.date(byAdding: .day, value: 1, to: day1))

        var state = GrowthState()
        let report = GameReport(won: true, difficulty: .normal, questions: 10, firstTryCorrect: 10, stars: 3, date: day1)
        _ = state.settle(report, catalog: .bundled, calendar: calendar)

        let todayAllowances = state.dailyCoinAllowances(at: day1, calendar: calendar)
        #expect(todayAllowances.count == CoinSource.allCases.count)
        let answerAllowance = try #require(todayAllowances.first { $0.source == .answers })
        #expect(answerAllowance.used > 0)
        #expect(answerAllowance.remaining == answerAllowance.limit - answerAllowance.used)

        // 跨天未开新局时，今日额度自动归零，不残留昨日计数
        let nextDayAllowances = state.dailyCoinAllowances(at: day2, calendar: calendar)
        #expect(nextDayAllowances.allSatisfy { $0.used == 0 && $0.remaining == $0.limit })
    }
}
