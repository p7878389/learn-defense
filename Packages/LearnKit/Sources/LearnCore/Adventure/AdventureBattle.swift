import Foundation

public struct AdventureTower: Codable, Equatable, Identifiable, Sendable {
    public let id: Int
    public let kindID: String
    public let lane: Int
    public let column: Int
    public var durability: Double
    var cooldown: Double = 0

    public var x: Double { 144 + 750 * (Double(column) + 0.5) / 9 }
    public var maxDurability: Double { kindID == "tallnut" ? 40 : kindID == "wallnut" ? 22 : 5 }
}

public struct AdventureEnemy: Codable, Equatable, Identifiable, Sendable {
    public let id: Int
    public let kind: AdventureEnemyKind
    public let lane: Int
    public let maxHealth: Int
    public var health: Int
    public var x: Double = 1155
    public var slowRemaining: Double = 0
}

/// 玩法事件只用于显示。场景动画回调不再扣血或发奖励，避免重放与恢复时重复结算。
public enum AdventureEvent: Equatable, Sendable {
    case spawned(AdventureEnemy)
    case shot(tower: AdventureTower, target: AdventureEnemy)
    case defeated(AdventureEnemy)
    case leaked(AdventureEnemy)
    case towerBroken(AdventureTower)
    case wave(Int)
    case ultimate
}

/// 可保存的完整玩法状态；使用固定步长，使不同帧率和存档恢复具有相同结果。
public struct AdventureBattle: Codable, Equatable, Identifiable, Sendable {
    public enum Phase: String, Codable, Sendable { case preparing, playing, paused, won, lost }

    public let id: UUID
    public let level: AdventureLevel
    public let difficulty: Difficulty
    public let deck: [String]
    public private(set) var phase: Phase = .preparing
    public private(set) var sun = 250
    public private(set) var lives = 10
    public private(set) var wave = 1
    public private(set) var defeated = 0
    public private(set) var energy = 0
    public private(set) var towers: [AdventureTower] = []
    public private(set) var enemies: [AdventureEnemy] = []
    public private(set) var leaksByLane = [Int](repeating: 0, count: 5)
    public private(set) var restRemaining: Double = 0
    private var ticks = 0
    private var waveTicks = 0
    private var spawnIndex = 0
    private var nextID = 1
    private var remainder: Double = 0

    public init(level: AdventureLevel, difficulty: Difficulty = .normal, deck: [String] = AdventureCatalog.defaultDeck) {
        id = UUID()
        self.level = level
        self.difficulty = difficulty
        var seen: Set<String> = []
        let valid = deck.filter { AdventureCatalog.defender($0) != nil && seen.insert($0).inserted }
        self.deck = valid.contains(where: { AdventureCatalog.defender($0)?.canShoot == true })
            ? Array(valid.prefix(4)) : AdventureCatalog.defaultDeck
    }

    public var elapsed: Double { Double(ticks) * 0.05 }
    public var isFinished: Bool { phase == .won || phase == .lost }
    public var ultimateReady: Bool { phase == .playing && energy >= AdventureCatalog.ultimateEnergy && !enemies.isEmpty }
    public var stars: Int { phase == .won ? (lives >= 9 ? 3 : lives >= 6 ? 2 : 1) : 0 }
    public var currentWave: AdventureWave? { level.waves.indices.contains(wave - 1) ? level.waves[wave - 1] : nil }
    public var nextWave: AdventureWave? { level.waves.indices.contains(wave) ? level.waves[wave] : nil }
    public var canBuild: Bool { phase == .preparing || phase == .playing }

    public var advice: String {
        guard let worst = leaksByLane.indices.max(by: { leaksByLane[$0] < leaksByLane[$1] }), leaksByLane[worst] > 0 else {
            return level.hint
        }
        return "第 \(5 - worst) 路通过了 \(leaksByLane[worst]) 只怪物，可以提前补充射手或用坚果保护前线。"
    }

    @discardableResult
    public mutating func plant(_ kindID: String, lane: Int, column: Int) -> Bool {
        guard canBuild, deck.contains(kindID), let kind = AdventureCatalog.defender(kindID),
              (0..<5).contains(lane), (0..<9).contains(column), sun >= kind.sunCost,
              !towers.contains(where: { $0.lane == lane && $0.column == column }) else { return false }
        var tower = AdventureTower(id: nextID, kindID: kindID, lane: lane, column: column, durability: 0)
        tower.durability = tower.maxDurability
        nextID += 1
        towers.append(tower)
        sun -= kind.sunCost
        return true
    }

    @discardableResult
    public mutating func shovel(lane: Int, column: Int) -> Bool {
        guard canBuild, let index = towers.firstIndex(where: { $0.lane == lane && $0.column == column }) else { return false }
        towers.remove(at: index)
        return true
    }

    @discardableResult
    public mutating func start() -> Bool {
        guard phase == .preparing, !level.waves.isEmpty,
              towers.contains(where: { AdventureCatalog.defender($0.kindID)?.canShoot == true }) else { return false }
        phase = .playing
        return true
    }

    public mutating func pause() { if phase == .playing { phase = .paused } }
    public mutating func resume() { if phase == .paused { phase = .playing } }

    public mutating func advance(by seconds: Double) -> [AdventureEvent] {
        guard phase == .playing, seconds.isFinite, seconds > 0 else { return [] }
        remainder += min(seconds, 3600)
        var events: [AdventureEvent] = []
        while remainder + 0.0000001 >= 0.05 && phase == .playing {
            remainder = max(0, remainder - 0.05)
            step(events: &events)
        }
        return events
    }

    public mutating func unleash() -> [AdventureEvent] {
        guard ultimateReady else { return [] }
        energy = 0
        var events: [AdventureEvent] = [.ultimate]
        for id in enemies.map(\.id) { hit(id, damage: 60, events: &events, chargesEnergy: false) }
        return events
    }

    private mutating func step(events: inout [AdventureEvent]) {
        ticks += 1
        if ticks % 100 == 0 { sun += 25 }
        if restRemaining > 0 {
            restRemaining = max(0, restRemaining - 0.05)
            return
        }
        guard let plan = currentWave else { phase = .won; return }
        waveTicks += 1
        let waveSeconds = Double(waveTicks) * 0.05
        let healthRate = (difficulty == .easy ? 0.8 : difficulty == .hard ? 1.25 : 1.0)
            * (1 + Double(max(0, level.id - 1)) * 0.08)
        while spawnIndex < plan.enemies.count && plan.enemies[spawnIndex].delay <= waveSeconds {
            let spawn = plan.enemies[spawnIndex]
            let hp = Int((Double(spawn.kind.health) * healthRate).rounded())
            let enemy = AdventureEnemy(id: nextID, kind: spawn.kind, lane: spawn.lane, maxHealth: hp, health: hp)
            nextID += 1
            enemies.append(enemy)
            events.append(.spawned(enemy))
            spawnIndex += 1
        }

        // 同路、射手前方的最靠近基地者优先；大喷菇只打近距离目标。
        for index in towers.indices {
            towers[index].cooldown = max(0, towers[index].cooldown - 0.05)
            let tower = towers[index]
            guard AdventureCatalog.defender(tower.kindID)?.canShoot == true, tower.cooldown <= 0,
                  let target = enemies.filter({
                      $0.lane == tower.lane && $0.x > tower.x + 12
                          && (tower.kindID != "stroke" || $0.x - tower.x < 300)
                  }).min(by: { $0.x < $1.x }) else { continue }
            towers[index].cooldown = AdventureCatalog.interval(tower.kindID)
            events.append(.shot(tower: tower, target: target))
            let victims = tower.kindID == "stroke"
                ? enemies.filter { $0.lane == tower.lane && $0.x > tower.x && $0.x - tower.x < 300 }.map(\.id)
                : [target.id]
            for id in victims { hit(id, damage: AdventureCatalog.damage(tower.kindID), events: &events) }
            if tower.kindID == "frost" {
                for i in enemies.indices where enemies[i].lane == tower.lane { enemies[i].slowRemaining = 2.5 }
            }
        }

        for id in enemies.map(\.id) {
            guard let index = enemies.firstIndex(where: { $0.id == id }) else { continue }
            let enemy = enemies[index]
            let slow = enemy.slowRemaining > 0 ? 0.5 : 1.0
            enemies[index].slowRemaining = max(0, enemy.slowRemaining - 0.05)
            let speed = enemy.kind.speed * (difficulty == .hard ? 1.1 : 1.0) * slow
            let nextX = enemy.x - speed * 0.05
            if let blocker = towers.filter({
                $0.lane == enemy.lane && $0.x <= enemy.x && nextX <= $0.x + 36
            }).max(by: { $0.x < $1.x }), let ti = towers.firstIndex(where: { $0.id == blocker.id }) {
                enemies[index].x = max(enemy.x, blocker.x + 36)
                towers[ti].durability -= 0.05 * slow * (enemy.kind == .boss ? 2.0 : 1.0)
                if towers[ti].durability <= 0 {
                    events.append(.towerBroken(towers.remove(at: ti)))
                }
            } else {
                enemies[index].x = nextX
            }
            if enemies[index].x <= 160 {
                let leaked = enemies.remove(at: index)
                leaksByLane[leaked.lane] += 1
                lives = max(0, lives - leaked.kind.baseDamage)
                events.append(.leaked(leaked))
                if lives == 0 { phase = .lost; return }
            }
        }

        if spawnIndex == plan.enemies.count && enemies.isEmpty {
            if wave >= level.waves.count { phase = .won }
            else {
                sun += 50
                wave += 1
                spawnIndex = 0
                waveTicks = 0
                restRemaining = 6
                events.append(.wave(wave))
            }
        }
    }

    private mutating func hit(_ id: Int, damage: Int, events: inout [AdventureEvent], chargesEnergy: Bool = true) {
        guard let index = enemies.firstIndex(where: { $0.id == id }) else { return }
        enemies[index].health = max(0, enemies[index].health - damage)
        guard enemies[index].health == 0 else { return }
        let enemy = enemies.remove(at: index)
        defeated += 1
        sun += enemy.kind.bounty
        if chargesEnergy { energy = min(AdventureCatalog.ultimateEnergy, energy + 1) }
        events.append(.defeated(enemy))
    }
}
