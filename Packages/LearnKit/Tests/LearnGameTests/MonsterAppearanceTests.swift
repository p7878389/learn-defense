import LearnCore
import SpriteKit
import Testing
@testable import LearnGame

@Suite("怪物外观隔离")
@MainActor
struct MonsterAppearanceTests {
    @Test func preloadsSelectedAppearanceInsteadOfCombatKind() throws {
        let textures = UnitSprites.preloadCombat(defenders: [], enemies: [.armored],
                                                loadout: Loadout(enemyAppearance: "knight"))
        #expect(textures["zombie-knight"]?.isEmpty == false)
        #expect(textures["zombie-armored"] == nil)
    }
    @Test func equippedMonsterKeepsCombatKindAndMovement() throws {
        let tuning = GameTuning.make(grade: .g1, difficulty: .easy)
        let scene = GameScene(tuning: tuning, theme: .academy, loadout: Loadout(enemyAppearance: "knight"))
        let shown = scene.spawn(EnemySpawn(id: 1, sign: "春", kind: .armored), lane: 0, x: 500)
        let original = EnemyNode(id: 2, kind: .armored, sign: "春", lane: 0, scale: 1)
        #expect(shown.kind.id == "armored")
        #expect(shown.health.max == 2)
        #expect(shown.isBoss == tuning.waves.isBoss(.armored))
        let sprite = try #require(shown.childNode(withName: "//unitSprite") as? SKSpriteNode)
        #expect(UnitSprites.frames(named: "zombie-knight").contains { $0 === sprite.texture })
        #expect(shown.advance(dt: 0.2, speed: 40) == original.advance(dt: 0.2, speed: 40))
        shown.health.take(1)
        shown.showWound()
        #expect(UnitSprites.frames(named: "zombie-knight").contains { $0 === sprite.texture })
        shown.slow(factor: 0, seconds: 2)
        #expect(shown.chewRate == 0)
        _ = shown.advance(dt: 3, speed: 40)
        #expect(shown.chewRate == 1)
    }

    @Test func everyFinishedAppearanceHasPreviewAndKeepsItsAttackArt() throws {
        let items = GrowthCatalog.bundled.cosmetics(in: .enemySkin).filter { !$0.isOriginal }
        var ids = Set<String>()
        for item in items {
            let appearance = try #require(item.enemyAppearance)
            let kind = try #require(UnitCatalog.enemy(id: appearance))
            #expect(UnitSprites.portrait(of: kind, skin: nil) != nil)
            let node = EnemyNode(id: 1, kind: .blob, sign: "春", lane: 0, scale: 1, appearance: appearance)
            let sprite = try #require(node.childNode(withName: "//unitSprite") as? SKSpriteNode)
            let base = "zombie-\(appearance)"
            #expect(UnitSprites.frames(named: base).contains { $0 === sprite.texture })
            node.lunge()
            if let attack = UnitSprites.state("attack", of: base) {
                #expect(UnitSprites.frames(named: attack).contains { $0 === sprite.texture })
            }
            #expect(node.kind.id == "blob")
            #expect(node.health.max == 1)
            let stage = CharacterSkinPreview.stageID(skin: nil, enemy: true, enemyAppearance: appearance)
            #expect(ids.insert(stage).inserted)
        }
        #expect(ids.count == 18)
    }

    @Test func badAppearanceFallsBackAndOriginalArmorStillSheds() throws {
        let node = EnemyNode(id: 1, kind: .armored, sign: "春", lane: 0, scale: 1, appearance: "missing")
        let sprite = try #require(node.childNode(withName: "//unitSprite") as? SKSpriteNode)
        #expect(UnitSprites.frames(named: "zombie-armored").contains { $0 === sprite.texture })
        node.health.take(1)
        node.showWound()
        let bare = try #require(UnitSprites.state("bare", of: "zombie-armored"))
        #expect(UnitSprites.frames(named: bare).contains { $0 === sprite.texture })
    }

}
