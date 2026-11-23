import Darwin
import Foundation
import LearnCore
import SpriteKit
import Testing
@testable import LearnGame

/// 独立进程、Release 构建下按需运行，避免把绘制和日志开销混入玩法循环耗时。
@MainActor
@Suite("经典模式性能测量", .serialized)
struct ClassicOptimizationMeasurements {
    @Test func rosterCacheAndCrowdedBattle() throws {
        guard ProcessInfo.processInfo.environment["LEARN_OPTIMIZATION_PROFILE"] == "1" else { return }
        let initial = residentBytes()
        for kind in UnitCatalog.enemies + UnitCatalog.forestEnemies {
            let name = "zombie-\(kind.id)"
            _ = UnitSprites.frames(named: name)
            for state in UnitSprites.clip(named: name)?.states?.values ?? [:].values {
                _ = UnitSprites.frames(named: state)
            }
            _ = UnitSprites.portrait(of: kind, skin: nil)
        }
        print("CLASSIC cache frames=\(UnitSprites.cachedAnimationFrameCount) residentDelta=\(residentBytes() - initial)")
        print("CLASSIC estimatedCacheBytes=\(UnitSprites.cachedResourceBytes)")
        #expect(UnitSprites.cachedResourceBytes <= 72 * 1024 * 1024)

        let tuning = GameTuning.make(grade: .g3, difficulty: .hard)
        let scene = GameScene(tuning: tuning, theme: .academy)
        let log = MeasurementDelegate()
        scene.gameDelegate = log
        let wall = DefenderKind.wallnut.guarding(.wall(seconds: 10000, tall: true))
        for lane in 0..<tuning.lanes {
            for column in 0..<8 {
                #expect(scene.plant(wall, in: DefenderCell(lane: lane, column: column)))
            }
        }
        for id in 0..<30 {
            scene.spawn(EnemySpawn(id: id, sign: "学", kind: .blob), lane: id % tuning.lanes, x: 1050)
        }
        var samples: [Double] = []
        for tick in 1...3000 {
            // 预热 200 帧，诊断日志只每 5 秒出现一次，不让它进入计时样本。
            let before = DispatchTime.now().uptimeNanoseconds
            scene.update(Double(tick) / 120)
            let elapsed = Double(DispatchTime.now().uptimeNanoseconds - before) / 1_000_000
            if tick > 200, tick % 600 != 0 { samples.append(elapsed) }
        }
        let sorted = samples.sorted()
        print(String(format: "CLASSIC loop samples=%d mean=%.4fms p95=%.4fms max=%.4fms", sorted.count,
            sorted.reduce(0, +) / Double(sorted.count), sorted[Int(Double(sorted.count) * 0.95)], sorted.last!))
        #expect(scene.plantedCellCount == tuning.lanes * 8)
    }

    private func residentBytes() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
}

@MainActor
private final class MeasurementDelegate: GameSceneDelegate {
    func nextEnemy() -> EnemySpawn? { nil }
    func targetChanged(to id: Int?) {}
    func enemyReachedBase(_ id: Int) -> Bool { false }
    func enemyDefeated(_ id: Int, at point: CGPoint) {}
    func barricadeRemoved() {}
    var speedFactor: Double { 1 }
}
