import LearnCore
import SpriteKit

/// 每个角色固定六片装饰，共享角色生命周期；不使用持续创建节点的粒子定时器。
@MainActor
enum CharacterSkinEffects {
    static let nodeName = "characterSkinEffects"

    static func decorate(_ parent: SKNode, skin: CharacterSkin?, radius: CGFloat) {
        guard let skin else { return }
        let root = SKNode()
        root.name = nodeName
        root.zPosition = -0.1
        parent.addChild(root)
        let blocky = isBlocky(skin)
        let palette: [UnitColor] = switch skin {
        case .bamboo: [.moss, .jade, .gold]
        case .voxel: [.moss, .gold, .sky]
        case .party, .pixel, .egg: [.coral, .sky, .gold]
        }
        for i in 0..<6 {
            let color = palette[i % 3].fill
            let piece: SKShapeNode
            if blocky {
                piece = SKShapeNode(rectOf: CGSize(width: 3.5, height: 3.5))
            } else if skin == .bamboo {
                // 竹叶：细长、斜着飘
                piece = SKShapeNode(ellipseOf: CGSize(width: 6, height: 2.4))
                piece.zRotation = CGFloat(i) * 0.7 + 0.4
            } else {
                piece = SKShapeNode(ellipseOf: CGSize(width: 2.5, height: 5))
            }
            piece.fillColor = color
            piece.strokeColor = .clear
            let angle = CGFloat(i) * .pi / 3
            piece.position = CGPoint(x: cos(angle) * radius * 1.15, y: sin(angle) * radius * 0.8)
            piece.alpha = 0.65
            root.addChild(piece)
            let rise = SKAction.moveBy(x: blocky ? 0 : 4, y: 7, duration: 0.9 + Double(i) * 0.08)
            rise.timingMode = .easeInEaseOut
            piece.run(.repeatForever(.sequence([rise, rise.reversed()])))
            piece.run(.repeatForever(.sequence([.fadeAlpha(to: 0.25, duration: 0.7), .fadeAlpha(to: 0.8, duration: 0.7)])))
        }
    }

    /// 方块风格的装饰与枪口闪光用方块，其余用圆片
    private static func isBlocky(_ skin: CharacterSkin) -> Bool {
        skin == .pixel || skin == .voxel
    }

    static func shoot(in node: SKNode, skin: CharacterSkin, at point: CGPoint) {
        let flash: SKShapeNode
        if isBlocky(skin) {
            flash = SKShapeNode(rectOf: CGSize(width: 9, height: 9))
        } else {
            flash = SKShapeNode(circleOfRadius: 5)
        }
        flash.name = "skinMuzzleFlash"
        flash.position = point
        // 角色装扮不改变属性语义：普通豌豆的发射反馈始终是绿色。
        flash.fillColor = UnitColor.jade.fill
        flash.strokeColor = .white
        flash.lineWidth = 1.5
        node.addChild(flash)
        flash.run(.sequence([
            .group([.scale(to: 1.8, duration: 0.16), .fadeOut(withDuration: 0.16), .moveBy(x: 8, y: 0, duration: 0.16)]),
            .removeFromParent(),
        ]))
    }
}
