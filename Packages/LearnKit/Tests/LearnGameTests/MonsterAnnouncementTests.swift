import LearnCore
import SpriteKit
import Testing
@testable import LearnGame

@Suite("怪物显示与播报一致")
@MainActor
struct MonsterAnnouncementTests {
    @Test func bossAnnouncementUsesChosenAppearanceNotCombatKind() throws {
        let tuning = GameTuning.make(grade: .g3, difficulty: .normal)
        var state = GrowthState()
        state.coins = 500
        let goblin = try #require(GrowthCatalog.bundled.cosmetic(id: "enemy.goblin"))
        let bought = state.purchase(goblin, level: 1)
        #expect(bought == .bought)
        state.owned.insert("enemy.knight") // 未达成就的旧记录不能进入展示池。
        #expect(state.loadout(.bundled).enemyAppearances == ["goblin"])
        let scene = GameScene(tuning: tuning, theme: .academy, loadout: state.loadout(.bundled))
        let listener = AppearanceAnnouncements()
        scene.gameDelegate = listener
        let node = scene.spawn(EnemySpawn(id: 1, sign: "春", kind: .king), lane: 0, x: 600)
        #expect(node.kind.id == "king" && node.health.max == 3)
        #expect(listener.names == ["掷石斥候"])
        let labels = node.children.flatMap { $0.children }.compactMap { ($0 as? SKLabelNode)?.text }
        #expect(labels.contains("掷石斥候"))
        #expect(!labels.contains("铁门僵尸"))
    }

    @Test func noPurchasedMonstersUseOnlyDefaultAppearance() throws {
        let scene = GameScene(tuning: .make(grade: .g3, difficulty: .normal), theme: .academy, loadout: .standard)
        let node = scene.spawn(EnemySpawn(id: 1, sign: "春", kind: .frostKing), lane: 0, x: 600)
        let sprite = try #require(node.childNode(withName: "//unitSprite") as? SKSpriteNode)
        #expect(UnitSprites.frames(named: "zombie-blob").contains { $0 === sprite.texture })
        #expect(node.kind.id == "frostKing" && node.health.max == 3)
    }

    @Test func speechCatalogCoversEveryPurchasableMonsterName() {
        let lines = Set(SpeechText.gameLines)
        for kind in UnitCatalog.enemies + UnitCatalog.forestEnemies {
            #expect(lines.contains(SpeechText.Line.bossArrive(kind.name)))
        }
    }
}

@MainActor
private final class AppearanceAnnouncements: GameSceneDelegate {
    var names: [String] = []
    func bossAppeared(name: String) { names.append(name) }
    func nextEnemy() -> EnemySpawn? { nil }
    func targetChanged(to id: Int?) {}
    func enemyReachedBase(_ id: Int) -> Bool { true }
    func enemyDefeated(_ id: Int, at point: CGPoint) {}
    func barricadeRemoved() {}
    var speedFactor: Double { 1 }
}
