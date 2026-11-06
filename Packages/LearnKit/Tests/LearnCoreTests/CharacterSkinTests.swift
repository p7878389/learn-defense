import Foundation
import Testing
@testable import LearnCore

@Suite("角色动画皮肤")
struct CharacterSkinTests {
    @Test func slotsPersistIndependentlyAndOriginalOnlyResetsItsSlot() throws {
        let catalog = GrowthCatalog.bundled
        var state = GrowthState()
        for id in ["defender.party", "enemy.pixel", "projectile.iceCrystal"] {
            let item = try #require(catalog.cosmetic(id: id))
            let equipped = state.equip(item, level: 1)
            #expect(equipped)
        }
        state = try JSONDecoder().decode(GrowthState.self, from: JSONEncoder().encode(state))
        #expect(state.loadout(catalog).defenderSkin == .party)
        #expect(state.loadout(catalog).enemySkin == .pixel)
        let original = try #require(catalog.cosmetic(id: "defender.original"))
        let reset = state.equip(original, level: 1)
        #expect(reset)
        #expect(state.loadout(catalog).defenderSkin == nil)
        #expect(state.loadout(catalog).enemySkin == .pixel)
        #expect(state.loadout(catalog).projectile?.shape == .gem)
    }

    @Test func oldAndInvalidEquipmentFallBackToOriginal() throws {
        var state = try JSONDecoder().decode(GrowthState.self, from: Data("{}".utf8))
        #expect(state.loadout(.bundled) == .standard)
        state.equipped = ["enemySkin": "defender.party", "defenderSkin": "defender.missing"]
        #expect(state.loadout(.bundled) == .standard)
        let original = try #require(GrowthCatalog.bundled.cosmetic(id: "projectile.original"))
        #expect(original.characterSkin == nil)
        #expect(original.isOriginal)
    }

    @Test(arguments: [CharacterSkin.bamboo, .voxel, .egg])
    func redrawnSkinsAreShooterOnly(skin: CharacterSkin) throws {
        let catalog = GrowthCatalog.bundled
        let item = try #require(catalog.cosmetic(id: "defender.\(skin.rawValue)"))
        #expect(item.slot == .defenderSkin)
        #expect(item.characterSkin == skin)
        #expect(!catalog.cosmetics.contains { $0.slot == .enemySkin && $0.characterSkin == skin })
        var state = GrowthState()
        let equipped = state.equip(item, level: 1)
        #expect(equipped)
        #expect(state.loadout(catalog).defenderSkin == skin)
        #expect(state.loadout(catalog).enemySkin == nil)
    }

    @Test func wrongSlotPayloadIsRejected() throws {
        var item = try #require(GrowthCatalog.bundled.cosmetic(id: "defender.party"))
        item.slot = .projectile
        var catalog = GrowthCatalog(badges: [], cosmetics: [item])
        catalog.validate()
        #expect(catalog.cosmetics.isEmpty)
        #expect(catalog.issues.count == 1)
    }
    @Test func bundledSkinsAreAvailableFromFirstLevel() throws {
        let catalog = GrowthCatalog.bundled
        for role in ["defender", "enemy"] {
            for style in ["party", "pixel"] {
                let item = try #require(catalog.cosmetic(id: "\(role).\(style)"))
                #expect(!item.isOriginal)
                #expect(item.unlockLevel == 1)
                #expect(item.price == 0)
                var state = GrowthState()
                let equipped = state.equip(item, level: 1)
                #expect(equipped)
                #expect(state.isEquipped(item))
                #expect(state.loadout(catalog) != .standard)
            }
        }
    }
}
