import SpriteKit

/// 一次整场雷霆演出：聚云 → 雷柱从上向下展开 → 身体电光化 → 星屑收束。
/// 由 GameScene 的帧时钟驱动，主动暂停时停止，收尾后才允许回合进入休息。
@MainActor
final class ThunderStrikeEffect: SKNode {
    let defeats: [(id: Int, point: CGPoint)]
    private var elapsed: Double = 0
    private var impacted = false
    private let shade: SKSpriteNode
    private let clouds = SKNode()
    private let size: CGSize
    private var strikes: [Strike] = []
    private let dissolve = SKUniform(name: "u_dissolve", float: 0)
    private lazy var electricShader = SKShader(source: """
        void main() {
            vec2 cell = floor(v_tex_coord * 32.0);
            float noise = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
            float coverage = step(u_dissolve, noise);
            gl_FragColor = v_color_mix * texture2D(u_texture, v_tex_coord).a * coverage;
        }
        """, uniforms: [dissolve])
    private static let cyan = SKColor(red: 0.04, green: 0.77, blue: 1, alpha: 1)

    private struct Strike {
        let enemy: EnemyNode
        let point: CGPoint
        let mask: SKSpriteNode
        let bolt: SKNode
        let impact: SKNode
        let impactArtwork: SKSpriteNode
        let ghost: SKNode
        let sparks: [SKNode]
    }

    init(victims: [EnemyNode], size: CGSize) {
        self.size = size
        defeats = victims.map { ($0.enemyID, $0.center) }
        shade = SKSpriteNode(color: SKColor(red: 0.015, green: 0.06, blue: 0.17, alpha: 1), size: size)
        super.init()
        name = "ultimateThunder"
        zPosition = 85
        shade.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(shade)
        buildClouds()
        for enemy in victims {
            strikes.append(buildStrike(enemy))
        }
        display()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 返回 true 前已移除所有演出节点，外层这时才能结算并暂停。
    func advance(by dt: TimeInterval) -> Bool {
        elapsed += max(0, min(dt, 0.1))
        if elapsed >= 0.34 && !impacted {
            impacted = true
            for strike in strikes { strike.enemy.removeFromParent() }
        }
        display()
        guard elapsed >= 1.35 else { return false }
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

    private func buildStrike(_ enemy: EnemyNode) -> Strike {
        let point = enemy.center
        let ground = CGPoint(x: point.x, y: enemy.position.y - 32 * enemy.yScale)
        let crop = SKCropNode()
        let mask = SKSpriteNode(color: .white, size: size)
        mask.anchorPoint = CGPoint(x: 0.5, y: 1)
        mask.position = CGPoint(x: size.width / 2, y: size.height)
        crop.maskNode = mask
        addChild(crop)
        let bolt = SKSpriteNode(texture: ThunderArtwork.texture(.lightning))
        bolt.name = "thunderBolt"
        bolt.anchorPoint = CGPoint(x: 0.5, y: 1)
        let height = max(48, size.height - 22 - point.y + 8)
        bolt.size = CGSize(width: max(50, min(124, height * 0.34)), height: height)
        bolt.position = CGPoint(x: point.x, y: size.height - 22)
        crop.addChild(bolt)

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
                silhouette.shader = electricShader
                silhouette.alpha = alpha
                ghost.addChild(silhouette)
            }
        }
        impact.addChild(ghost)
        var sparks: [SKNode] = []
        for i in 0..<22 {
            let star = CGMutablePath()
            let radius: CGFloat = i.isMultiple(of: 3) ? 6 : 3
            star.move(to: CGPoint(x: 0, y: radius))
            star.addLine(to: CGPoint(x: radius * 0.25, y: radius * 0.25))
            star.addLine(to: CGPoint(x: radius, y: 0))
            star.addLine(to: CGPoint(x: radius * 0.25, y: -radius * 0.25))
            star.addLine(to: CGPoint(x: 0, y: -radius))
            star.addLine(to: CGPoint(x: -radius * 0.25, y: -radius * 0.25))
            star.addLine(to: CGPoint(x: -radius, y: 0))
            star.addLine(to: CGPoint(x: -radius * 0.25, y: radius * 0.25))
            star.closeSubpath()
            let mote = SKShapeNode(path: star)
            mote.fillColor = i.isMultiple(of: 4) ? Palette.bullet : .white
            mote.strokeColor = i.isMultiple(of: 4) ? Palette.bullet : Self.cyan
            mote.glowWidth = 3
            mote.blendMode = .add
            mote.zPosition = 3
            impact.addChild(mote)
            sparks.append(mote)
        }
        return Strike(enemy: enemy, point: point, mask: mask, bolt: bolt,
                      impact: impact, impactArtwork: artwork, ghost: ghost, sparks: sparks)
    }

    private func display() {
        let gather = min(1, elapsed / 0.22)
        let end = min(1, max(0, (1.35 - elapsed) / 0.45))
        shade.alpha = 0.48 * gather * end
        clouds.alpha = gather * end
        clouds.position.y = CGFloat(1 - gather) * 65
        let descent = min(1, max(0, (elapsed - 0.22) / 0.12))
        let afterHit = max(0, elapsed - 0.34)
        dissolve.floatValue = Float(min(1, afterHit / 0.5))
        for strike in strikes {
            strike.mask.size.height = (size.height - strike.point.y + 24) * descent
            strike.bolt.alpha = elapsed < 0.22 ? 0 : min(1, max(0, (0.68 - elapsed) / 0.2))
            strike.impact.alpha = elapsed < 0.34 ? 0 : end
            let spread = 0.65 + 0.65 * (1 - pow(1 - min(1, afterHit / 0.5), 3))
            let width = 340 * spread
            strike.impactArtwork.size = CGSize(width: width, height: width * 2 / 3)
            strike.impactArtwork.alpha = CGFloat(max(0, min(1, (0.98 - elapsed) / 0.58)))
            strike.ghost.alpha = CGFloat(max(0, 1 - afterHit / 0.42))
            strike.ghost.setScale(1 + CGFloat(afterHit) * 0.25)
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
