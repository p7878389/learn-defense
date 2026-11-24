import LearnCore
import SpriteKit
import Metal
import ImageIO
import Testing
@testable import LearnGame

@Suite("角色皮肤序列帧")
@MainActor
struct CharacterSkinAnimationTests {

    @Test func freezeBiteAndDefeatKeepTheirSkin() throws {
        let clock = try SkinClock()
        let zombie = EnemyNode(id: 1, kind: .blob, sign: "春", lane: 0, scale: 1, skin: .spellbook)
        zombie.position = CGPoint(x: 300, y: 160)
        clock.scene.addChild(zombie)
        let sprite = try #require(zombie.childNode(withName: "//unitSprite") as? SKSpriteNode)
        #expect(zombie.childNode(withName: "//characterSkinEffects") == nil)
        try clock.advance(seconds: 0.2)
        zombie.slow(factor: 0, seconds: 3)
        let frozen = sprite.texture
        try clock.advance(seconds: 0.4)
        #expect(sprite.texture === frozen)
        _ = zombie.advance(dt: 4, speed: 1)
        zombie.lunge()
        #expect(UnitSprites.frames(named: "zombie-blob-attack").contains { $0 === sprite.texture })
        try clock.advance(seconds: 0.75)
        #expect(UnitSprites.frames(named: "zombie-blob").contains { $0 === sprite.texture })
        zombie.defeat()
        #expect(UnitSprites.frames(named: "zombie-blob-die").contains { $0 === sprite.texture })
        try clock.advance(seconds: 1.8)
        #expect(zombie.parent == nil)
    }

    /// 导出真正的 SpriteKit 动画，用于目检衣帽、粒子、攻击以及节点缩放组合。
    @Test func renderRuntimeComparison() throws {
        let width = CGFloat(CharacterSkin.allCases.count + 1) * 350
        let clock = try SkinClock(size: CGSize(width: width, height: 570))
        clock.setBackground(red: 0.97, green: 0.96, blue: 0.93)
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
            label.text = skin.flatMap { GrowthCatalog.bundled.cosmetic(id: "defender.\($0.rawValue)")?.name } ?? "经典原版"
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

    /// 退役萤火皮肤后，场景连对计数与正常种植仍然有效。
    @Test func sceneTracksAnswerStreak() throws {
        let scene = GameScene(tuning: GameTuning.make(grade: .g1, difficulty: .easy), theme: .academy,
                              loadout: Loadout(defenderSkins: ["inkling": .spellbook]))
        scene.noteCorrectAnswer()
        scene.noteCorrectAnswer()
        scene.noteCorrectAnswer()
        #expect(scene.answerStreak == 3)
        #expect(scene.plant(.inkling, in: DefenderCell(lane: 0, column: 0)))
        let shooter = try #require(scene.children.compactMap { $0 as? DefenderNode }.first)
        #expect(shooter.childNode(withName: "spellbookSkin") != nil)
        scene.penalize(42)
        #expect(scene.answerStreak == 0)
    }

    /// 收藏馆试穿：每种皮肤、每个角色的舞台身份各不相同，切换时 SpriteView 才会换成新场景
    @Test func previewStageIdentityFollowsSkinAndRole() {
        let skins: [CharacterSkin?] = [nil] + CharacterSkin.allCases.map { Optional($0) }
        let ids = UnitCatalog.defenders.filter(\.canShoot).flatMap { kind in skins.map { CharacterSkinPreview.stageID(kind: kind, skin: $0, enemy: false) } }
            + skins.map { CharacterSkinPreview.stageID(skin: $0, enemy: true) }
        #expect(Set(ids).count == ids.count)
    }

}

private func close(_ a: CGPoint?, _ b: CGPoint?) -> Bool {
    guard let a, let b else { return a == nil && b == nil }
    return abs(a.x - b.x) < 0.001 && abs(a.y - b.y) < 0.001
}

private typealias SkinClock = SceneClock
