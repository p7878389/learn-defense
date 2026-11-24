import LearnCore
import Metal
import ImageIO
import SpriteKit
import Testing
@testable import LearnGame

@Suite("资源主题皮肤运行", .serialized)
@MainActor
struct ThemeSkinTests {
    @Test(arguments: ["mecha", "teapot", "emerald", "astral", "frost", "festival"])
    func artworkAnimatesAndRecovers(id: String) throws {
        let skin = try #require(CharacterSkin(rawValue: id))
        let clock = try ThemeClock()
        let unit = DefenderNode(kind: .inkling, radius: 34, skin: skin)
        unit.position = CGPoint(x: 120, y: 150)
        clock.scene.addChild(unit)
        let root = try #require(unit.childNode(withName: "themeSkin"))
        let part = try #require(root.childNode(withName: "//movingPart"))
        let caster = try #require(root.childNode(withName: "//caster"))
        let muzzle = try #require(root.childNode(withName: "//muzzle"))
        #expect(unit.childNode(withName: "unitSprite") == nil)
        #expect(UnitSprites.portrait(of: DefenderKind.inkling, skin: skin) !== UnitSprites.portrait(of: DefenderKind.inkling, skin: nil))
        #expect(DefenderNode(kind: .frost, radius: 34, skin: skin).childNode(withName: "themeSkin") == nil)
        #expect(UnitSprites.enemy(.blob, skin: skin)?.base == "zombie-blob")
        try clock.advance(0.2)
        let idle = part.position
        unit.shoot()
        try clock.advance(0.1)
        #expect(hypot(part.position.x-idle.x, part.position.y-idle.y) > 0.5)
        let point = muzzle.convert(CGPoint.zero, to: clock.scene)
        #expect(hypot(unit.muzzle.x-point.x, unit.muzzle.y-point.y) < 0.001)
        unit.hurt(); try clock.advance(0.06)
        unit.shoot(); try clock.advance(0.7)
        #expect(abs(caster.xScale-1) < 0.001)
        #expect(abs(caster.yScale-1) < 0.001)
        #expect(abs(caster.zRotation) < 0.001)
        #expect(unit.position == CGPoint(x: 120, y: 150))
    }

    @Test(arguments: ["mecha", "teapot", "emerald", "astral", "frost", "festival"], [false, true])
    func shotsRespectOverrideAndCleanUp(id: String, override: Bool) throws {
        let skin = try #require(CharacterSkin(rawValue: id))
        let clock = try ThemeClock()
        let unit = DefenderNode(kind: .inkling, radius: 34, skin: skin)
        clock.scene.addChild(unit)
        let look = override ? ProjectileLook(shape: .gem, color: .sky, size: 13) : DefenderKind.inkling.projectile
        var hits: [Bool] = []
        unit.attack?.perform(from: CGPoint(x: 80,y: 150), to: CGPoint(x: 500,y: 150), projectile: look, in: clock.scene) { hits.append($0) }
        let bullet = WeakBox(clock.scene.childNode(withName: "themeProjectile"))
        #expect((bullet.value != nil) == !override)
        if override { #expect(clock.scene.childNode(withName: "//iceTrail") != nil) }
        try clock.advance(0.1)
        #expect(hits.isEmpty)
        try clock.advance(1.5)
        #expect(hits == [true])
        #expect(bullet.value == nil)
        #expect(clock.scene.children.count == 1)
        unit.crumble(); try clock.advance(1.2)
        #expect(clock.scene.children.isEmpty)
    }

    @Test(arguments: ["mecha", "teapot", "emerald", "astral", "frost", "festival"])
    func battleDamagePauseAndPreview(id: String) throws {
        let skin = try #require(CharacterSkin(rawValue: id))
        let scene = GameScene(tuning: .make(grade: .g3,difficulty: .normal),theme: .academy,
                              loadout: Loadout(defenderSkins: ["inkling": skin]))
        let clock = try ThemeClock(scene: scene)
        let log = ThemeDefeats(); scene.gameDelegate = log
        scene.setGamePaused(true, keepingAnimations: true)
        #expect(scene.plant(.inkling, in: DefenderCell(lane: 0,column: 0)))
        let enemy = scene.spawn(EnemySpawn(id: 91,sign: "云",kind: .armored),lane: 0,x: 620)
        try clock.advance(0.2)
        #expect(scene.fire(at: 91) == false)
        #expect(enemy.health.current == 1)
        try clock.advance(0.08)
        scene.setGamePaused(true)
        try clock.advance(0.05)
        let pixels = clock.pixels()
        try clock.advance(0.5)
        #expect(pixels == clock.pixels())
        #expect(log.ids.isEmpty)
        scene.setGamePaused(true, keepingAnimations: true)
        try clock.advance(1.5)
        #expect(scene.fire(at: 91) == true)
        try clock.advance(1.5)
        #expect(log.ids == [91])
        #expect(scene.fire(at: 91) == nil)
        let preview = CharacterSkinPreviewScene(kind: .inkling,skin: skin,enemy: false)
        let previewClock = try ThemeClock(scene: preview)
        let unit = try #require(preview.children.compactMap { $0 as? DefenderNode }.first)
        for _ in 0..<150 {
            try previewClock.advance(1.0/60)
            let bounds = unit.calculateAccumulatedFrame()
            #expect(bounds.minX >= 0 && bounds.maxX <= preview.size.width)
            #expect(bounds.minY >= 0 && bounds.maxY <= preview.size.height)
        }
        try previewClock.advance(1)
        #expect(preview.childNode(withName: "themeProjectile") == nil)
        #expect(preview.children.count == 2)
    }
    @Test(arguments: ["mecha", "teapot", "emerald", "astral", "frost", "festival"])
    func renderRuntime(id: String) throws {
        guard let path = ProcessInfo.processInfo.environment["LEARN_THEME_PREVIEW"] else { return }
        let skin = try #require(CharacterSkin(rawValue: id))
        let output = URL(fileURLWithPath: path).appendingPathComponent(id)
        try FileManager.default.createDirectory(at: output,withIntermediateDirectories: true)
        let scene = GameScene(tuning: .make(grade: .g3,difficulty: .normal),theme: .academy,
                              loadout: Loadout(defenderSkins: ["inkling": skin]))
        let view = SKView(frame: CGRect(origin: .zero,size: scene.size));scene.didMove(to: view)
        scene.setGamePaused(true,keepingAnimations: true)
        #expect(scene.plant(.inkling,in: DefenderCell(lane: 1,column: 1)))
        #expect(scene.children.compactMap { $0 as? DefenderNode }.first?.childNode(withName: "themeSkin") != nil)
        _ = scene.spawn(EnemySpawn(id: 101,sign: "云",kind: .armored),lane: 1,x: 680)
        let clock = try ThemeClock(scene: scene)
        for frame in 0..<120 {
            if frame == 20 { #expect(scene.fire(at: 101) == false) }
            if frame == 70 { #expect(scene.fire(at: 101) == true) }
            try clock.advance(1.0/30)
            try clock.writePNG(to: output.appendingPathComponent(String(format: "%03d.png",frame)))
        }
        let preview = CharacterSkinPreviewScene(kind: .inkling,skin: skin,enemy: false)
        let previewClock = try ThemeClock(scene: preview)
        let frames = output.appendingPathComponent("preview")
        try FileManager.default.createDirectory(at: frames,withIntermediateDirectories: true)
        for frame in 0..<105 {
            try previewClock.advance(1.0/30)
            try previewClock.writePNG(to: frames.appendingPathComponent(String(format: "%03d.png",frame)))
        }
    }

}

typealias ThemeClock = SceneClock

@MainActor
final class ThemeDefeats: GameSceneDelegate {
    var ids: [Int] = []
    var speedFactor: Double { 1 }
    func nextEnemy() -> EnemySpawn? { nil }
    func targetChanged(to id: Int?) {}
    func enemyReachedBase(_ id: Int) -> Bool { false }
    func enemyDefeated(_ id: Int, at point: CGPoint) { ids.append(id) }
    func barricadeRemoved() {}
}
