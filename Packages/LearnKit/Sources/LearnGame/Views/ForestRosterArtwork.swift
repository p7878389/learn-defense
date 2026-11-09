import Foundation
import CoreGraphics
import ImageIO
import SwiftUI
import LearnCore

/// 保留 Stitch 原始 JPG。加载时处理边缘白底，缓存一次，不在逐帧绘制中解码。
enum ForestRosterArtwork {
    static let names = ForestEnemyKind.allCases.filter { $0 != .skeleton && $0 != .boar }.map(\.rawValue)
        + ForestHero.allCases.map(\.rawValue)
        + ["ogre-skill", "berserker-skill", "frostKing-skill", "infernal-skill", "reaper-skill",
           "pharaoh-skill", "slime-skill", "gargoyle-skill",
           "reaper-windup", "pharaoh-windup", "slime-windup", "gargoyle-windup"]

    static let bitmaps: [String: CGImage] = {
        var result: [String: CGImage] = [:]
        for name in names {
            guard let url = Bundle.module.url(forResource: name, withExtension: "jpg", subdirectory: "Sprites/ForestRoster"),
                  let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let input = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceThumbnailMaxPixelSize: 512
                  ] as CFDictionary),
                  let image = removeBackdrop(input) else { continue }
            result[name] = image
        }
        return result
    }()

    static func image(_ name: String) -> Image {
        guard let image = bitmaps[name] else { return Image(systemName: "questionmark.square") }
        return Image(decorative: image, scale: 1)
    }

    static func pose(_ kind: ForestEnemyKind, cast: ForestCast?) -> String {
        let base = kind.rawValue
        guard let cast else { return base }
        let candidate = base + (cast.charging ? "-windup" : "-skill")
        // 冲击画面只在释放阶段出现，收招回到无爆炸的主体图。
        return (cast.charging || cast.releasing) && bitmaps[candidate] != nil ? candidate : base
    }

    /// 与边缘连通的近白像素作为背景，保留铠甲、骨头等内部白色高光。
    private static func removeBackdrop(_ source: CGImage) -> CGImage? {
        let width = source.width, height = source.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        return pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height,
                                          bitsPerComponent: 8, bytesPerRow: width * 4,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
            context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
            let bytes = buffer.bindMemory(to: UInt8.self)
            var visited = [Bool](repeating: false, count: width * height)
            var queue: [Int] = []
            func enqueue(_ x: Int, _ y: Int) {
                guard x >= 0, y >= 0, x < width, y < height else { return }
                let p = y * width + x, b = p * 4
                guard !visited[p], min(bytes[b], bytes[b + 1], bytes[b + 2]) > 225 else { return }
                visited[p] = true
                queue.append(p)
            }
            for x in 0..<width { enqueue(x, 0); enqueue(x, height - 1) }
            for y in 0..<height { enqueue(0, y); enqueue(width - 1, y) }
            var cursor = 0
            while cursor < queue.count {
                let p = queue[cursor], x = p % width, y = p / width
                cursor += 1
                enqueue(x - 1, y); enqueue(x + 1, y); enqueue(x, y - 1); enqueue(x, y + 1)
                let b = p * 4
                bytes[b] = 0; bytes[b + 1] = 0; bytes[b + 2] = 0; bytes[b + 3] = 0
            }
            return context.makeImage()
        }
    }
}
