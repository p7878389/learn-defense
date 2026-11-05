import LearnCore
import SpriteKit

/// 内置植物与僵尸的透明序列帧。动画共享纹理，节点独立；缺图时交回原有矢量绘制。
@MainActor
enum UnitSprites {
    private struct Clip: Decodable {
        let frameCount: Int
        let frameTime: Double
        let crop: [Double]
        let colorKey: [CGFloat]?
    }

    private static let clips: [String: Clip] = {
        guard let url = Bundle.module.url(forResource: "clips", withExtension: "json", subdirectory: "Sprites"),
              let data = try? Data(contentsOf: url),
              let clips = try? JSONDecoder().decode([String: Clip].self, from: data) else { return [:] }
        return clips
    }()
    private static var cachedFrames: [String: [SKTexture]] = [:]

    static func frames(named name: String) -> [SKTexture] {
        if let cached = cachedFrames[name] { return cached }
        guard let clip = clips[name], clip.frameCount > 0, clip.crop.count == 4 else { return [] }
        var frames: [SKTexture] = []
        for index in 0..<clip.frameCount {
            guard let url = Bundle.module.url(forResource: String(index), withExtension: "png", subdirectory: "Sprites/\(name)"),
                  let image = PlatformImage(contentsOfFile: url.path) else {
                cachedFrames[name] = []
                return []
            }
            // PNG 的 DPI 元数据会改变 NSImage 的点尺寸，裁切必须统一使用像素尺寸。
            #if canImport(UIKit)
            guard let bitmap = image.cgImage else { return [] }
            #else
            guard let bitmap = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return [] }
            #endif
            let source: CGImage
            if let key = clip.colorKey, key.count == 3 {
                // Core Graphics 的色键遮罩不接受带 alpha 的源图；先以 RGB 解码白底帧。
                guard let context = CGContext(data: nil, width: bitmap.width, height: bitmap.height,
                                              bitsPerComponent: 8, bytesPerRow: bitmap.width * 4,
                                              space: CGColorSpaceCreateDeviceRGB(),
                                              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return [] }
                context.draw(bitmap, in: CGRect(x: 0, y: 0, width: bitmap.width, height: bitmap.height))
                guard let rgb = context.makeImage(),
                      let masked = rgb.copy(maskingColorComponents: key.flatMap { [$0, $0] }) else { return [] }
                source = masked
            } else {
                source = bitmap
            }
            let full = SKTexture(cgImage: source)
            let size = full.size()
            let c = clip.crop
            guard size.width > 0, size.height > 0,
                  c[0] >= 0, c[1] >= 0, c[2] > 0, c[3] > 0,
                  c[0] + c[2] <= size.width, c[1] + c[3] <= size.height else { return [] }
            // 清单采用左上角像素坐标；SpriteKit 纹理坐标从左下角开始。
            let rect = CGRect(x: c[0] / size.width, y: 1 - (c[1] + c[3]) / size.height,
                              width: c[2] / size.width, height: c[3] / size.height)
            let texture = SKTexture(rect: rect, in: full)
            texture.filteringMode = .linear
            frames.append(texture)
        }
        cachedFrames[name] = frames
        return frames
    }

    static func node(named name: String, fitting bounds: CGSize) -> SKSpriteNode? {
        let frames = frames(named: name)
        guard let first = frames.first else { return nil }
        let size = first.size()
        let scale = min(bounds.width / size.width, bounds.height / size.height)
        let node = SKSpriteNode(texture: first, size: CGSize(width: size.width * scale, height: size.height * scale))
        node.name = "unitSprite"
        if frames.count > 1, let clip = clips[name] {
            node.run(.repeatForever(.animate(with: frames, timePerFrame: clip.frameTime, resize: false, restore: false)), withKey: "idle")
        }
        return node
    }

    static func defender(_ kind: DefenderKind, radius: CGFloat) -> SKSpriteNode? {
        node(named: "plant-\(kind.id)", fitting: CGSize(width: radius * 2.3, height: radius * 2.3))
    }

    static func enemy(_ kind: EnemyKind) -> SKSpriteNode? {
        node(named: "zombie-\(kind.id)", fitting: CGSize(width: 88, height: 80))
    }

    static func projectile(_ look: ProjectileLook) -> SKSpriteNode? {
        let name: String
        switch look.shape {
        case .orb: name = "pea"
        case .snowflake: name = "ice-pea"
        case .star: name = "star"
        case .petal: return nil
        }
        let diameter = CGFloat(look.size) * 2
        return node(named: name, fitting: CGSize(width: diameter, height: diameter))
    }
}
