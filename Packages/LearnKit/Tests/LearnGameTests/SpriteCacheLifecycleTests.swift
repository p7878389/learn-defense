import LearnCore
import SpriteKit
import Testing
@testable import LearnGame

@MainActor
@Suite("角色缓存清理", .serialized)
struct SpriteCacheLifecycleTests {
    @Test func croppedTexturesAreChargedForTheirFullBackingCanvas() throws {
        let context = try #require(CGContext(data: nil, width: 100, height: 80, bitsPerComponent: 8,
            bytesPerRow: 400, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        let full = SKTexture(cgImage: try #require(context.makeImage()))
        let cropped = SKTexture(rect: CGRect(x: 0.2, y: 0.1, width: 0.5, height: 0.5), in: full)
        #expect(SpriteResourceCache.estimatedCost(of: [cropped]) == 32_000)
    }

    @Test func clearingCachesPreservesLiveAnimationAndCanReloadTextures() throws {
        let rig = try #require(UnitSprites.defender(.inkling, radius: 34))
        let texture = try #require(rig.sprite.texture)
        _ = try #require(UnitSprites.portrait(of: EnemyKind.blob, skin: nil))
        _ = try #require(FXLibrary.effect(named: "PeaImpact"))
        _ = try #require(Pictures.texture("🌸"))
        _ = try #require(ThemeSkin.portrait(for: .emerald))
        #expect(FXLibrary.cachedArchiveCount > 0 && FXLibrary.cachedTextureCount > 0)
        #expect(Pictures.cachedImageCount > 0 && Pictures.cachedTextureCount > 0)
        #expect(ThemeSkin.cachedPortraitCount > 0)
        UnitSprites.releaseCachedResources()
        #expect(UnitSprites.cachedAnimationFrameCount == 0)
        #expect(UnitSprites.cachedResourceBytes == 0)
        #expect(FXLibrary.cachedArchiveCount == 0 && FXLibrary.cachedTextureCount == 0)
        #expect(Pictures.cachedImageCount == 0 && Pictures.cachedTextureCount == 0)
        #expect(ThemeSkin.cachedPortraitCount == 0)
        #expect(rig.sprite.texture === texture)
        #expect(rig.sprite.action(forKey: SpriteRig.loopKey) != nil)
        let reloaded = try #require(UnitSprites.frames(named: "plant-inkling").first)
        #expect(reloaded.size() == CGSize(width: 70, height: 71))
        #expect(reloaded !== texture)
        #expect(UnitSprites.cachedResourceBytes > 0)
        #expect(FXLibrary.effect(named: "PeaImpact") != nil)
        #expect(Pictures.texture("🌸") != nil)
        #expect(ThemeSkin.portrait(for: .emerald) != nil)
    }
}
