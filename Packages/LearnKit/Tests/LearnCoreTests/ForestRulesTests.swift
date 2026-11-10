import Foundation
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

    @Test func firstReadSeedsDefaultsAndEditsSurviveSyncAndReopen() throws {
        let (dir, url) = temporaryStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        do {
            let db = try LearnDatabase(url: url)
            #expect(try db.configFile(named: LearnDatabase.forestRulesName) == nil)
            var rules = try db.forestRules()
            #expect(rules == .defaults)
            #expect(try db.configFile(named: LearnDatabase.forestRulesName) != nil)
            rules.enemies[ForestEnemyKind.gargoyle.rawValue]!.skillCount = 1
            rules.towers[ForestTower.frost.rawValue]!.cost = 70
            rules.economy.startCoins = 240
            try db.saveForestRules(rules)
            try db.syncConfig(.bundled)
        }
        let rules = try LearnDatabase(url: url).forestRules()
        #expect(rules.enemy(.gargoyle).skillCount == 1)
        #expect(rules.tower(.frost).cost == 70)
        #expect(rules.economy.startCoins == 240)
        #expect(rules.enemy(.knight) == ForestRules.defaults.enemy(.knight))
    }

    @Test func partialDataIsFilledPerFieldAndInvalidUnitsFallBack() throws {
        let json = #"""
        {"economy":{"startCoins":300},
         "enemies":{"knight":{"health":40},"ogre":{"health":-5,"speed":0.02},"dragon":{"health":1}},
         "towers":{"rapid":{"damage":2}}}
        """#
        let rules = try #require(ForestRules.decode(Data(json.utf8)))
        #expect(rules.economy.startCoins == 300 && rules.economy.lives == 5)
        #expect(rules.enemy(.knight).health == 40)
        #expect(rules.enemy(.knight).speed == ForestRules.defaults.enemy(.knight).speed)
        // 血量非法：整只巨魔回退默认，不留下半套数值。
        #expect(rules.enemy(.ogre) == ForestRules.defaults.enemy(.ogre))
        #expect(rules.tower(.rapid).damage == 2 && rules.tower(.rapid).burst == 3)
        #expect(rules.hero(.paladin) == ForestRules.defaults.hero(.paladin))
        #expect(ForestRules.decode(Data("not json".utf8)) == nil)
        #expect(ForestRules.decode(Data(#"{"economy":{"lives":"many"}}"#.utf8)) == nil)
    }

    @Test func unreadableRowFallsBackToDefaultsWithoutOverwritingIt() throws {
        let (dir, url) = temporaryStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let db = try LearnDatabase(url: url)
        _ = try db.forestRules()
        let row = try #require(try db.configFile(named: LearnDatabase.forestRulesName))
        row.data = Data("broken".utf8)
        #expect(try db.forestRules() == .defaults)
        #expect(try db.configFile(named: LearnDatabase.forestRulesName)?.data == Data("broken".utf8))
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
