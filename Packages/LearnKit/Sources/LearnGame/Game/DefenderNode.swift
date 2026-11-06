import LearnCore
import SpriteKit

/// 字灵：每条路左侧的守卫，答对时发动攻击。外观和攻击方式由 DefenderKind 组合而来。
/// 坚果墙、土豆雷、铁栅门这类防御道具不发射，由 guardian 决定怎么拦僵尸
final class DefenderNode: SKNode {
    let kind: DefenderKind
    /// 射手才有；防御道具为 nil
    let attack: (any AttackStrategy)?
    let hitEffects: [any HitEffectStrategy]
    /// 防御道具才有：怎么拦僵尸
    let guardian: (any GuardStrategy)?
    /// 在第几路，由场景种下时设置
    var lane = 0
    private let radius: CGFloat
    private let body: SKShapeNode
    private let skin: CharacterSkin?
    /// 序列帧外观；自定义字灵没有，用矢量绘制
    private let rig: SpriteRig?
    private var sprite: SKSpriteNode? { rig?.sprite }
    /// 已经显示到第几档裂纹（0 完好，1、2 越来越破）
    private var crackStage = 0

    init(kind: DefenderKind, radius: CGFloat, skin: CharacterSkin? = nil) {
        self.kind = kind
        self.radius = radius
        attack = kind.attack?.makeStrategy()
        hitEffects = kind.effects.map { $0.makeStrategy() }
        guardian = kind.guardStyle?.makeStrategy()
        body = DefenderArt.body(kind.look, radius: radius)
        let rig = UnitSprites.defender(kind, radius: radius, skin: skin)
        self.rig = rig
        // 换贴图的皮肤要真有这套素材才算穿上；只加特效的皮肤（萤火精灵）沿用原版贴图，有序列帧就保留
        self.skin = rig?.base.hasPrefix("skin-") == true || (rig != nil && skin?.isEffectOnly == true) ? skin : nil
        super.init()
        if let rig {
            addChild(rig.sprite)
        } else {
            addChild(body)
            if let accessory = DefenderArt.accessory(kind.look, radius: radius) { addChild(accessory) }
            if kind.look.body.hasFace { addChild(DefenderArt.eyes(radius: radius)) }
        }
        CharacterSkinEffects.decorate(self, skin: self.skin, radius: radius)

        // 还没出土的土豆雷埋在土里
        if let mine = guardian as? MineGuard, !mine.isArmed {
            if let rig, let buried = rig.clip(for: "init") {
                rig.loop(buried)
            } else {
                body.setScale(0.6)
                body.alpha = 0.6
            }
            return
        }
        run(.repeatForever(.sequence([
            .moveBy(x: 0, y: 4, duration: 0.8),
            .moveBy(x: 0, y: -4, duration: 0.8),
        ])), withKey: "bob")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 答对时能不能由它发射
    var canShoot: Bool { attack != nil }

    /// 连对数变了：萤火精灵的光团跟着变亮变多，其他外观不变
    func showStreak(_ streak: Int) {
        CharacterSkinEffects.showStreak(streak, on: self, skin: skin)
    }

    /// 子弹出发的位置：有序列帧时从嘴里出来（豌豆射手的嘴在右上方），否则从身体右侧
    var muzzle: CGPoint {
        guard let mouth = rig?.muzzle else {
            return CGPoint(x: position.x + radius * 0.9, y: position.y)
        }
        return CGPoint(x: position.x + mouth.x * xScale, y: position.y + mouth.y * yScale)
    }

    /// 发射：有发射动画的（大喷菇）播一遍再回到待机。不缩放守卫，避免画面出现晃动
    func shoot() {
        if let skin, let rig {
            CharacterSkinEffects.shoot(in: self, skin: skin, at: rig.muzzle ?? .zero)
            rig.sprite.run(.sequence([
                .rotate(toAngle: -0.10, duration: 0.06),
                .rotate(toAngle: 0, duration: 0.16),
            ]), withKey: "skinRecoil")
        }
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

    // MARK: - 防御道具

    /// 被啃以后按剩下的耐久换裂纹（坚果有上游的裂纹序列帧，没有的画几道裂缝）
    func showDurability(_ fraction: Double) {
        let stage = fraction <= 1.0 / 3 ? 2 : fraction <= 2.0 / 3 ? 1 : 0
        guard stage > crackStage else { return }
        crackStage = stage
        if let rig, let clip = rig.clip(for: "cracked\(stage)") {
            rig.loop(clip)
            return
        }
        let crack = CGMutablePath()
        let r = radius
        let offset = stage == 1 ? -0.2 : 0.25
        crack.move(to: CGPoint(x: r * offset, y: r * 0.8))
        crack.addLine(to: CGPoint(x: r * (offset + 0.15), y: r * 0.3))
        crack.addLine(to: CGPoint(x: r * (offset - 0.1), y: -r * 0.1))
        crack.addLine(to: CGPoint(x: r * (offset + 0.1), y: -r * 0.6))
        let line = SKShapeNode(path: crack)
        line.strokeColor = Palette.ink
        line.lineWidth = 2.5
        line.zPosition = 1
        line.name = "crack"
        addChild(line)
    }

    /// 被啃的时候抖一下
    func shake() {
        guard action(forKey: "shake") == nil else { return }
        run(.sequence([
            .moveBy(x: 3, y: 0, duration: 0.05),
            .moveBy(x: -6, y: 0, duration: 0.08),
            .moveBy(x: 3, y: 0, duration: 0.05),
        ]), withKey: "shake")
    }

    /// 土豆雷出土
    func arm() {
        if let rig {
            rig.loop(rig.base)
        } else {
            body.run(.group([.scale(to: 1, duration: 0.2), .fadeIn(withDuration: 0.2)]))
        }
        run(.sequence([.moveBy(x: 0, y: 10, duration: 0.12), .moveBy(x: 0, y: -10, duration: 0.12)]))
    }

    /// 被啃碎：碎片散开后消失
    func crumble() {
        removeAllActions()
        if let parent {
            InkBurstEffect(color: kind.look.color.dark, scale: 0.8, count: 8).play(at: position, in: parent)
        }
        run(.sequence([
            .group([.scaleY(to: 0.2, duration: 0.25), .fadeOut(withDuration: 0.25)]),
            .removeFromParent(),
        ]))
    }

    /// 土豆雷炸开：播爆炸帧（没有就闪一下），然后消失
    func explode() {
        removeAllActions()
        var wait: TimeInterval = 0.25
        if let rig, let boom = rig.clip(for: "explode") {
            rig.sprite.setScale(1.3)
            wait = max(wait, rig.playOnce(boom, hold: true))
        } else {
            body.run(.scale(to: 1.6, duration: 0.15))
        }
        run(.sequence([
            .wait(forDuration: wait + 0.35),
            .fadeOut(withDuration: 0.25),
            .removeFromParent(),
        ]))
    }
}
