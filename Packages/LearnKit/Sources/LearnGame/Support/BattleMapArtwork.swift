import ImageIO
import LearnCore
import SpriteKit

/// 两张地图的共享图片与纹理，预览和战场读取同一份解码结果。
@MainActor
enum BattleMapArtwork {
    private static let images: [BattleMap: CGImage] = {
        var result: [BattleMap: CGImage] = [:]
        for map in BattleMap.allCases {
            let url = map == .courtyard
                ? Bundle.module.url(forResource: "courtyard", withExtension: "jpg", subdirectory: "Sprites")
                : Bundle.module.url(forResource: "woodland-grass", withExtension: "png", subdirectory: "Sprites/Maps")
            guard let url,
                  let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let full = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceThumbnailMaxPixelSize: 2400,
                    kCGImageSourceShouldCacheImmediately: true,
                  ] as CFDictionary) else { continue }
            if map == .courtyard {
                result[map] = full.cropping(to: CGRect(x: Double(full.width) * 100 / 1400, y: 0,
                                                       width: Double(full.width) * 1200 / 1400, height: Double(full.height)))
            } else {
                result[map] = alignedWoodland(full)
            }
        }
        return result
    }()

    private static var textures: [BattleMap: SKTexture] = [:]
    static func image(_ map: BattleMap) -> CGImage? { images[map] }
    static func texture(_ map: BattleMap) -> SKTexture? {
        if let cached = textures[map] { return cached }
        guard let image = image(map) else { return nil }
        let texture = SKTexture(cgImage: image)
        texture.filteringMode = .linear
        textures[map] = texture
        return texture
    }

    /// 将原画的草带分界校准到 Lawn 的 20…520 区间，预览和战场都使用校准后的图。
    private static func alignedWoodland(_ image: CGImage) -> CGImage? {
        guard let context = CGContext(data: nil, width: 1200, height: 600, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let sourceEdges: [CGFloat] = [0, 120, 278, 414, 551, 692, 850, 887]
        let targetEdges: [CGFloat] = [0, 80, 180, 280, 380, 480, 580, 600]
        for index in 0..<(sourceEdges.count - 1) {
            let top = sourceEdges[index] / 887 * CGFloat(image.height)
            let bottom = sourceEdges[index + 1] / 887 * CGFloat(image.height)
            guard let strip = image.cropping(to: CGRect(x: 0, y: top, width: CGFloat(image.width), height: bottom - top)) else { return nil }
            context.draw(strip, in: CGRect(x: 0, y: 600 - targetEdges[index + 1], width: 1200,
                                           height: targetEdges[index + 1] - targetEdges[index]))
        }
        return context.makeImage()
    }
}
