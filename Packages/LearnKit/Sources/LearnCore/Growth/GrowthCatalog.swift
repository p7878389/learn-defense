import Foundation

// MARK: - 徽章

/// 一枚徽章。条件是数据：累计统计达到某个值（stat + atLeast），或等级达到某级（level）
public struct BadgeKind: Codable, Identifiable, Sendable, Equatable {
    public var id: String
    public var name: String
    public var icon: String
    /// 给孩子看的获得条件
    public var summary: String
    /// 获得时奖励的积分
    public var coins: Int
    /// 累计统计项的名字，可选值见 `GrowthStats.Key`；写错的徽章在读取时被忽略
    public var stat: String?
    public var atLeast: Int?
    public var level: Int?

    public init(id: String, name: String, icon: String, summary: String, coins: Int,
                stat: GrowthStats.Key? = nil, atLeast: Int? = nil, level: Int? = nil) {
        self.id = id
        self.name = name
        self.icon = icon
        self.summary = summary
        self.coins = coins
        self.stat = stat?.rawValue
        self.atLeast = atLeast
        self.level = level
    }

    public var statKey: GrowthStats.Key? { stat.flatMap(GrowthStats.Key.init(rawValue:)) }

    /// 当前进度和目标，徽章墙上显示「63/100」
    public func progress(stats: GrowthStats, level current: Int) -> (value: Int, target: Int) {
        if let level { return (min(current, level), level) }
        if let statKey, let atLeast { return (min(stats[statKey], atLeast), atLeast) }
        return (0, 1)
    }

    public func isMet(stats: GrowthStats, level: Int) -> Bool {
        guard level >= 1, self.level != nil || statKey != nil else { return false }
        let p = progress(stats: stats, level: level)
        return p.value >= p.target
    }
}

// MARK: - 外观

/// 外观槽位。道具皮肤每个道具各占一个位置，所以装备时按 `CosmeticKind.equipKey` 区分
public enum CosmeticSlot: String, Codable, CaseIterable, Identifiable, Sendable {
    /// 普通豌豆类（orb）子弹
    case projectile
    /// 僵尸被打败的特效
    case defeat
    /// 道具图标和名字（效果不变）
    case itemSkin

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .projectile: "子弹外观"
        case .defeat: "僵尸退场"
        case .itemSkin: "道具皮肤"
        }
    }

    public var icon: String {
        switch self {
        case .projectile: "🟢"
        case .defeat: "💥"
        case .itemSkin: "🎒"
        }
    }
}

public enum CosmeticRarity: String, Codable, Sendable {
    case common, rare, legendary

    public var displayName: String {
        switch self {
        case .common: "普通"
        case .rare: "稀有"
        case .legendary: "传说"
        }
    }
}

/// 道具换皮：只换图标和名字
public struct ItemSkin: Codable, Sendable, Equatable {
    public var item: String
    public var icon: String
    public var name: String
}

extension ProjectileLook.Shape: Codable {}
extension UnitColor: Codable {}
extension DefeatEffect: Codable {}

/// 子弹外观在 JSON 里的写法
public struct ProjectilePayload: Codable, Sendable, Equatable {
    public var shape: ProjectileLook.Shape
    public var color: UnitColor
    public var size: Double?

    public var look: ProjectileLook { ProjectileLook(shape: shape, color: color, size: size ?? 11) }
}

/// 一件外观：到了 unlockLevel 解锁；price 为 0 的解锁即拥有，大于 0 的要用积分买
public struct CosmeticKind: Codable, Identifiable, Sendable, Equatable {
    public var id: String
    public var slot: CosmeticSlot
    public var name: String
    public var icon: String
    public var summary: String
    public var rarity: CosmeticRarity
    public var unlockLevel: Int
    public var price: Int
    /// 三种内容按槽位只填一种；子弹和退场都不填的是「原版」
    public var projectile: ProjectilePayload?
    public var defeat: DefeatEffect?
    public var itemSkin: ItemSkin?

    /// 「原版」：不替换任何东西，选它等于卸下
    public var isOriginal: Bool { projectile == nil && defeat == nil && itemSkin == nil }

    /// 同一个位置只能装一件
    public var equipKey: String {
        if let itemSkin { return "item.\(itemSkin.item)" }
        return slot.rawValue
    }
}

// MARK: - 目录

/// 成长系统用到的全部配置：节奏、徽章、外观。都来自 `Resources/Config` 下的 JSON
public struct GrowthCatalog: Sendable {
    public var pacing: PacingConfig
    public var badges: [BadgeKind]
    public var cosmetics: [CosmeticKind]
    /// 配置里写错的地方，显示在主页「题库问题」区
    public var issues: [String]

    public init(pacing: PacingConfig = .defaults, badges: [BadgeKind], cosmetics: [CosmeticKind], issues: [String] = []) {
        self.pacing = pacing
        self.badges = badges
        self.cosmetics = cosmetics
        self.issues = issues
    }

    public static let bundled: GrowthCatalog = load(bundle: .module)

    public static func load(bundle: Bundle) -> GrowthCatalog {
        func data(_ name: String) -> Data? {
            bundle.url(forResource: name, withExtension: "json", subdirectory: "Config").flatMap { try? Data(contentsOf: $0) }
        }
        var issues: [String] = []
        var pacing = PacingConfig.defaults
        if let d = data("pacing") {
            let parsed = PacingConfig.parse(d)
            pacing = parsed.0
            issues += parsed.1
        } else {
            issues.append("找不到 pacing.json，已使用默认节奏")
        }
        let badges = decodeList([BadgeKind].self, data("badges"), file: "badges.json", issues: &issues)
        let cosmetics = decodeList([CosmeticKind].self, data("cosmetics"), file: "cosmetics.json", issues: &issues)
        var catalog = GrowthCatalog(pacing: pacing, badges: badges, cosmetics: cosmetics, issues: issues)
        catalog.validate()
        return catalog
    }

    /// 逐条解析：某一条写错只丢掉这一条，不影响其他条目
    private static func decodeList<T: Decodable>(_ type: [T].Type, _ data: Data?, file: String, issues: inout [String]) -> [T] {
        guard let data else {
            issues.append("找不到 \(file)")
            return []
        }
        guard let entries = try? JSONDecoder().decode([Lossy<T>].self, from: data) else {
            issues.append("\(file) 不是有效的 JSON 列表")
            return []
        }
        for (i, entry) in entries.enumerated() where entry.value == nil {
            issues.append("\(file) 第 \(i + 1) 条字段不对，已忽略")
        }
        return entries.compactMap(\.value)
    }

    private struct Lossy<T: Decodable>: Decodable {
        let value: T?
        init(from decoder: Decoder) throws {
            value = try? T(from: decoder)
        }
    }

    /// 去掉重复 id、条件写错、内容和槽位对不上的条目
    mutating func validate() {
        var seen = Set<String>()
        badges = badges.filter { badge in
            guard seen.insert(badge.id).inserted else {
                issues.append("badges.json 里 \(badge.id) 重复，已忽略后一个")
                return false
            }
            let valid = (badge.level ?? 0) >= 1 || (badge.statKey != nil && (badge.atLeast ?? 0) >= 1)
            if !valid { issues.append("徽章「\(badge.name)」没有有效的获得条件，已忽略") }
            return valid
        }
        seen = []
        cosmetics = cosmetics.filter { item in
            guard seen.insert(item.id).inserted else {
                issues.append("cosmetics.json 里 \(item.id) 重复，已忽略后一个")
                return false
            }
            let matches: Bool = switch item.slot {
            case .projectile: item.defeat == nil && item.itemSkin == nil
            case .defeat: item.projectile == nil && item.itemSkin == nil
            case .itemSkin: item.itemSkin != nil && UnitCatalog.item(id: item.itemSkin!.item) != nil
            }
            let valid = matches && item.unlockLevel >= 1 && item.price >= 0
            if !valid { issues.append("外观「\(item.name)」的槽位、内容、等级或价格不对，已忽略") }
            return valid
        }
    }

    public func cosmetics(in slot: CosmeticSlot) -> [CosmeticKind] {
        cosmetics.filter { $0.slot == slot }
    }

    public func cosmetic(id: String) -> CosmeticKind? {
        cosmetics.first { $0.id == id }
    }

    public func badge(id: String) -> BadgeKind? {
        badges.first { $0.id == id }
    }
}
