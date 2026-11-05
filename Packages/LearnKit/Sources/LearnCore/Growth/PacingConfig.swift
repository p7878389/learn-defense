import Foundation

/// 按难度分别给值，JSON 里写成 `{ "easy": …, "normal": …, "hard": … }`
public struct ByDifficulty<Value: Codable & Sendable & Equatable>: Codable, Sendable, Equatable {
    public var easy: Value
    public var normal: Value
    public var hard: Value

    public init(easy: Value, normal: Value, hard: Value) {
        self.easy = easy
        self.normal = normal
        self.hard = hard
    }

    public subscript(_ difficulty: Difficulty) -> Value {
        switch difficulty {
        case .easy: easy
        case .normal: normal
        case .hard: hard
        }
    }
}

/// 节奏参数：每局题量、每天全额奖励局数、经验和积分系数、升级曲线。
/// 内置在 `Resources/Config/pacing.json`；JSON 缺项或写错时用这里的默认值，并在 `issues` 里说明哪一项无效。
public struct PacingConfig: Sendable, Equatable {
    /// 一个年级段每局的题量
    public struct QuestionBand: Sendable, Equatable {
        public var grades: [Grade]
        public var count: ByDifficulty<Int>
    }

    /// 错题复习局：题量 = 错题数 × perWrongItem，至少 min，最多不超过本档题量
    public struct Review: Sendable, Equatable {
        public var perWrongItem: Int
        public var min: Int
    }

    public struct Daily: Sendable, Equatable {
        /// 每天前几局拿全额奖励
        public var fullRewardGames: Int
        /// 之后每局奖励乘这个比例
        public var extraGameRewardRate: Double
        /// 每天第一次通关多给的经验、积分
        public var firstWinXP: Int
        public var firstWinCoins: Int
    }

    public struct XPRule: Sendable, Equatable {
        /// 首答正确率 × accuracy
        public var accuracy: Int
        public var win: Int
        public var perStar: Int
        /// 乘在总和上
        public var difficultyRate: ByDifficulty<Double>
    }

    public struct CoinRule: Sendable, Equatable {
        public var accuracy: Int
        public var win: ByDifficulty<Int>
        public var perStar: Int
        /// 每升一级送的积分
        public var perLevel: Int
    }

    /// Lv.L 升到 L+1 需要 `min(perLevel × L + offset, maxPerLevel)` 经验
    public struct Levels: Sendable, Equatable {
        public var perLevel: Int
        public var offset: Int
        public var maxPerLevel: Int
    }

    public var questions: [QuestionBand]
    public var review: Review
    public var daily: Daily
    public var xp: XPRule
    public var coins: CoinRule
    public var levels: Levels
    /// 一局至少这么多题全部首答正确，才算「一字不差」
    public var perfectMinQuestions: Int

    public static let questionRange = 1...40

    public static let defaults = PacingConfig(
        questions: [
            QuestionBand(grades: [.k2], count: ByDifficulty(easy: 6, normal: 7, hard: 8)),
            QuestionBand(grades: [.k3], count: ByDifficulty(easy: 8, normal: 9, hard: 10)),
            QuestionBand(grades: [.g1, .g2], count: ByDifficulty(easy: 10, normal: 12, hard: 14)),
            QuestionBand(grades: [.g3, .g4], count: ByDifficulty(easy: 12, normal: 14, hard: 16)),
            QuestionBand(grades: [.g5, .g6], count: ByDifficulty(easy: 14, normal: 16, hard: 18)),
        ],
        review: Review(perWrongItem: 2, min: 6),
        daily: Daily(fullRewardGames: 5, extraGameRewardRate: 0.5, firstWinXP: 30, firstWinCoins: 10),
        xp: XPRule(accuracy: 60, win: 20, perStar: 10,
                   difficultyRate: ByDifficulty(easy: 1.0, normal: 1.2, hard: 1.5)),
        coins: CoinRule(accuracy: 20, win: ByDifficulty(easy: 10, normal: 15, hard: 25), perStar: 5, perLevel: 30),
        levels: Levels(perLevel: 100, offset: -40, maxPerLevel: 1500),
        perfectMinQuestions: 8)

    /// 本年级、本难度一局的题量（不含孩子自己触发的大招题）
    public func questionBudget(grade: Grade, difficulty: Difficulty) -> Int {
        let band = questions.first { $0.grades.contains(grade) }
            ?? Self.defaults.questions.first { $0.grades.contains(grade) }!
        return band.count[difficulty]
    }

    /// 错题复习局的题量：错题少时不要来回重复同几道题
    public func reviewBudget(itemCount: Int, cap: Int) -> Int {
        min(cap, max(review.min, itemCount * review.perWrongItem))
    }

    public var levelCurve: LevelCurve { LevelCurve(levels) }
}

// MARK: - 读取与校验

extension PacingConfig {
    /// 解析 JSON；每个缺失或不合理的项都退回默认值，并记一条问题说明
    public static func parse(_ data: Data) -> (PacingConfig, [String]) {
        var issues: [String] = []
        guard let file = try? JSONDecoder().decode(PacingFile.self, from: data) else {
            return (defaults, ["pacing.json 不是有效的 JSON，已使用默认节奏"])
        }
        var config = defaults

        func pick<T>(_ value: T?, _ fallback: T, _ name: String, _ valid: (T) -> Bool) -> T {
            guard let value else {
                issues.append("pacing.json 缺少 \(name)，已用默认值")
                return fallback
            }
            guard valid(value) else {
                issues.append("pacing.json 的 \(name) 不合理，已用默认值")
                return fallback
            }
            return value
        }

        // 题量：每个年级段单独校验；没写到的年级用默认题量
        if let bands = file.questions {
            var parsed: [QuestionBand] = []
            var covered = Set<Grade>()
            for (i, band) in bands.enumerated() {
                let grades = (band.grades ?? []).compactMap(Grade.init(rawValue:))
                guard !grades.isEmpty, grades.count == band.grades?.count,
                      let e = band.easy, let n = band.normal, let h = band.hard,
                      [e, n, h].allSatisfy(questionRange.contains) else {
                    issues.append("pacing.json 的 questions[\(i)] 年级或题量（\(questionRange.lowerBound)~\(questionRange.upperBound)）无效，已忽略")
                    continue
                }
                let fresh = grades.filter { !covered.contains($0) }
                covered.formUnion(fresh)
                if !fresh.isEmpty { parsed.append(QuestionBand(grades: fresh, count: ByDifficulty(easy: e, normal: n, hard: h))) }
            }
            let missing = Grade.allCases.filter { !covered.contains($0) }
            if !missing.isEmpty {
                issues.append("pacing.json 没有配置 \(missing.map(\.displayName).joined(separator: "、")) 的题量，已用默认值")
            }
            config.questions = parsed
        } else {
            issues.append("pacing.json 缺少 questions，已用默认题量")
        }

        let d = defaults
        config.review = Review(
            perWrongItem: pick(file.review?.perWrongItem, d.review.perWrongItem, "review.perWrongItem") { $0 >= 1 },
            min: pick(file.review?.min, d.review.min, "review.min") { questionRange.contains($0) })
        config.daily = Daily(
            fullRewardGames: pick(file.daily?.fullRewardGames, d.daily.fullRewardGames, "daily.fullRewardGames") { $0 >= 1 },
            extraGameRewardRate: pick(file.daily?.extraGameRewardRate, d.daily.extraGameRewardRate, "daily.extraGameRewardRate") { (0...1).contains($0) },
            firstWinXP: pick(file.daily?.firstWinXP, d.daily.firstWinXP, "daily.firstWinXP") { $0 >= 0 },
            firstWinCoins: pick(file.daily?.firstWinCoins, d.daily.firstWinCoins, "daily.firstWinCoins") { $0 >= 0 })
        config.xp = XPRule(
            accuracy: pick(file.xp?.accuracy, d.xp.accuracy, "xp.accuracy") { $0 >= 0 },
            win: pick(file.xp?.win, d.xp.win, "xp.win") { $0 >= 0 },
            perStar: pick(file.xp?.perStar, d.xp.perStar, "xp.perStar") { $0 >= 0 },
            difficultyRate: pick(file.xp?.difficultyRate, d.xp.difficultyRate, "xp.difficultyRate") {
                [$0.easy, $0.normal, $0.hard].allSatisfy { $0 > 0 }
            })
        config.coins = CoinRule(
            accuracy: pick(file.coins?.accuracy, d.coins.accuracy, "coins.accuracy") { $0 >= 0 },
            win: pick(file.coins?.win, d.coins.win, "coins.win") { [$0.easy, $0.normal, $0.hard].allSatisfy { $0 >= 0 } },
            perStar: pick(file.coins?.perStar, d.coins.perStar, "coins.perStar") { $0 >= 0 },
            perLevel: pick(file.coins?.perLevel, d.coins.perLevel, "coins.perLevel") { $0 >= 0 })
        // 升级曲线三个数要一起合理：第一级就要大于 0，且封顶值不低于第一级
        let levels = Levels(
            perLevel: file.levels?.perLevel ?? -1, offset: file.levels?.offset ?? 0, maxPerLevel: file.levels?.maxPerLevel ?? -1)
        config.levels = pick(file.levels == nil ? nil : levels, d.levels, "levels") {
            $0.perLevel > 0 && $0.perLevel + $0.offset > 0 && $0.maxPerLevel >= $0.perLevel + $0.offset
        }
        config.perfectMinQuestions = pick(file.perfectMinQuestions, d.perfectMinQuestions, "perfectMinQuestions") { $0 >= 1 }
        return (config, issues)
    }

    /// JSON 的原样结构，所有字段都可缺省
    private struct PacingFile: Decodable {
        struct Band: Decodable { var grades: [String]?; var easy: Int?; var normal: Int?; var hard: Int? }
        struct ReviewFile: Decodable { var perWrongItem: Int?; var min: Int? }
        struct DailyFile: Decodable {
            var fullRewardGames: Int?; var extraGameRewardRate: Double?; var firstWinXP: Int?; var firstWinCoins: Int?
        }
        struct XPFile: Decodable { var accuracy: Int?; var win: Int?; var perStar: Int?; var difficultyRate: ByDifficulty<Double>? }
        struct CoinFile: Decodable { var accuracy: Int?; var win: ByDifficulty<Int>?; var perStar: Int?; var perLevel: Int? }
        struct LevelFile: Decodable { var perLevel: Int?; var offset: Int?; var maxPerLevel: Int? }

        var questions: [Band]?
        var review: ReviewFile?
        var daily: DailyFile?
        var xp: XPFile?
        var coins: CoinFile?
        var levels: LevelFile?
        var perfectMinQuestions: Int?
    }
}

/// 等级曲线：等级由累计经验算出，不单独存
public struct LevelCurve: Sendable, Equatable {
    public let levels: PacingConfig.Levels

    public init(_ levels: PacingConfig.Levels) {
        self.levels = levels
    }

    /// 从 level 升到 level + 1 需要的经验
    public func xpToNext(level: Int) -> Int {
        max(1, min(levels.perLevel * level + levels.offset, levels.maxPerLevel))
    }

    /// 到达 level 需要的累计经验
    public func totalXP(toReach level: Int) -> Int {
        (1..<max(1, level)).reduce(0) { $0 + xpToNext(level: $1) }
    }

    public func progress(totalXP: Int) -> LevelProgress {
        var level = 1
        var rest = max(0, totalXP)
        while rest >= xpToNext(level: level) {
            rest -= xpToNext(level: level)
            level += 1
        }
        return LevelProgress(level: level, xpIntoLevel: rest, xpForNext: xpToNext(level: level))
    }
}

public struct LevelProgress: Sendable, Equatable {
    public var level: Int
    /// 本级已经攒了多少经验
    public var xpIntoLevel: Int
    /// 本级升到下一级一共需要多少经验
    public var xpForNext: Int

    public var fraction: Double { xpForNext == 0 ? 0 : Double(xpIntoLevel) / Double(xpForNext) }
    public var xpToGo: Int { max(0, xpForNext - xpIntoLevel) }
}
