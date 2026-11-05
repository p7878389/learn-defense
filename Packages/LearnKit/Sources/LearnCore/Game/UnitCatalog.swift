import Foundation

// MARK: - 内置怪物

public extension EnemyKind {
    static let blob = EnemyKind(
        id: "blob", name: "普通僵尸",
        look: EnemyLook(body: .blob, color: .ink))

    static let hopper = EnemyKind(
        id: "hopper", name: "路障僵尸", speed: 1.1,
        movement: .hop(pause: 0.5, airTime: 0.45, height: 26),
        look: EnemyLook(body: .ball, color: .indigo, accessory: .sprout, scale: 0.9, defeat: .ripple),
        drop: ItemDrop(.luckyStar, chance: 0.2))

    static let dasher = EnemyKind(
        id: "dasher", name: "橄榄球僵尸", speed: 1.3,
        movement: .surge(period: 1.6, amplitude: 0.7),
        look: EnemyLook(body: .tall, color: .crimson, accessory: .horns),
        drop: ItemDrop(.frostCharm, chance: 0.2))

    static let drowsy = EnemyKind(
        id: "drowsy", name: "读报僵尸", speed: 0.8,
        look: EnemyLook(body: .cloud, color: .sky, eyes: .sleepy, defeat: .sparkle),
        drop: ItemDrop(.frostCharm, chance: 0.2))

    static let armored = EnemyKind(
        id: "armored", name: "铁桶僵尸", hp: 2, speed: 0.8, bonus: 10,
        look: EnemyLook(body: .blob, color: .plum, accessory: .helmet, scale: 1.1),
        drop: ItemDrop(.heartLeaf, chance: 0.35))

    static let king = EnemyKind(
        id: "king", name: "铁门僵尸", hp: 3, speed: 0.6, bonus: 30,
        look: EnemyLook(body: .spiky, color: .ink, accessory: .crown, eyes: .single, scale: 1.3, defeat: .sparkle))
}

// MARK: - 内置字灵

public extension DefenderKind {
    static let inkling = DefenderKind(
        id: "inkling", name: "豌豆射手", attack: .single(damage: 1),
        look: DefenderLook(body: .round, color: .jade, accessory: .brush),
        projectile: ProjectileLook(shape: .orb, color: .gold))

    static let twin = DefenderKind(
        id: "twin", name: "双发射手", attack: .volley(count: 2, damage: 1),
        look: DefenderLook(body: .drop, color: .coral, accessory: .bow),
        projectile: ProjectileLook(shape: .orb, color: .coral, size: 8))

    static let frost = DefenderKind(
        id: "frost", name: "寒冰射手", attack: .single(damage: 1),
        effects: [.slowLane(factor: 0.5, seconds: 3)],
        look: DefenderLook(body: .round, color: .sky, accessory: .scholarHat),
        projectile: ProjectileLook(shape: .snowflake, color: .sky, size: 13))

    static let stroke = DefenderKind(
        id: "stroke", name: "大喷菇", attack: .beam(damage: 1),
        effects: [.knockback(distance: 70)],
        look: DefenderLook(body: .seal, color: .gold, accessory: .brush),
        projectile: ProjectileLook(shape: .petal, color: .gold))

    static let starling = DefenderKind(
        id: "starling", name: "杨桃", attack: .single(damage: 1),
        look: DefenderLook(body: .round, color: .moss, accessory: .leaf),
        projectile: ProjectileLook(shape: .star, color: .gold, size: 14))
}

/// 所有内置的怪物和字灵，按 id 查找
public enum UnitCatalog {
    public static let enemies: [EnemyKind] = [.blob, .hopper, .dasher, .drowsy, .armored, .king]
    public static let defenders: [DefenderKind] = [.inkling, .twin, .frost, .stroke, .starling]

    public static func enemy(id: String) -> EnemyKind? {
        enemies.first { $0.id == id }
    }

    public static func defender(id: String) -> DefenderKind? {
        defenders.first { $0.id == id }
    }
}

// MARK: - 出怪计划

/// 一局里出哪些怪：开头几只用基础怪热身，中间按权重随机，最后可以有首领
public struct WavePlan: Sendable {
    public struct Entry: Sendable {
        public var kind: EnemyKind
        public var weight: Double

        public init(_ kind: EnemyKind, weight: Double) {
            self.kind = kind
            self.weight = weight
        }
    }

    public var warmup: Int
    public var basic: EnemyKind
    public var mix: [Entry]
    public var boss: EnemyKind?

    public init(warmup: Int = 2, basic: EnemyKind = .blob, mix: [Entry], boss: EnemyKind? = nil) {
        self.warmup = warmup
        self.basic = basic
        self.mix = mix
        self.boss = boss
    }

    public func kinds<R: RandomNumberGenerator>(count: Int, using rng: inout R) -> [EnemyKind] {
        let total = mix.reduce(0) { $0 + max(0, $1.weight) }
        return (0..<max(0, count)).map { i in
            if i < warmup || total <= 0 { return basic }
            if let boss, i == count - 1 { return boss }
            var roll = Double.random(in: 0..<total, using: &rng)
            for entry in mix where entry.weight > 0 {
                roll -= entry.weight
                if roll < 0 { return entry.kind }
            }
            return basic
        }
    }
}
