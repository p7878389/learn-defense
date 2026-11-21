import Foundation
import Testing
@testable import LearnCore

@Suite("射手皮肤解锁购买")
struct ShooterSkinPurchaseTests {
    @Test(arguments: GrowthCatalog.bundled.cosmetics.filter { $0.slot == .defenderSkin && !$0.isOriginal })
    func bundledSkinRequiresUnlockThenPayment(item: CosmeticKind) throws {
        let catalog = GrowthCatalog.bundled
        var state = GrowthState()
        state.coins = 1000
        #expect(state.status(of: item, level: 1) == .locked(level: item.unlockLevel))
        let earlyPurchase = state.purchase(item, level: 1)
        #expect(earlyPurchase == .locked(level: item.unlockLevel))
        let earlyEquip = state.equip(item, level: 1)
        #expect(!earlyEquip)
        #expect(state.coins == 1000 && state.owned.isEmpty && state.equipped.isEmpty)

        state.xp = catalog.pacing.levelCurve.totalXP(toReach: item.unlockLevel)
        let level = state.level(catalog.pacing.levelCurve).level
        #expect(state.status(of: item, level: level) == .forSale(price: item.price))
        let unpaidEquip = state.equip(item, level: level)
        #expect(!unpaidEquip)
        state.coins = item.price - 1
        let insufficient = state.purchase(item, level: level)
        #expect(insufficient == .notEnough(short: 1))
        #expect(state.coins == item.price - 1 && state.owned.isEmpty)

        state.coins = item.price
        let purchase = state.purchase(item, level: level)
        #expect(purchase == .bought)
        #expect(state.coins == 0 && state.owned == [item.id])
        #expect(state.status(of: item, level: level) == .owned)
        let repeatPurchase = state.purchase(item, level: level)
        #expect(repeatPurchase == .alreadyOwned)
        #expect(state.coins == 0)
        let equip = state.equip(item, level: level)
        #expect(equip)
        #expect(state.status(of: item, level: level) == .equipped)
        state = try JSONDecoder().decode(GrowthState.self, from: JSONEncoder().encode(state))
        #expect(state.loadout(catalog).defenderSkins[item.shooterID] == item.characterSkin)
    }

    @Test(arguments: GrowthCatalog.bundled.cosmetics.filter { $0.slot == .defenderSkin && !$0.isOriginal })
    func unpaidLegacyEquipmentFallsBackUntilPurchased(item: CosmeticKind) throws {
        let catalog = GrowthCatalog.bundled
        var legacy = GrowthState()
        legacy.xp = catalog.pacing.levelCurve.totalXP(toReach: item.unlockLevel)
        legacy.coins = 1000
        legacy.equipped[item.equipKey] = item.id
        var state = try JSONDecoder().decode(GrowthState.self, from: JSONEncoder().encode(legacy))
        #expect(state.loadout(catalog).defenderSkins.isEmpty)
        #expect(state.status(of: item, level: item.unlockLevel) == .forSale(price: item.price))
        #expect(state.coins == 1000 && state.owned.isEmpty)
        let purchase = state.purchase(item, level: item.unlockLevel)
        #expect(purchase == .bought)
        #expect(state.loadout(catalog).defenderSkins[item.shooterID] == item.characterSkin)
    }
}
