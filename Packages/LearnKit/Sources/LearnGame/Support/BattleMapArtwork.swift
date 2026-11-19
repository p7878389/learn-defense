import ImageIO
import LearnCore
import SpriteKit

/// 两张地图的共享图片与纹理，预览和战场读取同一份解码结果。
@MainActor
enum BattleMapArtwork {
    private static let images: [BattleMap: CGImage] = artwork.mapValues(\.field)

    /// field 是对齐战场 1200×600 的图；wide 是带两侧原画的图，比 field 每侧多出 inset（场景坐标）。
    /// 右边延伸：stretchFrom 为 nil 时沿原画右缘镜像（森林的草带是横的，镜像看不出接缝）；
    /// 否则把原画从场景 x = stretchFrom 到右缘的一整段按画面实际露出的宽度均匀拉开（庭院的马路是斜的，镜像会折出一个 V）
    private struct Artwork {
        let field: CGImage
        let wide: CGImage
        let inset: CGFloat
        var stretchFrom: CGFloat?
    }

    private static let artwork: [BattleMap: Artwork] = {
        var result: [BattleMap: Artwork] = [:]
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
                guard let field = full.cropping(to: CGRect(x: Double(full.width) * 100 / 1400, y: 0,
                                                           width: Double(full.width) * 1200 / 1400, height: Double(full.height)))
                else { continue }
                // 从草坪右缘起，人行道、马路和对面的院子一起拉，比例变化均匀
                result[map] = Artwork(field: field, wide: full, inset: 100, stretchFrom: 900)
            } else if let field = alignedWoodland(full) {
                result[map] = Artwork(field: field, wide: field, inset: 0)
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

    /// 战场右边外侧的延伸图。minX 是它在场景里的左缘，naturalWidth 是不拉伸时的宽度；
    /// stretches 为 true 时由场景按露出的宽度横向拉伸（SKSpriteNode 改 size 即可，不重画）
    struct RightExtension {
        let texture: SKTexture
        let minX: CGFloat
        let naturalWidth: CGFloat
        let stretches: Bool
    }

    private static var rightExtensions: [BattleMap: RightExtension] = [:]

    /// 镜像的从 1200 开始、宽 width；拉伸的从 stretchFrom 开始、盖住原图右边一段，接缝处画面连续
    static func rightExtension(_ map: BattleMap, width: CGFloat) -> RightExtension? {
        if let cached = rightExtensions[map] { return cached }
        guard width > 0, let art = artwork[map] else { return nil }
        let design = GameScene.designSize
        let result: RightExtension
        if let from = art.stretchFrom {
            // wide 图在场景里铺在 -inset…1200+inset，裁出 from…右缘
            let pixelsPerUnit = CGFloat(art.wide.width) / (design.width + art.inset * 2)
            let naturalWidth = design.width + art.inset - from
            guard let strip = art.wide.cropping(to: CGRect(x: (from + art.inset) * pixelsPerUnit, y: 0,
                                                           width: naturalWidth * pixelsPerUnit,
                                                           height: CGFloat(art.wide.height))) else { return nil }
            result = RightExtension(texture: SKTexture(cgImage: strip), minX: from, naturalWidth: naturalWidth, stretches: true)
        } else {
            guard let image = mirroredRight(art, width: width) else { return nil }
            result = RightExtension(texture: SKTexture(cgImage: image), minX: design.width, naturalWidth: width, stretches: false)
        }
        result.texture.filteringMode = .linear
        rightExtensions[map] = result
        return result
    }

    /// 按场景坐标作画（1 单位 = 1 像素，高 600），小图原点在场景 x = 1200：
    /// wide 图铺在 -inset…1200+inset，再沿它的右缘镜像一份，补上更外侧的部分
    private static func mirroredRight(_ art: Artwork, width: CGFloat) -> CGImage? {
        let design = GameScene.designSize
        guard let context = CGContext(data: nil, width: Int(width.rounded(.up)), height: Int(design.height),
                                      bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.interpolationQuality = .high
        let wide = CGRect(x: -art.inset - design.width, y: 0, width: design.width + art.inset * 2, height: design.height)
        context.draw(art.wide, in: wide)
        context.translateBy(x: wide.maxX * 2, y: 0)
        context.scaleBy(x: -1, y: 1)
        context.draw(art.wide, in: wide)
        return context.makeImage()
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
