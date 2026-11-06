import LearnCore
import SpriteKit

/// 每个角色固定几片装饰，共享角色生命周期；不使用持续创建节点的粒子定时器。
@MainActor
enum CharacterSkinEffects {
    static let nodeName = "characterSkinEffects"
    static let fireflyOrbName = "fireflyOrb"

    static func decorate(_ parent: SKNode, skin: CharacterSkin?, radius: CGFloat) {
        guard let skin else { return }
        let root = SKNode()
        root.name = nodeName
        root.zPosition = -0.1
        parent.addChild(root)
        if skin == .firefly {
            decorateFirefly(root, radius: radius)
            return
        }
        let blocky = isBlocky(skin)
        let palette: [UnitColor] = switch skin {
        case .bamboo: [.moss, .jade, .gold]
        case .voxel: [.moss, .gold, .sky]
        case .party, .pixel, .egg, .firefly: [.coral, .sky, .gold]
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

    // MARK: 萤火精灵

    /// 平时亮着的光团数；连对 3 题、5 题各再亮一颗
    static let fireflyBaseOrbs = 4
    static let fireflyOrbs = 6
    static let fireflyHolderName = "fireflyHolder"
    static let fireflyAuraName = "fireflyAura"

    /// 暖金色：在绿草地上要显眼，不用跟草撞色的黄绿
    private static let fireflyGold = SKColor(red: 1.0, green: 0.8, blue: 0.12, alpha: 1)
    private static let fireflyAmber = SKColor(red: 1.0, green: 0.64, blue: 0.16, alpha: 1)

    /// 中间亮、边缘透明的柔光圆点，光晕和光团共用一张
    private static let glowTexture: SKTexture = {
        let size = 128
        let space = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let gradient = CGGradient(colorsSpace: space, colors: [
                  CGColor(red: 1, green: 1, blue: 1, alpha: 1),
                  CGColor(red: 1, green: 1, blue: 1, alpha: 0.75),
                  CGColor(red: 1, green: 1, blue: 1, alpha: 0.25),
                  CGColor(red: 1, green: 1, blue: 1, alpha: 0),
              ] as CFArray, locations: [0, 0.25, 0.6, 1]) else { return SKTexture() }
        let center = CGPoint(x: CGFloat(size) / 2, y: CGFloat(size) / 2)
        context.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center,
                                   endRadius: CGFloat(size) / 2, options: [])
        guard let image = context.makeImage() else { return SKTexture() }
        return SKTexture(cgImage: image)
    }()

    private static func glow(size: CGFloat, color: SKColor) -> SKSpriteNode {
        let node = SKSpriteNode(texture: glowTexture, size: CGSize(width: size, height: size))
        node.colorBlendFactor = 1
        node.color = color
        return node
    }

    /// 萤火精灵：植物身后一圈呼吸的金色光晕，身边几颗大光团绕着飘、明灭不定。
    /// 每颗光团外面套一层：外层管漂移和连对点亮，里层管明灭，互不打断
    private static func decorateFirefly(_ root: SKNode, radius: CGFloat) {
        root.zPosition = 0.2
        root.alpha = intensity(streak: 0)

        // 身后光晕：整株植物像在发光，一眼认得出是萤火精灵
        let aura = glow(size: radius * 4.4, color: fireflyGold)
        aura.name = fireflyAuraName
        // 叠加发光：把身后的草地照亮成浅黄白色，绿草上也显眼
        aura.blendMode = .add
        aura.zPosition = -0.5
        aura.position = CGPoint(x: 0, y: radius * 0.15)
        aura.alpha = 0.75
        root.addChild(aura)
        let breathe = SKAction.group([.fadeAlpha(to: 1, duration: 0.9), .scale(to: 1.12, duration: 0.9)])
        breathe.timingMode = .easeInEaseOut
        let rest = SKAction.group([.fadeAlpha(to: 0.65, duration: 1.1), .scale(to: 0.94, duration: 1.1)])
        rest.timingMode = .easeInEaseOut
        aura.run(.repeatForever(.sequence([breathe, rest])))

        for i in 0..<fireflyOrbs {
            let holder = SKNode()
            holder.name = fireflyHolderName
            let angle = CGFloat(i) * 2 * .pi / CGFloat(fireflyOrbs) + 0.35
            holder.position = CGPoint(x: cos(angle) * radius * 1.25, y: sin(angle) * radius * 1.05 + radius * 0.15)
            holder.alpha = i < fireflyBaseOrbs ? 1 : 0
            root.addChild(holder)

            // 一颗光团 = 外圈柔光 + 亮白光核
            let orb = glow(size: radius * 1.35, color: i.isMultiple(of: 2) ? fireflyGold : fireflyAmber)
            orb.name = fireflyOrbName
            holder.addChild(orb)
            let core = glow(size: radius * 0.6, color: SKColor(red: 1, green: 0.98, blue: 0.85, alpha: 1))
            core.blendMode = .add
            orb.addChild(core)

            // 慢慢飘：每颗方向、快慢都不一样
            let dx = CGFloat([8, -9, 7, -6, 9, -7][i])
            let dy = CGFloat([10, 7, -9, 11, -8, 9][i])
            let drift = SKAction.moveBy(x: dx, y: dy, duration: 1.2 + 0.23 * Double(i))
            drift.timingMode = .easeInEaseOut
            holder.run(.repeatForever(.sequence([drift, drift.reversed()])))
            // 明灭不定：带随机停顿，几颗不会一起闪；最暗时也看得见
            orb.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.45, duration: 0.28 + 0.06 * Double(i)),
                .wait(forDuration: 0.2, withRange: 0.4),
                .fadeAlpha(to: 1, duration: 0.1),
                .wait(forDuration: 0.4, withRange: 0.6),
            ])))
            let pulse = SKAction.scale(to: 1.3, duration: 0.45 + 0.08 * Double(i))
            pulse.timingMode = .easeInEaseOut
            orb.run(.repeatForever(.sequence([pulse, .scale(to: 0.8, duration: 0.55 + 0.08 * Double(i))])))
        }
    }

    /// 连对越多越亮：平时 0.85，连对 5 题满亮
    static func intensity(streak: Int) -> CGFloat {
        0.85 + 0.03 * CGFloat(min(max(streak, 0), 5))
    }

    /// 连对越多光晕和光团越大：连对 5 题时大一圈
    static func glowScale(streak: Int) -> CGFloat {
        1 + 0.08 * CGFloat(min(max(streak, 0), 5))
    }

    /// 连对数变了：只调现有节点的亮度和大小，不新建节点
    static func showStreak(_ streak: Int, on parent: SKNode, skin: CharacterSkin?) {
        guard skin == .firefly, let root = parent.childNode(withName: nodeName) else { return }
        root.run(.group([
            .fadeAlpha(to: intensity(streak: streak), duration: 0.25),
            .scale(to: glowScale(streak: streak), duration: 0.25),
        ]), withKey: "fireflyStreak")
        let holders = root.children.filter { $0.name == fireflyHolderName }
        for (i, holder) in holders.enumerated() where i >= fireflyBaseOrbs {
            let lit = streak >= (i == fireflyBaseOrbs ? 3 : 5)
            holder.run(.fadeAlpha(to: lit ? 1 : 0, duration: 0.3), withKey: "fireflyLit")
        }
    }

    /// 萤火精灵发射：植物周围炸开一圈金光，转瞬即逝
    private static func fireflyBurst(in node: SKNode) {
        guard let root = node.childNode(withName: nodeName),
              let aura = root.childNode(withName: fireflyAuraName) as? SKSpriteNode else { return }
        let burst = glow(size: aura.size.width * 0.7, color: fireflyGold)
        burst.name = "fireflyBurst"
        burst.blendMode = .add
        burst.position = aura.position
        burst.zPosition = 0.1
        root.addChild(burst)
        burst.run(.sequence([
            .group([.scale(to: 1.8, duration: 0.3), .fadeOut(withDuration: 0.3)]),
            .removeFromParent(),
        ]))
    }

    /// 方块风格的装饰与枪口闪光用方块，其余用圆片
    private static func isBlocky(_ skin: CharacterSkin) -> Bool {
        skin == .pixel || skin == .voxel
    }

    static func shoot(in node: SKNode, skin: CharacterSkin, at point: CGPoint) {
        if skin == .firefly { fireflyBurst(in: node) }
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
