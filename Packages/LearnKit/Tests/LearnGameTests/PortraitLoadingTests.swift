import CoreGraphics
import LearnCore
import SpriteKit
import Testing
@testable import LearnGame

@MainActor
@Suite("头像按需加载", .serialized)
struct PortraitLoadingTests {
    @Test func portraitsDoNotPreloadFullAnimationClips() throws {
        let before = UnitSprites.cachedAnimationFrameCount
        let portrait = try #require(UnitSprites.portrait(of: EnemyKind.blob, skin: nil))
        #expect(portrait.width == 87 && portrait.height == 124)
        #expect(UnitSprites.cachedAnimationFrameCount == before, "头像不能预热整段动画")
        let first = try #require(UnitSprites.frames(named: "zombie-blob").first).cgImage()
        #expect(pixels(portrait) == pixels(first), "单帧加载必须保持原有裁切和透明像素")
    }

    private func pixels(_ image: CGImage) -> [UInt8] {
        var data = [UInt8](repeating: 0, count: image.width * image.height * 4)
        data.withUnsafeMutableBytes { bytes in
            let context = CGContext(data: bytes.baseAddress, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return data
    }
}
