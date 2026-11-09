import XCTest
@testable import LearnCore

final class ForestCombatTests: XCTestCase {
    // A live enemy beside a built tower; no test hooks in the engine.
    private func encounter(_ kind: ForestEnemyKind = .goblin) -> ForestBattle {
        var battle = ForestBattle(boss: .knight)
        XCTAssertTrue(battle.build(.rapid, at: 2))
        battle.phase = .fighting
        var enemy = ForestEnemy(id: 100, kind: kind)
        enemy.distance = stride(from: 0.0, to: ForestPath.forest.length, by: 0.005).min {
            ForestPath.forest.point(at: $0).distance(to: ForestBattle.slots[2]) <
            ForestPath.forest.point(at: $1).distance(to: ForestBattle.slots[2])
        }!
        enemy.health = 100
        enemy.attackCooldown = 0
        battle.enemies = [enemy]
        return battle
    }

    func testWindupDoesNotDamageAndProjectileHitsOnlyOnce() {
        var battle = encounter()
        battle.tick(0.01)
        XCTAssertNotNil(battle.enemies[0].cast)
        let hp = battle.defenses[2]!.health
        for _ in 0..<3 { battle.tick(0.1) }
        XCTAssertEqual(battle.defenses[2]!.health, hp)
        XCTAssertTrue(battle.combatShots.isEmpty)
        for _ in 0..<20 { battle.tick(0.05) }
        XCTAssertEqual(battle.defenses[2]!.health, hp - 3, accuracy: 0.001)
        for _ in 0..<5 { battle.tick(0.05) }
        XCTAssertEqual(battle.defenses[2]!.health, hp - 3, accuracy: 0.001)
    }

    func testDeadCasterCannotReleaseOrDamage() {
        var battle = encounter(.ogre)
        battle.tick(0.01)
        battle.enemies[0].health = 0
        for _ in 0..<30 { battle.tick(0.05) }
        XCTAssertEqual(battle.defenses[2]!.health, 30)
        XCTAssertFalse(battle.combatShots.contains { $0.side == .enemy })
        XCTAssertEqual(battle.coins, 150)
        battle.tick(0.1)
        XCTAssertEqual(battle.coins, 150)
    }

    func testDestroyedTargetCancelsPendingCast() {
        var battle = encounter(.pharaoh)
        battle.tick(0.01)
        battle.defenses[2]!.health = 0
        for _ in 0..<25 { battle.tick(0.05) }
        XCTAssertFalse(battle.combatShots.contains { $0.side == .enemy })
        XCTAssertNil(battle.enemies.first?.cast)
    }

    func testQuestionAndTerminalStatesPauseCombatAndInvalidTimeIsIgnored() {
        for phase in [ForestBattle.Phase.question, .won, .lost] {
            var battle = encounter()
            battle.tick(0.01)
            battle.phase = phase
            let time = battle.time
            let castTime = battle.enemies[0].cast!.age
            for delta in [0.1, Double.nan, Double.infinity, -1, 0] { battle.tick(delta) }
            XCTAssertEqual(battle.defenses[2]!.health, 30)
            XCTAssertEqual(battle.enemies[0].cast!.age, castTime)
            XCTAssertEqual(battle.time, time)
        }
    }

    func testEveryBossReleasesItsOwnAttackAndDoesNotLeavePath() {
        for kind in ForestEnemyKind.bosses {
            var battle = encounter(kind)
            battle.enemies[0].attacks = 2 // Third attack is the signature skill.
            let distance = battle.enemies[0].distance
            var saw = false
            for _ in 0..<60 {
                battle.tick(0.05)
                saw = saw || battle.combatShots.contains { $0.side == .enemy && $0.effect == kind.skillEffect }
            }
            XCTAssertTrue(saw, kind.rawValue)
            XCTAssertGreaterThanOrEqual(battle.enemies.first?.distance ?? distance, distance)
            XCTAssertLessThan(battle.defenses[2]!.health, 30, kind.rawValue)
        }
    }

    func testRepairChargesOnlyWhenUsefulAndRestoresRuins() {
        var battle = encounter()
        XCTAssertFalse(battle.repair(at: 2))
        XCTAssertEqual(battle.coins, 50)
        battle.defenses[2]!.health = 0
        XCTAssertTrue(battle.repair(at: 2))
        XCTAssertEqual(battle.defenses[2]!.health, 20)
        XCTAssertEqual(battle.coins, 35)
        XCTAssertTrue(battle.repair(at: 2))
        XCTAssertEqual(battle.defenses[2]!.health, 30)
        XCTAssertEqual(battle.coins, 20)
        XCTAssertFalse(battle.repair(at: 2))
        XCTAssertFalse(battle.repair(at: 99))
        battle.defenses[2]!.health = 1
        battle.phase = .question
        XCTAssertFalse(battle.repair(at: 2))
        battle.phase = .fighting
        battle.coins = 14
        XCTAssertFalse(battle.repair(at: 2))
    }

    func testRuinedTowerDoesNotFireAndOccupiedHeroSlotCannotBeBuiltOver() {
        var battle = encounter()
        battle.defenses[2]!.health = 0
        for _ in 0..<20 { battle.tick(0.05) }
        XCTAssertTrue(battle.shots.isEmpty)
        var setup = ForestBattle()
        XCTAssertTrue(setup.deploy(.paladin, at: 2))
        XCTAssertFalse(setup.build(.rapid, at: 2))
        XCTAssertFalse(setup.deploy(.botanist, at: 2))
        XCTAssertFalse(setup.deploy(.paladin, at: 3))
        XCTAssertEqual(setup.defenses[2]?.health, 36)
    }

    func testHeroIsTargetableAndShieldReducesIncomingDamage() {
        var unshielded = encounter()
        unshielded.towers.removeValue(forKey: 2)
        unshielded.defenses[2] = ForestDefenseUnit(hero: .paladin)
        // Shield has a real 0.8s windup; arrange the incoming attack after it.
        unshielded.enemies[0].attackCooldown = 0.5
        var shielded = unshielded
        XCTAssertTrue(shielded.useSkill(at: 2))
        XCTAssertFalse(shielded.useSkill(at: 2))
        for _ in 0..<32 {
            unshielded.tick(0.05)
            shielded.tick(0.05)
        }
        XCTAssertLessThan(unshielded.defenses[2]!.health, 36)
        XCTAssertGreaterThan(shielded.defenses[2]!.health, unshielded.defenses[2]!.health)
    }

    func testBotanistSkillRootsAndPausesMovementThenExpires() {
        var battle = encounter()
        battle.defenses[2] = ForestDefenseUnit(hero: .botanist)
        battle.towers.removeValue(forKey: 2)
        battle.enemies[0].attackCooldown = 20
        XCTAssertTrue(battle.useSkill(at: 2))
        for _ in 0..<35 { battle.tick(0.05) }
        XCTAssertGreaterThan(battle.enemies[0].rooted, 0)
        let stopped = battle.enemies[0].distance
        for _ in 0..<10 { battle.tick(0.05) }
        XCTAssertEqual(battle.enemies[0].distance, stopped)
        for _ in 0..<65 { battle.tick(0.05) }
        XCTAssertGreaterThan(battle.enemies[0].distance, stopped)
    }

    func testEachSelectedBossAppearsOnlyAtEndOfThirdWave() {
        for boss in ForestEnemyKind.bosses {
            var battle = ForestBattle(boss: boss)
            XCTAssertTrue(battle.build(.rapid, at: 5))
            battle.wave = 2
            battle.startWave()
            var seen = Set<ForestEnemyKind>()
            for _ in 0..<260 {
                battle.tick(0.05)
                seen.formUnion(battle.enemies.map(\.kind))
            }
            XCTAssertEqual(seen.filter(\.isBoss), [boss])
            XCTAssertEqual(battle.phase, .fighting)
        }
    }

    func testEveryBossCanCompleteAllWavesAndReachWin() {
        for boss in ForestEnemyKind.bosses {
            var battle = ForestBattle(boss: boss)
            battle.coins = 1000
            for slot in 0..<4 {
                XCTAssertTrue(battle.build(.rapid, at: slot), boss.rawValue)
            }
            XCTAssertTrue(battle.deploy(.paladin, at: 4), boss.rawValue)
            XCTAssertTrue(battle.deploy(.botanist, at: 5), boss.rawValue)

            for expectedWave in 1...3 {
                battle.startWave()
                for _ in 0..<12000 where battle.phase == .fighting {
                    battle.tick(0.05)
                }
                XCTAssertEqual(battle.phase, .question, "\(boss.rawValue) 第 \(expectedWave) 波")
                XCTAssertEqual(battle.wave, expectedWave)
                battle.answer(correct: true)
            }
            XCTAssertEqual(battle.phase, .won, boss.rawValue)
        }
    }

    func testBattleCanStillBeLostWhenDefenseIsDestroyed() {
        var battle = ForestBattle(boss: .knight)
        XCTAssertTrue(battle.build(.rapid, at: 0))
        battle.startWave()
        battle.defenses[0]!.health = 0

        for _ in 0..<8000 where battle.phase == .fighting { battle.tick(0.05) }
        XCTAssertEqual(battle.phase, .question)
        XCTAssertEqual(battle.lives, 1)
        battle.answer(correct: true)
        XCTAssertTrue(battle.repair(at: 0))
        battle.startWave()
        battle.defenses[0]!.health = 0
        for _ in 0..<8000 where battle.phase == .fighting { battle.tick(0.05) }

        XCTAssertEqual(battle.phase, .lost)
        XCTAssertEqual(battle.lives, 0)
    }
}
