import LearnCore
import SpriteKit

/// 冰晶视觉只读取外观，不参与伤害或减速。透明帧首次使用时绘制并缓存，所有实例共享。
@MainActor
enum IceCombatEffects {
    static func supports(_ look: ProjectileLook) -> Bool {
        look.shape == .snowflake || (look.shape == .gem && look.color == .sky)
    }

    static func decorate(_ defender: SKNode, projectile: ProjectileLook, radius: CGFloat) {
        guard supports(projectile), defender.childNode(withName: "iceAura") == nil else { return }
        let aura = SKNode()
        aura.name = "iceAura"
        aura.zPosition = -1
        aura.position.y = -radius * 0.75
        let ring = SKSpriteNode(texture: halo)
        ring.size = CGSize(width: radius * 2.7, height: radius * 0.95)
        ring.alpha = 0.7
        ring.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.35, duration: 1.1), .fadeAlpha(to: 0.7, duration: 1.1),
        ])))
        aura.addChild(ring)
        let motes = emitter(rate: 5, lifetime: 1.1)
        motes.particlePositionRange = CGVector(dx: radius * 1.7, dy: 6)
        motes.emissionAngle = .pi / 2
        motes.emissionAngleRange = .pi / 5
        motes.particleSpeed = 21
        motes.particleScale = 0.24
        aura.addChild(motes)
        defender.addChild(aura)
        DiagLog.log("ice aura+ emitter=\(DiagLog.id(motes)) defender=\(DiagLog.id(defender))")
    }

    /// 子弹尾迹：粒子挂在子弹上、随子弹一起移除。
    /// 不用 targetNode、飞行途中也不把发射器挪出子弹——那样会在 SpriteKit 帧更新里改节点树，
    /// 发射器释放后渲染层还引用着它的粒子，偶发闪退。
    /// 粒子往后飞的速度补上子弹的飞行速度 speed，匀速直线飞行时等同于留在原地慢慢散开
    static func trail(on bullet: SKNode, speed: CGFloat) -> SKEmitterNode {
        let trail = emitter(rate: 0, lifetime: 0.28)
        trail.name = "iceTrail"
        trail.emissionAngle = .pi
        trail.emissionAngleRange = .pi / 3
        trail.particleSpeed = 28 + speed
        trail.particlePositionRange = CGVector(dx: 4, dy: 7)
        bullet.addChild(trail)
        DiagLog.log("ice trail+ emitter=\(DiagLog.id(trail)) bullet=\(DiagLog.id(bullet)) speed=\(Int(speed))")
        return trail
    }

    static func launch(at point: CGPoint, in layer: SKNode) {
        let flash = SKSpriteNode(texture: burstFrames[2])
        flash.name = "iceLaunch"
        flash.position = point
        flash.zPosition = 51
        flash.setScale(0.25)
        layer.addChild(flash)
        flash.run(.sequence([
            .group([.scale(to: 0.5, duration: 0.16), .fadeOut(withDuration: 0.16)]),
            .removeFromParent(),
        ]))
    }

    static func impact(at point: CGPoint, in layer: SKNode) {
        let burst = SKSpriteNode(texture: burstFrames[0])
        burst.name = "iceImpact"
        burst.position = point
        burst.zPosition = 60
        burst.setScale(0.72)
        layer.addChild(burst)
        burst.run(.sequence([
            .animate(with: burstFrames, timePerFrame: 1.0 / 30, resize: false, restore: false),
            .removeFromParent(),
        ]))
        let shards = emitter(rate: 100, lifetime: 0.45)
        shards.name = "iceShards"
        shards.position = point
        shards.zPosition = 61
        shards.numParticlesToEmit = 12
        shards.emissionAngleRange = .pi * 2
        shards.particleSpeed = 80
        shards.particleSpeedRange = 35
        shards.yAcceleration = -100
        layer.addChild(shards)
        let shardsID = DiagLog.id(shards)
        DiagLog.log("ice shards+ emitter=\(shardsID)")
        shards.run(.sequence([.wait(forDuration: 0.8), .run { DiagLog.log("ice shards- emitter=\(shardsID)") },
                              .removeFromParent()]))
    }

    private static func emitter(rate: CGFloat, lifetime: CGFloat) -> SKEmitterNode {
        let node = SKEmitterNode()
        node.particleTexture = crystal
        node.particleBirthRate = rate
        node.particleLifetime = lifetime
        node.particleScale = 0.38
        node.particleScaleRange = 0.18
        node.particleScaleSpeed = -0.25
        node.particleAlpha = 0.85
        node.particleAlphaSpeed = -1 / lifetime
        node.particleRotationRange = .pi
        node.particleRotationSpeed = 1.2
        node.particleColorBlendFactor = 0
        node.particleBlendMode = .add
        return node
    }

    private static let crystal = texture(size: 24) { context in
        diamond(context, x: 0, y: 0, width: 6, height: 10)
    }

    private static let halo = texture(size: 128) { context in
        context.setStrokeColor(CGColor(red: 0.3, green: 0.85, blue: 1, alpha: 0.8))
        context.setShadow(offset: .zero, blur: 7, color: CGColor(red: 0.15, green: 0.65, blue: 1, alpha: 0.8))
        context.setLineWidth(2)
        context.strokeEllipse(in: CGRect(x: -52, y: -52, width: 104, height: 104))
        context.setLineWidth(1)
        context.strokeEllipse(in: CGRect(x: -43, y: -43, width: 86, height: 86))
        for index in 0..<6 {
            context.saveGState()
            context.rotate(by: CGFloat(index) * .pi / 3)
            diamond(context, x: 0, y: 48, width: 3, height: 7)
            context.restoreGState()
        }
    }

    private static let burstFrames: [SKTexture] = (0..<20).map { frame in
        let t = CGFloat(frame) / 19
        return texture(size: 192) { context in
            let spread = 1 - pow(1 - t, 3)
            context.setAlpha(pow(1 - t, 1.3))
            context.setStrokeColor(CGColor(red: 0.35, green: 0.85, blue: 1, alpha: 0.9))
            context.setShadow(offset: .zero, blur: 5, color: CGColor(red: 0.15, green: 0.65, blue: 1, alpha: 0.75))
            let radius = 8 + spread * 65
            context.setLineWidth(3 * (1 - t) + 0.5)
            context.strokeEllipse(in: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2))
            for index in 0..<8 {
                context.saveGState()
                context.rotate(by: CGFloat(index) * .pi / 4 + 0.15)
                diamond(context, x: 0, y: 10 + spread * 48,
                        width: 5 * (1 - t) + 1, height: 15 * (1 - t) + 3)
                context.restoreGState()
            }
            context.setFillColor(CGColor(red: 0.8, green: 0.97, blue: 1, alpha: pow(1 - t, 3)))
            let core = 15 * (1 - t)
            context.fillEllipse(in: CGRect(x: -core, y: -core, width: core * 2, height: core * 2))
        }
    }

    private static func diamond(_ context: CGContext, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        context.beginPath()
        context.move(to: CGPoint(x: x, y: y + height))
        context.addLine(to: CGPoint(x: x + width, y: y))
        context.addLine(to: CGPoint(x: x, y: y - height))
        context.addLine(to: CGPoint(x: x - width, y: y))
        context.closePath()
        context.setFillColor(CGColor(red: 0.4, green: 0.85, blue: 1, alpha: 0.95))
        context.fillPath()
        context.setStrokeColor(CGColor(red: 0.9, green: 1, blue: 1, alpha: 1))
        context.setLineWidth(1)
        context.move(to: CGPoint(x: x, y: y - height * 0.65))
        context.addLine(to: CGPoint(x: x, y: y + height * 0.8))
        context.strokePath()
    }

    private static func texture(size: Int, draw: (CGContext) -> Void) -> SKTexture {
        guard let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                                      bytesPerRow: size * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return SKTexture() }
        context.translateBy(x: CGFloat(size) / 2, y: CGFloat(size) / 2)
        draw(context)
        guard let image = context.makeImage() else { return SKTexture() }
        let result = SKTexture(cgImage: image)
        result.filteringMode = .linear
        return result
    }
}
