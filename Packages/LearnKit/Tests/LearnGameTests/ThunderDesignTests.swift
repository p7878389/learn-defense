import LearnCore
import SpriteKit
import Testing
#if os(macOS)
import AppKit
import SwiftUI
#endif
@testable import LearnGame

@Suite("雷霆大招")
@MainActor
struct ThunderDesignTests {
    @Test func artworkKeepsTransparencyAndSharesBoundedTextures() throws {
        let limits: [(ThunderArtwork.Asset, Int)] = [(.button, 1024), (.clouds, 1536), (.lightning, 1024), (.impact, 768)]
        var decodedBytes = 0
        for (asset, limit) in limits {
            let image = try #require(ThunderArtwork.image(asset))
            #expect(max(image.width, image.height) <= limit)
            #expect(image.alphaInfo == .premultipliedLast || image.alphaInfo == .premultipliedFirst
                    || image.alphaInfo == .first || image.alphaInfo == .last)
            decodedBytes += image.width * image.height * 4
            let texture = try #require(ThunderArtwork.texture(asset))
            #expect(texture === ThunderArtwork.texture(asset), "多目标与连续大招共享纹理，避免重复创建")
        }
        #expect(decodedBytes <= 8 * 1024 * 1024, "四张素材的解码像素控制在 8 MiB 内，不含 GPU 副本")
    }

    @Test func castRendersCloudBoltAndImpactFromPackagedArtwork() throws {
        let scene = GameScene(tuning: .make(grade: .g3, difficulty: .normal), theme: .academy)
        let log = DefeatLog()
        scene.gameDelegate = log
        _ = scene.spawn(EnemySpawn(id: 1, sign: "春", kind: .goblin), lane: 2, x: 800)
        scene.unleash()
        let effect = try #require(scene.childNode(withName: "ultimateThunder"))
        for name in ["thunderClouds", "thunderBolt", "thunderImpact"] {
            let sprite = try #require(effect.childNode(withName: ".//\(name)") as? SKSpriteNode,
                                      "\(name) 必须使用样片中的透明贴图")
            #expect(sprite.texture != nil)
        }
        advance(scene, seconds: 1.5)
        #expect(effect.parent == nil)
        #expect(log.ids == [1])
    }

    @Test func clearsUnprotectedLanesAndDoesNotDoubleSettle() {
        let scene = GameScene(tuning: .make(grade: .g3, difficulty: .normal), theme: .academy)
        let log = DefeatLog()
        scene.gameDelegate = log
        let enemy = scene.spawn(EnemySpawn(id: 42, sign: "春", kind: .goblin), lane: 2, x: 800)
        scene.unleash()
        #expect(enemy.doomed)
        #expect(enemy.health.current == 0)
        #expect(log.ids.isEmpty, "视觉消散结束前不能触发回合暂停")
        advance(scene, seconds: 1.5)
        #expect(log.ids == [42])
        scene.unleash()
        #expect(log.ids == [42])
        #expect(scene.enemies(inLane: 2).isEmpty)
    }

    @Test func skipsAlreadyDoomedEnemiesAndDefeatsBosses() {
        let scene = GameScene(tuning: .make(grade: .g3, difficulty: .normal), theme: .academy)
        let log = DefeatLog()
        scene.gameDelegate = log
        let claimed = scene.spawn(EnemySpawn(id: 1, sign: "春", kind: .goblin), lane: 0, x: 750)
        claimed.doomed = true // 已由另一颗飞行中的子弹负责结算。
        let boss = scene.spawn(EnemySpawn(id: 2, sign: "秋", kind: .ogre), lane: 3, x: 900)
        scene.unleash()
        advance(scene, seconds: 1.5)
        #expect(log.ids == [2])
        #expect(boss.health.current == 0)
        #expect(claimed.health.current == 1)
        #expect(scene.enemies(inLane: 0).map(\.enemyID) == [1])
    }

    @Test func holdsVictimUntilImpactAndCleansUpBeforeRoundPauses() {
        let scene = GameScene(tuning: .make(grade: .g3, difficulty: .normal), theme: .academy)
        let log = DefeatLog()
        log.onDefeat = { scene.setGamePaused(true) }
        scene.gameDelegate = log
        let enemy = scene.spawn(EnemySpawn(id: 1, sign: "春", kind: .goblin), lane: 2, x: 800)
        scene.unleash()
        advance(scene, seconds: 0.15)
        #expect(enemy.parent === scene, "聚云期间保留怪物，命中才消散")
        #expect(log.ids.isEmpty)
        advance(scene, seconds: 0.55, from: 0.15)
        #expect(enemy.parent == nil, "雷击命中时移除原怪物，由蓝色残影接替")
        scene.setGamePaused(true)
        advance(scene, seconds: 2, from: 0.7)
        #expect(log.ids.isEmpty, "主动暂停期间不得提前结算")
        scene.setGamePaused(false)
        advance(scene, seconds: 1, from: 2.7)
        #expect(log.ids == [1])
        #expect(scene.gamePaused)
        #expect(scene.childNode(withName: "ultimateThunder") == nil, "最后一个目标结算导致暂停时，雷云与残影已清理")
    }

    private func advance(_ scene: GameScene, seconds: Double, from start: Double = 0) {
        if start == 0 { scene.update(10) }
        for frame in 1...Int((seconds * 60).rounded()) {
            scene.update(10 + start + Double(frame) / 60)
        }
    }

    #if os(macOS)
    /// 导出真实 SpriteKit / SwiftUI 画面，供设计验收；不把生成概念图当运行效果。
    @Test func renderDesignPreview() throws {
        guard let folder = ProcessInfo.processInfo.environment["LEARN_THUNDER_PREVIEW"] else { return }
        let scene = GameScene(tuning: .make(grade: .g3, difficulty: .normal), theme: .academy)
        let view = SKView(frame: CGRect(origin: .zero, size: scene.size))
        scene.didMove(to: view)
        _ = scene.plant(.inkling, in: DefenderCell(lane: 2, column: 0))
        _ = scene.spawn(EnemySpawn(id: 1, sign: "春", kind: .goblin), lane: 1, x: 700)
        _ = scene.spawn(EnemySpawn(id: 2, sign: "秋", kind: .goblin), lane: 3, x: 880)
        let log = DefeatLog()
        log.onDefeat = { if log.ids.count == 2 { scene.setGamePaused(true) } }
        defer { log.onDefeat = nil }
        scene.gameDelegate = log
        // 使用生产 unleash/update，按 24 fps 导出完整过程，不能另造一张命中特效。
        let directory = URL(fileURLWithPath: folder).appendingPathComponent("frames")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        scene.update(10)
        scene.unleash()
        for frame in 0...36 {
            if frame > 0 { scene.update(10 + Double(frame) / 24) }
            let texture = try #require(view.texture(from: scene, crop: CGRect(origin: .zero, size: scene.size)))
            let bitmap = NSBitmapImageRep(cgImage: texture.cgImage())
            let data = try #require(bitmap.representation(using: .png, properties: [:]))
            try data.write(to: directory.appendingPathComponent(String(format: "%03d.png", frame)))
            if frame == 10 { try data.write(to: URL(fileURLWithPath: folder).appendingPathComponent("runtime-thunder-v2.png")) }
        }
        #expect(log.ids == [1, 2])
        #expect(scene.childNode(withName: "ultimateThunder") == nil)
        let states = HStack(spacing: 24) {
            UltimateButton(energy: 3, maxEnergy: 5, ready: false, action: {})
            UltimateButton(energy: 5, maxEnergy: 5, ready: true, action: {})
            UltimateButton(energy: 0, maxEnergy: 4, ready: false, action: {})
        }.padding(24).background(Theme.paper)
        let renderer = ImageRenderer(content: states)
        renderer.scale = 2
        let image = try #require(renderer.cgImage)
        try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
            .write(to: URL(fileURLWithPath: folder).appendingPathComponent("runtime-charge-v2.png"))
    }
    #endif

    private final class DefeatLog: GameSceneDelegate {
        var ids: [Int] = []
        var onDefeat: (() -> Void)?
        var speedFactor: Double { 1 }
        func nextEnemy() -> EnemySpawn? { nil }
        func targetChanged(to id: Int?) {}
        func enemyReachedBase(_ id: Int) -> Bool { false }
        func enemyDefeated(_ id: Int, at point: CGPoint) { ids.append(id); onDefeat?() }
        func barricadeRemoved() {}
    }
}
