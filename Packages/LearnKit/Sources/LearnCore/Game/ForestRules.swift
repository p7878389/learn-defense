import Foundation

/// 森林塔防的数值配置：怪物、英雄、炮塔、经济与战斗效果。
/// 数据库是运行时来源：首次使用把这里的默认值写入数据库，之后以数据库为准；
/// 战斗逻辑只读 `ForestBattle.rules`，不再各处写数字。
/// 距离与半径用地图归一化坐标，时间单位为秒，速度为每秒走过的路径长度。
public struct ForestRules: Codable, Sendable, Equatable {
    public struct Economy: Codable, Sendable, Equatable {
        public var startCoins = 100
        public var lives = 5
        /// 总波数；最后一波的最后一只是首领。
        public var waves = 3
        /// 每波怪物数 = spawnBase + 波次。
        public var spawnBase = 3
        public var spawnInterval = 1.8
        /// 波间答对题目的奖励。
        public var waveReward = 50
        public var repairCost = 15
        public var repairAmount = 20.0
    }

    public struct Tower: Codable, Sendable, Equatable {
        public var cost: Int
        public var maxHealth: Double
        public var damage: Double
        public var range: Double
        /// 一轮点射打完后的装填时间。
        public var reload: Double
        /// 每轮点射的发数与发间隔；单发塔为 1 和 0。
        public var burst: Int
        public var burstGap: Double
        /// 命中后减速的秒数；0 表示不减速。
        public var slowSeconds: Double
    }

    public struct Enemy: Codable, Sendable, Equatable {
        public var health: Double
        public var speed: Double
        /// 击败奖励，以及冲过终点扣掉的生命。
        public var reward: Int
        public var leakLives: Int
        public var windup: Double
        public var recovery: Double
        public var attackDamage: Double
        public var attackRange: Double
        public var attackCooldown: Double
        /// 强化技：伤害为 0 表示没有强化技；半径为 0 表示只打锁定目标；`skillCount` 是连发数。
        public var skillDamage: Double
        public var skillRadius: Double
        public var skillCount: Int
    }

    public struct Hero: Codable, Sendable, Equatable {
        public var cost: Int
        public var maxHealth: Double
        public var attackDamage: Double
        public var attackRange: Double
        public var attackWindup: Double
        public var attackRecovery: Double
        public var attackCooldown: Double
        public var skillWindup: Double
        public var skillRecovery: Double
        public var skillCooldown: Double
        /// 技能索敌距离；对自身释放的技能为 0。
        public var skillRange: Double
        /// 技能波及半径、伤害与效果持续时间（护盾时长 / 定身时长）。
        public var skillRadius: Double
        public var skillDamage: Double
        public var skillSeconds: Double
    }

    public struct Combat: Codable, Sendable, Equatable {
        /// 被冰塔减速时的移动速度倍率。
        public var slowFactor = 0.55
        /// 防线被冰霜击中后的冰冻时长，以及冰冻期间的出手速度倍率。
        public var chillSeconds = 3.0
        public var chillFactor = 0.5
        /// 护盾期间受到伤害的倍率。
        public var shieldDamageFactor = 0.35
        /// 强化技留下的持续区域：持续时间、跳伤间隔、每跳伤害与最小半径。
        public var zoneSeconds = 3.0
        public var zoneTickSeconds = 0.5
        public var zoneTickDamage = 1.0
        public var zoneMinRadius = 0.1
        /// 怪物出场后多久才会第一次出手。
        public var firstAttackDelay = 2.0
        /// 每第几次攻击换成强化技；0 表示从不。
        public var skillEvery = 3
        /// 近战强化技额外增加的前摇。
        public var meleeSkillExtraWindup = 0.25
    }

    public var economy = Economy()
    public var combat = Combat()
    /// 以 `ForestTower` / `ForestEnemyKind` / `ForestHero` 的 rawValue 为键。
    public var towers: [String: Tower]
    public var enemies: [String: Enemy]
    public var heroes: [String: Hero]

    public static let defaults = ForestRules()

    public init() {
        towers = [
            ForestTower.rapid.rawValue: Tower(cost: 50, maxHealth: 30, damage: 0.45, range: 0.18,
                                              reload: 0.75, burst: 3, burstGap: 0.09, slowSeconds: 0),
            ForestTower.frost.rawValue: Tower(cost: 50, maxHealth: 30, damage: 0.6, range: 0.18,
                                              reload: 1.2, burst: 1, burstGap: 0, slowSeconds: 2)
        ]
        enemies = Dictionary(uniqueKeysWithValues: ForestEnemyKind.allCases.map { ($0.rawValue, Self.defaultEnemy($0)) })
        heroes = [
            ForestHero.paladin.rawValue: Hero(cost: 50, maxHealth: 36, attackDamage: 1.2, attackRange: 0.24,
                                              attackWindup: 0.45, attackRecovery: 0.35, attackCooldown: 0.85,
                                              skillWindup: 0.8, skillRecovery: 0.5, skillCooldown: 12,
                                              skillRange: 0, skillRadius: 0.30, skillDamage: 0, skillSeconds: 6),
            ForestHero.botanist.rawValue: Hero(cost: 50, maxHealth: 36, attackDamage: 1.2, attackRange: 0.24,
                                               attackWindup: 0.65, attackRecovery: 0.45, attackCooldown: 0.85,
                                               skillWindup: 1, skillRecovery: 0.5, skillCooldown: 12,
                                               skillRange: 0.30, skillRadius: 0.14, skillDamage: 2, skillSeconds: 3)
        ]
    }

    private static func defaultEnemy(_ kind: ForestEnemyKind) -> Enemy {
        func minion(health: Double, speed: Double, windup: Double, recovery: Double = 0.30,
                    damage: Double, range: Double) -> Enemy {
            Enemy(health: health, speed: speed, reward: 10, leakLives: 1, windup: windup, recovery: recovery,
                  attackDamage: damage, attackRange: range, attackCooldown: 4,
                  skillDamage: 0, skillRadius: 0, skillCount: 1)
        }
        func boss(speed: Double, windup: Double, recovery: Double, range: Double,
                  radius: Double = 0.12, count: Int = 1) -> Enemy {
            Enemy(health: 18, speed: speed, reward: 100, leakLives: 3, windup: windup, recovery: recovery,
                  attackDamage: 3, attackRange: range, attackCooldown: 3.2,
                  skillDamage: 5, skillRadius: radius, skillCount: count)
        }
        let melee = 0.13, ranged = 0.24
        switch kind {
        case .skeleton: return minion(health: 3, speed: 0.055, windup: 0.35, damage: 1, range: melee)
        case .boar: return minion(health: 4, speed: 0.075, windup: 0.40, damage: 1, range: melee)
        case .goblin: return minion(health: 3, speed: 0.055, windup: 0.40, damage: 3, range: ranged)
        case .acolyte: return minion(health: 3, speed: 0.055, windup: 0.55, recovery: 0.35, damage: 3, range: ranged)
        case .knight: return boss(speed: 0.033, windup: 0.55, recovery: 0.40, range: melee)
        case .ogre: return boss(speed: 0.033, windup: 0.80, recovery: 0.65, range: melee)
        case .berserker: return boss(speed: 0.045, windup: 0.45, recovery: 0.35, range: melee)
        case .frostKing: return boss(speed: 0.045, windup: 0.50, recovery: 0.40, range: melee)
        case .infernal: return boss(speed: 0.038, windup: 0.70, recovery: 0.50, range: melee)
        case .reaper: return boss(speed: 0.038, windup: 0.90, recovery: 0.45, range: ranged, radius: 0, count: 3)
        case .pharaoh: return boss(speed: 0.038, windup: 1.00, recovery: 0.50, range: ranged)
        case .slime: return boss(speed: 0.033, windup: 0.85, recovery: 0.60, range: ranged)
        case .gargoyle: return boss(speed: 0.038, windup: 1.10, recovery: 0.65, range: ranged, count: 3)
        case .shaman: return boss(speed: 0.038, windup: 0.70, recovery: 0.45, range: ranged)
        }
    }

    public func tower(_ kind: ForestTower) -> Tower { towers[kind.rawValue] ?? Self.defaults.towers[kind.rawValue]! }
    public func enemy(_ kind: ForestEnemyKind) -> Enemy { enemies[kind.rawValue] ?? Self.defaults.enemies[kind.rawValue]! }
    public func hero(_ kind: ForestHero) -> Hero { heroes[kind.rawValue] ?? Self.defaults.heroes[kind.rawValue]! }

    /// 读取数据库里的配置。缺少的字段、缺少的单位逐项用默认值补齐（新版本加了怪物或字段时旧数据仍可用）；
    /// 字段类型不对导致整份无法解析时返回 nil，由调用方改用默认值，原数据保留供排查。
    public static func decode(_ data: Data) -> ForestRules? {
        guard let stored = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let base = try? JSONSerialization.jsonObject(with: JSONEncoder().encode(defaults)) as? [String: Any],
              let merged = try? JSONSerialization.data(withJSONObject: merge(base, stored)) else { return nil }
        return (try? JSONDecoder().decode(ForestRules.self, from: merged))?.validated()
    }

    private static func merge(_ base: [String: Any], _ over: [String: Any]) -> [String: Any] {
        var result = base
        // 默认配置里没有的键（已下线的单位、拼错的字段）直接忽略，不让它拖垮整份解析。
        for (key, value) in over where base[key] != nil {
            if let inner = result[key] as? [String: Any], let patch = value as? [String: Any] {
                result[key] = merge(inner, patch)
            } else {
                result[key] = value
            }
        }
        return result
    }

    /// 数值越界时回退：经济、战斗效果按整组回退，炮塔、怪物、英雄按单个单位回退。
    public func validated() -> ForestRules {
        var r = self
        let d = Self.defaults
        if !r.economy.isValid { r.economy = d.economy }
        if !r.combat.isValid { r.combat = d.combat }
        for kind in ForestTower.allCases where r.towers[kind.rawValue]?.isValid != true {
            r.towers[kind.rawValue] = d.towers[kind.rawValue]
        }
        for kind in ForestEnemyKind.allCases where r.enemies[kind.rawValue]?.isValid != true {
            r.enemies[kind.rawValue] = d.enemies[kind.rawValue]
        }
        for kind in ForestHero.allCases where r.heroes[kind.rawValue]?.isValid != true {
            r.heroes[kind.rawValue] = d.heroes[kind.rawValue]
        }
        return r
    }
}

private func inRange(_ values: Double..., min: Double = 0, max: Double = 10_000) -> Bool {
    values.allSatisfy { $0.isFinite && $0 >= min && $0 <= max }
}

private extension ForestRules.Economy {
    var isValid: Bool {
        (0...100_000).contains(startCoins) && (1...99).contains(lives) && (1...20).contains(waves)
            && (0...50).contains(spawnBase) && inRange(spawnInterval, min: 0.2, max: 60)
            && (0...100_000).contains(waveReward) && (0...100_000).contains(repairCost)
            && inRange(repairAmount, min: 0.01)
    }
}

private extension ForestRules.Combat {
    var isValid: Bool {
        inRange(slowFactor, shieldDamageFactor, max: 1) && inRange(chillFactor, min: 0.05, max: 1)
            && inRange(chillSeconds, zoneSeconds, zoneTickDamage, firstAttackDelay, meleeSkillExtraWindup, max: 600)
            && inRange(zoneTickSeconds, min: 0.05, max: 600) && inRange(zoneMinRadius, max: 2)
            && (0...100).contains(skillEvery)
    }
}

private extension ForestRules.Tower {
    var isValid: Bool {
        (0...100_000).contains(cost) && inRange(maxHealth, min: 0.01) && inRange(damage)
            && inRange(range, min: 0.01, max: 2) && inRange(reload, min: 0.05, max: 600)
            && (1...20).contains(burst) && inRange(burstGap, max: 600) && inRange(slowSeconds, max: 600)
    }
}

private extension ForestRules.Enemy {
    var isValid: Bool {
        inRange(health, min: 0.01) && inRange(speed, min: 0.001, max: 2)
            && (0...100_000).contains(reward) && (0...99).contains(leakLives)
            && inRange(windup, recovery, max: 600) && inRange(attackDamage, skillDamage)
            && inRange(attackRange, skillRadius, max: 2) && inRange(attackCooldown, min: 0.1, max: 600)
            && (1...10).contains(skillCount)
    }
}

private extension ForestRules.Hero {
    var isValid: Bool {
        (0...100_000).contains(cost) && inRange(maxHealth, min: 0.01) && inRange(attackDamage, skillDamage)
            && inRange(attackRange, skillRange, skillRadius, max: 2)
            && inRange(attackWindup, attackRecovery, skillWindup, skillRecovery, skillSeconds, max: 600)
            && inRange(attackCooldown, min: 0.05, max: 600) && inRange(skillCooldown, max: 3600)
    }
}
