import LearnCore
import SpriteKit

// MARK: - 视觉特效

/// 视觉特效策略：在 layer 的 point 处播放一次，播完自己清理。怪物退场、道具、大招都复用这些特效
@MainActor
protocol VisualEffect {
    func play(at point: CGPoint, in layer: SKNode)
}

extension DefeatEffect {
    @MainActor
    func makeEffect(color: SKColor, scale: CGFloat, count: Int) -> any VisualEffect {
        switch self {
        case .inkBurst: InkBurstEffect(color: color, scale: scale, count: count)
        case .ripple: RippleEffect(color: color, rings: 3)
        case .sparkle: SparkleEffect(count: count)
        case .confetti: ConfettiEffect(count: count + 6)
        case .firework: FireworkEffect(scale: scale)
        }
    }
}

/// 墨点四散
struct InkBurstEffect: VisualEffect {
    let color: SKColor
    var scale: CGFloat = 1
    var count = 7

    func play(at point: CGPoint, in layer: SKNode) {
        for i in 0..<count {
            let dot = Shapes.circle(CGFloat.random(in: 5...10), color, at: point)
            dot.zPosition = 60
            layer.addChild(dot)
            let angle = CGFloat(i) / CGFloat(count) * .pi * 2
            let distance = CGFloat.random(in: 50...90) * scale
            dot.run(.sequence([
                .group([
                    .moveBy(x: cos(angle) * distance, y: sin(angle) * distance, duration: 0.35),
                    .fadeOut(withDuration: 0.35),
                ]),
                .removeFromParent(),
            ]))
        }
    }
}

/// 一圈圈涟漪
struct RippleEffect: VisualEffect {
    let color: SKColor
    var rings = 3

    func play(at point: CGPoint, in layer: SKNode) {
        for i in 0..<rings {
            let ring = SKShapeNode(circleOfRadius: 20)
            ring.strokeColor = color
            ring.fillColor = .clear
            ring.lineWidth = 5
            ring.position = point
            ring.zPosition = 60
            ring.alpha = 0
            layer.addChild(ring)
            ring.run(.sequence([
                .wait(forDuration: 0.08 * Double(i)),
                .fadeIn(withDuration: 0.02),
                .group([.scale(to: 3, duration: 0.4), .fadeOut(withDuration: 0.4)]),
                .removeFromParent(),
            ]))
        }
    }
}

/// 星星飞散
struct SparkleEffect: VisualEffect {
    var count = 8

    func play(at point: CGPoint, in layer: SKNode) {
        for i in 0..<count {
            let star = Shapes.filled(Shapes.star(points: 5, outer: 11, inner: 5), Palette.bullet, stroke: Palette.target, width: 1.5)
            star.position = point
            star.zPosition = 61
            layer.addChild(star)
            let angle = CGFloat(i) / CGFloat(count) * .pi * 2
            star.run(.sequence([
                .group([
                    .moveBy(x: cos(angle) * 70, y: sin(angle) * 70 + 30, duration: 0.5),
                    .rotate(byAngle: .pi, duration: 0.5),
                    .sequence([.wait(forDuration: 0.25), .fadeOut(withDuration: 0.25)]),
                ]),
                .removeFromParent(),
            ]))
        }
    }
}

/// 彩纸礼花：五颜六色的小纸片往上撒，再飘落
struct ConfettiEffect: VisualEffect {
    var count = 14
    static let colors: [SKColor] = [Palette.hurt, Palette.bullet, Palette.jade, Palette.target,
                                    SKColor(red: 0.45, green: 0.6, blue: 0.95, alpha: 1),
                                    SKColor(red: 0.75, green: 0.5, blue: 0.95, alpha: 1)]

    func play(at point: CGPoint, in layer: SKNode) {
        for i in 0..<count {
            let piece = SKShapeNode(rectOf: CGSize(width: 7, height: 12), cornerRadius: 1.5)
            piece.fillColor = Self.colors[i % Self.colors.count]
            piece.strokeColor = .clear
            piece.position = point
            piece.zPosition = 61
            piece.zRotation = CGFloat.random(in: 0..<(.pi))
            layer.addChild(piece)
            let dx = CGFloat.random(in: -90...90)
            let up = CGFloat.random(in: 50...110)
            piece.run(.sequence([
                .group([
                    .moveBy(x: dx * 0.6, y: up, duration: 0.3),
                    .rotate(byAngle: .pi * 2, duration: 0.3),
                ]),
                .group([
                    .moveBy(x: dx * 0.4, y: -up - 40, duration: 0.6),
                    .rotate(byAngle: .pi * 3, duration: 0.6),
                    .sequence([.wait(forDuration: 0.3), .fadeOut(withDuration: 0.3)]),
                ]),
                .removeFromParent(),
            ]))
        }
    }
}

/// 烟花：一点亮光飞上去，砰地炸成一圈彩色光点
struct FireworkEffect: VisualEffect {
    var scale: CGFloat = 1
    var sparks = 14

    func play(at point: CGPoint, in layer: SKNode) {
        let color = ConfettiEffect.colors.randomElement() ?? Palette.bullet
        let rocket = Shapes.circle(5, Palette.bullet, at: point)
        rocket.zPosition = 61
        layer.addChild(rocket)
        let top = CGPoint(x: point.x, y: point.y + 70 * scale)
        rocket.run(.sequence([
            .move(to: top, duration: 0.2),
            .removeFromParent(),
        ]))
        for i in 0..<sparks {
            let spark = Shapes.circle(CGFloat.random(in: 3...5), i.isMultiple(of: 2) ? color : Palette.bullet, at: top)
            spark.zPosition = 62
            spark.alpha = 0
            spark.glowWidth = 2
            layer.addChild(spark)
            let angle = CGFloat(i) / CGFloat(sparks) * .pi * 2
            let distance = CGFloat.random(in: 60...85) * scale
            spark.run(.sequence([
                .wait(forDuration: 0.2),
                .fadeIn(withDuration: 0.01),
                .group([
                    .moveBy(x: cos(angle) * distance, y: sin(angle) * distance - 15, duration: 0.5),
                    .sequence([.wait(forDuration: 0.25), .fadeOut(withDuration: 0.25)]),
                ]),
                .removeFromParent(),
            ]))
        }
    }
}

/// 全屏闪一下
struct ScreenFlashEffect: VisualEffect {
    var color: SKColor = .white
    var alpha: CGFloat = 0.85
    var duration: TimeInterval = 0.5

    func play(at point: CGPoint, in layer: SKNode) {
        guard let scene = layer.scene else { return }
        let flash = SKSpriteNode(color: color, size: scene.size)
        flash.position = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)
        flash.zPosition = 100
        flash.alpha = alpha
        layer.addChild(flash)
        flash.run(.sequence([.fadeOut(withDuration: duration), .removeFromParent()]))
    }
}

/// 飘字，比如「+20」「❄️ 冰冻符」
struct FloatingTextEffect: VisualEffect {
    let text: String
    var color: SKColor = Palette.target
    var fontSize: CGFloat = 30

    func play(at point: CGPoint, in layer: SKNode) {
        let label = SKLabelNode(text: text)
        label.fontName = "PingFangSC-Semibold"
        label.fontSize = fontSize
        label.fontColor = color
        label.verticalAlignmentMode = .center
        label.position = point
        label.zPosition = 90
        label.setScale(0.5)
        layer.addChild(label)
        label.run(.sequence([
            .group([
                .scale(to: 1, duration: 0.15),
                .moveBy(x: 0, y: 60, duration: 0.9),
                .sequence([.wait(forDuration: 0.6), .fadeOut(withDuration: 0.3)]),
            ]),
            .removeFromParent(),
        ]))
    }
}

/// 雪花从上往下飘
struct SnowfallEffect: VisualEffect {
    var count = 24

    func play(at point: CGPoint, in layer: SKNode) {
        guard let size = layer.scene?.size else { return }
        ScreenFlashEffect(color: UnitColor.sky.fill, alpha: 0.35, duration: 0.8).play(at: point, in: layer)
        for _ in 0..<count {
            let flake = ProjectileArt.make(ProjectileLook(shape: .snowflake, color: .sky, size: Double.random(in: 7...13)))
            flake.position = CGPoint(x: CGFloat.random(in: 0...size.width), y: size.height + 20)
            flake.zPosition = 95
            layer.addChild(flake)
            flake.run(.sequence([
                .wait(forDuration: Double.random(in: 0...0.5)),
                .group([
                    .moveBy(x: CGFloat.random(in: -60...60), y: -size.height - 40, duration: Double.random(in: 1.2...1.8)),
                    .sequence([.wait(forDuration: 0.9), .fadeOut(withDuration: 0.4)]),
                ]),
                .removeFromParent(),
            ]))
        }
    }
}

/// 单词卡：3D 图片 + 字词 + 拼音。答对后在怪物上方弹出，停一会儿再飘走，同一时间只留一张
struct WordCardEffect: VisualEffect {
    static let nodeName = "wordCard"
    /// 画面顶部被 SwiftUI 卡牌栏、状态栏盖住的高度（场景坐标）。卡牌栏连边距约 88pt，
    /// 战场铺满宽度时 1pt 约等于 1 个场景单位，小一点的 iPad 上略大，这里留足 100
    static let topOverlayInset: CGFloat = 100
    let card: WordCard

    func play(at point: CGPoint, in layer: SKNode) {
        if let old = layer.childNode(withName: Self.nodeName) {
            old.name = nil
            old.removeAllActions()
            old.run(.sequence([.fadeOut(withDuration: 0.12), .removeFromParent()]))
        }

        let content = SKNode()
        var x: CGFloat = 0
        if let picture = card.picture {
            let image = Pictures.node(picture, size: 76)
            image.position = CGPoint(x: 38, y: 0)
            content.addChild(image)
            x = 90
        }
        let column = SKNode()
        var lines: [SKLabelNode] = []
        if let pinyin = card.pinyin {
            lines.append(label(pinyin, size: 22, color: Palette.target, font: "AvenirNext-DemiBold"))
        }
        let size: CGFloat = card.text.count <= 4 ? 44 : card.text.count <= 8 ? 32 : 26
        lines.append(label(card.text, size: size, color: Palette.ink, font: "PingFangSC-Semibold"))
        if let detail = card.detail {
            let line = label(detail, size: 18, color: Palette.signBorder, font: "PingFangSC-Regular")
            line.numberOfLines = 2
            line.preferredMaxLayoutWidth = 320
            lines.append(line)
        }
        let heights = lines.map { $0.frame.height }
        let total = heights.reduce(0, +) + CGFloat(lines.count - 1) * 6
        var y = total / 2
        var width: CGFloat = 0
        for (line, height) in zip(lines, heights) {
            line.position = CGPoint(x: 0, y: y - height / 2)
            y -= height + 6
            width = max(width, line.frame.width)
            column.addChild(line)
        }
        column.position.x = x + width / 2
        content.addChild(column)

        let contentWidth = x + width
        let cardSize = CGSize(width: contentWidth + 40, height: max(total, card.picture == nil ? 0 : 76) + 30)
        content.position.x = -contentWidth / 2
        let background = SKShapeNode(rectOf: cardSize, cornerRadius: 20)
        background.fillColor = .white
        background.strokeColor = Palette.jade
        background.lineWidth = 5

        let node = SKNode()
        node.name = Self.nodeName
        node.addChild(background)
        node.addChild(content)
        node.zPosition = 80

        // 放在怪物上方，不超出画面，也不钻到顶部的卡牌栏、状态栏底下
        let bounds = layer.scene?.size ?? CGSize(width: 1200, height: 520)
        let halfW = cardSize.width / 2 + 8, halfH = cardSize.height / 2 + 8
        node.position = CGPoint(
            x: min(max(point.x, halfW), bounds.width - halfW),
            y: min(max(point.y + 100, halfH), bounds.height - Self.topOverlayInset - halfH))
        // 直接淡入，不做由小到大的缩放，免得画面一下被放大
        node.alpha = 0
        layer.addChild(node)
        node.run(.sequence([
            .fadeIn(withDuration: 0.2),
            .wait(forDuration: 1.5),
            .group([.moveBy(x: 0, y: 40, duration: 0.35), .fadeOut(withDuration: 0.35)]),
            .removeFromParent(),
        ]))
    }

    private func label(_ text: String, size: CGFloat, color: SKColor, font: String) -> SKLabelNode {
        let label = SKLabelNode(text: text)
        label.fontName = font
        label.fontSize = size
        label.fontColor = color
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        return label
    }
}

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
