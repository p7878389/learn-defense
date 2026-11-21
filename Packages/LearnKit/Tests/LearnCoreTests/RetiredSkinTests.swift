import Foundation
import Testing
@testable import LearnCore

@Suite("退役皮肤兼容")
struct RetiredSkinTests {
    @Test(arguments: ["party", "pixel", "bamboo", "egg", "voxel", "firefly"])
    func retiredSkinsAreNotAvailable(style: String) {
        #expect(CharacterSkin(rawValue: style) == nil)
        #expect(GrowthCatalog.bundled.cosmetic(id: "defender.\(style)") == nil)
        #expect(GrowthCatalog.bundled.cosmetic(id: "enemy.\(style)") == nil)
        #expect(GrowthCatalog.bundled.issues.isEmpty)
    }

    @Test(arguments: ["party", "pixel", "bamboo", "egg", "voxel", "firefly"])
    func oldSaveRestoresOriginalWithoutLosingProgress(style: String) throws {
        var old = GrowthState()
        old.xp = 800
        old.coins = 321
        old.stats.gamesPlayed = 12
        old.owned = ["defender.\(style)", "projectile.flower"]
        old.equipped = ["defenderSkin": "defender.\(style)", "enemySkin": "enemy.party",
                        "defenderSkin.twin": "defender.twin.original"]
        let restored = try JSONDecoder().decode(GrowthState.self, from: JSONEncoder().encode(old))
        #expect(restored.xp == 800)
        #expect(restored.coins == 321)
        #expect(restored.stats.gamesPlayed == 12)
        #expect(restored.owned == old.owned)
        #expect(restored.equipped == ["defenderSkin.twin": "defender.twin.original"])
        #expect(restored.loadout(.bundled).defenderSkins.isEmpty)
        #expect(restored.loadout(.bundled).enemySkin == nil)
        let original = try #require(GrowthCatalog.bundled.cosmetic(id: "defender.original"))
        #expect(restored.isEquipped(original))
    }
}
