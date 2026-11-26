import Foundation

public struct AdventureResult: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let levelID: Int
    public let stars: Int
    public let lives: Int
    public let seconds: Int
    public let abandoned: Bool
    public let date: Date
}

public struct AdventureProgress: Codable, Equatable, Sendable {
    public var bestStars: [String: Int] = [:]
    public var results: [AdventureResult] = []
    /// 仅当前对局用于扣费与结算校验，不写入存档，也不读取旧版续局。
    public var active: AdventureBattle?

    public init() {}

    private enum CodingKeys: String, CodingKey { case bestStars, results }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        bestStars = try values.decodeIfPresent([String: Int].self, forKey: .bestStars) ?? [:]
        results = try values.decodeIfPresent([AdventureResult].self, forKey: .results) ?? []
        active = nil
    }

    public func isUnlocked(_ levelID: Int) -> Bool {
        AdventureCatalog.level(levelID) != nil && (levelID == 1 || (bestStars[String(levelID - 1)] ?? 0) > 0)
    }

    public var totalStars: Int { bestStars.values.reduce(0, +) }
    public var chapterComplete: Bool { (bestStars["6"] ?? 0) > 0 }
}

public enum AdventureError: Error, LocalizedError, Equatable {
    case notEnough(short: Int), locked, activeBattle, invalidBattle, missingSave

    public var errorDescription: String? {
        switch self {
        case .notEnough(let short): "还差 \(short) 积分，先去经典模式答题闯关吧。"
        case .locked: "先通过前一关，再来挑战这一关。"
        case .activeBattle: "还有一场冒险未结束，请先继续或放弃原来的对局。"
        case .invalidBattle: "对局状态无效，请返回地图重新准备。"
        case .missingSave: "没有找到这场冒险的入场记录，请返回地图。"
        }
    }
}
