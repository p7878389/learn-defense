import Foundation

/// 数据库中的运行规则；首次使用写入默认值，后续启动保留数据库配置。
public struct GameRules: Codable, Sendable, Equatable {
    public var initialRestRounds = 3
    public var initialRestSeconds = 10
    public var restIncrementSeconds = 5
    public var maxRestSeconds = 90
    public var questionIncrement = ByDifficulty(easy: 2, normal: 3, hard: 4)
    public var reviewEvery = 3
    public var coinLimits = ["answers": 100, "completion": 100, "firstWin": 10, "level": 90, "badge": 100]

    public init() {}
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Self.defaults
        initialRestRounds = (try? c.decodeIfPresent(Int.self, forKey: .initialRestRounds)) ?? d.initialRestRounds
        initialRestSeconds = (try? c.decodeIfPresent(Int.self, forKey: .initialRestSeconds)) ?? d.initialRestSeconds
        restIncrementSeconds = (try? c.decodeIfPresent(Int.self, forKey: .restIncrementSeconds)) ?? d.restIncrementSeconds
        maxRestSeconds = (try? c.decodeIfPresent(Int.self, forKey: .maxRestSeconds)) ?? d.maxRestSeconds
        questionIncrement = (try? c.decodeIfPresent(ByDifficulty<Int>.self, forKey: .questionIncrement)) ?? d.questionIncrement
        reviewEvery = (try? c.decodeIfPresent(Int.self, forKey: .reviewEvery)) ?? d.reviewEvery
        coinLimits = (try? c.decodeIfPresent([String: Int].self, forKey: .coinLimits)) ?? d.coinLimits
    }

    public static let defaults = GameRules()

    public func restSeconds(afterRound round: Int) -> Int {
        let r = validated()
        return min(r.maxRestSeconds, r.initialRestSeconds + max(0, round - r.initialRestRounds) * r.restIncrementSeconds)
    }

    public func coinLimit(_ source: CoinSource) -> Int {
        validated().coinLimits[source.rawValue] ?? 0
    }

    /// 无效字段单独回退，允许每日上限设为 0（关闭该来源）。
    public func validated() -> GameRules {
        var r = self
        let d = Self.defaults
        if !(1...100).contains(r.initialRestRounds) { r.initialRestRounds = d.initialRestRounds }
        if !(1...300).contains(r.initialRestSeconds) { r.initialRestSeconds = d.initialRestSeconds }
        if !(1...60).contains(r.restIncrementSeconds) { r.restIncrementSeconds = d.restIncrementSeconds }
        if !(r.initialRestSeconds...600).contains(r.maxRestSeconds) { r.maxRestSeconds = max(d.maxRestSeconds, r.initialRestSeconds) }
        if !(2...20).contains(r.reviewEvery) { r.reviewEvery = d.reviewEvery }
        if ![r.questionIncrement.easy, r.questionIncrement.normal, r.questionIncrement.hard].allSatisfy({ (1...20).contains($0) }) {
            r.questionIncrement = d.questionIncrement
        }
        for source in CoinSource.allCases {
            if !(0...10000).contains(r.coinLimits[source.rawValue] ?? -1) {
                r.coinLimits[source.rawValue] = d.coinLimits[source.rawValue]
            }
        }
        return r
    }
}
