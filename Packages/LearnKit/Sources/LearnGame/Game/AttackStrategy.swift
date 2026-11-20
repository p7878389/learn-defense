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
        // 留出从答题区看向战场的时间，短距离也不能一闪而过。
        let distance = hypot(target.x - origin.x, target.y - origin.y)
        let duration = TimeInterval(max(0.35, min(0.8, distance / 1200)))
        for i in 0..<n {
            let bullet: SKNode = UnitSprites.projectile(projectile) ?? ProjectileArt.make(projectile)
            // 连发时上下错开一点，看得出是几颗
            let offset = (CGFloat(i) - CGFloat(n - 1) / 2) * 12
            bullet.position = CGPoint(x: origin.x, y: origin.y + offset)
            bullet.zPosition = 50
            // 第一颗首帧就可见，后续连发仍等到各自发射时才显示。
            bullet.alpha = i == 0 ? 1 : 0
            layer.addChild(bullet)
            let flight = hypot(target.x - bullet.position.x, target.y - bullet.position.y) / duration
            let trail = IceCombatEffects.supports(projectile) ? IceCombatEffects.trail(on: bullet, speed: flight) : nil
            let bulletID = DiagLog.id(bullet)
            DiagLog.log("shot+ bullet=\(bulletID) \(i + 1)/\(n) shape=\(projectile.shape) ice=\(trail != nil)")
            bullet.run(.sequence([
                .wait(forDuration: interval * TimeInterval(i)),
                .run { [weak bullet, weak layer] in
                    bullet?.alpha = 1
                    if let trail, let bullet, let layer {
                        trail.particleBirthRate = 45
                        IceCombatEffects.launch(at: bullet.position, in: layer)
                    } else if projectile.shape == .orb, let bullet, let layer {
                        FXLibrary.launchOrb(on: bullet, towards: target, in: layer)
                    }
                },
                .move(to: target, duration: duration),
                // 冰晶尾迹挂在子弹上，这里一起移除
                .removeFromParent(),
            ])) { [weak layer] in
                DiagLog.log("shot- bullet=\(bulletID) layer=\(layer != nil)")
                if let layer {
                    if trail != nil {
                        IceCombatEffects.impact(at: target, in: layer)
                    } else {
                        Self.splat(projectile, at: target, in: layer)
                    }
                }
                onImpact(i == n - 1)
            }
        }
    }
}

extension ShotAttack {
    /// 圆弹使用资源组合；其他弹种保留原命中贴图，缺少资源时可回退。
    static func splat(_ projectile: ProjectileLook, at point: CGPoint, in layer: SKNode) {
        if projectile.shape == .orb,
           FXLibrary.playImpact(at: point, in: layer, color: projectile.color.fill) { return }
        guard let splat = UnitSprites.impact(projectile) else { return }
        // 稍微靠前一点，像打在僵尸身前
        splat.position = CGPoint(x: point.x - 8, y: point.y)
        splat.zPosition = 52
        splat.zRotation = CGFloat.random(in: -0.4...0.4)
        layer.addChild(splat)
        splat.run(.sequence([
            .wait(forDuration: 0.25),
            .fadeOut(withDuration: 0.12),
            .removeFromParent(),
        ]))
    }
}

/// 一道光束瞬间打中；有烟雾素材时（大喷菇）喷出一团孢子烟，否则画一道笔锋
struct BeamAttack: AttackStrategy {
    /// 打中的时间点，烟雾和笔锋一样在 0.08 秒时结算
    static let impactDelay: TimeInterval = 0.08

    func perform(from origin: CGPoint, to target: CGPoint, projectile: ProjectileLook, in layer: SKNode,
                 onImpact: @escaping (Bool) -> Void) {
        DiagLog.log("beam fume=\(UnitSprites.beam(projectile) != nil)")
        if let fume = UnitSprites.beam(projectile) {
            puff(fume.frames, frameTime: fume.frameTime, from: origin, to: target, projectile: projectile,
                 in: layer, onImpact: onImpact)
            return
        }
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

        beam.run(.sequence([
            .fadeIn(withDuration: Self.impactDelay),
            .run {
                Self.bloom(projectile, at: target, in: layer)
                onImpact(true)
            },
            .wait(forDuration: 0.08),
            .fadeOut(withDuration: 0.25),
            .removeFromParent(),
        ]))
    }

    /// 孢子烟：从出口一直铺到目标，播一遍序列帧后淡出
    private func puff(_ frames: [SKTexture], frameTime: TimeInterval, from origin: CGPoint, to target: CGPoint,
                      projectile: ProjectileLook, in layer: SKNode, onImpact: @escaping (Bool) -> Void) {
        let dx = target.x - origin.x, dy = target.y - origin.y
        let fume = SKSpriteNode(texture: frames[0])
        fume.name = "fume"
        fume.anchorPoint = CGPoint(x: 0, y: 0.5)
        // 横向拉到目标，纵向保持一团烟的高度
        fume.size = CGSize(width: max(60, hypot(dx, dy) + 24), height: 52)
        fume.zRotation = atan2(dy, dx)
        fume.position = origin
        fume.zPosition = 50
        layer.addChild(fume)
        fume.run(.sequence([
            .group([
                .animate(with: frames, timePerFrame: frameTime, resize: false, restore: false),
                .sequence([
                    .wait(forDuration: Self.impactDelay),
                    .run {
                        Self.bloom(projectile, at: target, in: layer)
                        onImpact(true)
                    },
                ]),
            ]),
            .fadeOut(withDuration: 0.15),
            .removeFromParent(),
        ]))
    }

    /// 命中处绽开一下
    private static func bloom(_ projectile: ProjectileLook, at point: CGPoint, in layer: SKNode) {
        let tip = ProjectileArt.make(projectile)
        tip.position = point
        tip.zPosition = 51
        tip.setScale(0.3)
        layer.addChild(tip)
        tip.run(.sequence([
            .group([.scale(to: 1.8, duration: 0.25), .fadeOut(withDuration: 0.25)]),
            .removeFromParent(),
        ]))
    }
}
