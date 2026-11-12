import LearnCore
import SpriteKit
import Testing
#if os(macOS)
import AppKit
import SwiftUI
#endif
@testable import LearnGame

@Suite("经典模式地图切换")
@MainActor
struct BattleMapTests {
    @Test func ultimateStateFollowsActualAnimation() {
        let library = ContentLibrary.load(userDirectory: nil)
        let pack = library.packs.first { $0.grade == .g3 }!
        let session = GameSession(config: GameConfig(profileID: UUID(), grade: .g3, packIDs: [pack.id],
                                                      selection: .all, difficulty: .normal),
                                  library: library, progress: ProgressStore(), speech: Speech(), map: .woodland)
        _ = session.scene.plant(.inkling, in: DefenderCell(lane: 0, column: 0))
        session.startBattle()
        session.scene.unleash()
        #expect(!session.isUnleashing, "空场不应显示释放中")
        _ = session.scene.spawn(EnemySpawn(id: 999, sign: "春", kind: .goblin), lane: 0, x: 800)
        session.scene.unleash()
        #expect(session.isUnleashing)
        session.scene.update(10)
        for index in 1...90 { session.scene.update(10 + Double(index) / 60) }
        #expect(!session.isUnleashing, "演出收尾后恢复蓄力状态")
    }

    @Test func switchingMapKeepsDefendersAndLawnGeometry() throws {
        let scene = GameScene(tuning: .make(grade: .g3, difficulty: .normal), theme: .academy)
        scene.didMove(to: SKView(frame: CGRect(origin: .zero, size: scene.size)))
        #expect(scene.plant(.inkling, in: DefenderCell(lane: 2, column: 0)))
        let defender = try #require(scene.children.compactMap { $0 as? DefenderNode }.first)
        let position = defender.position
        scene.setMap(.woodland)
        #expect(scene.childNode(withName: "woodland") != nil)
        #expect(scene.childNode(withName: "courtyard") == nil)
        #expect(defender.parent === scene)
        #expect(defender.position == position)
        #expect(scene.plantedCellCount == 1)
        #expect(scene.isPlantable(CGPoint(x: 190, y: 70)))
        #expect(!scene.isPlantable(CGPoint(x: 940, y: 270)))
        scene.setMap(.courtyard)
        #expect(scene.childNode(withName: "courtyard") != nil)
        #expect(scene.childNode(withName: "woodland") == nil)
    }

    @Test func mapCanOnlyChangeWhilePreparing() {
        let library = ContentLibrary.load(userDirectory: nil)
        let pack = library.packs.first { $0.grade == .g3 }!
        let session = GameSession(config: GameConfig(profileID: UUID(), grade: .g3, packIDs: [pack.id],
                                                      selection: .all, difficulty: .normal),
                                  library: library, progress: ProgressStore(), speech: Speech())
        session.selectMap(.woodland)
        #expect(session.map == .woodland)
        _ = session.scene.plant(.inkling, in: DefenderCell(lane: 0, column: 0))
        session.startBattle()
        session.selectMap(.courtyard)
        #expect(session.map == .woodland)
        #expect(session.scene.map == .woodland)
    }

    #if os(macOS)
    @Test func renderMapsAndPicker() throws {
        guard let folder = ProcessInfo.processInfo.environment["BATTLE_MAP_PREVIEW"] else { return }
        try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        let scene = GameScene(tuning: .make(grade: .g3, difficulty: .normal), theme: .academy)
        let view = SKView(frame: CGRect(origin: .zero, size: scene.size))
        scene.didMove(to: view)
        for lane in 0..<5 {
            #expect(scene.plant(.inkling, in: DefenderCell(lane: lane, column: 0)))
            let enemy = scene.spawn(EnemySpawn(id: lane, sign: ["春", "夏", "秋", "冬", "学"][lane], kind: .goblin), lane: lane, x: 780 + CGFloat(lane) * 25)
            enemy.removeAllActions()
            enemy.alpha = 1
        }
        for defender in scene.children.compactMap({ $0 as? DefenderNode }) {
            defender.removeAllActions()
            defender.setScale(1)
        }
        for map in BattleMap.allCases {
            scene.setMap(map)
            let texture = try #require(view.texture(from: scene, crop: CGRect(origin: .zero, size: scene.size)))
            try #require(NSBitmapImageRep(cgImage: texture.cgImage()).representation(using: .png, properties: [:]))
                .write(to: URL(fileURLWithPath: folder).appendingPathComponent("runtime-\(map.rawValue).png"))
        }
        for width in [760.0, 1100.0] {
            let picker = BattleMapPicker(selection: .woodland, onSelect: { _ in }).padding(20).frame(width: width).background(Theme.paper)
            let renderer = ImageRenderer(content: picker)
            renderer.scale = 2
            let cgImage = try #require(renderer.cgImage)
            try #require(NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:]))
                .write(to: URL(fileURLWithPath: folder).appendingPathComponent("picker-\(Int(width)).png"))
        }
    }
    #endif
}
