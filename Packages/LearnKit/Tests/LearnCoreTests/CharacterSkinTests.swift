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
        #expect(state.loadout(catalog).defenderSkins["inkling"] == .party)
        #expect(state.loadout(catalog).enemySkin == .pixel)
        let original = try #require(catalog.cosmetic(id: "defender.original"))
        let reset = state.equip(original, level: 1)
        #expect(reset)
        #expect(state.loadout(catalog).defenderSkins["inkling"] == nil)
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
        #expect(state.loadout(catalog).defenderSkins == ["inkling": skin])
        #expect(state.loadout(catalog).enemySkin == nil)
    }

    /// 每种射手一个装备位；豌豆射手沿用旧键，老存档照常生效
    @Test func eachShooterHasItsOwnSlot() throws {
        let catalog = GrowthCatalog.bundled
        for kind in UnitCatalog.defenders {
            let skins = catalog.shooterSkins(for: kind.id)
            #expect(skins.contains { $0.isOriginal }, "\(kind.id) 缺原版")
            #expect(Set(skins.map(\.equipKey)).count == 1)
        }
        let inkling = try #require(catalog.cosmetic(id: "defender.bamboo"))
        let twinOriginal = try #require(catalog.cosmetic(id: "defender.twin.original"))
        #expect(inkling.equipKey == "defenderSkin")
        #expect(twinOriginal.equipKey == "defenderSkin.twin")

        // 旧存档里的键
        var state = try JSONDecoder().decode(GrowthState.self, from: Data(#"{"equipped":{"defenderSkin":"defender.voxel"}}"#.utf8))
        #expect(state.loadout(catalog).defenderSkins == ["inkling": .voxel])
        // 换回双发射手的原版，不影响豌豆射手
        let equipped = state.equip(twinOriginal, level: 1)
        #expect(equipped)
        #expect(state.isEquipped(twinOriginal))
        #expect(state.isEquipped(inkling) == false)
        #expect(state.loadout(catalog).defenderSkins == ["inkling": .voxel])
    }

    @Test func shooterSkinMustTargetKnownShooter() throws {
        var item = try #require(GrowthCatalog.bundled.cosmetic(id: "defender.bamboo"))
        item.defender = "ghost"
        var wrongSlot = try #require(GrowthCatalog.bundled.cosmetic(id: "enemy.party"))
        wrongSlot.defender = "inkling"
        var catalog = GrowthCatalog(badges: [], cosmetics: [item, wrongSlot])
        catalog.validate()
        #expect(catalog.cosmetics.isEmpty)
        #expect(catalog.issues.count == 2)
    }

    @Test func shootersOnFieldFollowGrade() {
        #expect(GameTuning.defenders(for: .k2).map(\.id) == ["inkling", "frost", "starling"])
        #expect(GameTuning.defenders(for: .g3).map(\.id) == UnitCatalog.defenders.map(\.id))
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
