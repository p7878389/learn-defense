import Foundation
import Testing
@testable import LearnCore

/// 固定在上海时区，保证「同一天 / 跨天」判断可重复
private let calendar: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Asia/Shanghai")!
    return c
}()

private func day(_ d: Int, hour: Int = 10) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: 11, day: d, hour: hour))!
}

private let catalog = GrowthCatalog.bundled

@Suite("节奏配置")
struct PacingTests {
    @Test func bundledConfigLoadsCleanly() {
        #expect(catalog.issues.isEmpty, "\(catalog.issues)")
        #expect(catalog.pacing == .defaults, "内置 JSON 和代码里的默认值应保持一致")
        #expect(catalog.badges.count == 12)
        #expect(Set(CosmeticSlot.allCases) == Set(catalog.cosmetics.map(\.slot)))
    }

    @Test func questionBudgetPerGradeAndDifficulty() {
        for grade in Grade.allCases {
            let counts = Difficulty.allCases.map { catalog.pacing.questionBudget(grade: grade, difficulty: $0) }
            #expect(counts == counts.sorted(), "\(grade) 难度越高题量不应减少")
            #expect(counts.allSatisfy { (6...18).contains($0) }, "\(grade) 题量 \(counts) 超出 6~18")
        }
        #expect(catalog.pacing.questionBudget(grade: .g1, difficulty: .normal) == 12)
        #expect(catalog.pacing.questionBudget(grade: .g6, difficulty: .hard) == 18)
    }

    @Test func wavePlanMatchesQuestionBudgetExactly() {
        var rng = SeededRNG(state: 11)
        for grade in Grade.allCases {
            for difficulty in Difficulty.allCases {
                let tuning = GameTuning.make(grade: grade, difficulty: difficulty)
                for _ in 0..<50 {
                    let kinds = tuning.waves.kinds(questions: tuning.questions, using: &rng)
                    #expect(kinds.reduce(0) { $0 + $1.hp } == tuning.questions)
                    #expect(kinds.prefix(tuning.waves.warmup).allSatisfy { $0 == tuning.waves.basic })
                    if let boss = tuning.waves.boss { #expect(kinds.last == boss) }
                }
            }
        }
        // 题量太少放不下首领时就不出首领
        let plan = WavePlan(mix: [WavePlan.Entry(.armored, weight: 1)], boss: .king)
        let small = plan.kinds(questions: 4, using: &rng)
        #expect(small.reduce(0) { $0 + $1.hp } == 4 && !small.contains(.king))
    }

    @Test func reviewBudget() {
        let pacing = catalog.pacing
        #expect(pacing.reviewBudget(itemCount: 1, cap: 12) == 6, "错题少时至少 6 题")
        #expect(pacing.reviewBudget(itemCount: 5, cap: 12) == 10)
        #expect(pacing.reviewBudget(itemCount: 30, cap: 12) == 12, "最多不超过本档题量")
    }

    @Test func invalidValuesFallBackToDefaults() {
        let json = """
        { "questions": [ { "grades": ["g1", "g2"], "easy": 0, "normal": 12, "hard": 14 },
                         { "grades": ["k2", "k3", "g3", "g4", "g5", "g6"], "easy": 9, "normal": 9, "hard": 9 } ],
          "daily": { "fullRewardGames": 0, "extraGameRewardRate": 0.5, "firstWinXP": 30, "firstWinCoins": 10 },
          "levels": { "perLevel": 100, "offset": -200, "maxPerLevel": 1500 } }
        """
        let (config, issues) = PacingConfig.parse(Data(json.utf8))
        #expect(config.questionBudget(grade: .g1, difficulty: .easy) == 10, "一二年级那条无效，用默认题量")
        #expect(config.questionBudget(grade: .g3, difficulty: .hard) == 9)
        #expect(config.daily.fullRewardGames == 5)
        #expect(config.levels == PacingConfig.defaults.levels)
        #expect(config.review == PacingConfig.defaults.review)
        #expect(issues.contains { $0.contains("questions[0]") })
        #expect(issues.contains { $0.contains("一年级") })
        #expect(issues.contains { $0.contains("daily.fullRewardGames") })
        #expect(issues.contains { $0.contains("levels") })
        #expect(issues.contains { $0.contains("review") }, "缺少的项也要提示")
        #expect(PacingConfig.parse(Data("oops".utf8)).0 == .defaults)
    }
}

@Suite("等级曲线")
struct LevelCurveTests {
    let curve = catalog.pacing.levelCurve

    @Test func boundaries() {
        #expect(curve.xpToNext(level: 1) == 60)
        #expect(curve.xpToNext(level: 5) == 460)
        #expect(curve.xpToNext(level: 6) == 560)
        #expect(curve.xpToNext(level: 16) == 1500, "16 级起每级固定 1500")
        #expect(curve.xpToNext(level: 40) == 1500, "不设等级上限")
        #expect(curve.totalXP(toReach: 5) == 840)
        #expect(curve.totalXP(toReach: 10) == 4140)
        #expect(curve.progress(totalXP: 0) == LevelProgress(level: 1, xpIntoLevel: 0, xpForNext: 60))
        #expect(curve.progress(totalXP: 59).level == 1)
        #expect(curve.progress(totalXP: 60) == LevelProgress(level: 2, xpIntoLevel: 0, xpForNext: 160))
        #expect(curve.progress(totalXP: 840 + 390) == LevelProgress(level: 5, xpIntoLevel: 390, xpForNext: 460))
    }

    /// 每局约 100 经验连续玩：第 1 局升 Lv.2、8~10 局到 Lv.5、35~45 局到 Lv.10，任何一级都不超过 16 局
    @Test func pacingSimulation() {
        var xp = 0
        var reached: [Int: Int] = [:]
        var lastLevel = 1
        var gamesInLevel = 0
        var longest = 0
        for game in 1...400 {
            xp += 100
            gamesInLevel += 1
            let level = curve.progress(totalXP: xp).level
            if level > lastLevel {
                longest = max(longest, gamesInLevel)
                gamesInLevel = 0
                for l in (lastLevel + 1)...level where reached[l] == nil { reached[l] = game }
                lastLevel = level
            }
        }
        #expect(reached[2] == 1)
        #expect((8...10).contains(reached[5] ?? 0), "Lv.5 在第 \(reached[5] ?? 0) 局")
        #expect((35...45).contains(reached[10] ?? 0), "Lv.10 在第 \(reached[10] ?? 0) 局")
        #expect(longest <= 16, "最长一级要 \(longest) 局")
    }
}

@Suite("结算")
struct SettlementTests {
    func report(won: Bool = true, _ difficulty: Difficulty = .normal, questions: Int = 20, correct: Int = 17,
                stars: Int = 2, at date: Date = day(5)) -> GameReport {
        GameReport(won: won, difficulty: difficulty, questions: questions, firstTryCorrect: correct, stars: stars, date: date)
    }

    @Test func typicalGameAndDailyFirstWin() {
        var state = GrowthState()
        // 标准难度、正确率 85%、2 星：(51 + 20 + 20) × 1.2 ≈ 109，加每日首胜 30
        let first = state.settle(report(), catalog: catalog, calendar: calendar)
        #expect(first.dailyFirstWin)
        #expect(first.xp == 109 + 30)
        #expect(first.coins == 17 + 15 + 10 + 10)
        let second = state.settle(report(at: day(5, hour: 11)), catalog: catalog, calendar: calendar)
        #expect(!second.dailyFirstWin && second.xp == 109 && second.coins == 42)
        #expect(state.stats.gamesPlayed == 2 && state.stats.gamesWon == 2 && state.stats.normalWins == 2)
    }

    @Test func difficultyRates() {
        var state = GrowthState()
        _ = state.settle(report(at: day(4)), catalog: catalog, calendar: calendar) // 先用掉每日首胜
        state.stats.day = GrowthState.dayKey(day(5), calendar: calendar)
        state.stats.wonToday = true
        #expect(state.settle(report(.easy, questions: 10, correct: 10, stars: 3), catalog: catalog, calendar: calendar).xp == 110)
        #expect(state.settle(report(.hard, questions: 10, correct: 10, stars: 3), catalog: catalog, calendar: calendar).xp == 165)
    }

    @Test func lossGivesOnlyAnswerRewards() {
        var state = GrowthState()
        let result = state.settle(report(won: false, questions: 10, correct: 6, stars: 3), catalog: catalog, calendar: calendar)
        #expect(result.xp == Int((0.6 * 60 * 1.2).rounded()))
        #expect(result.coins == 12)
        #expect(!result.dailyFirstWin && state.stats.gamesWon == 0 && !state.stats.wonToday)
    }

    @Test func sixthGameOfTheDayIsHalved() {
        var state = GrowthState()
        var results: [GrowthResult] = []
        for i in 0..<6 {
            results.append(state.settle(report(at: day(5, hour: 8 + i)), catalog: catalog, calendar: calendar))
        }
        #expect(results[4].reduced == false && results[4].xp == 109)
        #expect(results[5].reduced && results[5].xp == 55 && results[5].fullXP == 109)
        #expect(results[5].coins == 21 && results[5].fullCoins == 42)
        // 第二天重新算
        let next = state.settle(report(at: day(6)), catalog: catalog, calendar: calendar)
        #expect(!next.reduced && next.dailyFirstWin && next.gamesToday == 1)
    }

    @Test func levelUpGivesCoinsAndUnlocks() {
        var state = GrowthState()
        state.xp = catalog.pacing.levelCurve.totalXP(toReach: 5) + 400
        state.stats.day = GrowthState.dayKey(day(5), calendar: calendar)
        state.stats.wonToday = true
        let coinsBefore = state.coins
        let result = state.settle(report(.hard, questions: 10, correct: 10, stars: 3), catalog: catalog, calendar: calendar)
        #expect(result.leveledUp && result.before.level == 5 && result.after.level == 6)
        #expect(result.levelCoins == 30)
        #expect(result.unlocked.map(\.id).sorted() == ["defeat.confetti", "item.giftHeart"])
        #expect(result.gifts.isEmpty)
        #expect(state.coins == coinsBefore + result.totalCoins)
    }

    @Test func badgesAwardedOnce() {
        var state = GrowthState()
        let first = state.settle(report(questions: 10, correct: 10, stars: 3), catalog: catalog, calendar: calendar)
        #expect(Set(first.newBadges.map(\.id)) == ["firstWin", "threeStar", "perfect"])
        #expect(first.badgeCoins == 20 + 30 + 50)
        let again = state.settle(report(questions: 10, correct: 10, stars: 3, at: day(5, hour: 12)), catalog: catalog, calendar: calendar)
        #expect(again.newBadges.isEmpty)
        // 题太少不算「一字不差」
        var other = GrowthState()
        let short = other.settle(report(questions: 6, correct: 6, stars: 3), catalog: catalog, calendar: calendar)
        #expect(!short.newBadges.contains { $0.id == "perfect" })
    }

    @Test func badgeProgress() {
        var stats = GrowthStats()
        stats.firstTryCorrect = 63
        let badge = catalog.badge(id: "correct100")!
        #expect(badge.progress(stats: stats, level: 6) == (63, 100))
        #expect(catalog.badge(id: "level10")!.progress(stats: stats, level: 6) == (6, 10))
        #expect(!badge.isMet(stats: stats, level: 6))
    }
}

@Suite("外观")
struct CosmeticTests {
    let petal = catalog.cosmetic(id: "projectile.petal")!
    let goldStar = catalog.cosmetic(id: "projectile.goldStar")!
    let original = catalog.cosmetic(id: "projectile.original")!

    @Test func purchaseRules() {
        var state = GrowthState()
        state.coins = 120
        let amethyst = catalog.cosmetic(id: "projectile.amethyst")!
        let early = state.purchase(petal, level: 4)
        #expect(early == .locked(level: 5))
        let free = state.purchase(goldStar, level: 3)
        #expect(free == .alreadyOwned, "免费外观到等级自动拥有")
        let short = state.purchase(amethyst, level: 7)
        #expect(short == .notEnough(short: 30))
        #expect(state.coins == 120, "买不成不扣分")
        let bought = state.purchase(petal, level: 5)
        #expect(bought == .bought && state.coins == 20)
        let again = state.purchase(petal, level: 5)
        #expect(again == .alreadyOwned && state.coins == 20)
        #expect(state.status(of: petal, level: 5) == .owned)
        #expect(state.status(of: catalog.cosmetic(id: "projectile.heart")!, level: 5) == .locked(level: 10))
    }

    @Test func equipAndLoadout() {
        var state = GrowthState()
        let notOwned = state.equip(petal, level: 6)
        #expect(!notOwned, "没买不能装")
        let star = state.equip(goldStar, level: 3)
        #expect(star)
        #expect(state.status(of: goldStar, level: 3) == .equipped)
        #expect(state.status(of: original, level: 3) == .owned)
        state.equipped["defeat"] = "defeat.unknown"
        state.xp = catalog.pacing.levelCurve.totalXP(toReach: 3)
        let loadout = state.loadout(catalog)
        #expect(loadout.projectile?.shape == .star)
        #expect(loadout.defeat == nil, "未知外观回退原版")
        #expect(loadout.projectile(for: .inkling).shape == .star)
        #expect(loadout.projectile(for: .frost) == DefenderKind.frost.projectile, "寒冰射手的子弹不换")
        #expect(loadout.projectile(for: .starling) == DefenderKind.starling.projectile)
        let reset = state.equip(original, level: 3)
        #expect(reset && state.equipped["projectile"] == nil, "装原版等于卸下")
    }

    @Test func itemSkinOnlyChangesLook() {
        var state = GrowthState()
        state.coins = 100
        state.xp = catalog.pacing.levelCurve.totalXP(toReach: 4)
        let ice = catalog.cosmetic(id: "item.iceCube")!
        let bought = state.purchase(ice, level: 4)
        #expect(bought == .bought)
        let equipped = state.equip(ice, level: 4)
        #expect(equipped)
        let skinned = state.loadout(catalog).skin(.frostCharm)
        #expect(skinned.icon == "🧊" && skinned.name == "冰块符")
        #expect(skinned.id == ItemKind.frostCharm.id && skinned.effects == ItemKind.frostCharm.effects)
        #expect(state.loadout(catalog).skin(.heartLeaf) == .heartLeaf)
    }
}

@Suite("成长存档")
struct GrowthStoreTests {
    func tempURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("growth-\(UUID().uuidString).json")
    }

    @Test func roundTrip() throws {
        let db = try LearnDatabase(url: nil)
        let id = UUID()
        let store = GrowthStore(profileID: id, database: db, catalog: catalog)
        // 存档里的时间精确到秒，这里用整秒的时间才能逐字段比较
        _ = store.settle(GameReport(won: true, difficulty: .easy, questions: 10, firstTryCorrect: 9, stars: 2, date: day(5)))
        let reloaded = GrowthStore(profileID: id, database: db, catalog: catalog)
        #expect(reloaded.state == store.state)
        #expect(reloaded.state.badges["firstWin"] != nil)
        #expect(GrowthStore(profileID: UUID(), database: db, catalog: catalog).state == GrowthState())
    }

    @Test func oldFileWithMissingFieldsStillLoads() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: AppPaths.migratedBackup(for: url)) }
        try Data(#"{ "xp": 300, "stats": { "gamesPlayed": 4 } }"#.utf8).write(to: url)
        let db = try LearnDatabase(url: nil)
        let id = UUID()
        let store = GrowthStore(profileID: id, database: db, legacyFile: url, catalog: catalog)
        #expect(store.state.xp == 300 && store.state.coins == 0 && store.state.stats.gamesPlayed == 4)
        #expect(store.state.equipped.isEmpty)
        // 已导入数据库，旧文件改名备份
        #expect(try db.growthState(profileID: id)?.xp == 300)
        #expect(!FileManager.default.fileExists(atPath: url.path))
        #expect(FileManager.default.fileExists(atPath: AppPaths.migratedBackup(for: url).path))
    }

    @Test func corruptedFileIsBackedUp() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url.appendingPathExtension("bak")) }
        try Data("not json".utf8).write(to: url)
        let store = GrowthStore(database: try LearnDatabase(url: nil), legacyFile: url, catalog: catalog,
                                legacyCorrectAnswers: { 500 })
        #expect(store.state == GrowthState(), "文件坏了从头开始，不重复补发")
        #expect(FileManager.default.fileExists(atPath: url.appendingPathExtension("bak").path))
    }

    @Test func withoutDatabaseLegacyFileIsReadOnly() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try Data(#"{ "xp": 120 }"#.utf8).write(to: url)
        let store = GrowthStore(legacyFile: url, catalog: catalog)
        #expect(store.state.xp == 120)
        #expect(FileManager.default.fileExists(atPath: url.path), "数据库打不开时不动旧文件")
    }

    @Test func migrationFromOldProgress() throws {
        let store = GrowthStore(database: try LearnDatabase(url: nil), legacyFile: tempURL(), catalog: catalog,
                                legacyCorrectAnswers: { 150 })
        #expect(store.state.xp == 750 && store.state.coins == 150)
        #expect(store.state.badges["correct100"] != nil)
        let capped = GrowthState.migrated(fromCorrectAnswers: 5000, catalog: catalog)
        #expect(capped.level(catalog.pacing.levelCurve).level == 10, "最多补到 Lv.10")
        #expect(GrowthStore(catalog: catalog, legacyCorrectAnswers: { 0 }).state == GrowthState())
    }
}
