import Foundation
import Testing
@testable import LearnCore

@Suite("星轨魔导书装备")
struct SpellbookCatalogTests {
    @Test func equipsPersistsAndResetsWithoutChangingOtherSlots() throws {
        let catalog = GrowthCatalog.bundled
        let book = try #require(catalog.cosmetic(id: "defender.spellbook"))
        #expect(catalog.issues.isEmpty)
        #expect(book.shooterID == "inkling")
        #expect(book.slot == .defenderSkin)
        var state = GrowthState()
        state.xp = catalog.pacing.levelCurve.totalXP(toReach: book.unlockLevel)
        let level = state.level(catalog.pacing.levelCurve).level
        let monster = try #require(catalog.cosmetic(id: "enemy.goblin"))
        state.coins = monster.price + book.price
        let bought = state.purchase(monster, level: 1)
        #expect(bought == .bought)
        let skinBought = state.purchase(book, level: level)
        #expect(skinBought == .bought)
        let equipped = state.equip(book, level: level)
        #expect(equipped)
        let projectile = try #require(catalog.cosmetic(id: "enemy.goblin"))
        let projectileEquipped = state.equip(projectile, level: 1)
        #expect(!projectileEquipped, "怪物无需单独装备")
        state = try JSONDecoder().decode(GrowthState.self, from: JSONEncoder().encode(state))
        #expect(state.loadout(catalog).defenderSkins["inkling"]?.rawValue == "spellbook")
        #expect(state.loadout(catalog).enemyAppearances == ["goblin"])
        #expect(state.loadout(catalog).defenderSkins["frost"] == nil)
        let reset = state.equip(try #require(catalog.cosmetic(id: "defender.original")), level: 1)
        #expect(reset)
        #expect(state.loadout(catalog).defenderSkins["inkling"] == nil)
        #expect(state.loadout(catalog).enemyAppearances == ["goblin"])
    }
}
