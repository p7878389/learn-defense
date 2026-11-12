import SpriteKit

/// 一次整场雷霆演出：聚云 → 雷柱从上向下展开 → 身体电光化 → 星屑收束。
/// 雷击从植物一侧向远处依次落下，不是全场同时爆开。
/// 由 GameScene 的帧时钟驱动，主动暂停时停止，收尾后才允许回合进入休息。
@MainActor
final class ThunderStrikeEffect: SKNode {
    /// 整场演出的时长。
    static let duration = 1.3
    /// 聚云结束、雷柱开始下落的时刻，以及雷柱落到目标身上的时刻（相对各自的起点）。
    private static let gatherTime = 0.22
    private static let hitTime = 0.34
    /// 雷击扫过整个战场宽度所用的时间；横向距离越远，落雷越晚。
    private static let sweepTime = 0.3
    /// 全场星屑的预算：目标少时每只 22 颗，目标多时均分，每只至少留 6 颗。
    static let sparkBudget = 132
    private static let cyan = SKColor(red: 0.04, green: 0.77, blue: 1, alpha: 1)

    let defeats: [(id: Int, point: CGPoint)]
    private var elapsed: Double = 0
    private let shade: SKSpriteNode
    private let clouds = SKNode()
    private let size: CGSize
    private var strikes: [Strike] = []

    /// 电光残影的溶解着色器：只编译一次，每个残影用自己的 a_dissolve 进度。
    private static let electricShader: SKShader = {
        let shader = SKShader(source: """
            void main() {
                vec2 cell = floor(v_tex_coord * 32.0);
                float noise = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
                float coverage = step(a_dissolve, noise);
                gl_FragColor = v_color_mix * texture2D(u_texture, v_tex_coord).a * coverage;
            }
            """)
        shader.attributes = [SKAttribute(name: "a_dissolve", type: .float)]
        return shader
    }()

    /// 星屑贴图：大、小两种尺寸各有金色与蓝白两种配色，辉光画进贴图里，同一种贴图可以合批。
    private static let sparkTextures: [SKTexture] = {
        [(CGFloat(6), true), (6, false), (3, true), (3, false)].map { radius, golden in
            let glow: CGFloat = 4
            let scale: CGFloat = 3
            let side = Int((radius + glow) * 2 * scale)
            guard let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                                          space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return SKTexture() }
            context.translateBy(x: CGFloat(side) / 2, y: CGFloat(side) / 2)
            context.scaleBy(x: scale, y: scale)
            let star = CGMutablePath()
            star.move(to: CGPoint(x: 0, y: radius))
            star.addLine(to: CGPoint(x: radius * 0.25, y: radius * 0.25))
            star.addLine(to: CGPoint(x: radius, y: 0))
            star.addLine(to: CGPoint(x: radius * 0.25, y: -radius * 0.25))
            star.addLine(to: CGPoint(x: 0, y: -radius))
            star.addLine(to: CGPoint(x: -radius * 0.25, y: -radius * 0.25))
            star.addLine(to: CGPoint(x: -radius, y: 0))
            star.addLine(to: CGPoint(x: -radius * 0.25, y: radius * 0.25))
            star.closeSubpath()
            let edge = golden ? Palette.bullet.cgColor : cyan.cgColor
            context.setShadow(offset: .zero, blur: 3 * scale, color: edge)
            context.setFillColor(golden ? Palette.bullet.cgColor : SKColor.white.cgColor)
            context.setStrokeColor(edge)
            context.setLineWidth(1)
            context.addPath(star)
            context.drawPath(using: .fillStroke)
            guard let image = context.makeImage() else { return SKTexture() }
            let texture = SKTexture(cgImage: image)
            texture.filteringMode = .linear
            return texture
        }
    }()

    private struct Strike {
        let enemy: EnemyNode
        let point: CGPoint
        /// 这道雷比第一道晚多久落下。
        let delay: Double
        let bolt: SKSpriteNode
        let boltSize: CGSize
        let impact: SKNode
        let impactArtwork: SKSpriteNode
        let ghost: SKNode
        let sparks: [SKSpriteNode]
        var struck = false
        var revealed: CGFloat = -1
    }

    init(victims: [EnemyNode], size: CGSize) {
        self.size = size
        defeats = victims.map { ($0.enemyID, $0.center) }
        shade = SKSpriteNode(color: SKColor(red: 0.015, green: 0.06, blue: 0.17, alpha: 1), size: size)
        super.init()
        name = "ultimateThunder"
        zPosition = 85
        shade.name = "thunderShade"
        shade.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(shade)
        buildClouds()
        let nearest = victims.map(\.center.x).min() ?? 0
        let sparkCount = max(6, min(22, Self.sparkBudget / max(1, victims.count)))
        for enemy in victims {
            let delay = Double((enemy.center.x - nearest) / max(1, size.width)) * Self.sweepTime
            strikes.append(buildStrike(enemy, delay: delay, sparkCount: sparkCount))
        }
        display()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 返回 true 前已移除所有演出节点，外层这时才能结算并暂停。
    func advance(by dt: TimeInterval) -> Bool {
        elapsed += max(0, min(dt, 0.1))
        for index in strikes.indices where !strikes[index].struck && elapsed - strikes[index].delay >= Self.hitTime {
            strikes[index].struck = true
            strikes[index].enemy.removeFromParent()
        }
        display()
        guard elapsed >= Self.duration else { return false }
        // 最远的一道雷也已落下；保险起见把还没移除的怪一并带走。
        for strike in strikes where !strike.struck { strike.enemy.removeFromParent() }
        removeFromParent()
        return true
    }

    private func buildClouds() {
        addChild(clouds)
        clouds.zPosition = 5
        let sprite = SKSpriteNode(texture: ThunderArtwork.texture(.clouds))
        sprite.name = "thunderClouds"
        sprite.anchorPoint = CGPoint(x: 0.5, y: 1)
        sprite.size = CGSize(width: size.width, height: size.width / 3)
        // 与样片相同：纹理顶部略超出画面，带辉光的云底落在战场上缘。
        sprite.position = CGPoint(x: size.width / 2, y: size.height + 54)
        clouds.addChild(sprite)
    }

    private func buildStrike(_ enemy: EnemyNode, delay: Double, sparkCount: Int) -> Strike {
        let point = enemy.center
        let ground = CGPoint(x: point.x, y: enemy.position.y - 32 * enemy.yScale)
        let bolt = SKSpriteNode(texture: ThunderArtwork.texture(.lightning))
        bolt.name = "thunderBolt"
        bolt.anchorPoint = CGPoint(x: 0.5, y: 1)
        let height = max(48, size.height - 22 - point.y + 8)
        let boltSize = CGSize(width: max(50, min(124, height * 0.34)), height: height)
        bolt.size = boltSize
        bolt.position = CGPoint(x: point.x, y: size.height - 22)
        addChild(bolt)

        let impact = SKNode()
        addChild(impact)
        let artwork = SKSpriteNode(texture: ThunderArtwork.texture(.impact))
        artwork.name = "thunderImpact"
        // 原图电环中心在自下往上约 37% 处，以脚下落点为锚点，缩放时不漂移。
        artwork.anchorPoint = CGPoint(x: 0.5, y: 0.37)
        artwork.position = ground
        artwork.zPosition = 2
        impact.addChild(artwork)
        let ghost = SKNode()
        ghost.position = point
        ghost.zPosition = 1
        // 复用怪物当前身体帧，蓝白轮廓与原怪物大小、位置相同。
        if let body = enemy.childNode(withName: ".//unitSprite") as? SKSpriteNode, let scene = enemy.scene {
            let center = body.convert(CGPoint.zero, to: scene)
            let corner = body.convert(CGPoint(x: body.size.width, y: body.size.height), to: scene)
            for (scale, color, alpha) in [(CGFloat(1.1), Self.cyan, CGFloat(0.38)),
                                           (CGFloat(1.035), SKColor.white, CGFloat(0.9)),
                                           (CGFloat(1), Self.cyan, CGFloat(0.95))] {
                let silhouette = SKSpriteNode(texture: body.texture, color: color,
                                              size: CGSize(width: abs(corner.x - center.x), height: abs(corner.y - center.y)))
                silhouette.position = CGPoint(x: center.x - point.x, y: center.y - point.y)
                silhouette.xScale = body.xScale < 0 ? -scale : scale
                silhouette.yScale = scale
                silhouette.colorBlendFactor = 1
                silhouette.shader = Self.electricShader
                silhouette.alpha = alpha
                ghost.addChild(silhouette)
            }
        }
        impact.addChild(ghost)
        var sparks: [SKSpriteNode] = []
        for i in 0..<sparkCount {
            let texture = Self.sparkTextures[(i.isMultiple(of: 3) ? 0 : 2) + (i.isMultiple(of: 4) ? 0 : 1)]
            let mote = SKSpriteNode(texture: texture, size: CGSize(width: texture.size().width / 3,
                                                                   height: texture.size().height / 3))
            mote.name = "thunderSpark"
            mote.blendMode = .add
            mote.zPosition = 3
            impact.addChild(mote)
            sparks.append(mote)
        }
        return Strike(enemy: enemy, point: point, delay: delay, bolt: bolt, boltSize: boltSize,
                      impact: impact, impactArtwork: artwork, ghost: ghost, sparks: sparks)
    }

    private func display() {
        let gather = min(1, elapsed / Self.gatherTime)
        let end = min(1, max(0, (Self.duration - elapsed) / 0.45))
        // 只把战场压暗一层，下面的植物和怪物仍然看得清。
        shade.alpha = 0.3 * gather * end
        clouds.alpha = gather * end
        clouds.position.y = CGFloat(1 - gather) * 65
        for index in strikes.indices {
            let strike = strikes[index]
            // 每道雷按自己的起点走同一套节拍。
            let time = elapsed - strike.delay
            let descent = min(1, max(0, (time - Self.gatherTime) / (Self.hitTime - Self.gatherTime)))
            let afterHit = max(0, time - Self.hitTime)
            // 雷柱自上而下露出：只取贴图顶部的一段，不用裁剪节点。
            let reach = (size.height - strike.point.y + 24) * descent - 22
            let shown = min(1, max(0, reach / strike.boltSize.height))
            if shown != strike.revealed {
                strikes[index].revealed = shown
                strike.bolt.isHidden = shown <= 0
                if shown > 0, let full = ThunderArtwork.texture(.lightning) {
                    strike.bolt.texture = shown >= 1 ? full
                        : SKTexture(rect: CGRect(x: 0, y: 1 - shown, width: 1, height: shown), in: full)
                    strike.bolt.size = CGSize(width: strike.boltSize.width, height: strike.boltSize.height * shown)
                }
            }
            strike.bolt.alpha = time < Self.gatherTime ? 0 : min(1, max(0, (0.68 - time) / 0.2))
            strike.impact.alpha = time < Self.hitTime ? 0 : end
            let spread = 0.65 + 0.65 * (1 - pow(1 - min(1, afterHit / 0.5), 3))
            let width = 340 * spread
            strike.impactArtwork.size = CGSize(width: width, height: width * 2 / 3)
            strike.impactArtwork.alpha = CGFloat(max(0, min(1, (0.98 - time) / 0.58)))
            strike.ghost.alpha = CGFloat(max(0, 1 - afterHit / 0.42))
            strike.ghost.setScale(1 + CGFloat(afterHit) * 0.25)
            let dissolve = SKAttributeValue(float: Float(min(1, afterHit / 0.5)))
            for silhouette in strike.ghost.children {
                silhouette.setValue(dissolve, forAttribute: "a_dissolve")
            }
            for (i, spark) in strike.sparks.enumerated() {
                let angle = CGFloat(i) * 2.39996
                let travel = CGFloat(1 - pow(max(0, 1 - afterHit / 0.85), 2))
                let radius = CGFloat(40 + (i * 17) % 65) * travel
                spark.position = CGPoint(x: strike.point.x + cos(angle) * radius,
                                         y: strike.point.y + sin(angle) * radius * 0.65 + CGFloat(afterHit) * 36)
                spark.alpha = CGFloat(max(0, 1 - afterHit / (0.65 + Double(i % 4) * 0.1)))
                spark.setScale(max(0.1, 1 - CGFloat(afterHit) * 0.7))
            }
        }
    }
}
