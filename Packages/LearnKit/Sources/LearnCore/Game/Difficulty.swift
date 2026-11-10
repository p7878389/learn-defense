import Foundation

public enum Difficulty: String, Codable, CaseIterable, Identifiable, Sendable {
    case easy, normal, hard

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .easy: "入门"
        case .normal: "标准"
        case .hard: "挑战"
        }
    }
}

/// 一局游戏的参数，由年级和难度决定
extension GameTuning {
    /// 这个年级在任一难度下会上场的射手。射手没有单独的解锁，按年级决定能不能出场
    public static func defenders(for grade: Grade) -> [DefenderKind] {
        let ids = Set(Difficulty.allCases.flatMap { make(grade: grade, difficulty: $0).lineup.map(\.id) })
        return UnitCatalog.defenders.filter { ids.contains($0.id) }
    }
}

public struct GameTuning: Sendable {
    public var lanes: Int
    /// 一局的题量：所有怪物血量之和，按年级段和难度从节奏配置读取（不含大招题）
    public var questions: Int
    /// 怪物从右走到左需要的秒数
    public var crossSeconds: Double
    public var spawnInterval: Double
    public var hearts: Int?
    /// 开局拥有的阳光，保证孩子可以先种下基础防线
    public var startingSun: Int
    /// 大招需要的能量（每次一次答对 +1）
    public var ultimateEnergy: Int
    /// 能量攒满后能放的大招
    public var ultimate: ItemKind
    public var generator: GeneratorSettings
    /// 每条路上的字灵，下标就是路号
    public var lineup: [DefenderKind]
    /// 能种的防御道具（坚果墙、土豆雷…），耐久和出土题数按难度调好
    public var guards: [DefenderKind]
    /// 战斗中花阳光放在当前僵尸面前的路障；nil 表示这一档不提供
    public var barricade: DefenderKind?
    /// 会跳的僵尸能不能跳过矮墙（幼儿园关掉，免得孩子看不懂为什么没挡住）
    public var wallsCanBeVaulted: Bool
    public var waves: WavePlan

    /// hearts 为 nil 表示不会失败，怪物走到头只会退回去
    public var canLose: Bool { hearts != nil }

    /// 卡牌栏里能拖到草坪上的全部卡牌：射手在前，防御道具在后
    public var plantable: [DefenderKind] { lineup + guards }

    /// 一档难度里防御道具的数值
    struct GuardNumbers {
        var wall: Double
        var tallWall: Double
        var mineArmAfter: Int
        var gate: Double

        /// tall 为 false 时不提供高坚果
        func guards(tall: Bool) -> [DefenderKind] {
            let mine = GuardStyle.mine(armAfter: mineArmAfter, bossDamage: 1)
            return [DefenderKind.wallnut.guarding(.wall(seconds: wall, tall: false))]
                + (tall ? [DefenderKind.tallnut.guarding(.wall(seconds: tallWall, tall: true))] : [])
                + [DefenderKind.potato.guarding(mine)]
        }

        var barricade: DefenderKind {
            DefenderKind.ironGate.guarding(.wall(seconds: gate, tall: true))
        }
    }

    public static func make(grade: Grade, difficulty: Difficulty, pacing: PacingConfig = GrowthCatalog.bundled.pacing) -> GameTuning {
        let questions = pacing.questionBudget(grade: grade, difficulty: difficulty)
        if grade.isPreschool {
            let i = Difficulty.allCases.firstIndex(of: difficulty)!
            return GameTuning(
                lanes: 3,
                questions: questions,
                crossSeconds: [45, 38, 30][i],
                spawnInterval: [9, 8, 7][i],
                hearts: nil,
                startingSun: [150, 200, 250][i],
                ultimateEnergy: 4,
                ultimate: .rainbow,
                generator: GeneratorSettings(
                    optionCount: [2, 3, 3][i], strategy: .easy, showHint: true, preschool: true,
                    answerMix: .make(for: difficulty)),
                lineup: [.starling, .inkling, .frost],
                // 幼儿园不会失败，只给坚果墙和土豆雷，也不让僵尸跳墙
                guards: GuardNumbers(wall: 20, tallWall: 40, mineArmAfter: 1, gate: 12).guards(tall: false),
                barricade: nil,
                wallsCanBeVaulted: false,
                // 幼儿园的怪物都只要答对一次
                waves: WavePlan(mix: [
                    WavePlan.Entry(.blob, weight: 3),
                    WavePlan.Entry(.drowsy, weight: 2),
                    WavePlan.Entry(.hopper, weight: difficulty == .easy ? 0 : 1),
                    WavePlan.Entry(.goblin, weight: difficulty == .easy ? 0 : 1),
                ]))
        }
        let lineup: [DefenderKind] = [.frost, .twin, .inkling, .stroke, .starling]
        let numbers: GuardNumbers = switch difficulty {
        case .easy, .normal: GuardNumbers(wall: 15, tallWall: 30, mineArmAfter: 2, gate: 10)
        case .hard: GuardNumbers(wall: 12, tallWall: 25, mineArmAfter: 3, gate: 8)
        }
        switch difficulty {
        case .easy:
            return GameTuning(
                lanes: 5, questions: questions, crossSeconds: 30, spawnInterval: 7, hearts: 5,
                startingSun: 250, ultimateEnergy: 5, ultimate: .inkStorm,
                generator: GeneratorSettings(optionCount: 3, strategy: .easy, showHint: true, preschool: false,
                                              answerMix: .make(for: difficulty)),
                lineup: lineup,
                guards: numbers.guards(tall: true),
                barricade: numbers.barricade,
                wallsCanBeVaulted: true,
                waves: WavePlan(mix: [
                    WavePlan.Entry(.blob, weight: 4),
                    WavePlan.Entry(.hopper, weight: 2),
                    WavePlan.Entry(.drowsy, weight: 1),
                    WavePlan.Entry(.goblin, weight: 1),
                ]))
        case .normal:
            return GameTuning(
                lanes: 5, questions: questions, crossSeconds: 22, spawnInterval: 5.5, hearts: 3,
                startingSun: 300, ultimateEnergy: 5, ultimate: .inkStorm,
                generator: GeneratorSettings(optionCount: 4, strategy: .normal, showHint: false, preschool: false,
                                              answerMix: .make(for: difficulty)),
                lineup: lineup,
                guards: numbers.guards(tall: true),
                barricade: numbers.barricade,
                wallsCanBeVaulted: true,
                waves: WavePlan(mix: [
                    WavePlan.Entry(.blob, weight: 4),
                    WavePlan.Entry(.hopper, weight: 2),
                    WavePlan.Entry(.dasher, weight: 2),
                    WavePlan.Entry(.armored, weight: 1),
                    WavePlan.Entry(.goblin, weight: 2),
                    WavePlan.Entry(.acolyte, weight: 1),
                ], boss: .king, bosses: EnemyKind.forestBosses))
        case .hard:
            return GameTuning(
                lanes: 5, questions: questions, crossSeconds: 16, spawnInterval: 4.2, hearts: 3,
                startingSun: 350, ultimateEnergy: 5, ultimate: .inkStorm,
                generator: GeneratorSettings(optionCount: 4, strategy: .hard, showHint: false, preschool: false,
                                              answerMix: .make(for: difficulty)),
                lineup: lineup,
                guards: numbers.guards(tall: true),
                barricade: numbers.barricade,
                wallsCanBeVaulted: true,
                waves: WavePlan(mix: [
                    WavePlan.Entry(.blob, weight: 3),
                    WavePlan.Entry(.hopper, weight: 2),
                    WavePlan.Entry(.dasher, weight: 3),
                    WavePlan.Entry(.armored, weight: 2),
                    WavePlan.Entry(.goblin, weight: 2),
                    WavePlan.Entry(.acolyte, weight: 2),
                ], boss: .king, bosses: EnemyKind.forestBosses))
        }
    }
}

/// 根据答题表现微调速度：连对加快，答错放慢
public struct AdaptiveTuner: Sendable {
    public private(set) var speedFactor = 1.0
    private var streak = 0

    public init() {}

    public mutating func record(correct: Bool) {
        if correct {
            streak += 1
            if streak >= 3 { speedFactor = min(1.25, speedFactor + 0.05) }
        } else {
            streak = 0
            speedFactor = max(0.7, speedFactor - 0.1)
        }
    }
}
