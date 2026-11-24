import LearnCore
import Metal
import ImageIO
import SpriteKit
import Testing
@testable import LearnGame

@Suite("星轨魔导书皮肤", .serialized)
@MainActor
struct SpellbookSkinTests {
    @Test func sceneSkinHasIndependentPagesMuzzleAndPortrait() throws {
        let skin = try #require(CharacterSkin(rawValue: "spellbook"))
        let book = DefenderNode(kind: .inkling, radius: 34, skin: skin)
        let root = try #require(book.childNode(withName: "spellbookSkin"))
        #expect(root.childNode(withName: "//leftPage") is SKSpriteNode)
        #expect(root.childNode(withName: "//rightPage") is SKSpriteNode)
        #expect(root.childNode(withName: "//muzzle") != nil)
        #expect(book.childNode(withName: "unitSprite") == nil, "不能在书本下面叠着原版植物")
        let portrait = try #require(UnitSprites.portrait(of: DefenderKind.inkling, skin: skin))
        #expect(portrait !== UnitSprites.portrait(of: DefenderKind.inkling, skin: nil))
        #expect(DefenderNode(kind: .frost, radius: 34, skin: skin).childNode(withName: "spellbookSkin") == nil)
        #expect(UnitSprites.enemy(.blob, skin: skin)?.base == "zombie-blob")
    }

    @Test func pagesAnimateAndRepeatedAttacksRecoverWithoutMovingTheUnit() throws {
        let clock = try BookClock()
        let book = DefenderNode(kind: .inkling, radius: 34, skin: .spellbook)
        book.position = CGPoint(x: 120, y: 150)
        clock.scene.addChild(book)
        let left = try #require(book.childNode(withName: "//leftPage"))
        let caster = try #require(book.childNode(withName: "//caster"))
        let muzzle = try #require(book.childNode(withName: "//muzzle"))
        try clock.advance(0.2)
        let idle = left.zRotation
        book.shoot()
        try clock.advance(0.10)
        #expect(abs(left.zRotation - idle) > 0.04)
        let origin = muzzle.convert(CGPoint.zero, to: clock.scene)
        #expect(hypot(book.muzzle.x - origin.x, book.muzzle.y - origin.y) < 0.001)
        book.shoot()
        try clock.advance(0.6)
        #expect(abs(caster.position.x) < 0.001)
        #expect(abs(caster.zRotation) < 0.001)
        #expect(abs(left.yScale - 1) < 0.001)
        #expect(left.action(forKey: "fxResourceAction") != nil)
        #expect(book.position == CGPoint(x: 120, y: 150))
    }

    @Test(arguments: [false, true])
    func themedShotsKeepCallbacksAndRespectProjectileOverride(override: Bool) throws {
        let clock = try BookClock()
        let book = DefenderNode(kind: .inkling, radius: 34, skin: .spellbook)
        book.position = CGPoint(x: 80, y: 150); clock.scene.addChild(book)
        let attack = try #require(book.attack)
        let look: ProjectileLook = override ? .init(shape: .gem, color: .sky, size: 13) : DefenderKind.inkling.projectile
        var hits: [Bool] = []
        book.shoot()
        attack.perform(from: book.muzzle, to: CGPoint(x: 540, y: 160), projectile: look, in: clock.scene) { hits.append($0) }
        let projectile = WeakBox(clock.scene.childNode(withName: "spellbookProjectile"))
        #expect((projectile.value != nil) == !override)
        if override { #expect(clock.scene.childNode(withName: "//iceTrail") != nil) }
        try clock.advance(0.1)
        #expect(hits.isEmpty)
        try clock.advance(1.2)
        #expect(hits == [true])
        #expect(projectile.value == nil, "星珠移出后应释放，不得被动作闭包保留")
        #expect(clock.scene.children.count == 1)
    }

    @Test func equippedSkinKeepsOneDamageAndOneDefeatPerAnswer() throws {
        let scene = GameScene(tuning: .make(grade: .g3, difficulty: .normal), theme: .academy,
                              loadout: Loadout(defenderSkins: ["inkling": .spellbook]))
        let clock = try BookClock(scene: scene)
        let log = BookDefeats();scene.gameDelegate = log
        scene.setGamePaused(true, keepingAnimations: true)
        #expect(scene.plant(.inkling, in: DefenderCell(lane: 0, column: 0)))
        let enemy = scene.spawn(EnemySpawn(id: 91, sign: "星", kind: .armored), lane: 0, x: 620)
        try clock.advance(0.3)
        #expect(scene.fire(at: 91) == false)
        #expect(enemy.health.current == 1)
        try clock.advance(1)
        #expect(log.ids.isEmpty)
        #expect(scene.fire(at: 91) == true)
        try clock.advance(1)
        #expect(log.ids == [91])
        #expect(scene.fire(at: 91) == nil)
    }

    @Test func previewShowsTheRealProjectileAndDoesNotAccumulateEffects() throws {
        let scene = CharacterSkinPreviewScene(kind: .inkling, skin: .spellbook, enemy: false)
        let clock = try BookClock(scene: scene)
        try clock.advance(2.05)
        #expect(scene.childNode(withName: "spellbookProjectile") != nil)
        try clock.advance(1.6)
        #expect(scene.childNode(withName: "spellbookProjectile") == nil)
        #expect(scene.childNode(withName: "SpellbookImpact") == nil)
    }

    @Test func previewKeepsTheAnimatedBookInsideItsStage() throws {
        let scene = CharacterSkinPreviewScene(kind: .inkling,skin: .spellbook,enemy: false)
        let clock = try BookClock(scene: scene)
        let book = try #require(scene.children.compactMap { $0 as? DefenderNode }.first)
        var leftmost: CGFloat = .greatestFiniteMagnitude
        var rightmost: CGFloat = 0
        for _ in 0..<150 {
            try clock.advance(1.0 / 60)
            let bounds = book.calculateAccumulatedFrame()
            leftmost = min(leftmost,bounds.minX);rightmost = max(rightmost,bounds.maxX)
        }
        #expect(leftmost >= 0, "待机和发射时不能从试看舞台左边裁掉书本或星轨")
        #expect(rightmost <= scene.size.width)
    }

    @Test func shootingAfterAHurtRestoresTheCasterScale() throws {
        let clock = try BookClock()
        let book = DefenderNode(kind: .inkling,radius: 34,skin: .spellbook)
        clock.scene.addChild(book)
        let caster = try #require(book.childNode(withName: "//caster"))
        try clock.advance(0.1)
        book.hurt();try clock.advance(0.06)
        #expect(caster.xScale < 0.99)
        book.shoot();try clock.advance(0.6)
        #expect(abs(caster.xScale-1) < 0.001)
        #expect(abs(caster.yScale-1) < 0.001)
    }

    @Test func pauseFreezesBookAndProjectileUntilResume() throws {
        let scene = GameScene(tuning: .make(grade: .g3, difficulty: .normal), theme: .academy)
        let clock = try BookClock(scene: scene)
        let book = DefenderNode(kind: .inkling, radius: 34, skin: .spellbook)
        book.position = CGPoint(x: 140,y: 150);scene.addChild(book)
        var hits = 0
        book.shoot()
        book.attack?.perform(from: book.muzzle, to: CGPoint(x: 950,y: 150), projectile: DefenderKind.inkling.projectile,
                             in: scene) { _ in hits += 1 }
        try clock.advance(0.08)
        scene.setGamePaused(true)
        try clock.advance(0.05)
        let paused = clock.pixels()
        try clock.advance(0.7)
        let unchanged = paused == clock.pixels()
        #expect(unchanged)
        #expect(hits == 0)
        scene.setGamePaused(false)
        try clock.advance(1.3)
        #expect(hits == 1)
    }

    @Test func renderSpellbookRuntime() throws {
        guard let path = ProcessInfo.processInfo.environment["LEARN_SPELLBOOK_PREVIEW"] else { return }
        let output = URL(fileURLWithPath: path)
        let frames = output.appendingPathComponent("frames")
        try FileManager.default.createDirectory(at: frames, withIntermediateDirectories: true)
        let scene = GameScene(tuning: .make(grade: .g3, difficulty: .normal), theme: .academy,
                              loadout: Loadout(defenderSkins: ["inkling": .spellbook]))
        let view = SKView(frame: CGRect(origin: .zero, size: scene.size));scene.didMove(to: view)
        scene.setGamePaused(true, keepingAnimations: true)
        #expect(scene.plant(.inkling, in: DefenderCell(lane: 1,column: 1)))
        #expect(scene.plant(.inkling, in: DefenderCell(lane: 3,column: 0)))
        _ = scene.spawn(EnemySpawn(id: 101,sign: "星",kind: .armored),lane: 1,x: 680)
        _ = scene.spawn(EnemySpawn(id: 102,sign: "书",kind: .blob),lane: 3,x: 810)
        let log = BookDefeats();scene.gameDelegate = log
        let header = SKSpriteNode(color: SKColor(white: 0.04,alpha: 0.84),size: CGSize(width: 1200,height: 82))
        header.position = CGPoint(x: 600,y: 559);header.zPosition = 199;scene.addChild(header)
        let title = SKLabelNode(fontNamed: "PingFangSC-Semibold")
        title.text = "星轨魔导书 · 实际战斗渲染";title.fontSize = 24;title.fontColor = .white
        title.position = CGPoint(x: 600,y: 570);title.zPosition = 200;scene.addChild(title)
        let subtitle = SKLabelNode(fontNamed: "PingFangSC-Regular")
        subtitle.text = "独立书页 · 悬浮星轨 · 星珠与星门";subtitle.fontSize = 17;subtitle.fontColor = .white
        subtitle.position = CGPoint(x: 600,y: 540);subtitle.zPosition = 200;scene.addChild(subtitle)
        let clock = try BookClock(scene: scene)
        for frame in 0..<210 {
            if frame == 30 { subtitle.text = "翻页与后坐，星珠从书页节点发射";#expect(scene.fire(at: 101) == false) }
            if frame == 85 { subtitle.text = "第二次答对击败目标，结算一次";#expect(scene.fire(at: 101) == true) }
            if frame == 135 { subtitle.text = "另一实例独立发射，保留原有伤害规则";#expect(scene.fire(at: 102) == true) }
            try clock.advance(1.0 / 30)
            try clock.writePNG(to: frames.appendingPathComponent(String(format: "%03d.png",frame)))
        }
        #expect(log.ids == [101,102])
        #expect(scene.childNode(withName: "spellbookProjectile") == nil)
        #expect(scene.childNode(withName: "SpellbookImpact") == nil)
        let preview = CharacterSkinPreviewScene(kind: .inkling,skin: .spellbook,enemy: false)
        let previewClock = try BookClock(scene: preview)
        let previewFrames = output.appendingPathComponent("preview-frames")
        try FileManager.default.createDirectory(at: previewFrames,withIntermediateDirectories: true)
        for frame in 0..<120 {
            try previewClock.advance(1.0 / 30)
            try previewClock.writePNG(to: previewFrames.appendingPathComponent(String(format: "%03d.png",frame)))
        }
    }
}

private typealias BookClock = SceneClock

@MainActor
private final class BookDefeats: GameSceneDelegate {
    var ids: [Int] = []
    var speedFactor: Double { 1 }
    func nextEnemy() -> EnemySpawn? { nil }
    func targetChanged(to id: Int?) {}
    func enemyReachedBase(_ id: Int) -> Bool { false }
    func enemyDefeated(_ id: Int, at point: CGPoint) { ids.append(id) }
    func barricadeRemoved() {}
}
