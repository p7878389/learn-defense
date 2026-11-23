import LearnCore
import SpriteKit

// MARK: - 命中效果

/// 命中效果作用的战场：能按路查到怪物
@MainActor
protocol LaneField: AnyObject {
    func enemies(inLane lane: Int) -> [EnemyNode]
}

/// 命中效果策略：字灵最后一颗子弹打中后执行
@MainActor
protocol HitEffectStrategy {
    func apply(to enemy: EnemyNode, defeated: Bool, field: LaneField)
}

extension HitEffect {
    @MainActor
    func makeStrategy() -> any HitEffectStrategy {
        switch self {
        case let .knockback(distance): KnockbackHit(distance: CGFloat(distance))
        case let .slowLane(factor, seconds): SlowLaneHit(factor: factor, seconds: seconds)
        }
    }
}

struct KnockbackHit: HitEffectStrategy {
    let distance: CGFloat

    func apply(to enemy: EnemyNode, defeated: Bool, field: LaneField) {
        if !defeated { enemy.knockBack(distance) }
    }
}

struct SlowLaneHit: HitEffectStrategy {
    let factor: Double
    let seconds: Double

    func apply(to enemy: EnemyNode, defeated: Bool, field: LaneField) {
        for other in field.enemies(inLane: enemy.lane) where !other.doomed {
            other.slow(factor: factor, seconds: seconds)
        }
    }
}
