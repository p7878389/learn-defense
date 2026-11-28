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
}
