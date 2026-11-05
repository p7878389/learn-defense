import LearnCore
import SpriteKit
import Testing
#if os(macOS)
import AppKit
#endif
@testable import LearnGame

@Suite("庭院战场")
@MainActor
struct BattlefieldTests {
    @Test func courtyardAndDefendersAlign() throws {
        let scene = GameScene(tuning: GameTuning.make(grade: .g3, difficulty: .normal), theme: .academy)
        let view = SKView(frame: CGRect(origin: .zero, size: scene.size))
        scene.didMove(to: view)
        #expect(scene.childNode(withName: "courtyard") != nil)
        #expect(scene.children.compactMap { $0 as? DefenderNode }.isEmpty)

        for lane in 0..<5 {
            #expect(scene.plant(.inkling, at: CGPoint(x: 190, y: 70 + CGFloat(lane) * 100)))
        }
        // 草坪横向 9 格，每格约 83
        for column in 1..<9 {
            #expect(scene.plant(.twin, at: CGPoint(x: 144 + (CGFloat(column) + 0.5) * 750 / 9, y: 70)))
        }
        #expect(!scene.plant(.frost, at: CGPoint(x: 260, y: 70)), "整条路都满时才拒绝")
        #expect(scene.isPlantable(CGPoint(x: 260, y: 70)), "种满的格子仍算草坪")
        #expect(!scene.plant(.twin, at: CGPoint(x: 350, y: 560)), "草坪外不能种植")
        #expect(!scene.plant(.twin, at: CGPoint(x: 940, y: 270)), "右侧石板路不能种植")
        #expect(!scene.plant(.twin, at: CGPoint(x: 120, y: 270)), "左侧房前不能种植")
        #expect(scene.plantedCellCount == 13)

        let defenders = scene.children.compactMap { $0 as? DefenderNode }
        #expect(defenders.count == 13)
        for defender in defenders {
            #expect(defender.position.x >= 144 && defender.position.x <= 894)
            #expect(defender.position.y >= 50 && defender.position.y <= 500)
        }
        #if os(macOS)
        if let path = ProcessInfo.processInfo.environment["BATTLEFIELD_PREVIEW"] {
            for (i, kind) in UnitCatalog.enemies.prefix(5).enumerated() {
                let enemy = EnemyNode(id: i, kind: kind, sign: ["春", "学", "天", "花", "书"][i], lane: i, scale: 1)
                enemy.position = CGPoint(x: 660 + i * 50, y: 70 + i * 100)
                if i == 2 { enemy.setTargeted(true) }
                scene.addChild(enemy)
            }
            let texture = try #require(view.texture(from: scene, crop: CGRect(origin: .zero, size: scene.size)))
            let bitmap = NSBitmapImageRep(cgImage: texture.cgImage())
            try #require(bitmap.representation(using: .png, properties: [:])).write(to: URL(fileURLWithPath: path))
        }
        #endif
    }

    @Test func preschoolPlantsOnlyInMiddleRows() {
        let scene = GameScene(tuning: GameTuning.make(grade: .k2, difficulty: .normal), theme: .academy)
        scene.didMove(to: SKView(frame: CGRect(origin: .zero, size: scene.size)))
        #expect(!scene.isPlantable(CGPoint(x: 190, y: 70)), "最下面一行没有僵尸来")
        #expect(!scene.isPlantable(CGPoint(x: 190, y: 470)), "最上面一行没有僵尸来")
        for y in [170, 270, 370] {
            #expect(scene.plant(.inkling, at: CGPoint(x: 190, y: CGFloat(y))))
        }
        #expect(scene.plantedLaneCount == 3)
    }
}
