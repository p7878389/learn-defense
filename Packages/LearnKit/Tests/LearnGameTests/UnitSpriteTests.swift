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
            // 土豆雷埋着时只有一帧，出土后才动起来
            if case .mine = kind.guardStyle { node.arm() }
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

    @Test func forestEnemiesWalkLeftWithForestArt() throws {
        for kind in UnitCatalog.forestEnemies {
            let base = "zombie-\(kind.id)"
            let walk = UnitSprites.frames(named: base)
            #expect(walk.count == 6, "\(kind.id) 行走六帧")
            let attack = try #require(UnitSprites.state("attack", of: base), "\(kind.id) 缺少出手动画")
            #expect(UnitSprites.placement(of: attack, in: base, scale: 0.3) != nil)

            let node = EnemyNode(id: 1, kind: kind, sign: "学", lane: 0, scale: 1)
            let sprite = try #require(node.childNode(withName: "//unitSprite") as? SKSpriteNode, "\(kind.id)")
            #expect(sprite.action(forKey: "idle") != nil)
            #expect(sprite.size.width <= 88.5 && sprite.size.height <= 80.5, "\(kind.id) 和僵尸占同样大的格子")
            // 答错时出手、被打败时没有倒地动画也能正常退场
            node.lunge()
            #expect(UnitSprites.frames(named: attack).contains { $0 === sprite.texture })
            node.defeat()
        }
    }

    /// 森林素材画的是朝右，经典模式里要翻成朝左：翻转后的第一帧应和原图左右对称
    @Test func mirroredFramesAreFlippedHorizontally() throws {
        let clip = try #require(UnitSprites.clip(named: "zombie-knight"))
        #expect(clip.mirrored == true)
        let file = try #require(clip.files?.first)
        let original = try #require(UnitSprites.webp(file, mirrored: false))
        let shown = try #require(UnitSprites.frames(named: "zombie-knight").first).cgImage()

        func alpha(_ image: CGImage) throws -> [UInt8] {
            var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
            try pixels.withUnsafeMutableBytes { bytes in
                let context = try #require(CGContext(data: bytes.baseAddress, width: image.width, height: image.height,
                                                   bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                                   space: CGColorSpaceCreateDeviceRGB(),
                                                   bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            }
            return stride(from: 3, to: pixels.count, by: 4).map { pixels[$0] }
        }
        let crop = clip.crop.map { Int($0) }
        #expect(shown.width == crop[2] && shown.height == crop[3])
        let before = try alpha(original), after = try alpha(shown)
        var mismatched = 0
        for y in 0..<crop[3] {
            for x in 0..<crop[2] {
                // 翻转后裁切框里的 (x, y) 对应原图的 (宽 - 1 - (左 + x), 上 + y)
                let sourceX = original.width - 1 - (crop[0] + x)
                let a = before[(crop[1] + y) * original.width + sourceX], b = after[y * crop[2] + x]
                if (a > 127) != (b > 127) { mismatched += 1 }
            }
        }
        #expect(mismatched < crop[2] * crop[3] / 200, "翻转后的轮廓应和原图左右对称")
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
