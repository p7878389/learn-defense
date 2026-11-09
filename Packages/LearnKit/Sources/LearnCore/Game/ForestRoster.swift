import Foundation

/// 森林模式独立目录，不改变经典模式的题目血量与攻击策略。
public enum ForestEnemyKind: String, CaseIterable, Sendable {
    case skeleton, boar, goblin, acolyte
    case knight, ogre, berserker, frostKing, infernal, reaper, pharaoh, slime, gargoyle, shaman

    public static let bosses: [Self] = [.knight, .ogre, .berserker, .frostKing, .infernal,
                                       .reaper, .pharaoh, .slime, .gargoyle, .shaman]
    public var isBoss: Bool { Self.bosses.contains(self) }
    public var name: String {
        switch self {
        case .skeleton: "骷髅步兵"
        case .boar: "尖刺野猪"
        case .goblin: "掷石斥候"
        case .acolyte: "暗影学徒"
        case .knight: "骷髅死亡骑士"
        case .ogre: "巨魔酋长"
        case .berserker: "双斧狂战士"
        case .frostKing: "寒霜魔王"
        case .infernal: "炎狱领主"
        case .reaper: "冥魂收割者"
        case .pharaoh: "古墓法老"
        case .slime: "剧毒史莱姆王"
        case .gargoyle: "暗翼石像鬼王"
        case .shaman: "炼金萨满王"
        }
    }
    public var health: Double { isBoss ? 18 : (self == .boar ? 4 : 3) }
    public var speed: Double {
        switch self {
        case .boar: 0.075
        case .berserker, .frostKing: 0.045
        case .slime, .ogre, .knight: 0.033
        default: isBoss ? 0.038 : 0.055
        }
    }
    public var floating: Bool { self == .reaper || self == .gargoyle }
    public var ranged: Bool { [.goblin, .acolyte, .reaper, .pharaoh, .slime, .gargoyle, .shaman].contains(self) }
    public var windup: Double {
        switch self {
        case .skeleton: 0.35
        case .boar, .goblin: 0.40
        case .acolyte, .knight: 0.55
        case .ogre: 0.80
        case .berserker: 0.45
        case .frostKing: 0.50
        case .infernal, .shaman: 0.70
        case .reaper: 0.90
        case .pharaoh: 1.00
        case .slime: 0.85
        case .gargoyle: 1.10
        }
    }
    public var recovery: Double {
        switch self {
        case .ogre, .gargoyle: 0.65
        case .slime: 0.60
        case .infernal, .pharaoh: 0.50
        case .reaper, .shaman: 0.45
        case .knight, .frostKing: 0.40
        case .berserker, .acolyte: 0.35
        default: 0.30
        }
    }
    public var effect: ForestCombatEffect {
        switch self {
        case .skeleton, .knight: .slash
        case .boar, .ogre: .smash
        case .goblin: .stone
        case .acolyte: .shadow
        case .berserker: .crossSlash
        case .frostKing: .frost
        case .infernal: .fire
        case .reaper: .soul
        case .pharaoh: .scarab
        case .slime: .acid
        case .gargoyle: .meteor
        case .shaman: .flask
        }
    }
    public var skillEffect: ForestCombatEffect {
        switch self {
        case .knight, .reaper: .soul
        case .pharaoh: .sandstorm
        default: effect
        }
    }
    public var skillName: String {
        switch self {
        case .knight: "魂刃横扫"
        case .ogre: "震地重锤"
        case .berserker: "双斧旋斩"
        case .frostKing: "霜环爆发"
        case .infernal: "熔火突刺"
        case .reaper: "三重魂弹"
        case .pharaoh: "圣甲虫沙暴"
        case .slime: "强酸喷发"
        case .gargoyle: "陨石召唤"
        case .shaman: "诅咒爆瓶"
        default: "攻击"
        }
    }
}

public enum ForestHero: String, CaseIterable, Sendable {
    case paladin, botanist
    public var name: String { self == .paladin ? "圣阳骑士" : "林地药剂师" }
    public var skillName: String { self == .paladin ? "盾垒" : "藤蔓缠绕" }
    public var windup: Double { self == .paladin ? 0.45 : 0.65 }
}

public enum ForestCombatEffect: String, Sendable {
    case slash, smash, stone, shadow, crossSlash, frost, fire, soul, scarab, sandstorm, acid, meteor, flask
    case holy, seed, shield, vines, repair
    public var arc: Double {
        switch self {
        case .acid, .flask, .seed: 0.075
        case .meteor: 0.14
        default: 0
        }
    }
}

public struct ForestCast: Sendable {
    public var age: Double = 0
    public var emitted = 0
    public let target: Int
    public let point: ForestPoint
    public let windup: Double
    public let recovery: Double
    public let effect: ForestCombatEffect
    public let skill: Bool
    public let count: Int
    public var duration: Double { windup + Double(count - 1) * 0.12 + 0.16 + recovery }
    public var charging: Bool { age < windup }
    public var releasing: Bool { age >= windup && age < windup + Double(count - 1) * 0.12 + 0.16 }
    public var progress: Double { min(1, age / max(0.01, windup)) }
}

public struct ForestDefenseUnit: Sendable {
    public let hero: ForestHero?
    public let maxHealth: Double
    public var health: Double
    public var hitTimer: Double = 0
    public var shield: Double = 0
    public var chilled: Double = 0
    public var cooldown: Double = 0
    public var skillCooldown: Double = 0
    public var cast: ForestCast?
    public var alive: Bool { health > 0 }
    public init(hero: ForestHero? = nil) {
        self.hero = hero
        maxHealth = hero == nil ? 30 : 36
        health = maxHealth
    }
}

public struct ForestCombatShot: Identifiable, Sendable {
    public enum Side: Sendable { case enemy, hero }
    public let id: Int
    public let side: Side
    public let source: Int
    public let target: Int
    public let origin: ForestPoint
    public var point: ForestPoint
    public let effect: ForestCombatEffect
    public let damage: Double
    public let flight: Double
    public let radius: Double
    public let skill: Bool
    public var age: Double = 0
    public var impacted = false
    public var duration: Double { flight + 0.45 }
}

public struct ForestZone: Identifiable, Sendable {
    public let id: Int
    public let point: ForestPoint
    public let effect: ForestCombatEffect
    public let radius: Double
    public var remaining: Double
    public var pulse: Double = 0
}
