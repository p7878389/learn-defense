import Foundation
import Testing
@testable import LearnCore

@Suite("怪物外观购买条件")
struct MonsterCosmeticTests {
    private func cosmetic(_ extra: String = "") throws -> CosmeticKind {
        try JSONDecoder().decode(CosmeticKind.self, from: Data("""
        {"id":"enemy.test","slot":"enemySkin","name":"测试怪物","icon":"👾","summary":"外观",
         "rarity":"rare","unlockLevel":1,"price":180,"enemyAppearance":"knight"\(extra)}
        """.utf8))
    }

    @Test func badgeGateNeverChargesBeforeAchievement() throws {
        let item = try cosmetic(",\"unlockBadge\":\"games10\"")
        var state = GrowthState()
        state.coins = 500
        let denied = state.purchase(item, level: 1)
        #expect(denied != .bought)
        #expect(state.coins == 500)
        let earlyEquip = state.equip(item, level: 1)
        #expect(!earlyEquip)
        state.badges["games10"] = Date()
        let purchased = state.purchase(item, level: 1)
        #expect(purchased == .bought)
        #expect(state.coins == 320)
        #expect(state.equipped.isEmpty)
        let duplicate = state.purchase(item, level: 1)
        #expect(duplicate == .alreadyOwned)
        #expect(state.coins == 320)
        let equip = state.equip(item, level: 1)
        #expect(!equip)
        #expect(state.equipped["enemySkin"] == nil)
        #expect(state.status(of: item, level: 1) == .owned)
    }

    @Test func allConditionsAndBalanceAreRequired() throws {
        let item = try cosmetic(",\"unlockBadge\":\"games10\",\"unlockStat\":\"gamesWon\",\"unlockCount\":10")
        var state = GrowthState()
        state.coins = 179
        state.badges["games10"] = Date()
        state.stats.gamesWon = 9
        let early = state.purchase(item, level: 1)
        #expect(early != .bought && early != .notEnough(short: 1))
        state.stats.gamesWon = 10
        let short = state.purchase(item, level: 1)
        #expect(short == .notEnough(short: 1))
        #expect(state.coins == 179)
        state.coins = 180
        let bought = state.purchase(item, level: 1)
        #expect(bought == .bought)
        #expect(state.coins == 0)
    }

    @Test func catalogIncludesEveryFinishedMonsterAndDefault() {
        let catalog = GrowthCatalog.bundled
        #expect(catalog.issues.isEmpty)
        #expect(catalog.cosmetics(in: .enemySkin).count == 19)
    }

    @Test func appearanceIsNotOriginalAndInvalidTargetsAreRejected() throws {
        var item = try cosmetic()
        #expect(!item.isOriginal)
        // 非怪物槽位不能携带怪物外观。
        item.slot = .projectile
        var catalog = GrowthCatalog(badges: [], cosmetics: [item])
        catalog.validate()
        #expect(catalog.cosmetics.isEmpty)
    }
    @Test func invalidConditionsAreRejectedButOldCatalogStillDecodes() throws {
        let base = try cosmetic()
        var unknownEnemy = base
        unknownEnemy.enemyAppearance = "missing"
        var wrongBadge = base
        wrongBadge.id = "enemy.badBadge"
        wrongBadge.unlockBadge = "missing"
        var zeroThreshold = base
        zeroThreshold.id = "enemy.zero"
        zeroThreshold.unlockStat = .gamesWon
        zeroThreshold.unlockCount = 0
        var missingStat = base
        missingStat.id = "enemy.noStat"
        missingStat.unlockCount = 10
        var catalog = GrowthCatalog(badges: [], cosmetics: [unknownEnemy, wrongBadge, zeroThreshold, missingStat])
        catalog.validate()
        #expect(catalog.cosmetics.isEmpty)
        #expect(catalog.issues.count == 4)
        let original = try #require(GrowthCatalog.bundled.cosmetic(id: "enemy.original"))
        #expect(original.isOriginal)
        #expect(original.enemyAppearance == nil)
        #expect(original.unlockBadge == nil)
    }

    @Test func purchasedAppearanceSurvivesSaveAndResetIsIsolated() throws {
        let catalog = GrowthCatalog.bundled
        let monster = try #require(catalog.cosmetic(id: "enemy.goblin"))
        let shooter = try #require(catalog.cosmetic(id: "defender.spellbook"))
        var state = GrowthState()
        state.coins = 300
        let bought = state.purchase(monster, level: 1)
        #expect(bought == .bought)
        let worn = state.equip(monster, level: 1)
        let other = state.equip(shooter, level: 1)
        #expect(!worn && other)
        state = try JSONDecoder().decode(GrowthState.self, from: JSONEncoder().encode(state))
        #expect(state.coins == 180)
        #expect(state.loadout(catalog).enemyAppearances == ["goblin"])
        #expect(state.loadout(catalog).defenderSkins["inkling"] == .spellbook)
        state.unequip(key: "enemySkin")
        #expect(state.loadout(catalog).enemyAppearances == ["goblin"])
        #expect(state.loadout(catalog).defenderSkins["inkling"] == .spellbook)
        state.equipped["enemySkin"] = "enemy.missing"
        #expect(state.loadout(catalog).enemyAppearances == ["goblin"])
    }

    @Test func lockedPurchaseCannotBeBypassedByOwnedRecord() throws {
        let item = try cosmetic(",\"unlockBadge\":\"games10\"")
        var state = GrowthState()
        state.owned.insert(item.id)
        state.equipped[item.equipKey] = item.id
        let catalog = GrowthCatalog(badges: [], cosmetics: [item])
        #expect(state.status(of: item, level: 1) == .conditionLocked)
        #expect(!state.owns(item, level: 1))
        #expect(state.loadout(catalog).enemyAppearances.isEmpty)
    }

    @Test func oldSingleEquipmentDoesNotRestrictOwnedPool() throws {
        let catalog = GrowthCatalog.bundled
        var state = GrowthState()
        state.coins = 500
        for id in ["enemy.goblin", "enemy.acolyte"] {
            let item = try #require(catalog.cosmetic(id: id))
            let result = state.purchase(item, level: 1)
            #expect(result == .bought)
        }
        state.equipped["enemySkin"] = "enemy.goblin"
        state.owned.insert("enemy.missing")
        state = try JSONDecoder().decode(GrowthState.self, from: JSONEncoder().encode(state))
        #expect(state.equipped["enemySkin"] == nil)
        #expect(state.loadout(catalog).enemyAppearances == ["acolyte", "goblin"])
        for id in ["enemy.goblin", "enemy.acolyte"] {
            let item = try #require(catalog.cosmetic(id: id))
            #expect(state.status(of: item, level: 1) == .owned)
            #expect(!state.isEquipped(item))
        }
    }

}
