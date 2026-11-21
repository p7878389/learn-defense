import Foundation
import Testing
@testable import LearnCore

@Suite("冒险塔防规则")
struct AdventureBattleTests {
    private func level(_ enemies: [AdventureSpawn], waves: Int = 1) -> AdventureLevel {
        AdventureLevel(id: 1, title: "试炼", hint: "守住防线", waves: (0..<waves).map { _ in
            AdventureWave(enemies: enemies)
        })
    }

    @Test func automaticallyShootsOnlyEnemiesAheadInSameLane() {
        var battle = AdventureBattle(level: level([.init(kind: .grunt, lane: 0, delay: 0)]))
        #expect(battle.plant("inkling", lane: 0, column: 0) == true)
        #expect(battle.start() == true)
        let events = battle.advance(by: 35)
        #expect(events.contains { if case .shot = $0 { return true }; return false })
        #expect(battle.defeated == 1)
        #expect(battle.phase == .won)
        #expect(battle.lives == 10)

        var wrongLane = AdventureBattle(level: level([.init(kind: .grunt, lane: 1, delay: 0)]))
        #expect(wrongLane.plant("inkling", lane: 0, column: 0) == true)
        #expect(wrongLane.start() == true)
        _ = wrongLane.advance(by: 80)
        #expect(wrongLane.defeated == 0)
        #expect(wrongLane.lives == 9)
        #expect(wrongLane.phase == .won)
    }

    @Test func preparationPauseAndResumeDoNotAdvanceClockOrIncome() throws {
        var battle = AdventureBattle(level: level([.init(kind: .grunt, lane: 0, delay: 0)]))
        _ = battle.advance(by: 60)
        #expect(battle.elapsed == 0)
        #expect(battle.sun == 250)
        #expect(battle.start() == false)
        #expect(battle.plant("inkling", lane: 0, column: 0) == true)
        #expect(battle.start() == true)
        _ = battle.advance(by: 2)
        battle.pause()
        let saved = battle
        _ = battle.advance(by: 60)
        #expect(battle == saved)
        var restored = try JSONDecoder().decode(AdventureBattle.self, from: JSONEncoder().encode(battle))
        restored.resume()
        _ = restored.advance(by: 5)
        #expect(restored.elapsed > saved.elapsed)
        #expect(restored.sun >= 225)
    }

    @Test func invalidPlacementAndShovelNeverCreateSun() {
        var battle = AdventureBattle(level: level([]))
        #expect(battle.plant("unknown", lane: 0, column: 0) == false)
        #expect(battle.plant("inkling", lane: 5, column: 0) == false)
        #expect(battle.plant("inkling", lane: 0, column: 9) == false)
        #expect(battle.plant("inkling", lane: 0, column: 0) == true)
        #expect(battle.plant("twin", lane: 0, column: 0) == false)
        #expect(battle.shovel(lane: 0, column: 0) == true)
        #expect(battle.shovel(lane: 0, column: 0) == false)
        #expect(battle.sun == 200)
        #expect(battle.towers.isEmpty)
    }

    @Test func leaksCanLoseAndCannotAwardKillsOrNegativeLives() {
        let spawns = (0..<15).map { AdventureSpawn(kind: .runner, lane: 1, delay: Double($0)) }
        var battle = AdventureBattle(level: level(spawns))
        #expect(battle.plant("inkling", lane: 0, column: 0) == true)
        #expect(battle.start() == true)
        _ = battle.advance(by: 120)
        #expect(battle.phase == .lost)
        #expect(battle.lives == 0)
        #expect(battle.defeated == 0)
        let settled = battle
        _ = battle.advance(by: 100)
        #expect(battle == settled)
    }

    @Test func waveCompletionAdvancesAllFiveWavesAndStarsUseBaseDurability() {
        var battle = AdventureBattle(level: level([.init(kind: .grunt, lane: 0, delay: 0)], waves: 5))
        #expect(battle.plant("inkling", lane: 0, column: 0) == true)
        #expect(battle.start() == true)
        _ = battle.advance(by: 250)
        #expect(battle.phase == .won)
        #expect(battle.wave == 5)
        #expect(battle.defeated == 5)
        #expect(battle.stars == 3)
    }

    @Test func combatAndSnapshotContinueIdenticallyAcrossTimeChunks() throws {
        var whole = AdventureBattle(level: AdventureCatalog.levels[0])
        for lane in 0..<5 { #expect(whole.plant("inkling", lane: lane, column: 0) == true) }
        #expect(whole.start() == true)
        var chunks = whole
        _ = whole.advance(by: 20)
        for _ in 0..<200 { _ = chunks.advance(by: 0.1) }
        #expect(whole.towers == chunks.towers)
        #expect(whole.enemies == chunks.enemies)
        #expect(whole.sun == chunks.sun)
        var restored = try JSONDecoder().decode(AdventureBattle.self, from: JSONEncoder().encode(chunks))
        _ = restored.advance(by: 300)
        _ = whole.advance(by: 300)
        #expect(restored.phase == whole.phase)
        #expect(restored.defeated == whole.defeated)
        #expect(restored.lives == whole.lives)
    }

    @Test func ultimateRequiresCombatEnergyAndCannotRepeatDamage() {
        var battle = AdventureBattle(level: AdventureCatalog.levels[0])
        #expect(battle.unleash().isEmpty)
        for lane in 0..<5 { _ = battle.plant("inkling", lane: lane, column: 0) }
        #expect(battle.start() == true)
        _ = battle.advance(by: 30)
        #expect(battle.energy > 0)
        while battle.phase == .playing && !battle.ultimateReady { _ = battle.advance(by: 0.5) }
        #expect(battle.ultimateReady)
        _ = battle.unleash()
        #expect(battle.energy == 0)
        #expect(battle.unleash().isEmpty)
    }

    @Test func fumeShooterWaitsUntilEnemyIsWithinItsShortRange() {
        var battle = AdventureBattle(level: level([.init(kind: .grunt, lane: 0, delay: 0)]),
                                     deck: ["stroke", "inkling", "frost", "wallnut"])
        #expect(battle.plant("stroke", lane: 0, column: 0) == true)
        #expect(battle.start() == true)
        let distant = battle.advance(by: 5)
        #expect(!distant.contains { if case .shot = $0 { return true }; return false })
        let nearby = battle.advance(by: 45)
        let shots = nearby.compactMap { event -> Double? in
            if case .shot(let tower, let target) = event { return target.x - tower.x }
            return nil
        }
        #expect(!shots.isEmpty)
        #expect(shots.allSatisfy { $0 > 0 && $0 < 300 })
        #expect(battle.defeated == 1)
    }

    @Test func frostSlowsApproachingEnemiesWithoutChangingTheirLane() throws {
        let wave = level([.init(kind: .runner, lane: 0, delay: 0)])
        var normal = AdventureBattle(level: wave)
        var frosted = AdventureBattle(level: wave)
        _ = normal.plant("inkling", lane: 0, column: 0)
        _ = frosted.plant("frost", lane: 0, column: 0)
        _ = normal.start()
        _ = frosted.start()
        _ = normal.advance(by: 2)
        _ = frosted.advance(by: 2)
        let a = try #require(normal.enemies.first)
        let b = try #require(frosted.enemies.first)
        #expect(b.x > a.x + 10)
        #expect(a.lane == b.lane)
    }

    @Test func wallsHoldBossUntilDurabilityRunsOutAndLeakDoesNotGiveBounty() {
        var battle = AdventureBattle(level: level([.init(kind: .boss, lane: 0, delay: 0)]))
        _ = battle.plant("inkling", lane: 1, column: 0)
        _ = battle.plant("wallnut", lane: 0, column: 8)
        _ = battle.start()
        let events = battle.advance(by: 32)
        #expect(events.contains { if case .towerBroken = $0 { return true }; return false })
        #expect(!battle.towers.contains { $0.kindID == "wallnut" })
        #expect(battle.lives == 10)
        _ = battle.advance(by: 100)
        #expect(battle.lives == 7)
        #expect(battle.defeated == 0)
        #expect(battle.energy == 0)
    }
}
