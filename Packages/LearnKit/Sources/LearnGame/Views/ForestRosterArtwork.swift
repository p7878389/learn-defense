import Foundation
import CoreGraphics
import ImageIO
import SwiftUI
import LearnCore

/// 森林首领、小怪、英雄的成品图：`scripts/import-forest-roster.py` 预先去底并压成透明 WebP。
/// 运行时只解码，不再抠图；用到哪张解哪张，解过的留在缓存里，不在逐帧绘制中解码。
enum ForestRosterArtwork {
    static let names = ForestEnemyKind.allCases.filter { $0 != .skeleton && $0 != .boar }.map(\.rawValue)
        + ForestHero.allCases.map(\.rawValue)
        + ["ogre-skill", "berserker-skill", "frostKing-skill", "infernal-skill", "reaper-skill",
           "pharaoh-skill", "slime-skill", "gargoyle-skill",
           "reaper-windup", "pharaoh-windup", "slime-windup", "gargoyle-windup"]

    /// 包里实际存在的素材。只查文件不解码，用来判断某个姿态有没有专门的图。
    static let files: [String: URL] = {
        var result: [String: URL] = [:]
        for name in names {
            result[name] = Bundle.module.url(forResource: name, withExtension: "webp", subdirectory: "Sprites/ForestRoster")
        }
        return result
    }()

    private static let lock = NSLock()
    private static var cache: [String: CGImage] = [:]

    /// 解码后的位图；第一次用到时解码并缓存。可以在任意线程调用。
    static func bitmap(_ name: String) -> CGImage? {
        lock.lock()
        let cached = cache[name]
        lock.unlock()
        if let cached { return cached }
        guard let url = files[name],
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              // 立刻解码成位图：否则会拖到第一次上屏时才解，卡在绘制那一帧。
              let image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
        else { return nil }
        lock.lock()
        cache[name] = image
        lock.unlock()
        return image
    }

    /// 进入战场时在后台把全部素材解好，首领第一次出手换姿态时不用现解。
    static func preload() {
        Task.detached(priority: .utility) {
            for name in names { _ = bitmap(name) }
        }
    }

    static func image(_ name: String) -> Image {
        guard let image = bitmap(name) else { return Image(systemName: "questionmark.square") }
        return Image(decorative: image, scale: 1)
    }

    static func pose(_ kind: ForestEnemyKind, cast: ForestCast?) -> String {
        let base = kind.rawValue
        guard let cast else { return base }
        let candidate = base + (cast.charging ? "-windup" : "-skill")
        // 冲击画面只在释放阶段出现，收招回到无爆炸的主体图。
        return (cast.charging || cast.releasing) && files[candidate] != nil ? candidate : base
    }
}
