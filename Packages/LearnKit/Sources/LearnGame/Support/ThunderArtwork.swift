import ImageIO
import SpriteKit

/// 样片与游戏使用同一批透明素材；首次解码时限制像素尺寸，并共享 CPU 图片及 GPU 纹理。
@MainActor
enum ThunderArtwork {
    enum Asset: String, CaseIterable {
        case button = "button-shell"
        case clouds = "storm-clouds"
        case lightning
        case impact

        var maxPixelSize: Int {
            switch self {
            case .button, .lightning: 1024
            case .clouds: 1536
            case .impact: 768
            }
        }
    }

    private static let images: [Asset: CGImage] = {
        var result: [Asset: CGImage] = [:]
        for asset in Asset.allCases {
            guard let url = Bundle.module.url(forResource: asset.rawValue, withExtension: "png",
                                               subdirectory: "Sprites/UltimateThunder"),
                  let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
                  let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: asset.maxPixelSize,
                    kCGImageSourceShouldCacheImmediately: true,
                  ] as CFDictionary) else { continue }
            result[asset] = image
        }
        return result
    }()

    private static var textures: [Asset: SKTexture] = [:]

    static func image(_ asset: Asset) -> CGImage? { images[asset] }

    static func texture(_ asset: Asset) -> SKTexture? {
        if let cached = textures[asset] { return cached }
        guard let image = image(asset) else { return nil }
        let texture = SKTexture(cgImage: image)
        texture.filteringMode = .linear
        textures[asset] = texture
        return texture
    }
}
