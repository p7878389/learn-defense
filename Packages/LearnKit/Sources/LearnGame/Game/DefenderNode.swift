import LearnCore
import SpriteKit

/// 字灵：每条路左侧的守卫，答对时发动攻击。外观和攻击方式由 DefenderKind 组合而来
final class DefenderNode: SKNode {
    let kind: DefenderKind
    let attack: any AttackStrategy
    let hitEffects: [any HitEffectStrategy]
    private let radius: CGFloat
    private let body: SKShapeNode
    /// 序列帧外观；自定义字灵没有，用矢量绘制
    private let rig: SpriteRig?
    private var sprite: SKSpriteNode? { rig?.sprite }

    init(kind: DefenderKind, radius: CGFloat) {
        self.kind = kind
        self.radius = radius
        attack = kind.attack.makeStrategy()
        hitEffects = kind.effects.map { $0.makeStrategy() }
        body = DefenderArt.body(kind.look, radius: radius)
        rig = UnitSprites.defender(kind, radius: radius)
        super.init()
        if let rig {
            addChild(rig.sprite)
        } else {
            addChild(body)
            if let accessory = DefenderArt.accessory(kind.look, radius: radius) { addChild(accessory) }
            addChild(DefenderArt.eyes(radius: radius))
        }

        run(.repeatForever(.sequence([
            .moveBy(x: 0, y: 4, duration: 0.8),
            .moveBy(x: 0, y: -4, duration: 0.8),
        ])))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 子弹出发的位置：有序列帧时从嘴里出来（豌豆射手的嘴在右上方），否则从身体右侧
    var muzzle: CGPoint {
        guard let mouth = rig?.muzzle else {
            return CGPoint(x: position.x + radius * 0.9, y: position.y)
        }
        return CGPoint(x: position.x + mouth.x * xScale, y: position.y + mouth.y * yScale)
    }

    /// 发射：有发射动画的（大喷菇）播一遍再回到待机。不缩放守卫，避免画面出现晃动
    func shoot() {
        guard let rig, let attack = rig.clip(for: "attack") else { return }
        rig.playOnce(attack)
    }

    func hurt() {
        if let sprite {
            sprite.run(.sequence([
                .colorize(with: Palette.hurt, colorBlendFactor: 0.75, duration: 0),
                .wait(forDuration: 0.4),
                .colorize(withColorBlendFactor: 0, duration: 0.1),
            ]), withKey: "hurt")
            return
        }
        let color = kind.look.color.fill
        body.run(.sequence([
            .run { [body] in body.fillColor = Palette.hurt },
            .wait(forDuration: 0.4),
            .run { [body] in body.fillColor = color },
        ]))
    }
}
