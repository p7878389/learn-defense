import LearnCore
import Metal
import SpriteKit
import Testing
#if os(macOS)
import AppKit
#endif
@testable import LearnGame

@Suite("SpriteKit 特效资源", .serialized)
@MainActor
struct FXResourceTests {
    @Test func cometLaunchWaitsForEachShotAndCleansWithTheBullet() throws {
        let clock = try FXClock()
        var hits: [Bool] = []
        ShotAttack(count: 2).perform(from: CGPoint(x: 50, y: 140), to: CGPoint(x: 450, y: 140),
                                    projectile: DefenderKind.inkling.projectile, in: clock.scene) { hits.append($0) }
        let bullets = clock.scene.children
        #expect(bullets.count == 2)
        #expect(clock.scene.childNode(withName: "peaMuzzle") == nil)
        try clock.advance(0.04)
        #expect(bullets[0].childNode(withName: "peaFlight") != nil)
        #expect(bullets[1].childNode(withName: "peaFlight") == nil)
        #expect(clock.scene.childNode(withName: "peaMuzzle") != nil)
        #expect(hits.isEmpty)
        try clock.advance(0.12)
        #expect(bullets[1].childNode(withName: "peaFlight") != nil)
        try clock.advance(1.1)
        #expect(hits == [false, true])
        #expect(clock.scene.children.isEmpty)
    }

    @Test func defeatAddsItsOwnBurstWithoutChangingDeathCleanup() throws {
        let clock = try FXClock()
        let enemy = EnemyNode(id: 31, kind: .blob, sign: "春", lane: 0, scale: 1)
        enemy.position = CGPoint(x: 300, y: 140)
        clock.scene.addChild(enemy)
        enemy.defeat()
        let bloom = try #require(clock.scene.childNode(withName: "defeatBloom"))
        #expect(bloom.childNode(withName: "corona") is SKSpriteNode)
        try clock.advance(0.65)
        #expect(bloom.parent == nil)
        try clock.advance(3)
        #expect(clock.scene.children.isEmpty)
    }

    @Test func cometFlightAndMuzzlePauseWithoutEarlyImpact() throws {
        let scene = GameScene(tuning: .make(grade: .g3, difficulty: .normal), theme: .academy)
        let clock = try FXClock(scene: scene)
        var hits = 0
        ShotAttack(count: 1).perform(from: CGPoint(x: 100, y: 240), to: CGPoint(x: 1000, y: 240),
                                    projectile: DefenderKind.inkling.projectile, in: scene) { _ in hits += 1 }
        try clock.advance(0.08)
        scene.setGamePaused(true)
        try clock.advance(0.05)
        let before = clock.pixels()
        try clock.advance(0.6)
        let unchanged = before == clock.pixels()
        #expect(unchanged)
        #expect(hits == 0)
        scene.setGamePaused(false)
        try clock.advance(1.4)
        #expect(hits == 1)
        #expect(scene.children.allSatisfy { $0 is SKCameraNode })
    }

    @Test func effectsShipAsReadableSpriteKitArchives() throws {
        for name in ["InkBurst", "PeaImpact"] {
            let url = try #require(Bundle.module.url(forResource: name, withExtension: "sks", subdirectory: "Effects"),
                                   "缺少可交付的 .sks 资源：\(name)")
            let decoder = try NSKeyedUnarchiver(forReadingFrom: Data(contentsOf: url))
            decoder.requiresSecureCoding = false
            defer { decoder.finishDecoding() }
            #expect(decoder.decodeObject(forKey: NSKeyedArchiveRootObjectKey) is SKNode)
        }
        let url = try #require(Bundle.module.url(forResource: "CombatActions", withExtension: "sks", subdirectory: "Effects"))
        for name in ["HitReaction", "ImpactFlash", "ImpactRing", "ImpactLifetime"] {
            let action = try #require(SKAction(named: name, from: url))
            #expect(action.duration > 0 && action.duration.isFinite)
        }
    }

    @Test func inkBurstUsesFiniteTexturedParticles() throws {
        let layer = SKNode()
        InkBurstEffect(color: .red, scale: 0.8, count: 11).play(at: CGPoint(x: 40, y: 50), in: layer)
        let emitter = try #require(layer.childNode(withName: "inkBurst") as? SKEmitterNode)
        #expect(emitter.numParticlesToEmit == 11)
        #expect(emitter.particleBirthRate > 0)
        #expect(emitter.particleLifetime > 0)
        #expect(emitter.particleTexture != nil)
        #expect(emitter.position == CGPoint(x: 40, y: 50))
        #expect(abs(emitter.xScale - 0.8) < 0.0001)
    }

    @Test func ordinaryImpactUsesAnAnimatedComposition() throws {
        let layer = SKNode()
        ShotAttack.splat(DefenderKind.inkling.projectile, at: CGPoint(x: 100, y: 80), in: layer)
        let impact = try #require(layer.childNode(withName: "impactSplat"))
        #expect(impact.childNode(withName: "ring") is SKSpriteNode)
        #expect(impact.childNode(withName: "flash") is SKSpriteNode)
        #expect(impact.childNode(withName: "debris") is SKEmitterNode)
    }

    @Test func repeatedHitsMoveOnlyTheVisualAndRecover() throws {
        let clock = try FXClock()
        let enemy = EnemyNode(id: 1, kind: .blob, sign: "春", lane: 0, scale: 1)
        enemy.position = CGPoint(x: 300, y: 130)
        clock.scene.addChild(enemy)
        let sprite = try #require(enemy.childNode(withName: "//unitSprite"))
        try clock.advance(0.05)
        enemy.flash()
        try clock.advance(0.08)
        #expect(abs(sprite.zRotation) > 0.02, "受击应播放归档中的后仰动作")
        enemy.flash()
        try clock.advance(0.08)
        #expect(abs(sprite.zRotation) < 0.2, "重复命中替换动作，不能累计角度")
        try clock.advance(0.4)
        #expect(abs(sprite.zRotation) < 0.001)
        #expect(enemy.position == CGPoint(x: 300, y: 130))
    }

    @Test func templatesDoNotShareMutableState() throws {
        let layer = SKNode()
        InkBurstEffect(color: .red, count: 4).play(at: .zero, in: layer)
        InkBurstEffect(color: .blue, count: 17).play(at: .zero, in: layer)
        let first = try #require(layer.children.first as? SKEmitterNode)
        let second = try #require(layer.children.last as? SKEmitterNode)
        #expect(first !== second)
        #expect(first.numParticlesToEmit == 4)
        #expect(second.numParticlesToEmit == 17)
        #expect(sameRGB(first.particleColor, .red))
        #expect(sameRGB(second.particleColor, .blue))
        #expect(first.particleTexture === second.particleTexture)
        first.removeAllActions()
        #expect(second.action(forKey: "lifetime") != nil)
        let impactA = try #require(FXLibrary.effect(named: "PeaImpact"))
        let impactB = try #require(FXLibrary.effect(named: "PeaImpact"))
        impactA.removeAllChildren()
        #expect(impactB.childNode(withName: "ring") != nil)
    }

    @Test func pausedEffectsKeepTheirPixelsAndFinishAfterResume() throws {
        let scene = GameScene(tuning: .make(grade: .g3, difficulty: .normal), theme: .academy)
        let clock = try FXClock(scene: scene)
        InkBurstEffect(color: .green, count: 20).play(at: CGPoint(x: 200, y: 150), in: clock.scene)
        ShotAttack.splat(DefenderKind.inkling.projectile, at: CGPoint(x: 420, y: 150), in: clock.scene)
        let effects = scene.children.filter { $0.name == "inkBurst" || $0.name == "impactSplat" }
        #expect(effects.count == 2)
        try clock.advance(0.10)
        scene.setGamePaused(true)
        try clock.advance(0.05)
        let paused = clock.pixels()
        try clock.advance(0.5)
        let pixelsUnchanged = clock.pixels() == paused
        #expect(pixelsUnchanged, "暂停必须冻结实际粒子与动作画面")
        #expect(effects.allSatisfy { $0.parent === scene })
        scene.setGamePaused(false)
        try clock.advance(1.2)
        #expect(effects.allSatisfy { $0.parent == nil })
    }

    @Test func repeatedBurstsAndVolleyDoNotLeaveNodesOrDuplicateCallbacks() throws {
        let clock = try FXClock()
        var hits: [Bool] = []
        ShotAttack(count: 3).perform(from: CGPoint(x: 50, y: 160), to: CGPoint(x: 400, y: 160),
                                    projectile: DefenderKind.inkling.projectile, in: clock.scene) { hits.append($0) }
        for _ in 0..<12 {
            InkBurstEffect(color: .green, count: 8).play(at: CGPoint(x: 300, y: 120), in: clock.scene)
        }
        try clock.advance(1.5)
        #expect(hits == [false, false, true])
        #expect(clock.scene.children.isEmpty)
    }

    @Test func hitReactionPreservesFrozenTintAndSkipsDoomedEnemies() throws {
        let clock = try FXClock()
        let enemy = EnemyNode(id: 2, kind: .blob, sign: "冬", lane: 0, scale: 1)
        clock.scene.addChild(enemy)
        let sprite = try #require(enemy.childNode(withName: "//unitSprite") as? SKSpriteNode)
        enemy.slow(factor: 0.5, seconds: 2)
        enemy.flash()
        try clock.advance(0.5)
        #expect(abs(sprite.colorBlendFactor - 0.45) < 0.001)
        #expect(sameRGB(sprite.color, UnitColor.sky.fill))
        #expect(abs(sprite.zRotation) < 0.001)
        enemy.doomed = true
        enemy.flash()
        #expect(sprite.action(forKey: "fxHitReaction") == nil)
    }

    @Test func missingEffectsAndEmptyBurstsAreHarmless() {
        #expect(FXLibrary.effect(named: "missing-effect") == nil)
        #expect(FXLibrary.effect(named: "CombatActions") == nil)
        let layer = SKNode()
        InkBurstEffect(color: .green, count: 0).play(at: .zero, in: layer)
        InkBurstEffect(color: .green, count: -1).play(at: .zero, in: layer)
        #expect(layer.children.isEmpty)
    }

    @Test func effectsCreatedDuringPauseWaitAndRoundRestKeepsAnimating() throws {
        let scene = GameScene(tuning: .make(grade: .g3, difficulty: .normal), theme: .academy)
        let clock = try FXClock(scene: scene)
        scene.setGamePaused(true)
        InkBurstEffect(color: .green, count: 10).play(at: CGPoint(x: 200, y: 150), in: scene)
        let effect = try #require(scene.childNode(withName: "inkBurst"))
        #expect(effect.isPaused)
        try clock.advance(0.1)
        #expect(effect.isPaused, "接入渲染树后的首帧不能丢失暂停状态")
        try clock.advance(1)
        #expect(effect.parent === scene)
        scene.setGamePaused(true, keepingAnimations: true)
        try clock.advance(1)
        #expect(scene.gamePaused)
        #expect(effect.parent == nil)
    }

    @Test(arguments: [false, true])
    func pauseBeforeFirstRenderSurvivesRepeatedPause(alreadyPaused: Bool) throws {
        let scene = GameScene(tuning: .make(grade: .g3, difficulty: .normal), theme: .academy)
        let clock = try FXClock(scene: scene)
        if alreadyPaused { scene.setGamePaused(true) }
        InkBurstEffect(color: .green, count: 10).play(at: CGPoint(x: 200, y: 150), in: scene)
        let effect = try #require(scene.childNode(withName: "inkBurst"))
        scene.setGamePaused(true)
        try clock.advance(0.05)
        #expect(effect.isPaused)
        try clock.advance(0.8)
        let stillAttached = effect.parent === scene
        #expect(stillAttached)
        scene.setGamePaused(false)
        try clock.advance(1)
        #expect(effect.parent == nil)
    }

    #if os(macOS)
    /// 导出生产 fire/flash/defeat 路径，所有画面来自 SKRenderer，非网页动画替身。
    @Test func renderResourceMVPPreview() throws {
        guard let folder = ProcessInfo.processInfo.environment["LEARN_FX_PREVIEW"] else { return }
        let output = URL(fileURLWithPath: folder)
        let frames = output.appendingPathComponent("frames")
        try FileManager.default.createDirectory(at: frames, withIntermediateDirectories: true)
        let scene = GameScene(tuning: .make(grade: .g3, difficulty: .normal), theme: .academy,
                              loadout: Loadout(defeat: .inkBurst))
        let view = SKView(frame: CGRect(origin: .zero, size: scene.size))
        scene.didMove(to: view)
        scene.setGamePaused(true, keepingAnimations: true)
        #expect(scene.plant(.inkling, in: DefenderCell(lane: 1, column: 1)))
        #expect(scene.plant(.twin, in: DefenderCell(lane: 2, column: 0)))
        let armored = scene.spawn(EnemySpawn(id: 101, sign: "春", kind: .armored), lane: 1, x: 640)
        _ = scene.spawn(EnemySpawn(id: 102, sign: "花", kind: .blob), lane: 2, x: 800)
        let log = FXDefeats()
        scene.gameDelegate = log
        let title = SKLabelNode(fontNamed: "PingFangSC-Semibold")
        let header = SKSpriteNode(color: SKColor(white: 0.05, alpha: 0.84), size: CGSize(width: 1200, height: 82))
        header.position = CGPoint(x: 600, y: 559); header.zPosition = 199
        scene.addChild(header)
        title.text = "SpriteKit 资源化 MVP · 实际战斗渲染"
        title.fontSize = 24; title.fontColor = .white
        title.position = CGPoint(x: 600, y: 570); title.zPosition = 200
        scene.addChild(title)
        let subtitle = SKLabelNode(fontNamed: "PingFangSC-Regular")
        subtitle.fontSize = 17; subtitle.fontColor = .white
        subtitle.position = CGPoint(x: 600, y: 540); subtitle.zPosition = 200
        subtitle.text = "普通命中 / 墨点粒子 / 受击动作：由 .sks 资源驱动"
        scene.addChild(subtitle)
        let clock = try FXClock(scene: scene)
        for frame in 0..<210 {
            if frame == 15 {
                subtitle.text = "① 第一次攻击：命中环、碎屑与受击后仰"
                #expect(scene.fire(at: 101) == false)
                #expect(armored.health.current == 1)
            }
            if frame == 65 {
                subtitle.text = "② 第二次攻击：墨点退场，击杀只结算一次"
                #expect(scene.fire(at: 101) == true)
            }
            if frame == 105 {
                subtitle.text = "③ 连发：多次视觉命中，一次击杀结算"
                #expect(scene.fire(at: 102) == true)
            }
            if [155, 173].contains(frame) {
                subtitle.text = "④ 同一 InkBurst.sks：独立绑定颜色、数量与比例"
                for (x, color) in [(CGFloat(420), SKColor.systemGreen), (600, .systemOrange), (780, .systemBlue)] {
                    InkBurstEffect(color: color, scale: 1.5, count: 18)
                        .play(at: CGPoint(x: x, y: 160), in: scene)
                }
            }
            try clock.advance(1.0 / 30)
            try clock.writePNG(to: frames.appendingPathComponent(String(format: "%03d.png", frame)))
        }
        #expect(log.ids == [101, 102])
        #expect(scene.childNode(withName: "impactSplat") == nil)
        #expect(scene.childNode(withName: "inkBurst") == nil)
        let summary = "生产 fire 路径：两只敌人各结算一次；连发回调与有限特效清理通过。\n"
        try summary.write(to: output.appendingPathComponent("preview-check.txt"), atomically: true, encoding: .utf8)
    }
    #endif

    private func sameRGB(_ lhs: SKColor, _ rhs: SKColor) -> Bool {
        var lr: CGFloat = 0, lg: CGFloat = 0, lb: CGFloat = 0, la: CGFloat = 0
        var rr: CGFloat = 0, rg: CGFloat = 0, rb: CGFloat = 0, ra: CGFloat = 0
        lhs.getRed(&lr, green: &lg, blue: &lb, alpha: &la)
        rhs.getRed(&rr, green: &rg, blue: &rb, alpha: &ra)
        return zip([lr, lg, lb, la], [rr, rg, rb, ra]).allSatisfy { abs($0 - $1) < 0.001 }
    }
}

/// 用真实 Metal 渲染帧推进资源动作与粒子；不以手工改节点模拟运行结果。
@MainActor
private final class FXClock {
    let scene: SKScene
    let texture: MTLTexture
    private let renderer: SKRenderer
    private let queue: MTLCommandQueue
    private let pass = MTLRenderPassDescriptor()
    private let start = CACurrentMediaTime()
    private var frame = 0

    init(scene supplied: SKScene? = nil) throws {
        let scene = supplied ?? SKScene(size: CGSize(width: 640, height: 320))
        self.scene = scene
        let device = try #require(MTLCreateSystemDefaultDevice())
        renderer = SKRenderer(device: device)
        renderer.scene = scene
        queue = try #require(device.makeCommandQueue())
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm,
            width: Int(scene.size.width), height: Int(scene.size.height), mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead]
        texture = try #require(device.makeTexture(descriptor: descriptor))
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        try advance(0)
    }

    func advance(_ seconds: Double) throws {
        for _ in 0..<max(1, Int((seconds * 60).rounded())) {
            renderer.update(atTime: start + Double(frame) / 60)
            let command = try #require(queue.makeCommandBuffer())
            renderer.render(withViewport: CGRect(origin: .zero, size: scene.size), commandBuffer: command,
                            renderPassDescriptor: pass)
            command.commit()
            command.waitUntilCompleted()
            frame += 1
        }
    }

    func pixels() -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: texture.width * texture.height * 4)
        bytes.withUnsafeMutableBytes {
            texture.getBytes($0.baseAddress!, bytesPerRow: texture.width * 4,
                             from: MTLRegionMake2D(0, 0, texture.width, texture.height), mipmapLevel: 0)
        }
        return bytes
    }

    #if os(macOS)
    func writePNG(to url: URL) throws {
        let data = Data(pixels())
        let provider = try #require(CGDataProvider(data: data as CFData))
        let image = try #require(CGImage(width: texture.width, height: texture.height, bitsPerComponent: 8,
            bitsPerPixel: 32, bytesPerRow: texture.width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
                .union(.byteOrder32Little), provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
        let bitmap = NSBitmapImageRep(cgImage: image)
        try #require(bitmap.representation(using: .png, properties: [:])).write(to: url)
    }
    #endif
}

@MainActor
private final class FXDefeats: GameSceneDelegate {
    var ids: [Int] = []
    var speedFactor: Double { 1 }
    func nextEnemy() -> EnemySpawn? { nil }
    func targetChanged(to id: Int?) {}
    func enemyReachedBase(_ id: Int) -> Bool { false }
    func enemyDefeated(_ id: Int, at point: CGPoint) { ids.append(id) }
    func barricadeRemoved() {}
}
