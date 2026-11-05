import LearnCore
import SpriteKit
import Testing
@testable import LearnGame

@Suite("植物与僵尸贴图")
@MainActor
struct UnitSpriteTests {
    @Test func framesUsePixelsAndShareTextures() throws {
        let first = UnitSprites.frames(named: "plant-inkling")
        #expect(first.count == 13)
        #expect(first.first?.size() == CGSize(width: 70, height: 71))
        let second = UnitSprites.frames(named: "plant-inkling")
        #expect(try #require(first.first) === #require(second.first))
        #expect(UnitSprites.node(named: "missing-resource", fitting: CGSize(width: 80, height: 80)) == nil)
    }

    @Test func newspaperBackgroundIsTransparent() throws {
        let texture = try #require(UnitSprites.frames(named: "zombie-drowsy").first)
        let image = texture.cgImage()
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        try pixels.withUnsafeMutableBytes { bytes in
            let context = try #require(CGContext(data: bytes.baseAddress, width: image.width, height: image.height,
                                               bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                               space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        #expect(pixels[3] == 0, "白色底板应转成透明，不能遮挡草地和题牌")
    }

    @Test func builtInDefendersHaveAnimatedSprites() throws {
        for kind in UnitCatalog.defenders {
            let node = DefenderNode(kind: kind, radius: 34)
            let sprite = try #require(node.childNode(withName: "//unitSprite") as? SKSpriteNode, "\(kind.id)")
            #expect(sprite.texture != nil)
            #expect(sprite.action(forKey: "idle") != nil)
            #expect(sprite.size.width <= 80 && sprite.size.height <= 80)
        }
    }

    @Test func zombiesKeepSignsAndSlowTintRecovers() throws {
        for kind in UnitCatalog.enemies {
            let node = EnemyNode(id: 1, kind: kind, sign: "学", lane: 0, scale: 1)
            let sprite = try #require(node.childNode(withName: "//unitSprite") as? SKSpriteNode, "\(kind.id)")
            #expect(sprite.texture != nil)
            #expect(sprite.action(forKey: "idle") != nil)
            // 题牌始终位于角色前面，换题仍保留文字。
            node.setSign("春天")
            #expect(node.children.contains { $0.children.contains { ($0 as? SKLabelNode)?.text == "春天" } })
            node.slow(factor: 0.5, seconds: 1)
            #expect(sprite.colorBlendFactor > 0)
            _ = node.advance(dt: 2, speed: 40)
            #expect(sprite.colorBlendFactor == 0)
        }
    }

    @Test func customKindsKeepVectorFallback() {
        let defender = DefenderKind(id: "custom", name: "新字灵", attack: .single(damage: 1),
                                    look: .init(body: .round, color: .jade), projectile: .init(shape: .orb, color: .gold))
        let enemy = EnemyKind(id: "custom", name: "新怪物", look: .init(body: .blob, color: .ink))
        let d = DefenderNode(kind: defender, radius: 34)
        let e = EnemyNode(id: 1, kind: enemy, sign: "书", lane: 0, scale: 1)
        #expect(d.childNode(withName: "//unitSprite") == nil)
        #expect(e.childNode(withName: "//unitSprite") == nil)
        #expect(d.children.contains { $0 is SKShapeNode })
        #expect(!e.children.isEmpty)
    }

    @Test func shotsUseSpriteWithoutChangingImpactTiming() {
        let layer = SKNode()
        var hits = 0
        ShotAttack(count: 2).perform(from: .zero, to: CGPoint(x: 300, y: 0), projectile: DefenderKind.inkling.projectile,
                                    in: layer) { _ in hits += 1 }
        #expect(layer.children.count == 2)
        #expect(layer.children.allSatisfy { ($0 as? SKSpriteNode)?.texture != nil })
        #expect(hits == 0)
    }
}
