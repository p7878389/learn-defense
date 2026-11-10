import Foundation
import SwiftData
import Testing
@testable import LearnCore

@Suite("森林数值数据库配置")
struct ForestRulesTests {
    private func temporaryStore() -> (URL, URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("forest-rules-\(UUID())")
        return (dir, dir.appendingPathComponent("learn.store"))
    }

    /// 迁入配置前写在代码里的数值，默认配置必须与之一致，保证搬迁不改变玩法。
    @Test func defaultsKeepTheValuesThatUsedToBeHardCoded() {
        let rules = ForestRules.defaults
        #expect(rules == rules.validated())
        #expect(rules.economy.startCoins == 100 && rules.economy.lives == 5 && rules.economy.waves == 3)
        #expect(rules.economy.repairCost == 15 && rules.economy.repairAmount == 20 && rules.economy.waveReward == 50)
        let rapid = rules.tower(.rapid), frost = rules.tower(.frost)
        #expect(rapid.cost == 50 && rapid.maxHealth == 30 && rapid.damage == 0.45 && rapid.burst == 3)
        #expect(rapid.burstGap == 0.09 && rapid.reload == 0.75 && rapid.range == 0.18 && rapid.slowSeconds == 0)
        #expect(frost.damage == 0.6 && frost.reload == 1.2 && frost.burst == 1 && frost.slowSeconds == 2)
        for kind in ForestEnemyKind.allCases {
            let stats = rules.enemy(kind)
            #expect(stats.health == (kind.isBoss ? 18 : (kind == .boar ? 4 : 3)), "\(kind)")
            #expect(stats.reward == (kind.isBoss ? 100 : 10) && stats.leakLives == (kind.isBoss ? 3 : 1), "\(kind)")
            #expect(stats.attackDamage == (kind.isBoss || kind.ranged ? 3 : 1), "\(kind)")
            #expect(stats.attackRange == (kind.ranged ? 0.24 : 0.13), "\(kind)")
            #expect(stats.attackCooldown == (kind.isBoss ? 3.2 : 4), "\(kind)")
            #expect(stats.skillDamage == (kind.isBoss ? 5 : 0), "\(kind)")
            #expect(stats.skillRadius == (kind.isBoss && kind != .reaper ? 0.12 : 0), "\(kind)")
            #expect(stats.skillCount == (kind == .reaper || kind == .gargoyle ? 3 : 1), "\(kind)")
        }
        #expect(rules.enemy(.boar).speed == 0.075 && rules.enemy(.knight).speed == 0.033)
        #expect(rules.enemy(.gargoyle).windup == 1.10 && rules.enemy(.ogre).recovery == 0.65)
        let paladin = rules.hero(.paladin), botanist = rules.hero(.botanist)
        #expect(paladin.cost == 50 && paladin.maxHealth == 36 && paladin.skillCooldown == 12)
        #expect(paladin.skillSeconds == 6 && paladin.skillRadius == 0.30 && paladin.attackWindup == 0.45)
        #expect(botanist.skillDamage == 2 && botanist.skillRadius == 0.14 && botanist.skillSeconds == 3)
        #expect(botanist.skillRange == 0.30 && botanist.attackWindup == 0.65 && botanist.attackDamage == 1.2)
    }

    private func storedObject(_ db: LearnDatabase) throws -> [String: Any]? {
        guard let row = try db.configFile(named: LearnDatabase.forestRulesName) else { return nil }
        return try JSONSerialization.jsonObject(with: row.data) as? [String: Any]
    }

    @Test func bundledFileIsCompleteAndValid() throws {
        let rules = try #require(ForestRules.load())
        #expect(rules == ForestRules.defaults)
        #expect(rules.version == 1)
        #expect(Set(rules.towers.keys) == Set(ForestTower.allCases.map(\.rawValue)))
        #expect(Set(rules.enemies.keys) == Set(ForestEnemyKind.allCases.map(\.rawValue)))
        #expect(Set(rules.heroes.keys) == Set(ForestHero.allCases.map(\.rawValue)))
        #expect(rules.isComplete)
    }

    /// 数据库只存改动项：没改过就不落库，改过的只记下改动的那几个值。
    @Test func databaseStoresOnlyChangedValuesAndKeepsThemAcrossSyncAndReopen() throws {
        let (dir, url) = temporaryStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        do {
            let db = try LearnDatabase(url: url)
            var rules = try db.forestRules()
            #expect(rules == .defaults)
            #expect(try db.configFile(named: LearnDatabase.forestRulesName) == nil)
            try db.saveForestRules(.defaults)
            #expect(try db.configFile(named: LearnDatabase.forestRulesName) == nil)

            rules.enemies[ForestEnemyKind.gargoyle.rawValue]!.skillCount = 1
            rules.towers[ForestTower.frost.rawValue]!.cost = 70
            rules.economy.startCoins = 240
            try db.saveForestRules(rules)
            let stored = try #require(try storedObject(db))
            #expect(stored as NSDictionary == [
                "version": 1,
                "economy": ["startCoins": 240],
                "towers": ["frost": ["cost": 70]],
                "enemies": ["gargoyle": ["skillCount": 1]]
            ] as NSDictionary)
            try db.syncConfig(.bundled)
        }
        let db = try LearnDatabase(url: url)
        var rules = try db.forestRules()
        #expect(rules.enemy(.gargoyle).skillCount == 1)
        #expect(rules.tower(.frost).cost == 70)
        #expect(rules.economy.startCoins == 240)
        #expect(rules.enemy(.knight) == ForestRules.defaults.enemy(.knight))

        // 改回默认值的项从库里消失；全部改回后整行删除。
        rules.towers[ForestTower.frost.rawValue]!.cost = ForestRules.defaults.tower(.frost).cost
        try db.saveForestRules(rules)
        #expect(try storedObject(db)?["towers"] == nil)
        try db.saveForestRules(.defaults)
        #expect(try db.configFile(named: LearnDatabase.forestRulesName) == nil)
    }

    /// 没改过的数值跟随内置默认值：默认值变了，库里的改动项不受影响，其余自动用新值。
    @Test func untouchedValuesFollowNewDefaults() throws {
        let overrides = Data(#"{"version":1,"enemies":{"gargoyle":{"skillCount":1}}}"#.utf8)
        var newer = ForestRules.defaults
        newer.enemies[ForestEnemyKind.gargoyle.rawValue]!.health = 25
        newer.enemies[ForestEnemyKind.knight.rawValue]!.health = 30
        newer.economy.startCoins = 150
        let rules = try #require(ForestRules.applying(overrides: overrides, to: newer))
        #expect(rules.enemy(.gargoyle).skillCount == 1)
        #expect(rules.enemy(.gargoyle).health == 25)
        #expect(rules.enemy(.knight).health == 30)
        #expect(rules.economy.startCoins == 150)
        #expect(rules.version == newer.version)
    }

    /// 上一版把整份默认值写进了库：读取时收敛成改动项，之后同样跟随默认值。
    @Test func legacyFullSnapshotIsReducedToItsChanges() throws {
        let db = try LearnDatabase(url: nil)
        var legacy = ForestRules.defaults
        legacy.enemies[ForestEnemyKind.ogre.rawValue]!.health = 22
        var object = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(legacy)) as? [String: Any])
        object.removeValue(forKey: "version")
        db.context.insert(StoredConfigFile(name: LearnDatabase.forestRulesName,
                                           data: try JSONSerialization.data(withJSONObject: object)))
        try db.context.save()
        #expect(try db.forestRules().enemy(.ogre).health == 22)
        #expect(try #require(try storedObject(db)) as NSDictionary
                == ["version": 1, "enemies": ["ogre": ["health": 22]]] as NSDictionary)

        let pristine = try LearnDatabase(url: nil)
        object = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(ForestRules.defaults)) as? [String: Any])
        object.removeValue(forKey: "version")
        pristine.context.insert(StoredConfigFile(name: LearnDatabase.forestRulesName,
                                                 data: try JSONSerialization.data(withJSONObject: object)))
        try pristine.context.save()
        #expect(try pristine.forestRules() == .defaults)
        #expect(try pristine.configFile(named: LearnDatabase.forestRulesName) == nil)
    }

    @Test func partialDataIsFilledPerFieldAndInvalidUnitsFallBack() throws {
        let json = #"""
        {"economy":{"startCoins":300},
         "enemies":{"knight":{"health":40},"ogre":{"health":-5,"speed":0.02},"dragon":{"health":1}},
         "towers":{"rapid":{"damage":2}}}
        """#
        let rules = try #require(ForestRules.applying(overrides: Data(json.utf8)))
        #expect(rules.economy.startCoins == 300 && rules.economy.lives == 5)
        #expect(rules.enemy(.knight).health == 40)
        #expect(rules.enemy(.knight).speed == ForestRules.defaults.enemy(.knight).speed)
        // 血量非法：整只巨魔回退默认，不留下半套数值。
        #expect(rules.enemy(.ogre) == ForestRules.defaults.enemy(.ogre))
        #expect(rules.tower(.rapid).damage == 2 && rules.tower(.rapid).burst == 3)
        #expect(rules.hero(.paladin) == ForestRules.defaults.hero(.paladin))
        #expect(ForestRules.applying(overrides: Data("not json".utf8)) == nil)
        #expect(ForestRules.applying(overrides: Data(#"{"economy":{"lives":"many"}}"#.utf8)) == nil)
    }

    @Test func unreadableRowFallsBackToDefaultsWithoutOverwritingIt() throws {
        let db = try LearnDatabase(url: nil)
        for broken in ["broken", #"{"version":1,"economy":{"lives":"many"}}"#] {
            for old in try db.context.fetch(FetchDescriptor<StoredConfigFile>()) { db.context.delete(old) }
            db.context.insert(StoredConfigFile(name: LearnDatabase.forestRulesName, data: Data(broken.utf8)))
            try db.context.save()
            #expect(try db.forestRules() == .defaults)
            #expect(try db.configFile(named: LearnDatabase.forestRulesName)?.data == Data(broken.utf8))
        }
    }

    @Test func battleFollowsTheRulesItWasGiven() {
        var rules = ForestRules.defaults
        rules.economy.startCoins = 500
        rules.economy.lives = 9
        rules.economy.waves = 1
        rules.economy.waveReward = 7
        rules.economy.repairCost = 3
        rules.economy.repairAmount = 5
        rules.towers[ForestTower.rapid.rawValue]!.cost = 120
        rules.towers[ForestTower.rapid.rawValue]!.maxHealth = 44
        rules.heroes[ForestHero.paladin.rawValue]!.cost = 80
        rules.heroes[ForestHero.paladin.rawValue]!.maxHealth = 12
        rules.enemies[ForestEnemyKind.knight.rawValue]!.health = 2
        rules.enemies[ForestEnemyKind.knight.rawValue]!.reward = 33

        var battle = ForestBattle(boss: .knight, rules: rules)
        #expect(battle.coins == 500 && battle.lives == 9)
        let built = battle.build(.rapid, at: 0)
        let deployed = battle.deploy(.paladin, at: 1)
        #expect(built && deployed)
        #expect(battle.coins == 300)
        #expect(battle.defenses[0]?.maxHealth == 44 && battle.defenses[1]?.maxHealth == 12)

        battle.defenses[0]!.health = 1
        let repaired = battle.repair(at: 0)
        #expect(repaired)
        #expect(battle.defenses[0]!.health == 6 && battle.coins == 297)

        // 只有一波：这一波的最后一只就是首领，打完答对即获胜。
        battle.startWave()
        var bossHealth: Double?
        for _ in 0..<4000 where battle.phase == .fighting {
            battle.tick(0.05)
            if let boss = battle.enemies.first(where: \.isBoss) { bossHealth = bossHealth ?? boss.maxHealth }
        }
        #expect(bossHealth == 2)
        #expect(battle.phase == .question)
        let before = battle.coins
        battle.answer(correct: true)
        #expect(battle.coins == before + 7)
        #expect(battle.phase == .won)
    }

    @Test func invalidRulesAreSanitisedBeforeABattleUsesThem() {
        var rules = ForestRules.defaults
        rules.economy.lives = 0
        rules.towers[ForestTower.frost.rawValue]!.reload = 0
        rules.enemies.removeValue(forKey: ForestEnemyKind.slime.rawValue)
        let battle = ForestBattle(rules: rules)
        #expect(battle.lives == 5)
        #expect(battle.rules.tower(.frost) == ForestRules.defaults.tower(.frost))
        #expect(battle.rules.enemy(.slime) == ForestRules.defaults.enemy(.slime))
    }
}
