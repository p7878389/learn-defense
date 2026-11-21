import LearnCore
import SpriteKit
import Testing
@testable import LearnGame

@Suite("收藏品质边框")
@MainActor
struct HeraldicArtworkTests {
    @Test(arguments: [CosmeticRarity.common, .rare, .legendary])
    func eachTierLoadsAndReusesItsArtwork(rarity: CosmeticRarity) throws {
        let image = try #require(HeraldicArtwork.image(for: rarity))
        #expect(image.width > 100 && image.height > image.width)
        let one = try #require(HeraldicArtwork.texture(for: rarity))
        let two = try #require(HeraldicArtwork.texture(for: rarity))
        #expect(one === two)
    }
    @Test(arguments: [CosmeticRarity.common, .rare, .legendary])
    func collectionLightFramesDoNotReplaceBattleFrames(rarity: CosmeticRarity) throws {
        let dark = try #require(HeraldicArtwork.image(for: rarity))
        let light = try #require(HeraldicArtwork.image(for: rarity, lightInterior: true))
        #expect(light !== dark)
        #expect(HeraldicArtwork.image(for: rarity, lightInterior: true) === light)
        #expect(HeraldicArtwork.image(for: rarity) === dark)
        #expect(light.width == dark.width && light.height == dark.height)
    }

    @Test func monsterFrameKeepsQuestionAndTargetFeedback() throws {
        let monster = EnemyNode(id: 1, kind: .armored, sign: "春", lane: 0, scale: 1, appearance: "knight")
        let frame = try #require(monster.childNode(withName: "//monsterRarityFrame") as? SKSpriteNode)
        let sign = try #require(frame.parent as? SKShapeNode)
        #expect(sign.children.contains { ($0 as? SKLabelNode)?.text == "春" })
        #expect(monster.health.max == 2 && monster.kind.id == "armored")
        monster.setSign("学习")
        #expect(sign.children.contains { ($0 as? SKLabelNode)?.text == "学习" })
        monster.setTargeted(true)
        #expect(sign.strokeColor == Palette.target)
        #expect(sign.lineWidth == 6)
        monster.setTargeted(false)
        #expect(monster.childNode(withName: "//monsterRarityFrame") === frame)
        let original = EnemyNode(id: 2, kind: .knight, sign: "春", lane: 0, scale: 1)
        let defaultFrame = try #require(original.childNode(withName: "//monsterRarityFrame") as? SKSpriteNode)
        #expect(defaultFrame.texture === HeraldicArtwork.texture(for: .common), "未换装怪物使用普通边框，不标成已购品质")
    }

}
