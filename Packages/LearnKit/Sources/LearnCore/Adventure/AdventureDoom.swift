import Foundation

/// 各地图共用的一次性爆破。格距与当前五行九列草坪一致，预览与伤害共用此几何。
public enum AdventureDoom {
    public static let id = "doomShroom"
    public static let unlockLevel = 3
    public static let unlockPrice = 300
    public static let cost = 125
    public static let fuse: Double = 1
    public static let cooldown: Double = 50
    public static let craterDuration: Double = 180
    public static let radius: Double = 3.5
    public static let damage = 120
    public static let columnWidth: Double = 750.0 / 9
    public static let rowHeight: Double = 100

    public static func x(_ column: Int) -> Double { 144 + columnWidth * (Double(column) + 0.5) }
    public static func y(_ lane: Int) -> Double { 20 + rowHeight * (Double(lane) + 0.5) }

    public static func contains(lane: Int, column: Int, enemyLane: Int, enemyX: Double) -> Bool {
        let dx = (enemyX - x(column)) / columnWidth
        let dy = Double(enemyLane - lane)
        return dx * dx + dy * dy <= radius * radius
    }
}

/// 蓄力与焦坑只按战斗时间推进；id 贯穿两阶段，恢复时不会再播放已结算爆炸。
public struct AdventureDoomSite: Codable, Equatable, Identifiable, Sendable {
    public let id: Int
    public let lane: Int
    public let column: Int
    public var remaining: Double
}

public struct AdventureDoomState: Codable, Equatable, Sendable {
    public private(set) var charges: [AdventureDoomSite] = []
    public private(set) var craters: [AdventureDoomSite] = []
    public private(set) var cooldown: Double = 0

    public init() {}

    public mutating func plant(id: Int, lane: Int, column: Int) {
        charges.append(AdventureDoomSite(id: id, lane: lane, column: column, remaining: AdventureDoom.fuse))
        cooldown = AdventureDoom.cooldown
    }

    /// 每次推进一个 50ms 战斗步长；伤害仍由各战斗引擎结算。
    public mutating func step() -> [AdventureDoomSite] {
        func tick(_ remaining: Double) -> Double { max(0, (remaining * 20).rounded() - 1) / 20 }
        cooldown = tick(cooldown)
        for i in craters.indices { craters[i].remaining = tick(craters[i].remaining) }
        craters.removeAll { $0.remaining <= 0 }
        for i in charges.indices { charges[i].remaining = tick(charges[i].remaining) }
        let exploded = charges.filter { $0.remaining <= 0 }
        charges.removeAll { $0.remaining <= 0 }
        for site in exploded {
            craters.append(AdventureDoomSite(id: site.id, lane: site.lane, column: site.column, remaining: AdventureDoom.craterDuration))
        }
        return exploded
    }
}
