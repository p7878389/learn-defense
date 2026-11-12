import Foundation

/// Coordinates are normalized to the forest artwork, with the origin at the top left.
public struct ForestPoint: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
    public func distance(to other: ForestPoint) -> Double { hypot(x - other.x, y - other.y) }
}

public struct ForestPath: Sendable {
    public let points: [ForestPoint]
    public let length: Double
    private let verticalScale: Double
    public init(points: [ForestPoint], verticalScale: Double = 1) {
        precondition(points.count >= 2)
        precondition(verticalScale > 0)
        self.points = points
        self.verticalScale = verticalScale
        self.length = zip(points, points.dropFirst()).reduce(0) { $0 + hypot($1.0.x - $1.1.x, ($1.0.y - $1.1.y) * verticalScale) }
    }
    public func point(at distance: Double) -> ForestPoint {
        var remaining = max(0, distance)
        for (a, b) in zip(points, points.dropFirst()) {
            let segment = hypot(a.x - b.x, (a.y - b.y) * verticalScale)
            guard segment > 0 else { continue }
            if remaining <= segment {
                let t = remaining / segment
                return .init(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
            }
            remaining -= segment
        }
        return points[points.count - 1]
    }
    public static let forest = ForestPath(points: [
        .init(x: 0.02, y: 0.47), .init(x: 0.14, y: 0.50), .init(x: 0.20, y: 0.57),
        .init(x: 0.19, y: 0.70), .init(x: 0.24, y: 0.77), .init(x: 0.35, y: 0.78),
        .init(x: 0.43, y: 0.73), .init(x: 0.44, y: 0.64), .init(x: 0.38, y: 0.53),
        .init(x: 0.33, y: 0.40), .init(x: 0.34, y: 0.32), .init(x: 0.40, y: 0.30),
        .init(x: 0.54, y: 0.36), .init(x: 0.63, y: 0.34), .init(x: 0.68, y: 0.29),
        .init(x: 0.72, y: 0.32), .init(x: 0.73, y: 0.40), .init(x: 0.68, y: 0.50),
        .init(x: 0.63, y: 0.62), .init(x: 0.64, y: 0.72), .init(x: 0.69, y: 0.76),
        .init(x: 0.77, y: 0.76), .init(x: 0.84, y: 0.72), .init(x: 0.86, y: 0.60),
        .init(x: 0.90, y: 0.53), .init(x: 1.02, y: 0.52)
    ], verticalScale: artworkAspect)
    /// 地图原图高宽比，用来把归一化坐标换算成真实比例的距离。
    public static let artworkAspect = 768.0 / 1376.0
}

public enum ForestTower: String, CaseIterable, Sendable { case rapid, frost }
public struct ForestShot: Identifiable, Sendable {
    public let id: Int
    /// 发射这一弹的塔位，界面据此计算炮口位置和后坐动画。
    public let slot: Int
    public let origin: ForestPoint
    public var target: ForestPoint
    public let targetID: Int
    public let tower: ForestTower
    /// 开火时炮管角度（弧度，0 朝右，正值朝下），界面据此算炮口位置。
    public let angle: Double
    /// 飞行时长按距离匀速计算，到达后结算伤害，再播放 `impact` 秒命中特效。
    public let flight: Double
    public var age: Double = 0
    /// 命中特效时长：冰爆比豌豆溅射更久，便于看清。
    public var impact: Double { tower == .rapid ? 0.16 : 0.32 }
    public var duration: Double { flight + impact }
    /// 弹速（地图宽度/秒）：豌豆快，冰锥略慢带弧线。
    public static func flightTime(from origin: ForestPoint, to target: ForestPoint, tower: ForestTower) -> Double {
        let distance = hypot(target.x - origin.x, (target.y - origin.y) * ForestPath.artworkAspect)
        let speed = tower == .rapid ? 1.0 : 0.7
        return min(0.4, max(0.1, distance / speed))
    }
}
public struct ForestEnemy: Identifiable, Sendable {
    public let id: Int
    public var distance: Double = 0
    public var health: Double
    public let maxHealth: Double
    public var slowed: Double = 0
    public let fast: Bool
    public let kind: ForestEnemyKind
    public var rooted: Double = 0
    public var attackCooldown = ForestRules.defaults.combat.firstAttackDelay
    public var attacks = 0
    public var cast: ForestCast?
    public var isBoss: Bool { kind.isBoss }
    /// 1 朝右、-1 朝左，只取这两个值；前方的路掉头时立即换向，并开始 `turnTimer` 转身动作。
    public var facing: Double = 1
    /// 转身动作剩余时间，从 `turnTime` 递减到 0。
    public var turnTimer: Double = 0
    public static let turnTime = 0.18
    /// 被击中后的剩余闪烁时间，从 `hitFlash` 递减到 0。
    public var hitTimer: Double = 0
    public static let hitFlash = 0.18
    public init(id: Int, health: Double, fast: Bool) {
        self.id = id; self.health = health; self.maxHealth = health; self.fast = fast
        self.kind = fast ? .boar : .skeleton
    }
    /// 不传 `health` 时取默认配置里的血量；对局中由 `ForestBattle` 按当前配置传入。
    public init(id: Int, kind: ForestEnemyKind, health: Double? = nil) {
        let health = health ?? ForestRules.defaults.enemy(kind).health
        self.id = id; self.kind = kind; self.health = health; maxHealth = health
        fast = kind == .boar
    }
}
/// 怪物被击败时留下的烟尘与奖励飘字。
public struct ForestDefeat: Identifiable, Sendable {
    public let id: Int
    public let point: ForestPoint
    public let fast: Bool
    public var kind: ForestEnemyKind = .skeleton
    public let reward: Int
    public var age: Double = 0
    public static let duration = 0.7
}

public struct ForestBattle: Sendable {
    public enum Phase: Sendable { case preparing, fighting, question, won, lost }
    public static let slots: [ForestPoint] = [
        .init(x: 0.575, y: 0.24), .init(x: 0.79, y: 0.30),
        .init(x: 0.55, y: 0.62), .init(x: 0.69, y: 0.66),
        .init(x: 0.62, y: 0.83), .init(x: 0.705, y: 0.88)
    ]
    public internal(set) var phase: Phase = .preparing
    /// 本局使用的数值配置，开局时确定，对局中不变。
    public let rules: ForestRules
    public internal(set) var coins: Int
    public private(set) var lives: Int
    public internal(set) var wave = 0
    public internal(set) var towers: [Int: ForestTower] = [:]
    public internal(set) var enemies: [ForestEnemy] = []
    public internal(set) var defenses: [Int: ForestDefenseUnit] = [:]
    public internal(set) var combatShots: [ForestCombatShot] = []
    public internal(set) var zones: [ForestZone] = []
    public private(set) var boss: ForestEnemyKind
    var nextCombatID = 0
    public private(set) var shots: [ForestShot] = []
    public private(set) var defeats: [ForestDefeat] = []
    /// 每座塔最近一次瞄准的位置。
    public private(set) var aims: [Int: ForestPoint] = [:]
    /// 每座塔炮管的角度（弧度，0 朝右，正值朝下），持续跟踪射程内的目标并按角速度平滑转动。
    public private(set) var angles: [Int: Double] = [:]
    /// 炮管每秒最多转过的弧度，与开火前允许的瞄准误差。
    public static let turnSpeed = 8.0
    public static let aimTolerance = 0.3
    /// 战斗时钟，界面用来驱动待机呼吸等循环动画。
    public private(set) var time = 0.0
    private var spawnRemaining = 0
    private var spawnTimer = 0.0
    private var cooldowns: [Int: Double] = [:]
    /// 连发塔当前点射还剩几发。
    private var burstLeft: [Int: Int] = [:]
    private var nextID = 0
    private var nextShotID = 0
    private var nextDefeatID = 0
    public init(boss: ForestEnemyKind = .knight, rules: ForestRules = .defaults) {
        self.boss = boss.isBoss ? boss : .knight
        self.rules = rules.validated()
        coins = self.rules.economy.startCoins
        lives = self.rules.economy.lives
    }
    public mutating func selectBoss(_ kind: ForestEnemyKind) {
        guard phase == .preparing, wave == 0, kind.isBoss else { return }
        boss = kind
    }
    @discardableResult public mutating func build(_ kind: ForestTower, at slot: Int) -> Bool {
        let stats = rules.tower(kind)
        guard phase == .preparing, Self.slots.indices.contains(slot), defenses[slot] == nil, coins >= stats.cost else { return false }
        coins -= stats.cost; towers[slot] = kind; defenses[slot] = ForestDefenseUnit(maxHealth: stats.maxHealth); return true
    }
    public mutating func startWave() {
        guard phase == .preparing, defenses.values.contains(where: \.alive) else { return }
        wave += 1; spawnRemaining = rules.economy.spawnBase + wave; spawnTimer = 0; phase = .fighting
    }
    /// 某一波里除骷髅、野猪之外会出场的单位，与 `tick` 的出怪规则保持一致；界面据此提前解码素材。
    public func rosterKinds(inWave wave: Int) -> [ForestEnemyKind] {
        guard wave >= 1 else { return [] }
        let final = wave == rules.economy.waves
        // 末波最后一只换成首领，顶掉原本的侍僧；出怪数不足两只时轮不到哥布林。
        var kinds: [ForestEnemyKind] = []
        if wave >= 2 && rules.economy.spawnBase + wave >= 2 { kinds.append(.goblin) }
        if final { kinds.append(boss) } else if wave >= 2 { kinds.append(.acolyte) }
        return kinds
    }
    public mutating func tick(_ elapsed: Double) {
        guard elapsed.isFinite, elapsed > 0, phase == .preparing || phase == .fighting else { return }
        let dt = min(elapsed, 0.1)
        time += dt
        guard phase == .fighting else { return }
        for index in shots.indices {
            let previous = shots[index].age
            shots[index].age += dt
            if previous < shots[index].flight, let enemyIndex = enemies.firstIndex(where: { $0.id == shots[index].targetID }) {
                shots[index].target = ForestPath.forest.point(at: enemies[enemyIndex].distance)
                if shots[index].age >= shots[index].flight {
                    let stats = rules.tower(shots[index].tower)
                    enemies[enemyIndex].health -= stats.damage
                    enemies[enemyIndex].hitTimer = ForestEnemy.hitFlash
                    if stats.slowSeconds > 0 { enemies[enemyIndex].slowed = stats.slowSeconds }
                }
            }
        }
        shots.removeAll { $0.age >= $0.duration }
        for index in defeats.indices { defeats[index].age += dt }
        defeats.removeAll { $0.age >= ForestDefeat.duration }
        spawnTimer -= dt
        if spawnRemaining > 0 && spawnTimer <= 0 {
            nextID += 1
            let kind: ForestEnemyKind
            if wave == rules.economy.waves && spawnRemaining == 1 { kind = boss }
            else if wave >= 2 && spawnRemaining <= 2 { kind = spawnRemaining == 2 ? .goblin : .acolyte }
            else { kind = nextID.isMultiple(of: 2) ? .boar : .skeleton }
            var enemy = ForestEnemy(id: nextID, kind: kind, health: rules.enemy(kind).health)
            enemy.attackCooldown = rules.combat.firstAttackDelay
            enemies.append(enemy)
            spawnRemaining -= 1; spawnTimer = rules.economy.spawnInterval
        }
        tickCombat(dt)
        for index in enemies.indices {
            guard enemies[index].health > 0 else { continue }
            let slow = enemies[index].slowed > 0 ? rules.combat.slowFactor : 1.0
            if enemies[index].cast == nil && enemies[index].rooted <= 0 {
                enemies[index].distance += dt * rules.enemy(enemies[index].kind).speed * slow
            }
            enemies[index].rooted = max(0, enemies[index].rooted - dt)
            enemies[index].slowed = max(0, enemies[index].slowed - dt)
            enemies[index].hitTimer = max(0, enemies[index].hitTimer - dt)
            enemies[index].turnTimer = max(0, enemies[index].turnTimer - dt)
            turn(&enemies[index])
        }
        for (slot, tower) in towers.sorted(by: { $0.key < $1.key }) {
            guard defenses[slot]?.alive == true else { continue }
            let stats = rules.tower(tower)
            cooldowns[slot, default: 0] -= dt * ((defenses[slot]?.chilled ?? 0) > 0 ? rules.combat.chillFactor : 1)
            let origin = Self.slots[slot]
            let candidates = enemies.indices.filter { enemies[$0].health > 0 && origin.distance(to: ForestPath.forest.point(at: enemies[$0].distance)) <= stats.range }
            guard let target = candidates.max(by: { enemies[$0].distance < enemies[$1].distance }) else { continue }
            let aim = ForestPath.forest.point(at: enemies[target].distance)
            // 炮管先转向目标，对准后才开火；只有炮管转动，塔身不动
            let goal = atan2((aim.y - origin.y) * ForestPath.artworkAspect, aim.x - origin.x)
            let current = angles[slot, default: 0]
            let difference = remainder(goal - current, 2 * .pi)
            let step = dt * Self.turnSpeed
            let angle = current + max(-step, min(step, difference))
            angles[slot] = remainder(angle, 2 * .pi)
            let aimed = abs(remainder(goal - angle, 2 * .pi)) < Self.aimTolerance
            guard cooldowns[slot, default: 0] <= 0, tower == .frost || aimed else { continue }
            nextShotID += 1
            shots.append(ForestShot(id: nextShotID, slot: slot, origin: origin, target: aim, targetID: enemies[target].id, tower: tower,
                                    angle: angles[slot, default: 0],
                                    flight: ForestShot.flightTime(from: origin, to: aim, tower: tower)))
            aims[slot] = aim
            // 一轮点射打完才进入装填；单发塔每发都是一轮。
            let left = burstLeft[slot, default: 0] > 0 ? burstLeft[slot, default: 0] - 1 : stats.burst - 1
            burstLeft[slot] = left
            cooldowns[slot] = left > 0 ? stats.burstGap : stats.reload
        }
        for enemy in enemies where enemy.health <= 0 {
            nextDefeatID += 1
            defeats.append(ForestDefeat(id: nextDefeatID, point: ForestPath.forest.point(at: enemy.distance), fast: enemy.fast,
                                        kind: enemy.kind, reward: rules.enemy(enemy.kind).reward))
        }
        coins += enemies.filter { $0.health <= 0 }.reduce(0) { $0 + rules.enemy($1.kind).reward }
        lives = max(0, lives - enemies.filter { $0.health > 0 && $0.distance >= ForestPath.forest.length }.reduce(0) { $0 + rules.enemy($1.kind).leakLives })
        enemies.removeAll { $0.health <= 0 || $0.distance >= ForestPath.forest.length }
        if lives <= 0 { phase = .lost }
        else if spawnRemaining == 0 && enemies.isEmpty { phase = .question }
        if phase != .fighting { endCombat(); shots.removeAll() }
    }
    /// 塔的装填进度：0 刚开火，1 已就绪；连发塔点射过程中视为就绪。
    public func readiness(of slot: Int) -> Double {
        guard let tower = towers[slot] else { return 0 }
        let cooldown = cooldowns[slot, default: 0]
        if burstLeft[slot, default: 0] > 0 { return 1 }
        let reload = rules.tower(tower).reload
        return min(1, max(0, 1 - cooldown / reload))
    }
    /// 看前方一小段路的水平走向：明显往反方向走时立即换向并开始转身动作；
    /// 接近竖直的路段保持原朝向，避免在弯道上来回翻面。
    private func turn(_ enemy: inout ForestEnemy) {
        let window = 0.02
        let path = ForestPath.forest
        let dx = path.point(at: enemy.distance + window).x - path.point(at: enemy.distance).x
        guard abs(dx) > window * 0.5 else { return }
        let goal: Double = dx > 0 ? 1 : -1
        guard goal != enemy.facing else { return }
        enemy.facing = goal
        enemy.turnTimer = ForestEnemy.turnTime
    }
    public mutating func answer(correct: Bool) {
        guard phase == .question, correct else { return }
        coins += rules.economy.waveReward
        phase = wave >= rules.economy.waves ? .won : .preparing
    }
}
