import Foundation

/// 一种道具 = 图标 + 名字 + 若干效果。效果的执行由 LearnGame 里对应的命令完成
public struct ItemKind: Identifiable, Hashable, Sendable {
    public var id: String
    public var name: String
    /// emoji 图标
    public var icon: String
    /// 给孩子看的一句话说明
    public var summary: String
    public var effects: [ItemEffect]

    public init(id: String, name: String, icon: String, summary: String, effects: [ItemEffect]) {
        self.id = id
        self.name = name
        self.icon = icon
        self.summary = summary
        self.effects = effects
    }

    /// 只有回血效果的道具，在不会失败的模式里没用
    public var onlyHeals: Bool {
        effects.allSatisfy { if case .heal = $0 { true } else { false } }
    }
}

public enum ItemEffect: Hashable, Sendable {
    /// 全场怪物都被打败
    case clearField
    /// 全场怪物停住几秒
    case freezeField(seconds: Double)
    /// 加几颗心
    case heal(hearts: Int)
    /// 加分
    case bonusScore(points: Int)
}

/// 怪物被打败时按概率掉落道具
public struct ItemDrop: Hashable, Sendable {
    public var item: ItemKind
    public var chance: Double

    public init(_ item: ItemKind, chance: Double) {
        self.item = item
        self.chance = chance
    }

    public func roll<R: RandomNumberGenerator>(using rng: inout R) -> ItemKind? {
        Double.random(in: 0..<1, using: &rng) < chance ? item : nil
    }
}

/// 道具栏，装满后新捡到的道具会被丢掉
public struct Inventory: Equatable, Sendable {
    public let capacity: Int
    public private(set) var items: [ItemKind] = []

    public init(capacity: Int = 3) {
        self.capacity = max(1, capacity)
    }

    public var isFull: Bool { items.count >= capacity }

    @discardableResult
    public mutating func add(_ item: ItemKind) -> Bool {
        guard !isFull else { return false }
        items.append(item)
        return true
    }

    public mutating func take(at index: Int) -> ItemKind? {
        items.indices.contains(index) ? items.remove(at: index) : nil
    }
}

// MARK: - 内置道具

public extension ItemKind {
    static let inkStorm = ItemKind(
        id: "inkStorm", name: "成语大招", icon: "⚡️", summary: "答对清空全场！", effects: [.clearField])

    static let rainbow = ItemKind(
        id: "rainbow", name: "彩虹大招", icon: "🌈", summary: "答对清空全场！", effects: [.clearField])

    static let frostCharm = ItemKind(
        id: "frostCharm", name: "冰冻符", icon: "❄️", summary: "全场怪物冻住 5 秒", effects: [.freezeField(seconds: 5)])

    static let heartLeaf = ItemKind(
        id: "heartLeaf", name: "爱心叶", icon: "💖", summary: "加一颗心", effects: [.heal(hearts: 1)])

    static let luckyStar = ItemKind(
        id: "luckyStar", name: "幸运星", icon: "⭐️", summary: "加 20 分", effects: [.bonusScore(points: 20)])
}

public extension UnitCatalog {
    static let items: [ItemKind] = [.inkStorm, .rainbow, .frostCharm, .heartLeaf, .luckyStar]

    static func item(id: String) -> ItemKind? {
        items.first { $0.id == id }
    }
}
