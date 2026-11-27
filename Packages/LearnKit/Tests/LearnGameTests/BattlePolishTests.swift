#if os(macOS)
import AppKit
#endif
import Foundation
import LearnCore
import SpriteKit
import SwiftUI
import Testing
@testable import LearnGame

@MainActor
@Suite("种植容错与准备阶段优化")
struct BattlePolishTests {
    private func makeClassicSession(sun: Int? = nil) throws -> GameSession {
        let pack = ContentPack(id: "polish", title: "测试题库", subject: .chinese, grade: .g3,
            units: [ContentUnit(id: "u", title: "单元", lessons: [Lesson(id: "l", title: "课",
                questions: [ChoiceItem(id: "q1", prompt: "一加一", options: ["二", "三"], answer: "二")])])])
        var growthState = GrowthState()
        growthState.xp = GrowthCatalog.bundled.pacing.levelCurve.totalXP(toReach: 4)
        growthState.coins = 500
        let db = try LearnDatabase(url: nil)
        let profileID = UUID()
        try db.saveGrowthState(growthState, profileID: profileID)
        let growth = GrowthStore(profileID: profileID, database: db, catalog: .bundled)
        _ = try growth.purchaseDoomShroom()
        let config = GameConfig(profileID: profileID, grade: .g3, packIDs: [pack.id], selection: .all, difficulty: .normal)
        let s = GameSession(config: config, library: ContentLibrary(packs: [pack]), progress: ProgressStore(),
                            speech: Speech(), growth: growth)
        if let sun { s.sun = sun }
        return s
    }

    @Test func classicResetPreparationRestoresSunAndClearsDefendersAndDoomOnlyWhilePreparing() throws {
        let s = try makeClassicSession()
        defer { s.end() }
        let startSun = s.tuning.startingSun
        #expect(s.resetPreparation() == false)
        let p0 = CGPoint(x: s.scene.lawn.columnX(0), y: s.scene.laneY(0))
        let p1 = CGPoint(x: s.scene.lawn.columnX(1), y: s.scene.laneY(1))
        #expect(s.dropSeed(id: DefenderKind.inkling.id, at: p0) == true)
        #expect(s.dropSeed(id: AdventureDoom.id, at: p1) == true)
        #expect(s.sun < startSun)
        #expect(s.plantedLaneCount == 1)
        #expect(s.doomCooldown > 0)

        #expect(s.resetPreparation() == true)
        #expect(s.sun == startSun)
        #expect(s.plantedLaneCount == 0 && s.scene.plantedCellCount == 0)
        #expect(s.doomCooldown == 0 && s.scene.doomState.charges.isEmpty)

        #expect(s.dropSeed(id: DefenderKind.inkling.id, at: p0) == true)
        s.startBattle()
        #expect(s.phase == .playing)
        #expect(s.resetPreparation() == false)
        #expect(s.plantedLaneCount == 1)
    }

    @Test func classicTapSelectCardThenTapBattlefieldPlantsDefender() throws {
        let s = try makeClassicSession()
        defer { s.end() }
        s.selectCard(id: DefenderKind.inkling.id)
        #expect(s.selectedCardID == DefenderKind.inkling.id)
        // 再次点击同一张卡取消选中
        s.selectCard(id: DefenderKind.inkling.id)
        #expect(s.selectedCardID == nil)

        s.selectCard(id: DefenderKind.inkling.id)
        let point = CGPoint(x: s.scene.lawn.columnX(2), y: s.scene.laneY(1))
        #expect(s.placeSelectedCard(at: point) == true)
        #expect(s.scene.plantedCellCount == 1)
        #expect(s.selectedCardID == nil, "点选种下后自动收起选中框，避免后续点击题目僵尸时误种")
    }

    @Test func adventureResetPreparationSyncsSessionHUDAndScene() throws {
        let db = try LearnDatabase(url: nil)
        let profile = Profile(name: "冒险", grade: .g3, avatar: "🐯")
        try db.saveProfiles([profile])
        let model = AppModel(database: db, library: ContentLibrary(packs: []), speechLibrary: SpeechLibrary(database: db))
        let session = AdventureSession(levelID: 1, model: model, profileID: profile.id, difficulty: .normal)
        #expect(session.plant("inkling", lane: 0, column: 0) == true)
        session.shovel(lane: 0, column: 0)
        #expect(session.hud.sun == 200 && session.hud.towers == 0)
        session.resetPreparation()
        #expect(session.hud.sun == 250 && session.hud.towers == 0)
        #expect(!session.scene.children.contains { $0 is DefenderNode })
    }

    @Test func parentGateReportsRemainingLockSecondsAndUnlocksAfterExpiry() {
        var gate = ParentGate()
        let start = Date(timeIntervalSince1970: 10_000)
        #expect(gate.remainingLockSeconds(now: start) == 0)
        for _ in 0..<3 {
            #expect(gate.submit(gate.answer + 1, now: start) == false)
        }
        #expect(!gate.canAnswer(now: start))
        #expect(gate.remainingLockSeconds(now: start.addingTimeInterval(15.2)) == 45)
        #expect(gate.remainingLockSeconds(now: start.addingTimeInterval(60)) == 0)
        #expect(gate.canAnswer(now: start.addingTimeInterval(60)))
    }

    #if os(macOS)
    @Test func adventureSceneCompensatesDoomNodesInPortraitViewport() throws {
        let db = try LearnDatabase(url: nil)
        let profile = Profile(name: "竖屏特效", grade: .g3, avatar: "🐯")
        try db.saveProfiles([profile])
        var state = GrowthState()
        state.xp = GrowthCatalog.bundled.pacing.levelCurve.totalXP(toReach: 4)
        state.coins = 500
        _ = state.purchaseDoomShroom(level: 4)
        try db.saveGrowthState(state, profileID: profile.id)
        let model = AppModel(database: db, library: ContentLibrary(packs: []), speechLibrary: SpeechLibrary(database: db))
        let session = AdventureSession(levelID: 1, model: model, profileID: profile.id, difficulty: .normal,
                                       deck: ["inkling", AdventureDoom.id, "frost", "wallnut"])
        #expect(session.plant(AdventureDoom.id, lane: 2, column: 3) == true)
        let size = CGSize(width: 820, height: 1100)
        let host = NSHostingView(rootView: AdventureScreen(session: session, onClose: {}).frame(width: size.width, height: size.height))
        host.frame = CGRect(origin: .zero, size: size)
        for _ in 0..<4 {
            host.layoutSubtreeIfNeeded()
            RunLoop.current.run(until: Date().addingTimeInterval(0.04))
        }
        session.scene.update(0.1)
        let doomNode = try #require(session.scene.childNode(withName: "doom-charge-1"))
        func findSKView(_ v: NSView) -> SKView? {
            if let sk = v as? SKView { return sk }
            return v.subviews.lazy.compactMap(findSKView).first
        }
        let skView = try #require(findSKView(host))
        let sx = skView.bounds.width / 1200 * abs(doomNode.xScale)
        let sy = skView.bounds.height / 600 * abs(doomNode.yScale)
        #expect(abs(sx - sy) < 0.02, "竖屏铺满视口时毁灭菇与场景特效不应被纵向拉长")
    }
    #endif
}
