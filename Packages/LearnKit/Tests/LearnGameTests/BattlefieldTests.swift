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
        #expect(!scene.plant(.frost, at: CGPoint(x: 260, y: 70)), "格子已有植物时拒绝")
        #expect(scene.isPlantable(CGPoint(x: 260, y: 70)), "种满的格子仍算草坪")
        #expect(!scene.plant(.frost, at: CGPoint(x: 190, y: 170)), "这一路还有空格也不挪到别格")
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

    @Test func lawnCellsMatchCourtyard() {
        let lawn = Lawn(lanes: 5)
        #expect(lawn.cell(at: CGPoint(x: 144, y: 20)) == DefenderCell(lane: 0, column: 0))
        #expect(lawn.cell(at: CGPoint(x: 894, y: 520)) == DefenderCell(lane: 4, column: 8), "右上角的边也算草坪")
        #expect(lawn.cell(at: CGPoint(x: 143, y: 100)) == nil)
        #expect(lawn.cell(at: CGPoint(x: 500, y: 521)) == nil)
        #expect(abs(lawn.columnX(0) - 185.67) < 0.01)
        #expect(lawn.laneY(0) == 70 && lawn.laneY(4) == 470)

        let preschool = Lawn(lanes: 3)
        #expect(preschool.laneY(0) == 170 && preschool.laneBottom(0) == 120)
        #expect(preschool.cell(at: CGPoint(x: 300, y: 119)) == nil)
        #expect(preschool.cell(at: CGPoint(x: 300, y: 120)) == DefenderCell(lane: 0, column: 1))
    }

    @Test func dragLocationMapsToScene() {
        let frame = CGRect(x: 10, y: 100, width: 600, height: 300)
        #expect(GameScene.scenePoint(at: CGPoint(x: 310, y: 250), in: frame) == CGPoint(x: 600, y: 300))
        #expect(GameScene.scenePoint(at: CGPoint(x: 10, y: 100), in: frame) == CGPoint(x: 0, y: 600), "左上角在场景里是左上")
        #expect(GameScene.scenePoint(at: CGPoint(x: 5, y: 250), in: frame) == nil, "战场外松手不算")
        #expect(GameScene.scenePoint(at: CGPoint(x: 0, y: 0), in: .zero) == nil, "还没量到战场位置时不算")
        // 战场比 2:1 高时上下留边
        let tall = CGRect(x: 0, y: 0, width: 600, height: 400)
        #expect(GameScene.scenePoint(at: CGPoint(x: 0, y: 350), in: tall) == CGPoint(x: 0, y: 0))
    }

    @Test func plantPreviewShowsTargetCell() throws {
        let scene = GameScene(tuning: GameTuning.make(grade: .g3, difficulty: .normal), theme: .academy)
        scene.didMove(to: SKView(frame: CGRect(origin: .zero, size: scene.size)))
        scene.showPlantPreview(at: CGPoint(x: 200, y: 80))
        let preview = try #require(scene.childNode(withName: "plantPreview") as? SKShapeNode)
        #expect(!preview.isHidden)
        #expect(abs(preview.position.x - 185.67) < 0.01 && preview.position.y == 70)
        #expect(preview.strokeColor == Palette.jade)

        scene.plant(.inkling, at: CGPoint(x: 200, y: 80))
        scene.showPlantPreview(at: CGPoint(x: 200, y: 80))
        #expect(preview.strokeColor == Palette.hurt, "已有植物的格子标红")

        scene.showPlantPreview(at: CGPoint(x: 1000, y: 80))
        #expect(preview.isHidden, "草坪外不显示")
        scene.showPlantPreview(at: CGPoint(x: 200, y: 80))
        scene.showPlantPreview(at: nil)
        #expect(preview.isHidden)
    }
}
