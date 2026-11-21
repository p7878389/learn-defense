import Foundation
import Testing
@testable import LearnCore

@Suite("角色动画皮肤")
struct CharacterSkinTests {
    @Test func slotsPersistIndependentlyAndOriginalOnlyResetsItsSlot() throws {
        let catalog = GrowthCatalog.bundled
        var state = GrowthState()
        state.xp = 1000
        for id in ["defender.spellbook", "defeat.sparkle", "projectile.iceCrystal"] {
            let item = try #require(catalog.cosmetic(id: id))
            let equipped = state.equip(item, level: 2)
            #expect(equipped)
        }
        state = try JSONDecoder().decode(GrowthState.self, from: JSONEncoder().encode(state))
        #expect(state.loadout(catalog).defenderSkins["inkling"] == .spellbook)
        #expect(state.loadout(catalog).defeat != nil)
        let original = try #require(catalog.cosmetic(id: "defender.original"))
        let reset = state.equip(original, level: 2)
        #expect(reset)
        #expect(state.loadout(catalog).defenderSkins["inkling"] == nil)
        #expect(state.loadout(catalog).defeat != nil)
        #expect(state.loadout(catalog).projectile?.shape == .gem)
    }

    @Test func oldAndInvalidEquipmentFallBackToOriginal() throws {
        var state = try JSONDecoder().decode(GrowthState.self, from: Data("{}".utf8))
        #expect(state.loadout(.bundled) == .standard)
        state.equipped = ["enemySkin": "defender.spellbook", "defenderSkin": "defender.missing"]
        #expect(state.loadout(.bundled) == .standard)
        let original = try #require(GrowthCatalog.bundled.cosmetic(id: "projectile.original"))
        #expect(original.characterSkin == nil)
        #expect(original.isOriginal)
    }

    @Test(arguments: [CharacterSkin.spellbook])
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

    /// 付费皮肤必须先解锁、购买，再装备；用场景皮肤验证通用交易规则。
    @Test func fireflyMustBeUnlockedAndBought() throws {
        let catalog = GrowthCatalog.bundled
        #expect(catalog.issues.isEmpty)
        var item = try #require(catalog.cosmetic(id: "defender.spellbook"))
        item.unlockLevel = 2
        item.price = 100
        #expect(item.slot == .defenderSkin)
        #expect(item.characterSkin == .spellbook)
        #expect(item.price > 0)
        #expect(!catalog.cosmetics.contains { $0.slot == .enemySkin && $0.characterSkin == .spellbook })

        var state = GrowthState()
        state.coins = item.price
        let tooEarly = state.purchase(item, level: item.unlockLevel - 1)
        #expect(tooEarly == .locked(level: item.unlockLevel))
        let equippedBeforeBuying = state.equip(item, level: item.unlockLevel)
        #expect(!equippedBeforeBuying)
        let bought = state.purchase(item, level: item.unlockLevel)
        #expect(bought == .bought)
        #expect(state.coins == 0)
        let equipped = state.equip(item, level: item.unlockLevel)
        #expect(equipped)
        #expect(state.equipped[item.equipKey] == item.id)
    }

    /// 每种射手一个装备位；豌豆射手沿用旧键，老存档照常生效
    @Test func eachShooterHasItsOwnSlot() throws {
        let catalog = GrowthCatalog.bundled
        for kind in UnitCatalog.defenders where kind.canShoot {
            let skins = catalog.shooterSkins(for: kind.id)
            #expect(skins.contains { $0.isOriginal }, "\(kind.id) 缺原版")
            #expect(Set(skins.map(\.equipKey)).count == 1)
        }
        let inkling = try #require(catalog.cosmetic(id: "defender.original"))
        let twinOriginal = try #require(catalog.cosmetic(id: "defender.twin.original"))
        #expect(inkling.equipKey == "defenderSkin")
        #expect(twinOriginal.equipKey == "defenderSkin.twin")

        // 旧存档里的键
        var state = try JSONDecoder().decode(GrowthState.self, from: Data(#"{"equipped":{"defenderSkin":"defender.spellbook"}}"#.utf8))
        #expect(state.loadout(catalog).defenderSkins == ["inkling": .spellbook])
        // 换回双发射手的原版，不影响豌豆射手
        let equipped = state.equip(twinOriginal, level: 1)
        #expect(equipped)
        #expect(state.isEquipped(twinOriginal))
        #expect(state.isEquipped(inkling) == false)
        #expect(state.loadout(catalog).defenderSkins == ["inkling": .spellbook])
    }

    @Test func shooterSkinMustTargetKnownShooter() throws {
        var item = try #require(GrowthCatalog.bundled.cosmetic(id: "defender.spellbook"))
        item.defender = "ghost"
        var wrongSlot = try #require(GrowthCatalog.bundled.cosmetic(id: "enemy.original"))
        wrongSlot.defender = "inkling"
        var catalog = GrowthCatalog(badges: [], cosmetics: [item, wrongSlot])
        catalog.validate()
        #expect(catalog.cosmetics.isEmpty)
        #expect(catalog.issues.count == 2)
    }

    @Test func shootersOnFieldFollowGrade() {
        #expect(GameTuning.defenders(for: .k2).map(\.id) == ["inkling", "frost", "starling"])
        #expect(GameTuning.defenders(for: .g3).filter(\.canShoot).map(\.id) == UnitCatalog.defenders.filter(\.canShoot).map(\.id))
    }

    @Test func wrongSlotPayloadIsRejected() throws {
        var item = try #require(GrowthCatalog.bundled.cosmetic(id: "defender.spellbook"))
        item.slot = .projectile
        var catalog = GrowthCatalog(badges: [], cosmetics: [item])
        catalog.validate()
        #expect(catalog.cosmetics.isEmpty)
        #expect(catalog.issues.count == 1)
    }
    @Test func bundledSkinsAreAvailableFromFirstLevel() throws {
        let catalog = GrowthCatalog.bundled
        let item = try #require(catalog.cosmetic(id: "defender.spellbook"))
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
