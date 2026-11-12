import ImageIO
import SpriteKit

/// 雷霆大招的成品图：`scripts/import-thunder-artwork.py` 预先缩到运行时尺寸并压成透明 WebP。
/// 运行时只解码，用到哪张解哪张；CPU 位图与 GPU 纹理都只建一次，多目标与连续大招共用。
enum ThunderArtwork {
    enum Asset: String, CaseIterable, Sendable {
        case button = "button-shell"
        case clouds = "storm-clouds"
        case lightning
        case impact
    }

    private static let lock = NSLock()
    private static var images: [Asset: CGImage] = [:]
    @MainActor private static var textures: [Asset: SKTexture] = [:]

    /// 包里的素材文件；只查路径不解码。
    static func url(_ asset: Asset) -> URL? {
        Bundle.module.url(forResource: asset.rawValue, withExtension: "webp", subdirectory: "Sprites/UltimateThunder")
    }

    /// 解码后的位图；第一次用到时解码并缓存。可以在任意线程调用。
    static func image(_ asset: Asset) -> CGImage? {
        lock.lock()
        let cached = images[asset]
        lock.unlock()
        if let cached { return cached }
        guard let url = url(asset),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              // 立刻解码成位图：否则会拖到第一次上屏时才解，卡在雷霆落下的那一帧。
              let image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
        else { return nil }
        lock.lock()
        images[asset] = image
        lock.unlock()
        return image
    }

    /// 进入战场时在后台把四张图解好，第一次放大招不用在主线程现解。
    static func preload() {
        Task.detached(priority: .utility) {
            for asset in Asset.allCases { _ = image(asset) }
        }
    }

    @MainActor static func texture(_ asset: Asset) -> SKTexture? {
        if let cached = textures[asset] { return cached }
        guard let image = image(asset) else { return nil }
        let texture = SKTexture(cgImage: image)
        texture.filteringMode = .linear
        textures[asset] = texture
        return texture
    }
}
