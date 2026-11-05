import Foundation

/// 一局结束时交给成长系统的数据（只有通关或失败才结算，中途退出不算）
public struct GameReport: Sendable, Equatable {
    public var won: Bool
    public var difficulty: Difficulty
    /// 作答过的题数（每题只算第一次作答）
    public var questions: Int
    public var firstTryCorrect: Int
    public var stars: Int
    public var bossesDefeated: Int
    public var enemiesDefeated: Int
    public var itemsUsed: Int
    public var ultimatesCast: Int
    public var seconds: Int
    public var date: Date

    public init(won: Bool, difficulty: Difficulty, questions: Int, firstTryCorrect: Int, stars: Int,
                bossesDefeated: Int = 0, enemiesDefeated: Int = 0, itemsUsed: Int = 0, ultimatesCast: Int = 0,
                seconds: Int = 0, date: Date = Date()) {
        self.won = won
        self.difficulty = difficulty
        self.questions = max(0, questions)
        self.firstTryCorrect = min(max(0, firstTryCorrect), max(0, questions))
        self.stars = won ? min(max(0, stars), 3) : 0
        self.bossesDefeated = bossesDefeated
        self.enemiesDefeated = enemiesDefeated
        self.itemsUsed = itemsUsed
        self.ultimatesCast = ultimatesCast
        self.seconds = max(0, seconds)
        self.date = date
    }

    /// 首答正确率
    public var accuracy: Double {
        questions == 0 ? 0 : Double(firstTryCorrect) / Double(questions)
    }
}

/// 一局结算的结果，结算页按这个显示
public struct GrowthResult: Sendable, Equatable {
    /// 本局得到的经验（已含每日首胜、已按当天局数打折）
    public var xp: Int
    /// 本局答题和通关得到的积分（已含每日首胜、已打折），不含升级和徽章奖励
    public var coins: Int
    /// 升级送的积分
    public var levelCoins: Int
    /// 新徽章送的积分
    public var badgeCoins: Int
    /// 今天第一次通关
    public var dailyFirstWin: Bool
    /// 今天玩的局数超过全额奖励局数，这局奖励打了折
    public var reduced: Bool
    /// 不打折时本局能得的经验、积分（用来在结算页显示「原来是多少」）
    public var fullXP: Int
    public var fullCoins: Int
    public var gamesToday: Int
    public var before: LevelProgress
    public var after: LevelProgress
    /// 这次升级送的外观（价格为 0）
    public var gifts: [CosmeticKind]
    /// 这次升级解锁、可以用积分买的外观
    public var unlocked: [CosmeticKind]
    public var newBadges: [BadgeKind]

    public var leveledUp: Bool { after.level > before.level }
    public var totalCoins: Int { coins + levelCoins + badgeCoins }
}

extension GrowthState {
    /// 每日记录按设备所在时区的日期划分
    static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// 结算一局：更新统计、经验、积分、等级奖励和徽章，返回结算页要显示的内容
    public mutating func settle(_ report: GameReport, catalog: GrowthCatalog, calendar: Calendar = .current) -> GrowthResult {
        let pacing = catalog.pacing
        let curve = pacing.levelCurve
        let before = level(curve)

        // 当天第几局、是否每日首胜
        let today = Self.dayKey(report.date, calendar: calendar)
        if stats.day != today {
            stats.day = today
            stats.gamesToday = 0
            stats.wonToday = false
        }
        stats.gamesToday += 1
        let dailyFirstWin = report.won && !stats.wonToday
        if report.won { stats.wonToday = true }
        let reduced = stats.gamesToday > pacing.daily.fullRewardGames
        let rate = reduced ? pacing.daily.extraGameRewardRate : 1

        // 经验：正确率 + 通关 + 星级，乘难度倍率；每日首胜另加
        var rawXP = report.accuracy * Double(pacing.xp.accuracy)
        var rawCoins = report.accuracy * Double(pacing.coins.accuracy)
        if report.won {
            rawXP += Double(pacing.xp.win + report.stars * pacing.xp.perStar)
            rawCoins += Double(pacing.coins.win[report.difficulty] + report.stars * pacing.coins.perStar)
        }
        rawXP *= pacing.xp.difficultyRate[report.difficulty]
        if dailyFirstWin {
            rawXP += Double(pacing.daily.firstWinXP)
            rawCoins += Double(pacing.daily.firstWinCoins)
        }
        let fullXP = Int(rawXP.rounded())
        let fullCoins = Int(rawCoins.rounded())
        let gainedXP = Int((rawXP * rate).rounded())
        let gainedCoins = Int((rawCoins * rate).rounded())

        // 累计统计
        stats.gamesPlayed += 1
        stats.questionsAnswered += report.questions
        stats.firstTryCorrect += report.firstTryCorrect
        stats.bossesDefeated += report.bossesDefeated
        stats.enemiesDefeated += report.enemiesDefeated
        stats.itemsUsed += report.itemsUsed
        stats.ultimatesCast += report.ultimatesCast
        stats.playSeconds += report.seconds
        if report.won {
            stats.gamesWon += 1
            switch report.difficulty {
            case .easy: stats.easyWins += 1
            case .normal: stats.normalWins += 1
            case .hard: stats.hardWins += 1
            }
            if report.stars >= 3 { stats.threeStarGames += 1 }
        }
        if report.questions >= pacing.perfectMinQuestions && report.firstTryCorrect == report.questions {
            stats.perfectGames += 1
        }

        xp += gainedXP
        coins += gainedCoins
        let after = level(curve)

        // 升级奖励：每升一级送积分；这几级解锁的外观，免费的直接拥有，收费的可以去买
        let levelCoins = max(0, after.level - before.level) * pacing.coins.perLevel
        coins += levelCoins
        let newlyUnlocked = catalog.cosmetics.filter {
            !$0.isOriginal && $0.unlockLevel > before.level && $0.unlockLevel <= after.level
        }

        // 徽章：每枚只发一次
        var newBadges: [BadgeKind] = []
        for badge in catalog.badges where badges[badge.id] == nil && badge.isMet(stats: stats, level: after.level) {
            badges[badge.id] = report.date
            coins += max(0, badge.coins)
            newBadges.append(badge)
        }

        return GrowthResult(
            xp: gainedXP, coins: gainedCoins, levelCoins: levelCoins,
            badgeCoins: newBadges.reduce(0) { $0 + max(0, $1.coins) },
            dailyFirstWin: dailyFirstWin, reduced: reduced, fullXP: fullXP, fullCoins: fullCoins,
            gamesToday: stats.gamesToday, before: before, after: after,
            gifts: newlyUnlocked.filter { $0.price == 0 },
            unlocked: newlyUnlocked.filter { $0.price > 0 },
            newBadges: newBadges)
    }

    /// 老档案第一次使用成长系统时，按以前的答对次数补发：每次答对 5 经验（最多补到 Lv.10）、1 积分。
    /// 免费外观按补发后的等级自动拥有，不另外记录
    public static func migrated(fromCorrectAnswers correct: Int, catalog: GrowthCatalog) -> GrowthState {
        var state = GrowthState()
        let curve = catalog.pacing.levelCurve
        state.xp = min(max(0, correct) * 5, curve.totalXP(toReach: 10))
        state.coins = max(0, correct)
        state.stats.firstTryCorrect = max(0, correct)
        // 补发后已满足条件的徽章（比如累计答对 100 题）直接点亮，不另送积分，免得一下子拿太多
        let level = state.level(curve).level
        for badge in catalog.badges where badge.isMet(stats: state.stats, level: level) {
            state.badges[badge.id] = Date()
        }
        return state
    }
}

/// 读写一个孩子的成长档案（growth/<档案id>.json）。url 为 nil 时只在内存里（测试用）
public final class GrowthStore {
    public private(set) var state: GrowthState
    public let catalog: GrowthCatalog
    private let url: URL?

    /// - Parameter legacyCorrectAnswers: 没有成长档案时，老学习记录里累计答对的次数，用来补发
    public init(url: URL?, catalog: GrowthCatalog, legacyCorrectAnswers: () -> Int = { 0 }) {
        self.url = url
        self.catalog = catalog
        guard let url, FileManager.default.fileExists(atPath: url.path) else {
            let correct = legacyCorrectAnswers()
            state = correct > 0 ? GrowthState.migrated(fromCorrectAnswers: correct, catalog: catalog) : GrowthState()
            if correct > 0 { save() }
            return
        }
        if let data = try? Data(contentsOf: url), let saved = try? JSONDecoder.growth.decode(GrowthState.self, from: data) {
            state = saved
        } else {
            // 文件坏了：先把原文件留成 .bak，再从头开始，不覆盖丢数据
            let backup = url.appendingPathExtension("bak")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.moveItem(at: url, to: backup)
            state = GrowthState()
        }
    }

    public var level: LevelProgress { state.level(catalog.pacing.levelCurve) }

    public var loadout: Loadout { state.loadout(catalog) }

    public func settle(_ report: GameReport) -> GrowthResult {
        let result = state.settle(report, catalog: catalog)
        save()
        return result
    }

    @discardableResult
    public func purchase(_ item: CosmeticKind) -> GrowthState.PurchaseResult {
        let result = state.purchase(item, level: level.level)
        if result == .bought { save() }
        return result
    }

    @discardableResult
    public func equip(_ item: CosmeticKind) -> Bool {
        let ok = state.equip(item, level: level.level)
        if ok { save() }
        return ok
    }

    public func unequip(key: String) {
        state.unequip(key: key)
        save()
    }

    public func save() {
        guard let url else { return }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder.growth.encode(state).write(to: url, options: .atomic)
        } catch {
            print("保存成长档案失败：\(error)")
        }
    }
}

extension JSONEncoder {
    static var growth: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    static var growth: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
