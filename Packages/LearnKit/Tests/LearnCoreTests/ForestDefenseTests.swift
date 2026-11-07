import XCTest
@testable import LearnCore

final class ForestDefenseTests: XCTestCase {
    func testPathUsesArtworkAspectForDistance() {
        let path = ForestPath(points: [.init(x: 0, y: 0), .init(x: 0, y: 1)], verticalScale: 0.5)
        XCTAssertEqual(path.length, 0.5, accuracy: 0.0001)
        XCTAssertEqual(path.point(at: 0.25), .init(x: 0, y: 0.5))
    }
    func testAttackEmitsVisibleShotThatExpires() {
        var battle = ForestBattle()
        XCTAssertTrue(battle.build(.rapid, at: 2))
        battle.startWave()
        for _ in 0..<2000 where battle.shots.isEmpty { battle.tick(0.05) }
        XCTAssertFalse(battle.shots.isEmpty)
        let shotID = battle.shots[0].id
        let targetID = battle.shots[0].targetID
        let health = battle.enemies.first { $0.id == targetID }?.health
        battle.tick(0.05)
        XCTAssertEqual(battle.enemies.first { $0.id == targetID }?.health, health)
        for _ in 0..<12 { battle.tick(0.05) }
        XCTAssertFalse(battle.shots.contains { $0.id == shotID })
    }
    func testHitFlashesEnemyAndRecordsTowerAim() {
        var battle = ForestBattle()
        XCTAssertTrue(battle.build(.rapid, at: 2))
        battle.startWave()
        for _ in 0..<2000 where battle.shots.isEmpty { battle.tick(0.05) }
        let shot = battle.shots[0]
        XCTAssertEqual(shot.slot, 2)
        XCTAssertEqual(battle.aims[2], shot.target)
        for _ in 0..<5 { battle.tick(0.05) }
        let enemy = battle.enemies.first { $0.id == shot.targetID }
        XCTAssertNotNil(enemy)
        XCTAssertGreaterThan(enemy?.hitTimer ?? 0, 0)
        XCTAssertLessThan(enemy?.health ?? 0, enemy?.maxHealth ?? 0)
        // 同一轮点射的后两发命中后闪烁结束，下一轮点射还没到
        for _ in 0..<10 { battle.tick(0.05) }
        XCTAssertEqual(battle.enemies.first { $0.id == shot.targetID }?.hitTimer, 0)
    }
    func testRapidTowerFiresBurstsAndShotsTravelAtSteadySpeed() {
        var battle = ForestBattle()
        XCTAssertTrue(battle.build(.rapid, at: 2))
        battle.startWave()
        var fireTimes: [Double] = []
        var seen = Set<Int>()
        var flights: [(distance: Double, flight: Double)] = []
        for _ in 0..<4000 where fireTimes.count < 6 && battle.phase == .fighting {
            battle.tick(0.01)
            for shot in battle.shots where !seen.contains(shot.id) {
                seen.insert(shot.id)
                fireTimes.append(battle.time)
                let distance = hypot(shot.target.x - shot.origin.x, (shot.target.y - shot.origin.y) * ForestPath.artworkAspect)
                flights.append((distance, shot.flight))
            }
        }
        XCTAssertEqual(fireTimes.count, 6)
        // 一轮三发间隔很短，两轮之间是装填冷却
        XCTAssertEqual(fireTimes[1] - fireTimes[0], ForestBattle.burstGap, accuracy: 0.02)
        XCTAssertEqual(fireTimes[2] - fireTimes[1], ForestBattle.burstGap, accuracy: 0.02)
        XCTAssertEqual(fireTimes[3] - fireTimes[2], ForestBattle.rapidReload, accuracy: 0.02)
        for (distance, flight) in flights where flight > 0.1 && flight < 0.4 {
            XCTAssertEqual(distance / flight, 1.0, accuracy: 0.001)
        }
    }
    func testTowerTurnsTowardTargetBeforeFiring() {
        var battle = ForestBattle()
        XCTAssertTrue(battle.build(.rapid, at: 2))
        battle.startWave()
        for _ in 0..<4000 where battle.shots.isEmpty { battle.tick(0.01) }
        let shot = battle.shots[0]
        let goal = atan2((shot.target.y - shot.origin.y) * ForestPath.artworkAspect, shot.target.x - shot.origin.x)
        XCTAssertLessThan(abs(remainder(goal - shot.angle, 2 * .pi)), ForestBattle.aimTolerance)
        XCTAssertEqual(battle.angles[2], shot.angle)
        XCTAssertEqual(battle.readiness(of: 2), 1)
    }
    func testBarrelTurnsGraduallyAtLimitedSpeed() {
        var battle = ForestBattle()
        XCTAssertTrue(battle.build(.rapid, at: 2))
        battle.startWave()
        var previous = battle.angles[2] ?? 0
        for _ in 0..<3000 where battle.phase == .fighting {
            battle.tick(0.01)
            let angle = battle.angles[2] ?? 0
            XCTAssertLessThanOrEqual(abs(remainder(angle - previous, 2 * .pi)), ForestBattle.turnSpeed * 0.01 + 1e-9)
            previous = angle
        }
    }
    func testDefeatLeavesEffectAndReward() {
        var battle = ForestBattle()
        XCTAssertTrue(battle.build(.rapid, at: 2))
        XCTAssertTrue(battle.build(.rapid, at: 3))
        battle.startWave()
        let coins = battle.coins
        for _ in 0..<3000 where battle.defeats.isEmpty { battle.tick(0.05) }
        XCTAssertEqual(battle.defeats.count, 1)
        XCTAssertEqual(battle.coins, coins + ForestBattle.reward)
        let defeatID = battle.defeats[0].id
        for _ in 0..<15 { battle.tick(0.05) }
        XCTAssertFalse(battle.defeats.contains { $0.id == defeatID })
    }
    func testEnemyTurnsAroundOnLeftwardPath() {
        var battle = ForestBattle()
        XCTAssertTrue(battle.build(.frost, at: 5))
        battle.startWave()
        var turned = false
        for _ in 0..<4000 where battle.phase == .fighting && !turned {
            battle.tick(0.05)
            turned = battle.enemies.contains { $0.facing <= -0.99 }
        }
        XCTAssertTrue(turned)
        XCTAssertTrue(battle.enemies.allSatisfy { (-1...1).contains($0.facing) })
    }
    /// 转身是离散换向加一段转身动作，不会出现朝向介于左右之间的中间值（画面上就是不会把图横向压扁）。
    func testTurningSwitchesFacingInstantlyAndStartsTurnAction() {
        var battle = ForestBattle()
        XCTAssertTrue(battle.build(.frost, at: 5))
        battle.startWave()
        var facings: [Int: Double] = [:]
        var sawTurn = false
        for _ in 0..<4000 where battle.phase == .fighting {
            battle.tick(0.02)
            for enemy in battle.enemies {
                XCTAssertTrue(enemy.facing == 1 || enemy.facing == -1)
                if let old = facings[enemy.id], old != enemy.facing {
                    sawTurn = true
                    XCTAssertGreaterThan(enemy.turnTimer, ForestEnemy.turnTime - 0.03)
                }
                facings[enemy.id] = enemy.facing
            }
        }
        XCTAssertTrue(sawTurn)
    }
    func testPathInterpolatesAndClamps() {
        let path = ForestPath(points: [.init(x: 0, y: 0), .init(x: 3, y: 0), .init(x: 3, y: 4)])
        XCTAssertEqual(path.length, 7)
        XCTAssertEqual(path.point(at: 5), .init(x: 3, y: 2))
        XCTAssertEqual(path.point(at: -1), .init(x: 0, y: 0))
        XCTAssertEqual(path.point(at: 99), .init(x: 3, y: 4))
    }
    func testBuildRequiresFundsAndEmptySlot() {
        var battle = ForestBattle()
        XCTAssertTrue(battle.build(.rapid, at: 0))
        XCTAssertFalse(battle.build(.frost, at: 0))
        XCTAssertFalse(battle.build(.rapid, at: 99))
        XCTAssertTrue(battle.build(.frost, at: 1))
        XCTAssertFalse(battle.build(.rapid, at: 2))
    }
    func testWaveEndsAndQuestionAwardsOnlyOnce() {
        var battle = ForestBattle()
        XCTAssertTrue(battle.build(.rapid, at: 3))
        battle.startWave()
        for _ in 0..<3000 where battle.phase == .fighting { battle.tick(0.1) }
        XCTAssertEqual(battle.phase, .question)
        let before = battle.coins
        battle.answer(correct: false)
        XCTAssertEqual(battle.phase, .question)
        XCTAssertEqual(battle.coins, before)
        battle.answer(correct: true)
        XCTAssertEqual(battle.coins, before + 50)
        battle.answer(correct: true)
        XCTAssertEqual(battle.coins, before + 50)
    }
}
