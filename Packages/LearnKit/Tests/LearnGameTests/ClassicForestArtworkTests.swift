import Foundation
import LearnCore
import SpriteKit
import Testing
@testable import LearnGame

@MainActor
@Suite("经典森林角色素材")
struct ClassicForestArtworkTests {
    /// 保留森林角色的真实步行动作和出手帧，不依赖已退役的路径塔防渲染器。
    @Test func everyClassicForestEnemyKeepsDistinctWalkAndAttackFrames() throws {
        #expect(UnitCatalog.forestEnemies.count == 12)
        for kind in UnitCatalog.forestEnemies {
            let walkName = "zombie-\(kind.id)"
            let walk = try #require(UnitSprites.clip(named: walkName))
            let attackName = try #require(UnitSprites.state("attack", of: walkName))
            let attack = try #require(UnitSprites.clip(named: attackName))
            let files = try #require(walk.files) + (try #require(attack.files))
            #expect(walk.frameCount == 6)
            #expect(attack.frameCount == (kind.id == "ogre" ? 1 : 3))
            var pixels: Set<Data> = []
            for file in files {
                let image = try #require(UnitSprites.webp(file, mirrored: false), "\(kind.id)：\(file)")
                pixels.insert(try #require(image.dataProvider?.data) as Data)
            }
            #expect(pixels.count == files.count, "\(kind.id) 不能用重复立绘替代动作")
            #expect(UnitSprites.frames(named: walkName).count == 6)
            #expect(UnitSprites.frames(named: attackName).count == attack.frameCount)
        }
    }
}
