import Foundation

/// 森林塔防的数值配置：怪物、英雄、炮塔、经济与战斗效果。
/// 默认值在内置的 `Resources/Config/forest.json`，调数值改那个文件；
/// 数据库只存被改动过的项（见 `LearnDatabase.forestRules`），没改过的始终跟随内置默认值。
/// 战斗逻辑只读 `ForestBattle.rules`，不在各处写数字。
/// 距离与半径用地图归一化坐标，时间单位为秒，速度为每秒走过的路径长度。
public struct ForestRules: Codable, Sendable, Equatable {
    public struct Economy: Codable, Sendable, Equatable {
        public var startCoins: Int
        public var lives: Int
        /// 总波数；最后一波的最后一只是首领。
        public var waves: Int
        /// 每波怪物数 = spawnBase + 波次。
        public var spawnBase: Int
        public var spawnInterval: Double
        /// 波间答对题目的奖励。
        public var waveReward: Int
        public var repairCost: Int
        public var repairAmount: Double
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
        public var slowFactor: Double
        /// 防线被冰霜击中后的冰冻时长，以及冰冻期间的出手速度倍率。
        public var chillSeconds: Double
        public var chillFactor: Double
        /// 护盾期间受到伤害的倍率。
        public var shieldDamageFactor: Double
        /// 强化技留下的持续区域：持续时间、跳伤间隔、每跳伤害与最小半径。
        public var zoneSeconds: Double
        public var zoneTickSeconds: Double
        public var zoneTickDamage: Double
        public var zoneMinRadius: Double
        /// 怪物出场后多久才会第一次出手。
        public var firstAttackDelay: Double
        /// 每第几次攻击换成强化技；0 表示从不。
        public var skillEvery: Int
        /// 近战强化技额外增加的前摇。
        public var meleeSkillExtraWindup: Double
    }

    /// 配置结构的版本号，随内置文件走；数据库里的改动项记下写入时的版本，供以后字段变动时迁移。
    public var version: Int
    public var economy: Economy
    public var combat: Combat
    /// 以 `ForestTower` / `ForestEnemyKind` / `ForestHero` 的 rawValue 为键。
    public var towers: [String: Tower]
    public var enemies: [String: Enemy]
    public var heroes: [String: Hero]

    /// 内置 forest.json 的内容。文件随包发布，缺失或写坏属于构建问题（测试会拦住），这里不再备一份数字。
    public static let defaults: ForestRules = {
        guard let rules = load() else { fatalError("内置 Config/forest.json 缺失或内容无效") }
        return rules
    }()

    /// 读取内置配置：必须能完整解析、覆盖全部单位且数值都在合法范围内。bundle 为 nil 时读 LearnCore 自带的。
    public static func load(bundle: Bundle? = nil) -> ForestRules? {
        guard let url = (bundle ?? .module).url(forResource: "forest", withExtension: "json", subdirectory: "Config"),
              let data = try? Data(contentsOf: url),
              let rules = try? JSONDecoder().decode(ForestRules.self, from: data),
              rules.isComplete else { return nil }
        return rules
    }

    /// 全部单位都有配置，且每一组数值都合法。
    public var isComplete: Bool {
        economy.isValid && combat.isValid
            && ForestTower.allCases.allSatisfy { towers[$0.rawValue]?.isValid == true }
            && ForestEnemyKind.allCases.allSatisfy { enemies[$0.rawValue]?.isValid == true }
            && ForestHero.allCases.allSatisfy { heroes[$0.rawValue]?.isValid == true }
    }

    public func tower(_ kind: ForestTower) -> Tower { towers[kind.rawValue] ?? Self.defaults.towers[kind.rawValue]! }
    public func enemy(_ kind: ForestEnemyKind) -> Enemy { enemies[kind.rawValue] ?? Self.defaults.enemies[kind.rawValue]! }
    public func hero(_ kind: ForestHero) -> Hero { heroes[kind.rawValue] ?? Self.defaults.heroes[kind.rawValue]! }

    /// 把数据库里的改动项叠加到默认值上。只写了部分字段的单位，其余字段取默认值；
    /// 字段类型不对导致无法解析时返回 nil，由调用方改用默认值，原数据保留供排查。
    public static func applying(overrides data: Data, to base: ForestRules = .defaults) -> ForestRules? {
        guard var stored = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let baseObject = base.jsonObject else { return nil }
        // 版本号跟内置文件走，不被库里记下的旧版本覆盖。
        stored.removeValue(forKey: "version")
        guard let merged = try? JSONSerialization.data(withJSONObject: merge(baseObject, stored)) else { return nil }
        return (try? JSONDecoder().decode(ForestRules.self, from: merged))?.validated()
    }

    /// 相对默认值被改动的项（带版本号），用来写入数据库；没有任何改动时返回 nil。
    public func overrides(from base: ForestRules = .defaults) -> Data? {
        guard let mine = validated().jsonObject, let baseObject = base.jsonObject else { return nil }
        var changed = Self.difference(mine, from: baseObject)
        changed.removeValue(forKey: "version")
        guard !changed.isEmpty else { return nil }
        changed["version"] = base.version
        return try? JSONSerialization.data(withJSONObject: changed, options: [.sortedKeys, .prettyPrinted])
    }

    private var jsonObject: [String: Any]? {
        (try? JSONEncoder().encode(self)).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
    }

    private static func difference(_ value: [String: Any], from base: [String: Any]) -> [String: Any] {
        var result: [String: Any] = [:]
        for (key, item) in value {
            if let inner = item as? [String: Any], let baseInner = base[key] as? [String: Any] {
                let changed = difference(inner, from: baseInner)
                if !changed.isEmpty { result[key] = changed }
            } else if (item as? NSObject) != (base[key] as? NSObject) {
                result[key] = item
            }
        }
        return result
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
