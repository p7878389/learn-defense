import LearnCore
import SpriteKit

/// 字灵：每条路左侧的守卫，答对时发动攻击。外观和攻击方式由 DefenderKind 组合而来
final class DefenderNode: SKNode {
    let kind: DefenderKind
    let attack: any AttackStrategy
    let hitEffects: [any HitEffectStrategy]
    private let radius: CGFloat
    private let body: SKShapeNode
    private let sprite: SKSpriteNode?

    init(kind: DefenderKind, radius: CGFloat) {
        self.kind = kind
        self.radius = radius
        attack = kind.attack.makeStrategy()
        hitEffects = kind.effects.map { $0.makeStrategy() }
        body = DefenderArt.body(kind.look, radius: radius)
        sprite = UnitSprites.defender(kind, radius: radius)
        super.init()
        if let sprite {
            addChild(sprite)
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

    /// 子弹出发的位置
    var muzzle: CGPoint {
        CGPoint(x: position.x + radius * 0.9, y: position.y)
    }

    func shoot() {
        // 子弹发射时不缩放守卫，避免画面出现晃动
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
