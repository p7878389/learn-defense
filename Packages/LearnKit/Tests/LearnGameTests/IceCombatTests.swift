import LearnCore
import SpriteKit
import Testing
import Metal
#if os(macOS)
import AppKit
#endif
@testable import LearnGame

@Suite("冰晶战斗视觉")
@MainActor
struct IceCombatTests {
    @Test func cosmeticEquipsWithoutChangingCombatRulesAndCanBeRemoved() throws {
        let catalog = GrowthCatalog.bundled
        let ice = try #require(catalog.cosmetic(id: "projectile.iceCrystal"))
        let store = GrowthStore(catalog: catalog)
        #expect(store.equip(ice))
        #expect(store.loadout.projectile(for: .inkling).shape == .gem)
        #expect(store.loadout.projectile(for: .inkling).color == .sky)
        #expect(store.loadout.projectile(for: .frost) == DefenderKind.frost.projectile)
        #expect(store.loadout.projectile(for: .starling) == DefenderKind.starling.projectile)
        store.unequip(key: "projectile")
        #expect(store.loadout.projectile(for: .inkling) == DefenderKind.inkling.projectile)
    }

    @Test func plantedAuraFollowsEffectiveLoadout() throws {
        let ice = Loadout(projectile: .init(shape: .gem, color: .sky))
        for (loadout, expected) in [(Loadout.standard, false), (ice, true)] {
            let scene = GameScene(tuning: .make(grade: .g3, difficulty: .normal), theme: .academy, loadout: loadout)
            #expect(scene.plant(.inkling, at: CGPoint(x: 190, y: 70)))
            let defender = try #require(scene.children.compactMap { $0 as? DefenderNode }.first)
            #expect((defender.childNode(withName: "iceAura") != nil) == expected)
        }
    }

    @Test func iceVolleyKeepsImpactOrderAndCleansTransientEffects() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let renderer = SKRenderer(device: device)
        let scene = SKScene(size: CGSize(width: 700, height: 300))
        renderer.scene = scene
        scene.isPaused = false
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: 700, height: 300, mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead]
        let texture = try #require(device.makeTexture(descriptor: descriptor))
        let queue = try #require(device.makeCommandQueue())
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        let start = CACurrentMediaTime()
        func frame(_ index: Int) throws {
            renderer.update(atTime: start + Double(index) / 60)
            let command = try #require(queue.makeCommandBuffer())
            renderer.render(withViewport: CGRect(origin: .zero, size: scene.size), commandBuffer: command, renderPassDescriptor: pass)
            command.commit()
            command.waitUntilCompleted()
        }
        try frame(0)
        var impacts: [Bool] = []
        ShotAttack(count: 2).perform(from: CGPoint(x: 50, y: 100), to: CGPoint(x: 650, y: 100),
                                    projectile: .init(shape: .gem, color: .sky), in: scene) { impacts.append($0) }
        #expect(impacts.isEmpty)
        #expect(scene.children.contains { $0.childNode(withName: "iceTrail") != nil })
        #expect(scene.children.compactMap { $0.childNode(withName: "iceTrail") as? SKEmitterNode }
            .allSatisfy { $0.particleBirthRate == 0 }, "延迟发射前不产生拖尾")
        // 闪退回归：尾迹不能用 targetNode，也不能在帧更新途中被挪出子弹（11-06 iPad EXC_BAD_ACCESS）
        func trailsStayOnBullets() -> Bool {
            scene.childNode(withName: "iceTrail") == nil
                && scene.children.compactMap { $0.childNode(withName: "iceTrail") as? SKEmitterNode }
                    .allSatisfy { $0.targetNode == nil }
        }
        #expect(trailsStayOnBullets())
        for index in 1...12 { try frame(index); #expect(trailsStayOnBullets()) }
        #expect(impacts.isEmpty, "视觉不能提前结算命中")
        for index in 13...45 { try frame(index); #expect(trailsStayOnBullets()) }
        #expect(impacts == [false, true])
        for index in 46...180 { try frame(index) }
        #expect(scene.children.isEmpty, "子弹、残留拖尾、爆点都必须清理")

        #if os(macOS)
        // 可选导出真实渲染结果，沿用项目已有的预览测试约定。
        if let path = ProcessInfo.processInfo.environment["ICE_COMBAT_PREVIEW"] {
            scene.backgroundColor = SKColor(red: 0.08, green: 0.15, blue: 0.22, alpha: 1)
            pass.colorAttachments[0].clearColor = MTLClearColor(red: 0.08, green: 0.15, blue: 0.22, alpha: 1)
            for (row, kind) in [DefenderKind.inkling, .frost].enumerated() {
                let y = CGFloat(200 - row * 120)
                let look = row == 0 ? ProjectileLook(shape: .gem, color: .sky, size: 13) : kind.projectile
                let defender = DefenderNode(kind: kind, radius: 34)
                defender.position = CGPoint(x: 80, y: y)
                IceCombatEffects.decorate(defender, projectile: look, radius: 34)
                scene.addChild(defender)
                let enemy = EnemyNode(id: row, kind: .blob, sign: "冰", lane: row, scale: 1)
                enemy.position = CGPoint(x: 600, y: y)
                scene.addChild(enemy)
                let label = SKLabelNode(fontNamed: "PingFangSC-Semibold")
                label.text = row == 0 ? "冰晶皮肤 · 光环 / 尾迹 / 碎晶爆点" : "寒冰射手 · 保留原有减速能力"
                label.fontSize = 17
                label.position = CGPoint(x: 350, y: y + 50)
                scene.addChild(label)
                ShotAttack(count: 2).perform(from: CGPoint(x: 115, y: y), to: CGPoint(x: 600, y: y),
                                            projectile: look, in: scene) { _ in }
            }
            for index in 181...201 { try frame(index) }
            let bitmap = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 700, pixelsHigh: 300,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 2800, bitsPerPixel: 32))
            let bytes = try #require(bitmap.bitmapData)
            texture.getBytes(bytes, bytesPerRow: 2800, from: MTLRegionMake2D(0, 0, 700, 300), mipmapLevel: 0)
            // Metal 渲染目标是 BGRA，PNG 位图使用 RGBA。
            for pixel in 0..<(700 * 300) {
                let blue = bytes[pixel * 4]
                bytes[pixel * 4] = bytes[pixel * 4 + 2]
                bytes[pixel * 4 + 2] = blue
            }
            try #require(bitmap.representation(using: .png, properties: [:])).write(to: URL(fileURLWithPath: path))
        }
        #endif
    }
}
