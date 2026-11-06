import LearnCore
import Metal
import SpriteKit
import Testing
#if os(macOS)
import AppKit
#endif
@testable import LearnGame

/// 用 SKRenderer 真正推进 SpriteKit 动作，按 60 帧/秒走时间
@MainActor
private final class SceneClock {
    let scene: SKScene
    private let renderer: SKRenderer
    private let queue: MTLCommandQueue
    private let pass = MTLRenderPassDescriptor()
    private let start = CACurrentMediaTime()
    private(set) var frame = 0
    let texture: MTLTexture

    init(size: CGSize = CGSize(width: 900, height: 360)) throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        scene = SKScene(size: size)
        scene.isPaused = false
        renderer = SKRenderer(device: device)
        renderer.scene = scene
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm, width: Int(size.width), height: Int(size.height), mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead]
        texture = try #require(device.makeTexture(descriptor: descriptor))
        queue = try #require(device.makeCommandQueue())
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        try advance(seconds: 0)
    }

    func advance(seconds: Double) throws {
        let frames = max(1, Int((seconds * 60).rounded()))
        for _ in 0..<frames {
            renderer.update(atTime: start + Double(frame) / 60)
            let command = try #require(queue.makeCommandBuffer())
            renderer.render(withViewport: CGRect(origin: .zero, size: scene.size), commandBuffer: command,
                            renderPassDescriptor: pass)
            command.commit()
            command.waitUntilCompleted()
            frame += 1
        }
    }

    func setBackground(red: Double, green: Double, blue: Double) {
        scene.backgroundColor = SKColor(red: red, green: green, blue: blue, alpha: 1)
        pass.colorAttachments[0].clearColor = MTLClearColor(red: red, green: green, blue: blue, alpha: 1)
    }
}

@Suite("植物与僵尸战斗动画")
@MainActor
struct CombatAnimationTests {
    private func sprite(of node: SKNode) throws -> SKSpriteNode {
        try #require(node.childNode(withName: "//unitSprite") as? SKSpriteNode)
    }

    private func isFrame(_ texture: SKTexture?, of clip: String) -> Bool {
        guard let texture else { return false }
        return UnitSprites.frames(named: clip).contains { $0 === texture }
    }

    @Test func everyBuiltInZombieHasBiteAndFallAnimations() throws {
        for kind in UnitCatalog.enemies {
            let base = "zombie-\(kind.id)"
            for state in ["attack", "die", "boom"] {
                let clip = try #require(UnitSprites.state(state, of: base), "\(kind.id) 缺少 \(state)")
                #expect(UnitSprites.placement(of: clip, in: base, scale: 0.6) != nil)
            }
        }
        // 只有带防具、要打好几下的僵尸才会掉防具
        for kind in UnitCatalog.enemies {
            #expect((UnitSprites.state("bare", of: "zombie-\(kind.id)") != nil) == (kind.hp > 1), "\(kind.id)")
        }
        #expect(UnitSprites.state("attack", of: "plant-stroke") != nil)
        #expect(UnitSprites.state("missing", of: "zombie-blob") == nil)
    }

    @Test func switchingAnimationsKeepsFeetInPlace() throws {
        // 换动画后，各自的 pivot 和画布底边落在同一点上
        for (clip, base) in [("zombie-blob", "zombie-armored"), ("zombie-blob-die", "zombie-blob"),
                             ("zombie-king-attack", "zombie-king"), ("zombie-dasher-die", "zombie-dasher"),
                             ("plant-stroke-attack", "plant-stroke")] {
            let scale: CGFloat = 0.6
            let rect = try #require(UnitSprites.placement(of: clip, in: base, scale: scale))
            let info = try #require(UnitSprites.clip(named: clip))
            let canvas = try #require(info.canvas)
            let pivot = info.pivot ?? canvas[0] / 2
            let foot = CGPoint(x: rect.midX + (pivot - info.crop[0] - info.crop[2] / 2) * scale,
                               y: rect.midY - (canvas[1] - info.crop[1] - info.crop[3] / 2) * scale)
            let baseInfo = try #require(UnitSprites.clip(named: base))
            let baseCanvas = try #require(baseInfo.canvas)
            let baseFoot = try #require(UnitSprites.point([baseInfo.pivot ?? 0, baseCanvas[1]], in: base, scale: scale))
            #expect(abs(foot.x - baseFoot.x) < 0.001 && abs(foot.y - baseFoot.y) < 0.001, "\(clip)")
            #expect(abs(rect.width - info.crop[2] * scale) < 0.001)
        }
        // 走路动画放回自己身上时不动
        let same = try #require(UnitSprites.placement(of: "zombie-blob", in: "zombie-blob", scale: 0.6))
        #expect(abs(same.midX) < 0.001 && abs(same.midY) < 0.001)
    }

    @Test func armorFallsOffOnlyBeforeTheLastHit() throws {
        let bucket = EnemyNode(id: 1, kind: .armored, sign: "学", lane: 0, scale: 1)
        let bucketSprite = try sprite(of: bucket)
        #expect(isFrame(bucketSprite.texture, of: "zombie-armored"))
        bucket.health.take(1)
        bucket.showWound()
        #expect(isFrame(bucketSprite.texture, of: "zombie-blob"), "铁桶被打掉后换成普通僵尸")
        #expect(bucketSprite.action(forKey: SpriteRig.loopKey) != nil)

        let door = EnemyNode(id: 2, kind: .king, sign: "书", lane: 0, scale: 1)
        let doorSprite = try sprite(of: door)
        door.health.take(1)
        door.showWound()
        #expect(isFrame(doorSprite.texture, of: "zombie-king"), "还剩两下时铁门还在")
        door.health.take(1)
        door.showWound()
        #expect(isFrame(doorSprite.texture, of: "zombie-blob"))

        let plain = EnemyNode(id: 3, kind: .blob, sign: "天", lane: 0, scale: 1)
        plain.showWound()
        #expect(isFrame(try sprite(of: plain).texture, of: "zombie-blob"))
    }

    @Test func freezeStopsTheWalkCycleAndThawResumesIt() throws {
        let clock = try SceneClock()
        let zombie = EnemyNode(id: 1, kind: .blob, sign: "冰", lane: 0, scale: 1)
        zombie.position = CGPoint(x: 450, y: 180)
        clock.scene.addChild(zombie)
        let body = try sprite(of: zombie)
        try clock.advance(seconds: 0.2)
        zombie.slow(factor: 0, seconds: 5)
        let frozen = body.texture
        try clock.advance(seconds: 0.5)
        #expect(body.texture === frozen, "冻住时动作停下")
        // 减速时还在走，只是慢一些（帧间隔从 0.09 变成 0.18 秒）
        _ = zombie.advance(dt: 6, speed: 40)
        zombie.slow(factor: 0.5, seconds: 5)
        let slowed = body.texture
        try clock.advance(seconds: 0.12)
        #expect(body.texture === slowed)
        try clock.advance(seconds: 0.12)
        #expect(body.texture !== slowed)
        let thawing = body.texture
        _ = zombie.advance(dt: 6, speed: 40)
        try clock.advance(seconds: 0.12)
        #expect(body.texture !== thawing, "恢复原速继续走")
        #expect(body.colorBlendFactor == 0)
    }

    @Test func wrongAnswerBitesThenKeepsWalking() throws {
        let clock = try SceneClock()
        let zombie = EnemyNode(id: 1, kind: .hopper, sign: "错", lane: 0, scale: 1)
        zombie.position = CGPoint(x: 450, y: 180)
        clock.scene.addChild(zombie)
        let body = try sprite(of: zombie)
        zombie.lunge()
        zombie.lunge()
        #expect(isFrame(body.texture, of: "zombie-hopper-attack"))
        try clock.advance(seconds: 0.3)
        #expect(isFrame(body.texture, of: "zombie-hopper-attack"))
        try clock.advance(seconds: 0.5)
        #expect(isFrame(body.texture, of: "zombie-hopper"), "咬完回到走路，连续答错也不会一直咬")
    }

    @Test func defeatedZombieLosesHeadFallsAndIsCleanedUp() throws {
        let clock = try SceneClock()
        let zombie = EnemyNode(id: 1, kind: .blob, sign: "倒", lane: 0, scale: 1)
        zombie.position = CGPoint(x: 450, y: 180)
        clock.scene.addChild(zombie)
        zombie.slow(factor: 0.5, seconds: 3)
        let body = try sprite(of: zombie)
        zombie.defeat()
        #expect(isFrame(body.texture, of: "zombie-blob-die"))
        #expect(body.colorBlendFactor == 0, "倒下时去掉减速的蓝色")
        let head = zombie.children.flatMap { $0.children }.flatMap { $0.children }
            .compactMap { $0 as? SKSpriteNode }.first { isFrame($0.texture, of: "zombie-head") }
        #expect(head != nil, "头掉下来")
        try clock.advance(seconds: 0.5)
        #expect(zombie.parent != nil, "倒地动画还在播")
        try clock.advance(seconds: 1.2)
        #expect(zombie.parent == nil)
        try clock.advance(seconds: 0.5)
        #expect(clock.scene.children.isEmpty, "退场特效也要清理")
    }

    @Test func ultimateBurnsZombiesWithoutDroppingHeads() throws {
        let clock = try SceneClock()
        let zombie = EnemyNode(id: 1, kind: .drowsy, sign: "焦", lane: 0, scale: 1)
        clock.scene.addChild(zombie)
        let body = try sprite(of: zombie)
        zombie.defeat(burnt: true)
        #expect(isFrame(body.texture, of: "zombie-boom"))
        let spawned = zombie.children.flatMap { $0.children }.flatMap { $0.children }.filter { $0 !== body }
        #expect(spawned.isEmpty)
        try clock.advance(seconds: 2.5)
        #expect(zombie.parent == nil)
    }

    @Test func breakingIntoTheBaseBitesFirst() throws {
        let clock = try SceneClock()
        let zombie = EnemyNode(id: 1, kind: .dasher, sign: "家", lane: 0, scale: 1)
        clock.scene.addChild(zombie)
        zombie.breakThrough()
        #expect(isFrame(try sprite(of: zombie).texture, of: "zombie-dasher-attack"))
        try clock.advance(seconds: 0.4)
        #expect(zombie.parent != nil)
        try clock.advance(seconds: 0.7)
        #expect(zombie.parent == nil)
    }

    @Test func peashootersFireFromTheMouth() {
        for kind in [DefenderKind.inkling, .twin, .frost] {
            let plant = DefenderNode(kind: kind, radius: 34)
            plant.position = CGPoint(x: 200, y: 100)
            #expect(plant.muzzle.x > 225, "\(kind.id) 嘴在右边")
            #expect(plant.muzzle.y > 110, "\(kind.id) 嘴在上半身")
        }
        let custom = DefenderNode(kind: DefenderKind(id: "custom", name: "新字灵", attack: .single(damage: 1),
                                                     look: .init(body: .round, color: .jade),
                                                     projectile: .init(shape: .orb, color: .gold)), radius: 34)
        #expect(custom.muzzle == CGPoint(x: 34 * 0.9, y: 0))
    }

    @Test func fumeShroomPlaysAttackThenReturnsToIdle() throws {
        let clock = try SceneClock()
        let plant = DefenderNode(kind: .stroke, radius: 34)
        clock.scene.addChild(plant)
        let body = try sprite(of: plant)
        plant.shoot()
        #expect(isFrame(body.texture, of: "plant-stroke-attack"))
        try clock.advance(seconds: 1.3)
        #expect(isFrame(body.texture, of: "plant-stroke"))
        #expect(body.action(forKey: SpriteRig.loopKey) != nil)
        #expect(body.action(forKey: SpriteRig.onceKey) == nil, "发射动画播完自己结束")
        // 闪退回归：连续发射时，上一次的回调回到待机不能删掉正在跑的动作；再打一轮仍能回到待机
        plant.shoot()
        try clock.advance(seconds: 0.2)
        plant.shoot()
        try clock.advance(seconds: 1.3)
        #expect(isFrame(body.texture, of: "plant-stroke"))
        #expect(body.action(forKey: SpriteRig.loopKey) != nil)
        // 没有发射动画的豌豆射手不受影响
        let pea = DefenderNode(kind: .inkling, radius: 34)
        pea.shoot()
        #expect(isFrame(try sprite(of: pea).texture, of: "plant-inkling"))
    }

    @Test func peaSplatsOnImpactAndIsCleanedUp() throws {
        let clock = try SceneClock()
        var impacts: [Bool] = []
        var splatSeen = false
        ShotAttack(count: 2).perform(from: CGPoint(x: 50, y: 100), to: CGPoint(x: 650, y: 100),
                                    projectile: DefenderKind.twin.projectile, in: clock.scene) { final in
            impacts.append(final)
            splatSeen = splatSeen || clock.scene.childNode(withName: "impactSplat") != nil
        }
        try clock.advance(seconds: 0.8)
        #expect(impacts == [false, true])
        #expect(splatSeen || clock.scene.childNode(withName: "impactSplat") != nil)
        try clock.advance(seconds: 0.6)
        #expect(clock.scene.children.isEmpty)
        // 没有命中图的外观（爱心皮肤）不画
        #expect(UnitSprites.impact(.init(shape: .heart, color: .coral)) == nil)
        #expect(UnitSprites.impact(DefenderKind.starling.projectile) != nil)
    }

    @Test func fumeBeamHitsOnceAtTheSameMomentAndCleansUp() throws {
        let clock = try SceneClock()
        var impacts: [Bool] = []
        BeamAttack().perform(from: CGPoint(x: 80, y: 120), to: CGPoint(x: 700, y: 120),
                             projectile: DefenderKind.stroke.projectile, in: clock.scene) { impacts.append($0) }
        let fume = try #require(clock.scene.childNode(withName: "fume") as? SKSpriteNode)
        #expect(fume.size.width > 600)
        #expect(impacts.isEmpty)
        try clock.advance(seconds: 0.15)
        #expect(impacts == [true])
        try clock.advance(seconds: 1)
        #expect(impacts == [true])
        #expect(clock.scene.children.isEmpty)
    }

    #if os(macOS)
    /// 导出一张动画分解图目检：COMBAT_PREVIEW=/path/to/preview.png swift test --filter exportPreview
    @Test func exportPreview() throws {
        guard let path = ProcessInfo.processInfo.environment["COMBAT_PREVIEW"] else { return }
        let clock = try SceneClock(size: CGSize(width: 1200, height: 640))
        clock.setBackground(red: 0.45, green: 0.66, blue: 0.3)
        let scene = clock.scene
        func label(_ text: String, _ x: CGFloat, _ y: CGFloat) {
            let node = SKLabelNode(fontNamed: "PingFangSC-Semibold")
            node.text = text
            node.fontSize = 18
            node.position = CGPoint(x: x, y: y)
            scene.addChild(node)
        }
        // 上排：豌豆从嘴里平着飞出、打中溅开；大喷菇喷烟
        for (row, kind) in [DefenderKind.inkling, .stroke].enumerated() {
            let y = CGFloat(540 - row * 130)
            let plant = DefenderNode(kind: kind, radius: 34)
            plant.position = CGPoint(x: 90, y: y)
            scene.addChild(plant)
            let zombie = EnemyNode(id: row, kind: .blob, sign: "打", lane: 0, scale: 1)
            zombie.position = CGPoint(x: 560, y: y)
            scene.addChild(zombie)
            plant.shoot()
            plant.attack.perform(from: plant.muzzle, to: CGPoint(x: 560, y: plant.muzzle.y),
                                 projectile: kind.projectile, in: scene) { _ in }
        }
        // 下排：各种僵尸的啃咬、掉防具、倒下、烧焦
        let poses: [(EnemyKind, String)] = [(.armored, "铁桶"), (.armored, "掉防具"), (.king, "啃咬"),
                                            (.blob, "掉头倒下"), (.dasher, "倒下"), (.drowsy, "烧焦")]
        var zombies: [EnemyNode] = []
        for (index, pose) in poses.enumerated() {
            let zombie = EnemyNode(id: 10 + index, kind: pose.0, sign: "字", lane: 0, scale: 1)
            zombie.position = CGPoint(x: 110 + CGFloat(index) * 190, y: 150)
            scene.addChild(zombie)
            label(pose.1, zombie.position.x, 40)
            zombies.append(zombie)
        }
        zombies[1].health.take(1)
        zombies[1].showWound()
        zombies[2].lunge()
        zombies[3].defeat()
        zombies[4].defeat()
        zombies[5].defeat(burnt: true)
        try clock.advance(seconds: 0.32)

        let width = 1200, height = 640
        let bitmap = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: width * 4, bitsPerPixel: 32))
        let bytes = try #require(bitmap.bitmapData)
        clock.texture.getBytes(bytes, bytesPerRow: width * 4, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        // Metal 渲染目标是 BGRA，PNG 位图使用 RGBA
        for pixel in 0..<(width * height) {
            let blue = bytes[pixel * 4]
            bytes[pixel * 4] = bytes[pixel * 4 + 2]
            bytes[pixel * 4 + 2] = blue
        }
        try #require(bitmap.representation(using: .png, properties: [:])).write(to: URL(fileURLWithPath: path))
    }
    #endif
}
