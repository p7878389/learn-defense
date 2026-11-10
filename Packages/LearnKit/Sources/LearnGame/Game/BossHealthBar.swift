import SpriteKit

/// 首领头顶的血条：名字 + 一条分段的血量。每一段是一道题，答对一题掉一段。
/// 掉血时彩色部分马上缩短，后面的白色残影慢半拍跟上，孩子看得清这一下打掉了多少
final class BossHealthBar: SKNode {
    static let size = CGSize(width: 104, height: 16)
    private static let inset: CGFloat = 3

    private let segments: Int
    private let fill: SKSpriteNode
    private let ghost: SKSpriteNode
    /// 当前显示的血量比例（0~1）
    private(set) var ratio: CGFloat = 1

    init(name: String, segments: Int) {
        self.segments = max(1, segments)
        let inner = CGSize(width: Self.size.width - Self.inset * 2, height: Self.size.height - Self.inset * 2)
        fill = SKSpriteNode(color: Self.color(for: 1), size: inner)
        ghost = SKSpriteNode(color: .white, size: inner)
        super.init()

        let frame = CGRect(x: -Self.size.width / 2, y: -Self.size.height / 2,
                           width: Self.size.width, height: Self.size.height)
        let back = SKShapeNode(rect: frame, cornerRadius: Self.size.height / 2)
        back.fillColor = Palette.ink.withAlphaComponent(0.85)
        back.strokeColor = .white
        back.lineWidth = 2.5
        addChild(back)

        // 血量从右往左掉：两条都以左端为锚点，改 xScale 就是改长度
        for (bar, z) in [(ghost, CGFloat(1)), (fill, 2)] {
            bar.anchorPoint = CGPoint(x: 0, y: 0.5)
            bar.position = CGPoint(x: -inner.width / 2, y: 0)
            bar.zPosition = z
        }
        // 圆角裁切，血条两头和外框一样是圆的
        let crop = SKCropNode()
        let mask = SKShapeNode(rect: CGRect(x: -inner.width / 2, y: -inner.height / 2,
                                            width: inner.width, height: inner.height),
                               cornerRadius: inner.height / 2)
        mask.fillColor = .white
        mask.strokeColor = .clear
        crop.maskNode = mask
        crop.addChild(ghost)
        crop.addChild(fill)
        crop.zPosition = 1
        addChild(crop)

        // 分段线：一段一道题
        for i in 1..<self.segments {
            let tick = SKSpriteNode(color: Palette.ink.withAlphaComponent(0.85),
                                    size: CGSize(width: 2.5, height: inner.height))
            tick.position = CGPoint(x: -inner.width / 2 + inner.width * CGFloat(i) / CGFloat(self.segments), y: 0)
            tick.zPosition = 3
            addChild(tick)
        }

        // 名字：白字压一层深色描影，草地、石板路上都看得清
        for (color, offset, nodeName) in [(Palette.ink, CGPoint(x: 1.5, y: -1.5), "bossNameShadow"),
                                          (SKColor.white, CGPoint.zero, "bossName")] {
            let label = SKLabelNode(text: name)
            label.name = nodeName
            label.fontName = "PingFangSC-Semibold"
            label.fontSize = 16
            label.fontColor = color
            label.verticalAlignmentMode = .bottom
            label.horizontalAlignmentMode = .center
            label.position = CGPoint(x: offset.x, y: Self.size.height / 2 + 4 + offset.y)
            label.zPosition = nodeName == "bossName" ? 5 : 4
            addChild(label)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 血多是绿的，过半变黄，快没了变红
    static func color(for ratio: CGFloat) -> SKColor {
        if ratio > 0.67 { return Palette.jade }
        if ratio > 0.34 { return Palette.bullet }
        return Palette.hurt
    }

    /// 更新血量。animated 为 false 时直接到位（刚出场、测试）
    func set(current: Int, max: Int, animated: Bool = true) {
        let target = CGFloat(Swift.max(0, current)) / CGFloat(Swift.max(1, max))
        let dropped = target < ratio
        ratio = target
        fill.color = Self.color(for: target)
        fill.removeAllActions()
        ghost.removeAllActions()
        guard animated, dropped else {
            fill.xScale = target
            ghost.xScale = target
            return
        }
        fill.run(.scaleX(to: target, duration: 0.12))
        ghost.run(.sequence([.wait(forDuration: 0.3), .scaleX(to: target, duration: 0.35)]))
        // 挨打时整条血条跳一下
        removeAction(forKey: "bump")
        setScale(1)
        run(.sequence([.scale(to: 1.15, duration: 0.07), .scale(to: 1, duration: 0.12)]), withKey: "bump")
    }
}
