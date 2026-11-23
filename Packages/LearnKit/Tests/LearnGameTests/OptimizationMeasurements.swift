import Foundation
import LearnCore
import Testing
@testable import LearnGame

/// 可选测量：LEARN_OPTIMIZATION_PROFILE=1 swift test -c release --filter OptimizationMeasurements
@MainActor
@Suite("优化基线测量", .serialized)
struct OptimizationMeasurements {
    @Test func adventureSimulationRenderingAndDiskSave() throws {
        guard ProcessInfo.processInfo.environment["LEARN_OPTIMIZATION_PROFILE"] == "1" else { return }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let database = try LearnDatabase(url: folder.appendingPathComponent("measurement.store"))
        let id = UUID()
        var initial = GrowthState(); initial.coins = 600
        initial.adventure.bestStars["5"] = 3
        try database.saveGrowthState(initial, profileID: id)
        let growth = GrowthStore(profileID: id, database: database, catalog: .bundled)
        var battle = AdventureBattle(level: AdventureCatalog.levels[5], difficulty: .easy)
        for lane in 0..<5 { _ = battle.plant("inkling", lane: lane, column: 0) }
        let started = battle.start()
        #expect(started)
        try growth.startAdventure(battle)
        let scene = AdventureScene(loadout: .standard)
        var simulation: [Double] = [], rendering: [Double] = [], saving: [Double] = []
        for tick in 0..<2000 {
            guard battle.phase == .playing else { break }
            var start = DispatchTime.now().uptimeNanoseconds
            let events = battle.advance(by: 0.05)
            simulation.append(Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000)
            start = DispatchTime.now().uptimeNanoseconds
            scene.render(battle, events: events)
            rendering.append(Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000)
            if tick % 40 == 0 && !battle.isFinished {
                start = DispatchTime.now().uptimeNanoseconds
                try growth.saveAdventure(battle)
                saving.append(Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000)
            }
        }
        for (name, samples) in [("simulation-50ms-step", simulation), ("render-sync", rendering), ("disk-save", saving)] {
            let sorted = samples.sorted()
            guard !sorted.isEmpty else { continue }
            let p95 = sorted[min(sorted.count - 1, Int(Double(sorted.count) * 0.95))]
            print(String(format: "OPTIMIZATION %@ samples=%d mean=%.3fms p95=%.3fms max=%.3fms", name,
                         sorted.count, sorted.reduce(0, +) / Double(sorted.count), p95, sorted.last!))
        }
        #expect(try database.growthState(profileID: id)?.coins == 585)
    }
}
