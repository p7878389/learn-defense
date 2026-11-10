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

// MARK: - 森林怪物（经典模式也能出场）

/// 森林模式的小怪和首领，在经典模式里照样是「血量 = 要答对几题」。
/// id 和 `ForestEnemyKind` 的 rawValue 一致，序列帧复用森林素材（见 `Sprites/forest-classic.json`）。
/// 骷髅步兵、尖刺野猪没有成品图，暂不加入
public extension EnemyKind {
    static let goblin = EnemyKind(
        id: "goblin", name: "掷石斥候", speed: 1.2,
        movement: .surge(period: 1.4, amplitude: 0.6),
        look: EnemyLook(body: .ball, color: .moss, accessory: .horns, defeat: .ripple),
        drop: ItemDrop(.luckyStar, chance: 0.2))

    static let acolyte = EnemyKind(
        id: "acolyte", name: "暗影学徒", speed: 0.9,
        look: EnemyLook(body: .cloud, color: .plum, eyes: .single, defeat: .sparkle),
        drop: ItemDrop(.frostCharm, chance: 0.2))

    /// 首领统一 3 滴血（和铁门僵尸一样），一局题量不会因为抽到哪个首领而变
    private static func forestBoss(_ id: String, _ name: String, speed: Double, color: UnitColor,
                                   movement: MovementStyle = .steady, scale: Double = 1.4) -> EnemyKind {
        EnemyKind(id: id, name: name, hp: 3, speed: speed, bonus: 30, movement: movement,
                  look: EnemyLook(body: .spiky, color: color, accessory: .crown, eyes: .single,
                                  scale: scale, defeat: .firework))
    }

    /// 飘在空中的首领：一路上下浮动，矮墙拦不住（和会跳的僵尸同一条规则）
    private static let hover = MovementStyle.hop(pause: 0, airTime: 1.4, height: 10)

    static let knight = forestBoss("knight", "骷髅死亡骑士", speed: 0.6, color: .indigo)
    static let ogre = forestBoss("ogre", "巨魔酋长", speed: 0.5, color: .coral, scale: 1.5)
    static let berserker = forestBoss("berserker", "双斧狂战士", speed: 0.7, color: .moss,
                                      movement: .surge(period: 2, amplitude: 0.5))
    static let frostKing = forestBoss("frostKing", "寒霜魔王", speed: 0.6, color: .sky)
    static let infernal = forestBoss("infernal", "炎狱领主", speed: 0.6, color: .crimson)
    static let reaper = forestBoss("reaper", "冥魂收割者", speed: 0.6, color: .plum, movement: hover)
    static let pharaoh = forestBoss("pharaoh", "古墓法老", speed: 0.55, color: .gold)
    static let slime = forestBoss("slime", "剧毒史莱姆王", speed: 0.5, color: .jade, scale: 1.5)
    static let gargoyle = forestBoss("gargoyle", "暗翼石像鬼王", speed: 0.65, color: .crimson, movement: hover)
    static let shaman = forestBoss("shaman", "炼金萨满王", speed: 0.6, color: .moss)

    /// 森林首领，经典模式每局从首领候选里随机抽一个压轴
    static let forestBosses: [EnemyKind] = [.knight, .ogre, .berserker, .frostKing, .infernal,
                                            .reaper, .pharaoh, .slime, .gargoyle, .shaman]
}

// MARK: - 内置字灵

public extension DefenderKind {
    static let inkling = DefenderKind(
        id: "inkling", name: "豌豆射手", sunCost: 50, attack: .single(damage: 1),
        look: DefenderLook(body: .round, color: .jade, accessory: .brush),
        projectile: ProjectileLook(shape: .orb, color: .gold))

    static let twin = DefenderKind(
        id: "twin", name: "双发射手", sunCost: 100, attack: .volley(count: 2, damage: 1),
        look: DefenderLook(body: .drop, color: .coral, accessory: .bow),
        projectile: ProjectileLook(shape: .orb, color: .coral, size: 8))

    static let frost = DefenderKind(
        id: "frost", name: "寒冰射手", sunCost: 100, attack: .single(damage: 1),
        effects: [.slowLane(factor: 0.5, seconds: 3)],
        look: DefenderLook(body: .round, color: .sky, accessory: .scholarHat),
        projectile: ProjectileLook(shape: .snowflake, color: .sky, size: 13))

    static let stroke = DefenderKind(
        id: "stroke", name: "大喷菇", sunCost: 125, attack: .beam(damage: 1),
        effects: [.knockback(distance: 70)],
        look: DefenderLook(body: .seal, color: .gold, accessory: .brush),
        projectile: ProjectileLook(shape: .petal, color: .gold))

    static let starling = DefenderKind(
        id: "starling", name: "杨桃", sunCost: 125, attack: .single(damage: 1),
        look: DefenderLook(body: .round, color: .moss, accessory: .leaf),
        projectile: ProjectileLook(shape: .star, color: .gold, size: 14))
}

// MARK: - 内置防御道具（不发射，用来拦僵尸、多给答题时间）

public extension DefenderKind {
    static let wallnut = DefenderKind(
        id: "wallnut", name: "坚果墙", sunCost: 50,
        guardStyle: .wall(seconds: 15, tall: false),
        look: DefenderLook(body: .round, color: .gold))

    static let tallnut = DefenderKind(
        id: "tallnut", name: "高坚果", sunCost: 125,
        guardStyle: .wall(seconds: 30, tall: true),
        look: DefenderLook(body: .drop, color: .gold))

    static let potato = DefenderKind(
        id: "potato", name: "土豆雷", sunCost: 25,
        guardStyle: .mine(armAfter: 2, bossDamage: 1),
        look: DefenderLook(body: .round, color: .coral, accessory: .leaf))

    /// 战斗中点一下就用：落在正在答题的僵尸面前，不占种植格
    static let ironGate = DefenderKind(
        id: "ironGate", name: "铁栅门", sunCost: 75,
        guardStyle: .wall(seconds: 10, tall: true),
        look: DefenderLook(body: .gate, color: .ink))
}

/// 所有内置的怪物和字灵，按 id 查找
public enum UnitCatalog {
    /// 原版的六种僵尸：啃咬、倒下、烧焦、掉防具的动画齐全
    public static let enemies: [EnemyKind] = [.blob, .hopper, .dasher, .drowsy, .armored, .king]
    /// 从森林模式来的小怪和首领：只有行走和出手动画，被打败时直接用退场特效
    public static let forestEnemies: [EnemyKind] = [.goblin, .acolyte] + EnemyKind.forestBosses
    /// 能种在草坪上的植物：射手和防御道具
    public static let defenders: [DefenderKind] = [.inkling, .twin, .frost, .stroke, .starling,
                                                   .wallnut, .tallnut, .potato]
    /// 战斗中花阳光放下的路障，不占种植格
    public static let barricades: [DefenderKind] = [.ironGate]

    public static func enemy(id: String) -> EnemyKind? {
        (enemies + forestEnemies).first { $0.id == id }
    }

    public static func defender(id: String) -> DefenderKind? {
        (defenders + barricades).first { $0.id == id }
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
    /// 首领候选：每局随机抽一个放在最后。空表示这一档不出首领
    public var bosses: [EnemyKind]
    /// 默认的首领（候选里的第一个）
    public var boss: EnemyKind? { bosses.first }

    public init(warmup: Int = 2, basic: EnemyKind = .blob, mix: [Entry], boss: EnemyKind? = nil,
                bosses: [EnemyKind] = []) {
        self.warmup = warmup
        self.basic = basic
        self.mix = mix
        self.bosses = (boss.map { [$0] } ?? []) + bosses.filter { $0 != boss }
    }

    public func isBoss(_ kind: EnemyKind) -> Bool { bosses.contains(kind) }

    /// 按题量出怪：所有怪物要答对的题数（血量）加起来正好等于 questions，每局题量固定。
    /// 先出 warmup 只基础怪；首领算在题量里，放在最后，题量不够容纳首领时就不出首领；
    /// 剩下的预算放不下血量多的怪时补基础怪
    public func kinds<R: RandomNumberGenerator>(questions budget: Int, using rng: inout R) -> [EnemyKind] {
        var remaining = max(0, budget)
        var result: [EnemyKind] = []
        // 只有一个候选时不消耗随机数，出怪顺序和以前一致
        let boss = bosses.count > 1 ? bosses.randomElement(using: &rng) : bosses.first
        let bossHP = boss?.hp ?? 0
        let withBoss = boss != nil && remaining >= warmup * basic.hp + bossHP + 1
        if withBoss { remaining -= bossHP }
        while remaining >= basic.hp, remaining > 0 {
            let candidates = result.count < warmup ? [] : mix.filter { $0.weight > 0 && $0.kind.hp <= remaining }
            let total = candidates.reduce(0) { $0 + $1.weight }
            var kind = basic
            if total > 0 {
                var roll = Double.random(in: 0..<total, using: &rng)
                for entry in candidates {
                    roll -= entry.weight
                    if roll < 0 { kind = entry.kind; break }
                }
            }
            result.append(kind)
            remaining -= kind.hp
        }
        if withBoss, let boss { result.append(boss) }
        return result
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
