import LearnCore
import SpriteKit
import Testing
@testable import LearnGame

@MainActor
@Suite("经典地图毁灭菇爆破")
struct ClassicDoomSceneTests {
    @Test func preparationAndPauseFreezeTimersAndCraterExpiresOnBattleClock() {
        let scene = GameScene(tuning: .make(grade: .g3, difficulty: .normal), theme: .academy)
        let probe = DoomSceneProbe(); scene.gameDelegate = probe
        scene.setPreparing(true)
        #expect(scene.plant(AdventureCatalog.doomShroom, in: DefenderCell(lane: 2, column: 5)))
        var now = 100.0
        scene.update(now)
        advance(scene, steps: 200, now: &now)
        #expect(scene.doomCooldown == 50)
        #expect(!scene.children.contains { $0.name?.hasPrefix("doom-crater-") == true })
        scene.setPreparing(false)
        advance(scene, steps: 10, now: &now)
        scene.setGamePaused(true)
        advance(scene, steps: 200, now: &now)
        #expect(scene.doomCooldown == 50)
        #expect(!scene.children.contains { $0.name?.hasPrefix("doom-crater-") == true })
        scene.setGamePaused(false)
        advance(scene, steps: 11, now: &now)
        #expect(scene.hasDoomCrater(at: CGPoint(x: 602, y: 270)))
        advance(scene, steps: 980, now: &now)
        #expect(scene.doomCooldown == 0)
        #expect(!scene.plant(.inkling, in: DefenderCell(lane: 2, column: 5)))
        advance(scene, steps: 2618, now: &now)
        #expect(!scene.plant(.inkling, in: DefenderCell(lane: 2, column: 5)), "焦坑 180 秒尚未结束")
        advance(scene, steps: 1, now: &now)
        #expect(scene.plant(.inkling, in: DefenderCell(lane: 2, column: 5)))
    }

    @Test func preschoolChargeUsesTheMiddleThreeRowsAndSurvivesMapChange() throws {
        let scene = GameScene(tuning: .make(grade: .k2, difficulty: .easy), theme: .academy)
        scene.setPreparing(true)
        #expect(scene.plant(AdventureCatalog.doomShroom, in: DefenderCell(lane: 1, column: 5)))
        let body = try #require(scene.children.first { $0.name?.hasPrefix("doom-charge-") == true })
        // SpriteKit 会将节点坐标量化为 Float，允许远小于一个像素的舍入误差。
        #expect(abs(body.position.x - Lawn(lanes: 3).columnX(5)) < 0.001)
        #expect(body.position.y == Lawn(lanes: 3).laneY(1))
        scene.setMap(.woodland)
        #expect(body.parent === scene)
        #expect(!scene.plant(.wallnut, in: DefenderCell(lane: 1, column: 5)))
    }

    private func advance(_ scene: GameScene, steps: Int, now: inout Double) {
        for _ in 0..<steps { now += 0.05; scene.update(now) }
    }

    @Test func delayedBlastKillsOnlyInRangeOnceAndLeavesBlockedCell() {
        for map in BattleMap.allCases {
            let scene = GameScene(tuning: .make(grade: .g3, difficulty: .normal), theme: .academy, map: map)
            let probe = DoomSceneProbe()
            scene.gameDelegate = probe
            let near = scene.spawn(EnemySpawn(id: 1, sign: "近", kind: .armored), lane: 2, x: 602)
            let far = scene.spawn(EnemySpawn(id: 2, sign: "远", kind: .blob), lane: 2, x: 1150)
            #expect(scene.plant(.wallnut, in: DefenderCell(lane: 1, column: 5)))
            #expect(scene.plant(AdventureCatalog.doomShroom, in: DefenderCell(lane: 2, column: 5)))
            scene.update(100)
            for i in 1...10 { scene.update(100 + Double(i) * 0.05) }
            #expect(near.health.current == 2)
            for i in 11...22 { scene.update(100 + Double(i) * 0.05) }
            #expect(near.health.current == 0)
            #expect(far.health.current == 1)
            #expect(probe.defeated == [1])
            #expect(scene.children.contains { $0.name?.hasPrefix("doom-crater-") == true })
            #expect(!scene.plant(.inkling, in: DefenderCell(lane: 2, column: 5)))
            #expect(scene.children.compactMap { $0 as? DefenderNode }.contains { $0.kind.id == "wallnut" })
            for i in 23...30 { scene.update(100 + Double(i) * 0.05) }
            #expect(probe.defeated == [1], "爆炸不能重复结算击杀")
        }
    }
}

@MainActor
private final class DoomSceneProbe: GameSceneDelegate {
    var defeated: [Int] = []
    var speedFactor: Double { 0 }
    func nextEnemy() -> EnemySpawn? { nil }
    func targetChanged(to id: Int?) {}
    func enemyReachedBase(_ id: Int) -> Bool { false }
    func enemyDefeated(_ id: Int, at point: CGPoint) { defeated.append(id) }
    func barricadeRemoved() {}
}
