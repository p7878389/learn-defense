import Foundation
import Testing
@testable import LearnCore

@Suite("资源主题皮肤装备")
struct ThemeSkinCatalogTests {
    @Test(arguments: ["mecha", "teapot", "emerald", "astral", "frost", "festival"])
    func equipmentSurvivesSaveAndPreservesOtherSlots(id: String) throws {
        let catalog = GrowthCatalog.bundled
        let item = try #require(catalog.cosmetic(id: "defender.\(id)"))
        #expect(catalog.issues.isEmpty)
        #expect(item.shooterID == "inkling")
        var state = GrowthState()
        let equipped = state.equip(item, level: 1)
        #expect(equipped)
        let projectileEquipped = state.equip(try #require(catalog.cosmetic(id: "projectile.iceCrystal")), level: 1)
        #expect(projectileEquipped)
        state = try JSONDecoder().decode(GrowthState.self, from: JSONEncoder().encode(state))
        #expect(state.loadout(catalog).defenderSkins["inkling"]?.rawValue == id)
        #expect(state.loadout(catalog).defenderSkins["frost"] == nil)
        #expect(state.loadout(catalog).projectile?.shape == .gem)
        let reset = state.equip(try #require(catalog.cosmetic(id: "defender.original")), level: 1)
        #expect(reset)
        #expect(state.loadout(catalog).defenderSkins["inkling"] == nil)
        #expect(state.loadout(catalog).projectile?.shape == .gem)
    }
}
