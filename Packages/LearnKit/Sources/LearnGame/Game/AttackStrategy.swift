import LearnCore
import SpriteKit

/// 攻击策略：只负责播放攻击动画，每颗子弹打中时回调 onImpact，最后一颗的 isFinal 为 true。
/// 伤害多少由 AttackStyle.totalDamage 决定，结算在 GameScene 里
@MainActor
protocol AttackStrategy {
    func perform(from origin: CGPoint, to target: CGPoint, projectile: ProjectileLook, in layer: SKNode,
                 onImpact: @escaping (_ isFinal: Bool) -> Void)
}

extension AttackStyle {
    @MainActor
    func makeStrategy() -> any AttackStrategy {
        switch self {
        case .single: ShotAttack(count: 1)
        case let .volley(count, _): ShotAttack(count: count)
        case .beam: BeamAttack()
        }
    }
}

/// 发射子弹，count > 1 时依次连发
struct ShotAttack: AttackStrategy {
    let count: Int
    var interval: TimeInterval = 0.12

    func perform(from origin: CGPoint, to target: CGPoint, projectile: ProjectileLook, in layer: SKNode,
                 onImpact: @escaping (Bool) -> Void) {
        let n = max(1, count)
        let duration = TimeInterval(max(0.15, min(0.45, (target.x - origin.x) / 2400)))
        for i in 0..<n {
            let bullet: SKNode = UnitSprites.projectile(projectile) ?? ProjectileArt.make(projectile)
            // 连发时上下错开一点，看得出是几颗
            let offset = (CGFloat(i) - CGFloat(n - 1) / 2) * 12
            bullet.position = CGPoint(x: origin.x, y: origin.y + offset)
            bullet.zPosition = 50
            bullet.alpha = 0
            layer.addChild(bullet)
            bullet.run(.sequence([
                .wait(forDuration: interval * TimeInterval(i)),
                .fadeIn(withDuration: 0.02),
                .move(to: target, duration: duration),
                .removeFromParent(),
            ])) {
                onImpact(i == n - 1)
            }
        }
    }
}

/// 一道笔锋光束，瞬间打中
struct BeamAttack: AttackStrategy {
    func perform(from origin: CGPoint, to target: CGPoint, projectile: ProjectileLook, in layer: SKNode,
                 onImpact: @escaping (Bool) -> Void) {
        let path = CGMutablePath()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: target.x - origin.x, y: target.y - origin.y))
        let beam = SKShapeNode(path: path)
        beam.strokeColor = projectile.color.fill
        beam.lineWidth = CGFloat(projectile.size)
        beam.lineCap = .round
        beam.glowWidth = 6
        beam.position = origin
        beam.zPosition = 50
        beam.alpha = 0
        layer.addChild(beam)

        let tip = ProjectileArt.make(projectile)
        tip.position = target
        tip.zPosition = 51
        tip.setScale(0.3)
        beam.run(.sequence([
            .fadeIn(withDuration: 0.08),
            .run {
                layer.addChild(tip)
                tip.run(.sequence([
                    .group([.scale(to: 1.8, duration: 0.25), .fadeOut(withDuration: 0.25)]),
                    .removeFromParent(),
                ]))
                onImpact(true)
            },
            .wait(forDuration: 0.08),
            .fadeOut(withDuration: 0.25),
            .removeFromParent(),
        ]))
    }
}
