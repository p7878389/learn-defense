import Foundation
import Testing
@testable import LearnCore

@Suite("退役外观分类兼容")
struct RetiredCosmeticSlotTests {
    @Test func catalogOnlyOffersCharacterSkins() {
        #expect(GrowthCatalog.bundled.issues.isEmpty)
        #expect(GrowthCatalog.bundled.cosmetics.allSatisfy { [.defenderSkin, .enemySkin].contains($0.slot) })
    }

    @Test func oldSlotsRestoreDefaultsWithoutLosingOtherProgress() throws {
        var old = GrowthState()
        old.coins = 500
        old.xp = 2000
        old.owned = ["projectile.petal", "defeat.confetti", "item.iceCube"]
        old.equipped = ["projectile":"projectile.petal", "defeat":"defeat.confetti", "item.frostCharm":"item.iceCube",
                        "defenderSkin":"defender.spellbook"]
        let saved = try JSONDecoder().decode(GrowthState.self, from: JSONEncoder().encode(old))
        #expect(saved.equipped == ["defenderSkin":"defender.spellbook"])
        #expect(saved.coins == 500 && saved.xp == 2000 && saved.owned == old.owned)
        let loadout = saved.loadout(.bundled)
        #expect(loadout.projectile(for: .inkling) == DefenderKind.inkling.projectile)
        #expect(loadout.defeat(for: .blob) == EnemyKind.blob.look.defeat)
        #expect(loadout.skin(.frostCharm) == .frostCharm)
        #expect(loadout.defenderSkins["inkling"] == .spellbook)
    }

    @Test(arguments: [CosmeticSlot.projectile, .defeat, .itemSkin])
    func staleItemsCannotBePurchasedOrEquipped(slot: CosmeticSlot) throws {
        var item = try #require(GrowthCatalog.bundled.cosmetic(id: "defender.spellbook"))
        item.slot = slot
        item.price = 100
        var state = GrowthState()
        state.coins = 500
        let bought = state.purchase(item, level: 10)
        #expect(bought != .bought)
        #expect(state.coins == 500)
        state.owned.insert(item.id)
        let equipped = state.equip(item, level: 10)
        #expect(!equipped)
    }
}
