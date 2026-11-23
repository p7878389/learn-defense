import Foundation

/// 冒险专用的一次性爆破。格距与当前五行九列草坪一致，预览与伤害共用此几何。
public enum AdventureDoom {
    public static let id = "doomShroom"
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

struct AdventureDoomState: Codable, Equatable, Sendable {
    var charges: [AdventureDoomSite] = []
    var craters: [AdventureDoomSite] = []
    var cooldown: Double = 0
}
