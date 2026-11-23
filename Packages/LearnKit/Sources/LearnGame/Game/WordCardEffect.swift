import LearnCore
import SpriteKit

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
