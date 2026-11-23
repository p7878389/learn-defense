import Foundation

public enum AdventureEnemyKind: String, Codable, Sendable, CaseIterable {
    case grunt, runner, armored, boss

    public var name: String {
        switch self {
        case .grunt: "普通怪"
        case .runner: "疾跑怪"
        case .armored: "重甲怪"
        case .boss: "森林首领"
        }
    }

    public var artwork: EnemyKind {
        switch self {
        case .grunt: .blob
        case .runner: .dasher
        case .armored: .armored
        case .boss: .knight
        }
    }

    var health: Int {
        switch self {
        case .grunt: 20
        case .runner: 14
        case .armored: 42
        case .boss: 160
        }
    }

    var speed: Double {
        switch self {
        case .grunt: 24
        case .runner: 42
        case .armored: 19
        case .boss: 16
        }
    }

    var bounty: Int { self == .boss ? 75 : self == .armored ? 30 : 20 }
    var baseDamage: Int { self == .boss ? 3 : 1 }
}

public struct AdventureSpawn: Codable, Equatable, Sendable {
    public let kind: AdventureEnemyKind
    public let lane: Int
    public let delay: Double

    public init(kind: AdventureEnemyKind, lane: Int, delay: Double) {
        self.kind = kind
        self.lane = min(4, max(0, lane))
        self.delay = max(0, delay)
    }
}

public struct AdventureWave: Codable, Equatable, Sendable {
    public let enemies: [AdventureSpawn]

    public init(enemies: [AdventureSpawn]) {
        self.enemies = enemies.sorted { $0.delay < $1.delay }
    }

    public var preview: String {
        AdventureEnemyKind.allCases.compactMap { kind in
            let count = enemies.filter { $0.kind == kind }.count
            return count > 0 ? "\(kind.name) ×\(count)" : nil
        }.joined(separator: " · ")
    }
}

public struct AdventureLevel: Codable, Identifiable, Equatable, Sendable {
    public let id: Int
    public let title: String
    public let hint: String
    public let waves: [AdventureWave]

    public init(id: Int, title: String, hint: String, waves: [AdventureWave]) {
        self.id = id
        self.title = title
        self.hint = hint
        self.waves = waves
    }
}

public enum AdventureCatalog {
    public static let entryCost = 15
    public static let ultimateEnergy = 12
    public static let doomShroom = DefenderKind(
        id: AdventureDoom.id, name: "毁灭菇", sunCost: AdventureDoom.cost,
        look: DefenderLook(body: .seal, color: .plum))
    public static let defenders: [DefenderKind] = [.inkling, .twin, .frost, .stroke, .wallnut, .tallnut, doomShroom]
    public static let defaultDeck = ["inkling", "twin", "frost", "wallnut"]

    public static let levels: [AdventureLevel] = {
        let titles = ["林间初哨", "疾风小径", "铁甲来袭", "岔路防线", "暮色围攻", "森林守卫战"]
        let hints = ["先让每条路都有射手，再补充防御。", "疾跑怪速度快，寒冰射手能争取时间。",
                     "重甲怪耐打，试试双发射手集中火力。", "用坚果挡住前线，为后排争取输出时间。",
                     "留一笔阳光，应对下一波集中的进攻。", "首领会带小怪进攻，把大招留在最需要的时候。"]
        return (1...6).map { level in
            let waves = (0..<5).map { wave in
                let count = 6 + level + wave
                var spawns = (0..<count).map { offset -> AdventureSpawn in
                    let kind: AdventureEnemyKind
                    if level >= 3 && wave >= 1 && offset % 4 == 2 { kind = .armored }
                    else if (level >= 2 || wave >= 2) && offset % 3 == 1 { kind = .runner }
                    else { kind = .grunt }
                    return AdventureSpawn(kind: kind, lane: (offset * 2 + wave + level) % 5,
                                          delay: Double(offset) * max(2.8, 5.0 - Double(level) * 0.25))
                }
                if wave == 4 {
                    spawns.append(.init(kind: .boss, lane: (level + 2) % 5, delay: 15))
                }
                return AdventureWave(enemies: spawns)
            }
            return AdventureLevel(id: level, title: titles[level - 1], hint: hints[level - 1], waves: waves)
        }
    }()

    public static func level(_ id: Int) -> AdventureLevel? { levels.first { $0.id == id } }

    public static func defender(_ id: String) -> DefenderKind? { defenders.first { $0.id == id } }

    static func interval(_ id: String) -> Double { id == "twin" ? 1.65 : id == "stroke" ? 2.2 : 1.8 }
    static func damage(_ id: String) -> Int { id == "twin" ? 8 : id == "stroke" ? 10 : 4 }
}
