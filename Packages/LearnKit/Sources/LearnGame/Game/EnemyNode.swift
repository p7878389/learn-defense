import LearnCore
import SpriteKit

private let labelFont = "PingFangSC-Semibold"

/// 怪物：举着写有题目的牌子，从右往左走。外观、走法、血量都由 EnemyKind 组合而来
final class EnemyNode: SKNode {
    let enemyID: Int
    let lane: Int
    let kind: EnemyKind
    var health: Health
    /// 已被打败（子弹在路上），不再移动也不能再被瞄准
    var doomed = false

    private var movement: any MovementStrategy
    /// 有子弹在路上时停住，保证打得中
    private var holds = 0
    private var slowFactor = 1.0
    private var slowRemaining = 0.0

    /// figure 负责跳起的高度，squash 负责身体一压一伸
    private let figure = SKNode()
    private let squash = SKNode()
    private let figureBaseY: CGFloat
    private let body: SKShapeNode
    private let sprite: SKSpriteNode?
    private var chill: SKShapeNode?
    private let sign = SKShapeNode()
    private let label = SKLabelNode()
    /// 牌子上是单个 emoji（如听音题的 🔊）时，换成 3D 图片
    private var signPicture: SKNode?
    private let pips = SKNode()

    init(id: Int, kind: EnemyKind, sign text: String, lane: Int, scale: CGFloat) {
        enemyID = id
        self.lane = lane
        self.kind = kind
        health = Health(max: kind.hp)
        movement = kind.movement.makeStrategy()

        let look = kind.look
        let s = CGFloat(look.scale)
        let extent = EnemyArt.extent(of: look.body)
        sprite = UnitSprites.enemy(kind)
        // 不管多大，脚底都在同一高度，牌子挡住下半身
        let halfHeight = sprite.map { $0.size.height / 2 } ?? extent.height
        figureBaseY = -24 + halfHeight * s
        body = EnemyArt.body(look)
        super.init()

        if let sprite {
            squash.addChild(sprite)
        } else {
            squash.addChild(body)
            squash.addChild(EnemyArt.eyes(look))
            if let accessory = EnemyArt.accessory(look) { squash.addChild(accessory) }
        }
        figure.addChild(squash)
        figure.setScale(s)
        figure.position.y = figureBaseY
        addChild(figure)

        label.fontName = labelFont
        label.fontSize = 30
        label.fontColor = Palette.ink
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        sign.fillColor = .white
        sign.strokeColor = Palette.signBorder
        sign.lineWidth = 3
        sign.position = CGPoint(x: 0, y: -20)
        sign.zPosition = 2
        sign.addChild(label)
        addChild(sign)
        setSign(text)

        if kind.hp > 1 {
            pips.position = CGPoint(x: 0, y: figureBaseY + halfHeight * s + 16)
            addChild(pips)
            showHealth()
        }
        setScale(scale)

        squash.run(.repeatForever(.sequence([
            .scaleX(to: 1.06, y: 0.94, duration: 0.35),
            .scaleX(to: 0.95, y: 1.05, duration: 0.35),
        ])))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - 移动

    var isHeld: Bool { holds > 0 }

    func hold() { holds += 1 }

    func release() { holds = max(0, holds - 1) }

    /// 按走法前进一帧，返回向书架方向走了多远
    func advance(dt: Double, speed: Double) -> CGFloat {
        if slowRemaining > 0 {
            slowRemaining -= dt
            if slowRemaining <= 0 { endSlow() }
        }
        guard !doomed, !isHeld else { return 0 }
        let motion = movement.step(dt: dt, speed: speed * slowFactor)
        figure.position.y = figureBaseY + CGFloat(motion.lift)
        return CGFloat(motion.dx)
    }

    func slow(factor: Double, seconds: Double) {
        slowFactor = min(slowFactor, factor)
        slowRemaining = max(slowRemaining, seconds)
        if let sprite {
            sprite.color = UnitColor.sky.fill
            sprite.colorBlendFactor = 0.45
            return
        }
        guard chill == nil, let path = body.path else { return }
        let overlay = SKShapeNode(path: path)
        overlay.fillColor = UnitColor.sky.fill.withAlphaComponent(0.5)
        overlay.strokeColor = .white
        overlay.lineWidth = 2
        squash.addChild(overlay)
        chill = overlay
    }

    private func endSlow() {
        slowFactor = 1
        slowRemaining = 0
        chill?.removeFromParent()
        chill = nil
        sprite?.colorBlendFactor = 0
    }

    // MARK: - 牌子和血量

    func setSign(_ text: String) {
        signPicture?.removeFromParent()
        signPicture = nil
        if Pictures.texture(text) != nil {
            let picture = Pictures.node(text, size: 38)
            sign.addChild(picture)
            signPicture = picture
            label.text = ""
        } else {
            label.text = text
        }
        let width = max(64, label.frame.width + 26)
        sign.path = CGPath(roundedRect: CGRect(x: -width / 2, y: -22, width: width, height: 44),
                           cornerWidth: 10, cornerHeight: 10, transform: nil)
    }

    func setTargeted(_ on: Bool) {
        sign.strokeColor = on ? Palette.target : Palette.signBorder
        sign.lineWidth = on ? 6 : 3
        sign.removeAction(forKey: "pulse")
        sign.setScale(1)
        if on {
            sign.run(.repeatForever(.sequence([
                .scale(to: 1.12, duration: 0.4),
                .scale(to: 1.0, duration: 0.4),
            ])), withKey: "pulse")
        }
    }

    func showHealth() {
        pips.removeAllChildren()
        let n = health.max
        for i in 0..<n {
            let pip = Shapes.circle(7, i < health.current ? Palette.hurt : SKColor(white: 0.8, alpha: 1),
                                    at: CGPoint(x: (CGFloat(i) - CGFloat(n - 1) / 2) * 18, y: 0))
            pip.strokeColor = .white
            pip.lineWidth = 2
            pips.addChild(pip)
        }
    }

    // MARK: - 动画

    func appear() {
        alpha = 0
        run(.fadeIn(withDuration: 0.3))
    }

    /// 被打中一下：身体闪白
    func flash() {
        if let sprite {
            sprite.run(.sequence([
                .colorize(with: .white, colorBlendFactor: 0.85, duration: 0),
                .wait(forDuration: 0.08),
                .run { [weak self, weak sprite] in
                    sprite?.color = UnitColor.sky.fill
                    sprite?.colorBlendFactor = (self?.slowRemaining ?? 0) > 0 ? 0.45 : 0
                },
            ]), withKey: "flash")
            return
        }
        let color = kind.look.color.fill
        body.run(.sequence([
            .run { [body] in body.fillColor = .white },
            .wait(forDuration: 0.08),
            .run { [body] in body.fillColor = color },
        ]))
    }

    /// 被打中但没倒下：往后退一段
    func knockBack(_ distance: CGFloat) {
        run(.moveBy(x: distance, y: 0, duration: 0.18))
    }

    /// 答错：往前冲一小段
    func lunge() {
        position.x -= 36
        run(.sequence([
            .moveBy(x: -6, y: 0, duration: 0.05),
            .moveBy(x: 12, y: 0, duration: 0.08),
            .moveBy(x: -6, y: 0, duration: 0.05),
        ]))
    }

    /// 被打败：播放退场特效（默认用外观配置里的，孩子装备了退场外观时由场景传入）
    func defeat(with effect: DefeatEffect? = nil) {
        removeAllActions()
        if let parent {
            (effect ?? kind.look.defeat)
                .makeEffect(color: kind.look.color.fill, scale: CGFloat(kind.look.scale), count: 7 + kind.hp * 2)
                .play(at: center, in: parent)
        }
        run(.sequence([
            .group([.scale(by: 1.4, duration: 0.2), .fadeOut(withDuration: 0.2)]),
            .removeFromParent(),
        ]))
    }

    /// 走到书架：钻进去消失
    func breakThrough() {
        run(.sequence([
            .group([.moveBy(x: -60, y: 0, duration: 0.3), .fadeOut(withDuration: 0.3)]),
            .removeFromParent(),
        ]))
    }

    /// 幼儿园模式：退回起点重新走
    func bounceBack(toX x: CGFloat) {
        position.x = x
        alpha = 0
        run(.fadeIn(withDuration: 0.4))
    }

    /// 身体中心在父节点里的位置，特效从这里播放
    var center: CGPoint {
        CGPoint(x: position.x, y: position.y + figure.position.y * yScale)
    }
}
