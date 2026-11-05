import LearnCore
import SpriteKit

/// 道具能操作的战场。由 GameSession 实现，道具只通过这些接口改变战局
@MainActor
protocol Battlefield: AnyObject {
    func clearField()
    func freezeField(seconds: Double)
    func heal(hearts: Int)
    func addScore(_ points: Int)
}

/// 道具效果用命令模式：每个效果是一条命令，道具 = 一组命令，按顺序执行
@MainActor
protocol ItemCommand {
    func execute(on field: Battlefield)
}

extension ItemEffect {
    @MainActor
    func makeCommand() -> any ItemCommand {
        switch self {
        case .clearField: ClearFieldCommand()
        case let .freezeField(seconds): FreezeFieldCommand(seconds: seconds)
        case let .heal(hearts): HealCommand(hearts: hearts)
        case let .bonusScore(points): BonusScoreCommand(points: points)
        }
    }
}

extension ItemKind {
    @MainActor
    func use(on field: Battlefield) {
        for effect in effects {
            effect.makeCommand().execute(on: field)
        }
    }
}

struct ClearFieldCommand: ItemCommand {
    func execute(on field: Battlefield) { field.clearField() }
}

struct FreezeFieldCommand: ItemCommand {
    let seconds: Double
    func execute(on field: Battlefield) { field.freezeField(seconds: seconds) }
}

struct HealCommand: ItemCommand {
    let hearts: Int
    func execute(on field: Battlefield) { field.heal(hearts: hearts) }
}

struct BonusScoreCommand: ItemCommand {
    let points: Int
    func execute(on field: Battlefield) { field.addScore(points) }
}
