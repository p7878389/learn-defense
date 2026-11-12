import Foundation
import CoreGraphics
import ImageIO
import SwiftUI
import LearnCore

/// 森林首领、小怪、英雄的成品图：`scripts/import-forest-roster.py` 预先去底并压成透明 WebP。
/// 运行时只解码，不再抠图；用到哪张解哪张，解过的留在缓存里，不在逐帧绘制中解码。
enum ForestRosterArtwork {
    static let ogreWalk = (0..<6).map { "ogre-walk-\($0)" }
    static let actionKinds: [ForestEnemyKind] = [
        .knight, .goblin, .acolyte, .berserker, .frostKing, .infernal,
        .pharaoh, .reaper, .slime, .gargoyle, .shaman,
    ]
    static let actionNames = Set(actionKinds.flatMap { kind in
        (0..<9).map { "\(kind.rawValue)-action-\($0)" }
    })
    static let names = ForestEnemyKind.allCases.filter { $0 != .skeleton && $0 != .boar }.map(\.rawValue)
        + ForestHero.allCases.map(\.rawValue)
        + ["ogre-skill", "berserker-skill", "frostKing-skill", "infernal-skill", "reaper-skill",
           "pharaoh-skill", "slime-skill", "gargoyle-skill",
           "reaper-windup", "pharaoh-windup", "slime-windup", "gargoyle-windup"] + ogreWalk

    /// 包里实际存在的素材。只查文件不解码，用来判断某个姿态有没有专门的图。
    static let files: [String: URL] = {
        var result: [String: URL] = [:]
        for name in names {
            result[name] = Bundle.module.url(forResource: name, withExtension: "webp", subdirectory: "Sprites/ForestRoster")
        }
        return result
    }()
    private static let actionFiles: [String: URL] = {
        var result: [String: URL] = [:]
        for name in actionNames {
            result[name] = Bundle.module.url(forResource: name, withExtension: "webp",
                                             subdirectory: "Sprites/ForestActions")
        }
        return result
    }()

    private static let lock = NSLock()
    private static var cache: [String: CGImage] = [:]
    /// 一次战斗通常只出现一个首领；27 帧覆盖三个动作单位，避免 99 帧全部常驻。
    static let actionCacheLimit = 27
    private static var actionRecency = ForestFrameRecency(limit: actionCacheLimit)

    /// 解码后的位图；第一次用到时解码并缓存。可以在任意线程调用。
    static func bitmap(_ name: String) -> CGImage? {
        lock.lock()
        let cached = cache[name]
        // 正在显示的动作帧每次命中都记一次使用，超出上限时不会先被淘汰。
        if cached != nil, actionFiles[name] != nil { _ = actionRecency.touch(name) }
        lock.unlock()
        if let cached { return cached }
        guard let url = files[name] ?? actionFiles[name],
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              // 立刻解码成位图：否则会拖到第一次上屏时才解，卡在绘制那一帧。
              let image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
        else { return nil }
        lock.lock()
        cache[name] = image
        if actionFiles[name] != nil {
            for old in actionRecency.touch(name) { cache.removeValue(forKey: old) }
        }
        lock.unlock()
        return image
    }

    /// 进入战场时在后台把全部素材解好，首领第一次出手换姿态时不用现解。
    static func preload() {
        Task.detached(priority: .utility) {
            for name in names { _ = bitmap(name) }
        }
    }

    /// 当前单位进场后只预热它的九帧；未遇到的首领不占动作缓存。
    static func preload(_ kind: ForestEnemyKind) async {
        guard actionKinds.contains(kind) else { return }
        await Task.detached(priority: .utility) {
            for index in 0..<9 { _ = bitmap(actionFrame(kind, index)) }
        }.value
    }

    /// 开波前把这一波会出场的单位一次解好，怪物第一次上屏时不用在主线程现解。
    static func preload(_ kinds: [ForestEnemyKind]) async {
        for kind in kinds { await preload(kind) }
    }

    static func image(_ name: String) -> Image {
        guard let image = bitmap(name) else { return Image(systemName: "questionmark.square") }
        return Image(decorative: image, scale: 1)
    }

    /// 巨魔原图和行走帧均朝左，不能套用其他素材默认朝右的约定。
    static func nativeFacing(_ kind: ForestEnemyKind) -> Double { kind == .ogre ? -1 : 1 }

    static func hasActionSheet(_ kind: ForestEnemyKind) -> Bool { actionKinds.contains(kind) }

    static func actionFrame(_ kind: ForestEnemyKind, _ index: Int) -> String {
        "\(kind.rawValue)-action-\(min(8, max(0, index)))"
    }

    static func locomotionPose(_ enemy: ForestEnemy, progress: Double) -> String {
        if enemy.kind == .ogre {
            guard enemy.cast == nil, enemy.health > 0 else { return pose(enemy.kind, cast: enemy.cast) }
            // 定身时 distance 不变，因此保持当前脚步帧；进入施法才切回攻击姿态。
            let frame = min(ogreWalk.count - 1, max(0, Int(progress * Double(ogreWalk.count))))
            let name = ogreWalk[frame]
            return files[name] != nil ? name : enemy.kind.rawValue
        }
        guard hasActionSheet(enemy.kind) else { return pose(enemy.kind, cast: enemy.cast) }
        let index: Int
        if let cast = enemy.cast {
            index = cast.age < cast.windup ? 6 : (cast.releasing ? 7 : 8)
        } else {
            index = min(5, max(0, Int(progress * 6)))
        }
        let name = actionFrame(enemy.kind, index)
        return actionFiles[name] != nil ? name : enemy.kind.rawValue
    }

    static func pose(_ kind: ForestEnemyKind, cast: ForestCast?) -> String {
        let base = kind.rawValue
        guard let cast else { return base }
        let candidate = base + (cast.charging ? "-windup" : "-skill")
        // 冲击画面只在释放阶段出现，收招回到无爆炸的主体图。
        return (cast.charging || cast.releasing) && files[candidate] != nil ? candidate : base
    }
}

/// 记录每个名字最近一次被用到的先后，超出上限时交出最久没用的。
struct ForestFrameRecency {
    let limit: Int
    private var stamps: [String: Int] = [:]
    private var clock = 0

    init(limit: Int) { self.limit = limit }

    /// 记一次使用，返回因此该淘汰的名字。
    mutating func touch(_ name: String) -> [String] {
        clock += 1
        stamps[name] = clock
        var evicted: [String] = []
        while stamps.count > limit, let oldest = stamps.min(by: { $0.value < $1.value })?.key {
            stamps.removeValue(forKey: oldest)
            evicted.append(oldest)
        }
        return evicted
    }
}
