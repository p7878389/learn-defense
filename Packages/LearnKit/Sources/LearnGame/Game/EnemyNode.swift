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
    /// 当前动作速度，跟着减速变化
    private var tempo: CGFloat = 1

    /// figure 负责跳起的高度，squash 负责身体一压一伸
    private let figure = SKNode()
    private let squash = SKNode()
    private let figureBaseY: CGFloat
    private let body: SKShapeNode
    /// 序列帧外观（走路、啃咬、倒下…）；自定义怪物没有，用矢量绘制
    private let rig: SpriteRig?
    private var sprite: SKSpriteNode? { rig?.sprite }
    /// 身体一半高（缩放前），掉防具碎片从头部附近飞出
    private let halfHeight: CGFloat
    /// 防具（铁桶、铁门）已经被打掉，改用普通僵尸的动画
    private var armorShed = false
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
        rig = UnitSprites.enemy(kind)
        // 不管多大，脚底都在同一高度，牌子挡住下半身
        let halfHeight = rig.map { $0.sprite.size.height / 2 } ?? extent.height
        self.halfHeight = halfHeight
        figureBaseY = -24 + halfHeight * s
        body = EnemyArt.body(look)
        super.init()

        if let rig {
            squash.addChild(rig.sprite)
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

        breathe(speed: 1)
    }

    /// 身体一压一伸
    private func breathe(speed: CGFloat) {
        guard speed > 0 else {
            squash.removeAction(forKey: "breathe")
            return
        }
        let half = 0.35 / Double(speed)
        squash.run(.repeatForever(.sequence([
            .scaleX(to: 1.06, y: 0.94, duration: half),
            .scaleX(to: 0.95, y: 1.05, duration: half),
        ])), withKey: "breathe")
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
        setTempo(slowFactor)
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
        setTempo(1)
    }

    /// 减速时动作跟着变慢，冻住时停住不动（和上游减速时放慢动画一样）
    private func setTempo(_ factor: Double) {
        let tempo = CGFloat(max(0, factor))
        guard tempo != self.tempo else { return }
        self.tempo = tempo
        rig?.tempo = tempo
        if !doomed { breathe(speed: tempo) }
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

    /// 被打中但没倒下：更新血量红点；只剩最后一下时，铁桶、铁门这类防具被打掉，换成普通僵尸继续走
    func showWound() {
        showHealth()
        guard !armorShed, health.max > 1, health.current == 1,
              let rig, let bare = rig.clip(for: "bare") else { return }
        armorShed = true
        // 正在咬人时先不换，咬完回到走路时自然换成普通僵尸
        if action(forKey: "chomp") == nil { rig.loop(bare) }
        if let parent {
            let head = CGPoint(x: center.x, y: center.y + halfHeight * CGFloat(kind.look.scale) * 0.5 * yScale)
            InkBurstEffect(color: SKColor(white: 0.6, alpha: 1), scale: 0.6, count: 6).play(at: head, in: parent)
        }
    }

    /// 啃咬动画（掉了防具后用普通僵尸的）
    private var biteClip: String? {
        rig?.clip(for: armorShed ? "bareAttack" : "attack")
    }

    /// 走路动画（掉了防具后用普通僵尸的）
    private var walkClip: String? {
        guard let rig else { return nil }
        return armorShed ? rig.clip(for: "bare") ?? rig.base : rig.base
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

    /// 答错：往前冲一小段，张嘴咬一下
    func lunge() {
        position.x -= 36
        run(.sequence([
            .moveBy(x: -6, y: 0, duration: 0.05),
            .moveBy(x: 12, y: 0, duration: 0.08),
            .moveBy(x: -6, y: 0, duration: 0.05),
        ]))
        guard let rig, let bite = biteClip else { return }
        rig.loop(bite)
        run(.sequence([
            .wait(forDuration: 0.6),
            .run { [weak self] in
                guard let self, let rig = self.rig, let walk = self.walkClip else { return }
                rig.loop(walk)
            },
        ]), withKey: "chomp")
    }

    /// 被打败：播放退场特效（默认用外观配置里的，孩子装备了退场外观时由场景传入）。
    /// 有序列帧时僵尸掉头倒下；burnt 为 true（大招）时整个烧焦
    func defeat(with effect: DefeatEffect? = nil, burnt: Bool = false) {
        DiagLog.log("enemy defeat id=\(enemyID) kind=\(kind.id) node=\(DiagLog.id(self)) burnt=\(burnt) rig=\(rig != nil)")
        removeAllActions()
        if let parent {
            (effect ?? kind.look.defeat)
                .makeEffect(color: kind.look.color.fill, scale: CGFloat(kind.look.scale), count: 7 + kind.hp * 2)
                .play(at: center, in: parent)
        }
        let fallClip = burnt ? (rig?.clip(for: "boom") ?? rig?.clip(for: "die")) : rig?.clip(for: "die")
        guard let rig, let fallClip else {
            run(.sequence([
                .group([.scale(by: 1.4, duration: 0.2), .fadeOut(withDuration: 0.2)]),
                .removeFromParent(),
            ]))
            return
        }
        // 倒在地上：停掉呼吸和跳跃，取消冰冻色
        endSlow()
        squash.removeAllActions()
        squash.xScale = 1
        squash.yScale = 1
        figure.position.y = figureBaseY
        for node in [sign, pips] {
            node.removeAllActions()
            node.run(.fadeOut(withDuration: 0.15))
        }
        let duration = rig.playOnce(fallClip, hold: true)
        if !burnt, let head = rig.clip(for: "head") {
            rig.spawn(head)
        }
        run(.sequence([
            .wait(forDuration: duration + 0.35),
            .fadeOut(withDuration: 0.3),
            .removeFromParent(),
        ]))
    }

    /// 走到书架：先啃两口，再钻进去消失
    func breakThrough() {
        DiagLog.log("enemy breakThrough id=\(enemyID) kind=\(kind.id) node=\(DiagLog.id(self))")
        removeAction(forKey: "chomp")
        var steps: [SKAction] = []
        if let rig, let bite = biteClip {
            rig.loop(bite)
            steps.append(.wait(forDuration: 0.6))
        }
        steps += [
            .group([.moveBy(x: -60, y: 0, duration: 0.3), .fadeOut(withDuration: 0.3)]),
            .removeFromParent(),
        ]
        run(.sequence(steps))
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
