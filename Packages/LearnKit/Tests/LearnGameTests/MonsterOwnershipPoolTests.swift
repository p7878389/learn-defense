import LearnCore
import SpriteKit
import Testing
@testable import LearnGame

@Suite("已拥有怪物自动展示")
@MainActor
struct MonsterOwnershipPoolTests {
    @Test func purchasesJoinPoolWithoutEquippingAndRotateWithoutRepeats() throws {
        let catalog = GrowthCatalog.bundled
        var state = GrowthState()
        state.coins = 500
        for id in ["enemy.goblin", "enemy.acolyte"] {
            let item = try #require(catalog.cosmetic(id: id))
            let result = state.purchase(item, level: 1)
            #expect(result == .bought)
        }
        #expect(state.equipped.isEmpty)
        let scene = GameScene(tuning: .make(grade: .g1, difficulty: .easy), theme: .academy, loadout: state.loadout(catalog))
        var appearances: [String] = []
        for id in 0..<8 {
            let node = scene.spawn(EnemySpawn(id: id, sign: "春", kind: .blob), lane: 0, x: 600)
            let sprite = try #require(node.childNode(withName: "//unitSprite") as? SKSpriteNode)
            let name = ["goblin", "acolyte"].first { name in
                UnitSprites.frames(named: "zombie-\(name)").contains { $0 === sprite.texture }
            }
            appearances.append(try #require(name))
            #expect(node.kind.id == "blob" && node.health.max == 1)
            node.removeFromParent()
        }
        #expect(Set(appearances) == ["goblin", "acolyte"])
        for pair in zip(appearances, appearances.dropFirst()) { #expect(pair.0 != pair.1) }
    }
}
