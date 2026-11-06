import Foundation

/// 一种怪物 = 血量 + 速度 + 走法 + 外观 + 掉落。新增怪物只要组合已有的部件，写一个新的 EnemyKind 即可
public struct EnemyKind: Identifiable, Hashable, Sendable {
    public var id: String
    public var name: String
    /// 要答对几题（被打几下）才能打败
    public var hp: Int
    /// 相对基础速度的倍数
    public var speed: Double
    /// 打败后额外加分
    public var bonus: Int
    /// 打败后获得的阳光；默认按血量递增
    public var sunReward: Int
    public var movement: MovementStyle
    public var look: EnemyLook
    public var drop: ItemDrop?

    public init(id: String, name: String, hp: Int = 1, speed: Double = 1, bonus: Int = 0,
                sunReward: Int? = nil, movement: MovementStyle = .steady,
                look: EnemyLook, drop: ItemDrop? = nil) {
        self.id = id
        self.name = name
        self.hp = max(1, hp)
        self.speed = speed
        self.bonus = bonus
        self.sunReward = sunReward ?? max(1, hp) * 25
        self.movement = movement
        self.look = look
        self.drop = drop
    }

    /// 会跳的僵尸能跳过矮的防御道具（坚果墙），跳不过高坚果
    public var canVault: Bool {
        if case .hop = movement { true } else { false }
    }
}

/// 一种字灵 = 攻击方式 + 命中效果 + 外观 + 子弹外观。
/// 坚果墙、土豆雷这类防御道具没有攻击方式，只有拦僵尸的方式（guardStyle）
public struct DefenderKind: Identifiable, Hashable, Sendable {
    public var id: String
    public var name: String
    /// 射手才有；防御道具为 nil，答对时不由它发射
    public var attack: AttackStyle?
    public var effects: [HitEffect]
    /// 防御道具才有：怎么拦僵尸
    public var guardStyle: GuardStyle?
    public var look: DefenderLook
    public var projectile: ProjectileLook
    /// 种植需要的阳光
    public var sunCost: Int

    public init(id: String, name: String, sunCost: Int = 50, attack: AttackStyle? = nil, effects: [HitEffect] = [],
                guardStyle: GuardStyle? = nil, look: DefenderLook,
                projectile: ProjectileLook = ProjectileLook(shape: .orb, color: .gold)) {
        self.id = id
        self.name = name
        self.sunCost = max(0, sunCost)
        self.attack = attack
        self.effects = effects
        self.guardStyle = guardStyle
        self.look = look
        self.projectile = projectile
    }

    /// 答对时能不能发射
    public var canShoot: Bool { attack != nil }

    /// 换一种拦法（按难度调耐久、出土题数），其他不变
    public func guarding(_ style: GuardStyle) -> DefenderKind {
        var kind = self
        kind.guardStyle = style
        return kind
    }
}

/// 防御道具拦僵尸的方式，实现在 LearnGame 的 GuardStrategy
public enum GuardStyle: Hashable, Sendable {
    /// 僵尸走到面前停下来啃，啃 seconds 秒后碎掉。
    /// tall 为 false 时，会跳的僵尸（走法 .hop）在允许跳墙的难度里能跳过去
    case wall(seconds: Double, tall: Bool)
    /// 答对 armAfter 题后出土；出土后第一个踩上的僵尸直接倒下，首领只扣 bossDamage 血并被弹开
    case mine(armAfter: Int, bossDamage: Int)
}

/// 攻击方式的配置，动画由 LearnGame 里对应的策略实现
public enum AttackStyle: Hashable, Sendable {
    /// 发一颗子弹
    case single(damage: Int)
    /// 连发几颗，每颗都有伤害
    case volley(count: Int, damage: Int)
    /// 一道光束瞬间打中
    case beam(damage: Int)

    /// 一次攻击的总伤害
    public var totalDamage: Int {
        switch self {
        case let .single(damage), let .beam(damage): max(1, damage)
        case let .volley(count, damage): max(1, count) * max(1, damage)
        }
    }
}

/// 命中后的附加效果
public enum HitEffect: Hashable, Sendable {
    /// 没打倒时把怪物往后推
    case knockback(distance: Double)
    /// 这条路上的怪物都变慢一段时间
    case slowLane(factor: Double, seconds: Double)
}

/// 战斗中的血量
public struct Health: Equatable, Sendable {
    public let max: Int
    public private(set) var current: Int

    public init(max: Int) {
        self.max = Swift.max(1, max)
        current = self.max
    }

    public var isDefeated: Bool { current <= 0 }

    /// 受到伤害，返回是否被打败
    @discardableResult
    public mutating func take(_ damage: Int) -> Bool {
        current = Swift.max(0, current - Swift.max(0, damage))
        return isDefeated
    }
}
