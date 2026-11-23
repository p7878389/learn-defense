import Foundation
import Testing
@testable import LearnCore

@Suite("毁灭菇战斗规则")
struct AdventureDoomTests {
    private let deck = ["inkling", "frost", "wallnut", "doomShroom"]

    private func battle(spawns: [AdventureSpawn] = [.init(kind: .boss, lane: 0, delay: 3600)]) throws -> AdventureBattle {
        _ = try #require(AdventureCatalog.defender("doomShroom"), "毁灭菇必须是可选择的冒险卡牌")
        let level = AdventureLevel(id: 1, title: "毁灭菇试炼", hint: "范围爆破", waves: [.init(enemies: spawns)])
        var battle = AdventureBattle(level: level, deck: deck)
        #expect(battle.plant("inkling", lane: 4, column: 0) == true)
        return battle
    }

    @Test func placementChargesOnceAndRejectsTakenCellsWithoutSpending() throws {
        var state = try battle()
        #expect(state.plant("doomShroom", lane: 4, column: 0) == false)
        #expect(state.plant("doomShroom", lane: 5, column: 0) == false)
        #expect(state.plant("doomShroom", lane: 0, column: 9) == false)
        #expect(state.sun == 200)
        #expect(state.plant("doomShroom", lane: 2, column: 5) == true)
        #expect(state.sun == 75)
        #expect(state.plant("wallnut", lane: 2, column: 5) == false)
        #expect(state.shovel(lane: 2, column: 5) == false)
        #expect(state.sun == 75)
        #expect(state.plant("doomShroom", lane: 2, column: 6) == false)
    }

    @Test func blastWaitsForFuseKillsOnlyInRangeAndDamagesBossOnce() throws {
        var state = try battle(spawns: [
            .init(kind: .grunt, lane: 0, delay: 0), .init(kind: .armored, lane: 2, delay: 0),
            .init(kind: .grunt, lane: 4, delay: 0), .init(kind: .grunt, lane: 2, delay: 0),
            .init(kind: .boss, lane: 1, delay: 0), .init(kind: .boss, lane: 0, delay: 3600)
        ])
        #expect(state.start() == true)
        _ = state.advance(by: 0.05)
        // 用真实 JSON 存档设置独立手算位置，不新增产品测试接口。
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        var enemies = try #require(json["enemies"] as? [[String: Any]])
        for i in enemies.indices { enemies[i]["x"] = i == 3 ? 1020 : 602 }
        json["enemies"] = enemies
        state = try JSONDecoder().decode(AdventureBattle.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(state.plant("doomShroom", lane: 2, column: 5) == true)
        _ = state.advance(by: 0.95)
        #expect(state.enemies.contains { $0.kind == .boss && $0.health == 160 })
        let events = state.advance(by: 0.05)
        #expect(state.defeated == 3)
        #expect(state.enemies.contains { $0.kind == .grunt && $0.x > 900 })
        #expect(state.enemies.first { $0.kind == .boss }?.health == 40)
        #expect(events.filter { if case .defeated = $0 { return true }; return false }.count == 3)
        let energy = state.energy
        _ = state.advance(by: 0.1)
        #expect(state.defeated == 3)
        #expect(state.energy == energy)
        #expect(state.enemies.first { $0.kind == .boss }?.health == 40)
    }

    @Test func craterBlocksItsCellUntilExpiryAndCannotBeShoveled() throws {
        var state = try battle()
        #expect(state.plant("wallnut", lane: 1, column: 5) == true)
        #expect(state.plant("doomShroom", lane: 2, column: 5) == true)
        #expect(state.start() == true)
        _ = state.advance(by: 1)
        #expect(state.towers.contains { $0.kindID == "wallnut" }, "爆炸不得伤害相邻植物")
        #expect(state.shovel(lane: 2, column: 5) == false)
        _ = state.advance(by: 50)
        let before = state.sun
        #expect(state.plant("wallnut", lane: 2, column: 5) == false)
        #expect(state.sun == before)
        #expect(state.plant("doomShroom", lane: 2, column: 6) == true, "冷却结束应允许在另一空格使用")
        _ = state.advance(by: 129.95)
        #expect(state.plant("wallnut", lane: 2, column: 5) == false)
        _ = state.advance(by: 0.05)
        #expect(state.plant("wallnut", lane: 2, column: 5) == true)
    }

    @Test func preparationAndPauseFreezeFuseAndSnapshotContinuesIdentically() throws {
        var state = try battle()
        #expect(state.plant("doomShroom", lane: 2, column: 5) == true)
        let preparing = state
        _ = state.advance(by: 60)
        #expect(state == preparing)
        #expect(state.start() == true)
        _ = state.advance(by: 0.5)
        state.pause()
        let paused = state
        _ = state.advance(by: 500)
        #expect(state == paused)
        var restored = try JSONDecoder().decode(AdventureBattle.self, from: JSONEncoder().encode(state))
        #expect(restored == state)
        restored.resume(); state.resume()
        let whole = state.advance(by: 1)
        var chunks: [AdventureEvent] = []
        for _ in 0..<20 { chunks += restored.advance(by: 0.05) }
        #expect(restored == state)
        #expect(chunks == whole)
        #expect(restored.plant("wallnut", lane: 2, column: 5) == false)
        #expect(restored.plant("doomShroom", lane: 2, column: 6) == false)
    }

    @Test func oldBattleWithoutNewStateStillDecodesAndAcceptsNewCard() throws {
        var state = try battle()
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        json.removeValue(forKey: "doomState")
        state = try JSONDecoder().decode(AdventureBattle.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(state.plant("doomShroom", lane: 2, column: 5) == true)
        #expect(state.sun == 75)
    }
}
