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
    public var waves: WavePlan

    /// hearts 为 nil 表示不会失败，怪物走到头只会退回去
    public var canLose: Bool { hearts != nil }

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
                    optionCount: [2, 3, 3][i], strategy: .easy, showHint: true, preschool: true),
                lineup: [.starling, .inkling, .frost],
                // 幼儿园的怪物都只要答对一次
                waves: WavePlan(mix: [
                    WavePlan.Entry(.blob, weight: 3),
                    WavePlan.Entry(.drowsy, weight: 2),
                    WavePlan.Entry(.hopper, weight: difficulty == .easy ? 0 : 1),
                ]))
        }
        let lineup: [DefenderKind] = [.frost, .twin, .inkling, .stroke, .starling]
        switch difficulty {
        case .easy:
            return GameTuning(
                lanes: 5, questions: questions, crossSeconds: 30, spawnInterval: 7, hearts: 5,
                startingSun: 250, ultimateEnergy: 5, ultimate: .inkStorm,
                generator: GeneratorSettings(optionCount: 3, strategy: .easy, showHint: true, preschool: false),
                lineup: lineup,
                waves: WavePlan(mix: [
                    WavePlan.Entry(.blob, weight: 4),
                    WavePlan.Entry(.hopper, weight: 2),
                    WavePlan.Entry(.drowsy, weight: 1),
                ]))
        case .normal:
            return GameTuning(
                lanes: 5, questions: questions, crossSeconds: 22, spawnInterval: 5.5, hearts: 3,
                startingSun: 300, ultimateEnergy: 5, ultimate: .inkStorm,
                generator: GeneratorSettings(optionCount: 4, strategy: .normal, showHint: false, preschool: false),
                lineup: lineup,
                waves: WavePlan(mix: [
                    WavePlan.Entry(.blob, weight: 4),
                    WavePlan.Entry(.hopper, weight: 2),
                    WavePlan.Entry(.dasher, weight: 2),
                    WavePlan.Entry(.armored, weight: 1),
                ], boss: .king))
        case .hard:
            return GameTuning(
                lanes: 5, questions: questions, crossSeconds: 16, spawnInterval: 4.2, hearts: 3,
                startingSun: 350, ultimateEnergy: 5, ultimate: .inkStorm,
                generator: GeneratorSettings(optionCount: 4, strategy: .hard, showHint: false, preschool: false),
                lineup: lineup,
                waves: WavePlan(mix: [
                    WavePlan.Entry(.blob, weight: 3),
                    WavePlan.Entry(.hopper, weight: 2),
                    WavePlan.Entry(.dasher, weight: 3),
                    WavePlan.Entry(.armored, weight: 2),
                ], boss: .king))
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
