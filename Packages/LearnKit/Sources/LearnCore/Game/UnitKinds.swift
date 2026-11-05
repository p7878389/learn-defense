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
    public var movement: MovementStyle
    public var look: EnemyLook
    public var drop: ItemDrop?

    public init(id: String, name: String, hp: Int = 1, speed: Double = 1, bonus: Int = 0,
                movement: MovementStyle = .steady, look: EnemyLook, drop: ItemDrop? = nil) {
        self.id = id
        self.name = name
        self.hp = max(1, hp)
        self.speed = speed
        self.bonus = bonus
        self.movement = movement
        self.look = look
        self.drop = drop
    }
}

/// 一种字灵 = 攻击方式 + 命中效果 + 外观 + 子弹外观
public struct DefenderKind: Identifiable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var attack: AttackStyle
    public var effects: [HitEffect]
    public var look: DefenderLook
    public var projectile: ProjectileLook

    public init(id: String, name: String, attack: AttackStyle, effects: [HitEffect] = [],
                look: DefenderLook, projectile: ProjectileLook) {
        self.id = id
        self.name = name
        self.attack = attack
        self.effects = effects
        self.look = look
        self.projectile = projectile
    }
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
