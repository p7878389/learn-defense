import SpriteKit
import SwiftUI
#if canImport(UIKit)
import UIKit
typealias PlatformImage = UIImage
#else
import AppKit
typealias PlatformImage = NSImage
#endif

/// 按 emoji 找 3D 图片（microsoft/fluentui-emoji，MIT 许可，见 Resources/Pictures）。
/// 找不到图片时，界面和场景都退回显示系统 emoji，所以新题库里没下载图片的词也能正常显示
@MainActor
enum Pictures {
    private static var images: [String: PlatformImage] = [:]
    private static var textures: [String: SKTexture] = [:]
    private static var missing: Set<String> = []

    /// 去掉变体选择符后的码点，和 scripts/fetch-pictures.py 的命名一致，如 🍎 → 1f34e
    static func key(_ emoji: String) -> String {
        emoji.unicodeScalars
            .filter { $0.value != 0xFE0F }
            .map { String($0.value, radix: 16) }
            .joined(separator: "-")
    }

    static func image(_ emoji: String) -> PlatformImage? {
        let key = key(emoji)
        if let cached = images[key] { return cached }
        guard !key.isEmpty, !missing.contains(key) else { return nil }
        guard let url = Bundle.module.url(forResource: key, withExtension: "png", subdirectory: "Pictures"),
              let image = PlatformImage(contentsOfFile: url.path) else {
            missing.insert(key)
            return nil
        }
        images[key] = image
        return image
    }

    static func texture(_ emoji: String) -> SKTexture? {
        let key = key(emoji)
        if let cached = textures[key] { return cached }
        guard let image = image(emoji) else { return nil }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        textures[key] = texture
        return texture
    }

    /// 场景里用的图片节点，边长为 size，中心对齐
    static func node(_ emoji: String, size: CGFloat) -> SKNode {
        if let texture = texture(emoji) {
            return SKSpriteNode(texture: texture, size: CGSize(width: size, height: size))
        }
        let label = SKLabelNode(text: emoji)
        label.fontSize = size * 0.85
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        return label
    }
}

/// SwiftUI 里显示 emoji 对应的 3D 图片，没有图片就显示 emoji 本身
struct PictureView: View {
    let emoji: String
    var size: CGFloat = 60

    var body: some View {
        if let image = Pictures.image(emoji) {
            picture(image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        } else {
            Text(emoji)
                .font(.system(size: size * 0.85))
                .frame(width: size, height: size)
        }
    }

    private func picture(_ image: PlatformImage) -> Image {
        #if canImport(UIKit)
        Image(uiImage: image)
        #else
        Image(nsImage: image)
        #endif
    }
}
