import LearnCore

/// 防御道具怎么拦僵尸（策略）。场景只调用这几个方法，不区分坚果墙、土豆雷还是铁栅门
@MainActor
protocol GuardStrategy: AnyObject {
    /// 僵尸走到面前会不会停下来啃。vaulting 为 true 时会跳的僵尸能跳过矮墙
    func blocks(_ enemy: EnemyNode, vaulting: Bool) -> Bool
    /// 被啃掉 seconds 秒的耐久，返回剩下的比例（0 表示碎了）
    func chew(_ seconds: Double) -> Double
    /// 孩子答对了一题，返回这次是不是刚好出土
    func correctAnswer() -> Bool
    /// 僵尸踩上来：返回要造成的伤害；不会引爆（没出土、已经炸过、不是地雷）时为 nil
    func trigger(isBoss: Bool, health: Int) -> Int?
    /// 已经碎了或炸过，要从场上移除
    var isSpent: Bool { get }
}

extension GuardStyle {
    @MainActor
    func makeStrategy() -> any GuardStrategy {
        switch self {
        case let .wall(seconds, tall): WallGuard(seconds: seconds, tall: tall)
        case let .mine(armAfter, bossDamage): MineGuard(armAfter: armAfter, bossDamage: bossDamage)
        }
    }
}

/// 坚果墙、高坚果、铁栅门：挡住僵尸，耐久按被啃的秒数算
final class WallGuard: GuardStrategy {
    let total: Double
    let tall: Bool
    private(set) var remaining: Double

    init(seconds: Double, tall: Bool) {
        total = max(0.1, seconds)
        remaining = total
        self.tall = tall
    }

    func blocks(_ enemy: EnemyNode, vaulting: Bool) -> Bool {
        guard !isSpent else { return false }
        return tall || !(vaulting && enemy.kind.canVault)
    }

    func chew(_ seconds: Double) -> Double {
        remaining = max(0, remaining - max(0, seconds))
        return remaining / total
    }

    func correctAnswer() -> Bool { false }

    func trigger(isBoss: Bool, health: Int) -> Int? { nil }

    var isSpent: Bool { remaining <= 0 }
}

/// 土豆雷：答对几题后出土，第一个踩上的僵尸倒下；首领只扣几滴血
final class MineGuard: GuardStrategy {
    private(set) var answersToArm: Int
    let bossDamage: Int
    private var exploded = false

    init(armAfter: Int, bossDamage: Int) {
        answersToArm = max(0, armAfter)
        self.bossDamage = max(1, bossDamage)
    }

    var isArmed: Bool { answersToArm == 0 }

    func blocks(_ enemy: EnemyNode, vaulting: Bool) -> Bool { false }

    func chew(_ seconds: Double) -> Double { 1 }

    func correctAnswer() -> Bool {
        guard answersToArm > 0 else { return false }
        answersToArm -= 1
        return answersToArm == 0
    }

    func trigger(isBoss: Bool, health: Int) -> Int? {
        guard isArmed, !exploded else { return nil }
        exploded = true
        return isBoss ? min(bossDamage, health) : health
    }

    var isSpent: Bool { exploded }
}
