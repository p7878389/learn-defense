import LearnCore
import SpriteKit
import Metal
import ImageIO
import Testing
@testable import LearnGame

@Suite("角色皮肤序列帧")
@MainActor
struct CharacterSkinAnimationTests {
    @Test func onlyIntendedCharactersChangeAndMissingResourcesFallBack() throws {
        for skin in CharacterSkin.allCases {
            let rig = try #require(UnitSprites.defender(.inkling, radius: 34, skin: skin))
            #expect(rig.base == "skin-\(skin.rawValue)-plant-inkling")
            let original = try #require(UnitSprites.defender(.inkling, radius: 34))
            #expect(close(rig.muzzle, original.muzzle))
            #expect(abs(rig.sprite.size.width - original.sprite.size.width) < 0.01)
            #expect(abs(rig.sprite.size.height - original.sprite.size.height) < 0.01)
            // 整株重画的皮肤只有射手；僵尸配它们时整套回退原版
            #expect(UnitSprites.enemy(.blob, skin: skin)?.base == (redrawn.contains(skin) ? "zombie-blob" : "skin-\(skin.rawValue)-zombie-blob"))
            #expect(UnitSprites.enemy(.armored, skin: skin)?.base == "zombie-armored")
            #expect(UnitSprites.defender(.frost, radius: 34, skin: skin)?.base == "plant-frost")
            #expect(UnitSprites.characterName("plant-missing", skin: skin) == "plant-missing")
            #expect(rig.sprite.texture?.filteringMode == (skin == .pixel ? .nearest : .linear))
        }
    }

    @Test func freezeBiteAndDefeatKeepTheirSkin() throws {
        let clock = try SkinClock()
        let zombie = EnemyNode(id: 1, kind: .blob, sign: "春", lane: 0, scale: 1, skin: .party)
        zombie.position = CGPoint(x: 300, y: 160)
        clock.scene.addChild(zombie)
        let sprite = try #require(zombie.childNode(withName: "//unitSprite") as? SKSpriteNode)
        let effects = try #require(zombie.childNode(withName: "//characterSkinEffects"))
        try clock.advance(seconds: 0.2)
        zombie.slow(factor: 0, seconds: 3)
        let frozen = sprite.texture
        let confettiY = try #require(effects.children.first).position.y
        try clock.advance(seconds: 0.4)
        #expect(sprite.texture === frozen)
        #expect(effects.children.first?.position.y == confettiY)
        #expect(effects.speed == 0)
        _ = zombie.advance(dt: 4, speed: 1)
        #expect(effects.speed == 1)
        zombie.lunge()
        #expect(UnitSprites.frames(named: "skin-party-zombie-blob-attack").contains { $0 === sprite.texture })
        try clock.advance(seconds: 0.75)
        #expect(UnitSprites.frames(named: "skin-party-zombie-blob").contains { $0 === sprite.texture })
        zombie.defeat()
        #expect(UnitSprites.frames(named: "skin-party-zombie-blob-die").contains { $0 === sprite.texture })
        try clock.advance(seconds: 1.8)
        #expect(zombie.parent == nil)
    }

    @Test func sceneUsesEquippedSkinAndShotEffectsExpire() throws {
        let scene = GameScene(tuning: GameTuning.make(grade: .g1, difficulty: .easy), theme: .academy,
                              loadout: Loadout(defenderSkins: ["inkling": .pixel, "frost": .bamboo]))
        let planted = scene.plant(.inkling, in: DefenderCell(lane: 0, column: 0))
        #expect(planted)
        let defender = try #require(scene.children.compactMap { $0 as? DefenderNode }.first)
        let sprite = try #require(defender.childNode(withName: "unitSprite") as? SKSpriteNode)
        #expect(UnitSprites.frames(named: "skin-pixel-plant-inkling").contains { $0 === sprite.texture })
        let clock = try SkinClock()
        let shooter = DefenderNode(kind: .inkling, radius: 34, skin: .pixel)
        clock.scene.addChild(shooter)
        let initial = shooter.children.count
        shooter.shoot()
        #expect(shooter.childNode(withName: "skinMuzzleFlash") != nil)
        try clock.advance(seconds: 0.5)
        #expect(shooter.childNode(withName: "skinMuzzleFlash") == nil)
        #expect(shooter.children.count == initial)
    }

    /// 导出真正的 SpriteKit 动画，用于目检衣帽、粒子、攻击以及节点缩放组合。
    @Test func renderRuntimeComparison() throws {
        let width = CGFloat(CharacterSkin.allCases.count + 1) * 350
        let clock = try SkinClock(size: CGSize(width: width, height: 570))
        clock.scene.backgroundColor = SKColor(red: 0.97, green: 0.96, blue: 0.93, alpha: 1)
        var shooters: [DefenderNode] = []
        var zombies: [EnemyNode] = []
        for (index, skin) in ([nil] + CharacterSkin.allCases.map { Optional($0) }).enumerated() {
            let x = CGFloat(index) * 350 + 175
            let shooter = DefenderNode(kind: .inkling, radius: 68, skin: skin)
            shooter.position = CGPoint(x: x, y: 400)
            clock.scene.addChild(shooter)
            shooters.append(shooter)
            let zombie = EnemyNode(id: index, kind: .blob, sign: "春", lane: 0, scale: 1.85, skin: skin)
            zombie.position = CGPoint(x: x, y: 120)
            clock.scene.addChild(zombie)
            zombies.append(zombie)
            let label = SKLabelNode(fontNamed: "PingFangSC-Semibold")
            label.text = ["经典原版", "软糖派对", "像素方块", "竹筒小侠", "方块工匠", "弹弹蛋"][index]
            label.fontColor = SKColor(red: 0.15, green: 0.25, blue: 0.21, alpha: 1)
            label.fontSize = 25
            label.position = CGPoint(x: x, y: 525)
            clock.scene.addChild(label)
        }
        try clock.advance(seconds: 0.1)
        #expect(clock.texture.width == Int(width))
        guard let folder = ProcessInfo.processInfo.environment["LEARN_DEFENSE_SKIN_PREVIEW"] else { return }
        let url = URL(fileURLWithPath: folder).appendingPathComponent("runtime.gif")
        let gif = try #require(CGImageDestinationCreateWithURL(url as CFURL, "com.compuserve.gif" as CFString, 40, nil))
        CGImageDestinationSetProperties(gif, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        for frame in 0..<40 {
            if frame == 14 { shooters.forEach { $0.shoot() }; zombies.forEach { $0.lunge() } }
            try clock.advance(seconds: 0.08)
            let bitmap = try clock.snapshot()
            if frame == 6 {
                let png = try #require(CGImageDestinationCreateWithURL(URL(fileURLWithPath: folder).appendingPathComponent("runtime.png") as CFURL, "public.png" as CFString, 1, nil))
                CGImageDestinationAddImage(png, bitmap, nil)
                #expect(CGImageDestinationFinalize(png))
            }
            CGImageDestinationAddImage(gif, bitmap, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 0.08]] as CFDictionary)
        }
        #expect(CGImageDestinationFinalize(gif))
    }

    /// 植物卡、拖动预览、收藏馆卡片：穿着皮肤的第一帧；这种射手还没有这套素材时是原版
    @Test func portraitsFollowEquippedSkin() throws {
        let bamboo = try #require(UnitSprites.portrait(of: .inkling, skin: .bamboo))
        let original = try #require(UnitSprites.portrait(of: .inkling, skin: nil))
        #expect(bamboo.width == original.width * 3)
        let frost = try #require(UnitSprites.portrait(of: .frost, skin: .bamboo))
        let frostOriginal = try #require(UnitSprites.portrait(of: .frost, skin: nil))
        #expect(frost.width == frostOriginal.width)
        #expect(UnitSprites.defender(.frost, radius: 34, skin: .bamboo)?.base == "plant-frost")
    }

    /// 收藏馆试穿：每种皮肤、每个角色的舞台身份各不相同，切换时 SpriteView 才会换成新场景
    @Test func previewStageIdentityFollowsSkinAndRole() {
        let skins: [CharacterSkin?] = [nil] + CharacterSkin.allCases.map { Optional($0) }
        let ids = UnitCatalog.defenders.filter(\.canShoot).flatMap { kind in skins.map { CharacterSkinPreview.stageID(kind: kind, skin: $0, enemy: false) } }
            + skins.map { CharacterSkinPreview.stageID(skin: $0, enemy: true) }
        #expect(Set(ids).count == ids.count)
    }

    /// 整株重画的皮肤：画布放大 3 倍更清晰，但比例、节奏和子弹出口与原版一致
    @Test func redrawnSkinsKeepPlacementAndTiming() throws {
        let original = try #require(UnitSprites.clip(named: "plant-inkling"))
        for skin in redrawn {
            let name = "skin-\(skin.rawValue)-plant-inkling"
            let clip = try #require(UnitSprites.clip(named: name))
            #expect(clip.frameCount == original.frameCount)
            #expect(clip.frameTime == original.frameTime)
            #expect(clip.crop == original.crop.map { $0 * 3 })
            #expect(clip.muzzle == original.muzzle?.map { $0 * 3 })
            let frames = UnitSprites.frames(named: name)
            #expect(frames.count == original.frameCount)
            #expect(Set(frames.map { ObjectIdentifier($0) }).count == frames.count)
            let zombie = EnemyNode(id: 0, kind: .blob, sign: "春", lane: 0, scale: 1, skin: skin)
            #expect(zombie.childNode(withName: "//characterSkinEffects") == nil)
            let shooter = DefenderNode(kind: .inkling, radius: 34, skin: skin)
            #expect(shooter.childNode(withName: "characterSkinEffects") != nil)
        }
    }

    @Test func everySkinnedStateKeepsOriginalAlignmentAndTiming() throws {
        for style in ["party", "pixel"] {
            for source in ["plant-inkling", "zombie-blob", "zombie-blob-attack", "zombie-blob-die", "zombie-head", "zombie-boom"] {
                let original = try #require(UnitSprites.clip(named: source))
                let name = "skin-\(style)-\(source)"
                let skinned = try #require(UnitSprites.clip(named: name))
                #expect(skinned.frameCount == original.frameCount)
                #expect(skinned.frameTime == original.frameTime)
                #expect(skinned.crop == original.crop)
                #expect(skinned.canvas == original.canvas)
                #expect(skinned.pivot == original.pivot)
                #expect(skinned.muzzle == original.muzzle)
                #expect(UnitSprites.frames(named: name).count == original.frameCount)
                for (state, target) in original.states ?? [:] {
                    #expect(UnitSprites.state(state, of: name) == "skin-\(style)-\(target)")
                }
            }
        }
    }
}

/// 整株重画、只有射手的皮肤
private let redrawn: [CharacterSkin] = [.bamboo, .voxel, .egg]

private func close(_ a: CGPoint?, _ b: CGPoint?) -> Bool {
    guard let a, let b else { return a == nil && b == nil }
    return abs(a.x - b.x) < 0.001 && abs(a.y - b.y) < 0.001
}

/// 真正推进 SKAction 并等待 Metal 完成，不依赖窗口或模拟器。
@MainActor
private final class SkinClock {
    let scene: SKScene
    let texture: MTLTexture
    private let renderer: SKRenderer
    private let queue: MTLCommandQueue
    private let pass = MTLRenderPassDescriptor()
    private let start = CACurrentMediaTime()
    private var frame = 0

    init(size: CGSize = CGSize(width: 600, height: 360)) throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        scene = SKScene(size: size)
        renderer = SKRenderer(device: device)
        renderer.scene = scene
        queue = try #require(device.makeCommandQueue())
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm,
            width: Int(size.width), height: Int(size.height), mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .shared
        texture = try #require(device.makeTexture(descriptor: descriptor))
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 0.97, green: 0.96, blue: 0.93, alpha: 1)
        try advance(seconds: 0)
    }

    func advance(seconds: Double) throws {
        for _ in 0..<max(1, Int((seconds * 60).rounded())) {
            renderer.update(atTime: start + Double(frame) / 60)
            let command = try #require(queue.makeCommandBuffer())
            renderer.render(withViewport: CGRect(origin: .zero, size: scene.size), commandBuffer: command, renderPassDescriptor: pass)
            command.commit()
            command.waitUntilCompleted()
            frame += 1
        }
    }

    func snapshot() throws -> CGImage {
        let row = texture.width * 4
        var bytes = [UInt8](repeating: 0, count: row * texture.height)
        texture.getBytes(&bytes, bytesPerRow: row, from: MTLRegionMake2D(0, 0, texture.width, texture.height), mipmapLevel: 0)
        let provider = try #require(CGDataProvider(data: Data(bytes) as CFData))
        return try #require(CGImage(width: texture.width, height: texture.height, bitsPerComponent: 8,
            bitsPerPixel: 32, bytesPerRow: row, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
    }
}
