import LearnCore
import SpriteKit

extension EnemyNode {
    // MARK: - 动画

    func appear() {
        alpha = 0
        run(.fadeIn(withDuration: 0.3))
        if isBoss { enterAsBoss() }
    }

    /// 首领出场：从大到小「砸」到地上弹一下，落地时脚下荡开两圈波纹
    private func enterAsBoss() {
        let rest = figure.xScale
        figure.setScale(rest * 1.7)
        let land = SKAction.sequence([
            .scale(to: rest * 0.9, duration: 0.28),
            .scale(to: rest * 1.08, duration: 0.1),
            .scale(to: rest, duration: 0.1),
        ])
        land.timingMode = .easeIn
        figure.run(.sequence([
            land,
            .run { [weak self] in
                guard let self, let parent = self.parent else { return }
                RippleEffect(color: Palette.hurt, rings: 2)
                    .play(at: CGPoint(x: self.position.x, y: self.position.y - 44 * self.yScale), in: parent)
            },
        ]), withKey: "bossEntrance")
    }

    /// 被打中一下：身体闪白，存活精灵叠加资源中的后仰回正。
    func flash() {
        if let sprite {
            if !doomed { FXLibrary.react(on: sprite) }
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

    /// 答错：往前冲一小段，张嘴咬一下。被挡住时不往前冲，原地狠咬一口
    func lunge() {
        if !isChewing { position.x -= 36 }
        run(.sequence([
            .moveBy(x: -6, y: 0, duration: 0.05),
            .moveBy(x: 12, y: 0, duration: 0.08),
            .moveBy(x: -6, y: 0, duration: 0.05),
        ]))
        guard let rig, let bite = biteClip, !isChewing else { return }
        rig.loop(bite)
        run(.sequence([
            .wait(forDuration: 0.6),
            .run { [weak self] in
                guard let self, let rig = self.rig,
                      let clip = self.isChewing ? self.biteClip : self.walkClip else { return }
                rig.loop(clip)
            },
        ]), withKey: "chomp")
    }

    /// 被打败：播放退场特效（默认用外观配置里的，孩子装备了退场外观时由场景传入）。
    /// 有序列帧时僵尸掉头倒下；burnt 为 true（大招）时整个烧焦
    func defeat(with effect: DefeatEffect? = nil, burnt: Bool = false) {
        DiagLog.log("enemy defeat id=\(enemyID) kind=\(kind.id) node=\(DiagLog.id(self)) burnt=\(burnt) rig=\(rig != nil)")
        removeAllActions()
        if let parent {
            if !burnt { FXLibrary.playDefeat(at: center, in: parent) }
            (effect ?? kind.look.defeat)
                .makeEffect(color: kind.look.color.fill, scale: CGFloat(kind.look.scale), count: 7 + kind.hp * 2)
                .play(at: center, in: parent)
        }
        let fallClip = burnt ? (rig?.clip(for: "boom") ?? rig?.clip(for: "die")) : rig?.clip(for: "die")
        guard let rig, let fallClip else {
            // 首领没有倒地动画：先抖两下再炸开，比小怪退场更有分量
            let vanish = SKAction.group([.scale(by: isBoss ? 1.7 : 1.4, duration: isBoss ? 0.35 : 0.2),
                                         .fadeOut(withDuration: isBoss ? 0.35 : 0.2)])
            let shudder = SKAction.sequence([
                .moveBy(x: 8, y: 0, duration: 0.05), .moveBy(x: -16, y: 0, duration: 0.08),
                .moveBy(x: 16, y: 0, duration: 0.08), .moveBy(x: -8, y: 0, duration: 0.05),
            ])
            run(.sequence((isBoss ? [shudder] : []) + [vanish, .removeFromParent()]))
            return
        }
        // 倒在地上：停掉呼吸和跳跃，取消冰冻色
        endSlow()
        squash.removeAllActions()
        squash.xScale = 1
        squash.yScale = 1
        figure.position.y = figureBaseY
        for node in [sign, pips, healthBar, childNode(withName: "bossAura"), childNode(withName: "bossAnger")]
            .compactMap({ $0 }) {
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
}
