import Foundation

/// 颜色，0xRRGGBB
public struct RGB: Hashable, Sendable {
    public var r: Double
    public var g: Double
    public var b: Double

    public init(_ hex: UInt32) {
        r = Double((hex >> 16) & 0xFF) / 255
        g = Double((hex >> 8) & 0xFF) / 255
        b = Double(hex & 0xFF) / 255
    }
}

/// 战场背景主题 = 天空 + 远景 + 路面 + 装饰 + 飘过的东西 + 守护的基地。
/// 图案都用 emoji 表示，画面层按 emoji 找 3D 图片，没有图片就画系统 emoji
public struct SceneTheme: Identifiable, Hashable, Sendable {
    public enum Ground: Hashable, Sendable {
        /// 草地，带小草丛
        case grass
        /// 石板路，带砖缝
        case stone
    }

    public var id: String
    public var name: String
    public var skyTop: RGB
    public var skyBottom: RGB
    /// 天上的太阳或月亮
    public var celestial: String?
    /// 地平线上的远景，从左到右排开
    public var horizon: [String]
    /// 每条路交替使用的颜色
    public var lanes: [RGB]
    public var ground: Ground
    /// 路边的小装饰
    public var scenery: [String]
    /// 慢慢飘过天空的东西（云、风筝）
    public var drifters: [String]
    /// 在路上飞来飞去的小东西（蝴蝶、蜜蜂），nil 表示没有
    public var flutter: [String]
    /// 左边要守护的东西
    public var base: String
    public var baseColor: RGB

    public init(id: String, name: String, skyTop: RGB, skyBottom: RGB, celestial: String? = nil,
                horizon: [String], lanes: [RGB], ground: Ground, scenery: [String],
                drifters: [String], flutter: [String] = [], base: String, baseColor: RGB) {
        self.id = id
        self.name = name
        self.skyTop = skyTop
        self.skyBottom = skyBottom
        self.celestial = celestial
        self.horizon = horizon
        self.lanes = lanes.isEmpty ? [RGB(0xE9DDBF)] : lanes
        self.ground = ground
        self.scenery = scenery
        self.drifters = drifters
        self.flutter = flutter
        self.base = base
        self.baseColor = baseColor
    }
}

// MARK: - 内置主题

public extension SceneTheme {
    /// 草地：动物
    static let meadow = SceneTheme(
        id: "meadow", name: "草地",
        skyTop: RGB(0x7CC6F2), skyBottom: RGB(0xD7F0FB), celestial: "☀️",
        horizon: ["⛰️", "🌳", "🏡", "🌲", "⛰️", "🌳", "🌲"],
        lanes: [RGB(0x9BD67A), RGB(0xADDF8C)], ground: .grass,
        scenery: ["🌼", "🌷", "🍄", "🌿", "🐞"],
        drifters: ["☁️", "☁️", "🪁"], flutter: ["🦋", "🐝"],
        base: "🏡", baseColor: RGB(0xB98A5E))

    /// 果园：水果
    static let orchard = SceneTheme(
        id: "orchard", name: "果园",
        skyTop: RGB(0x8FD3F4), skyBottom: RGB(0xFFF1CF), celestial: "☀️",
        horizon: ["🌳", "🌳", "🌲", "🌳", "🏡", "🌳", "🌳"],
        lanes: [RGB(0xC9DC86), RGB(0xD6E59A)], ground: .grass,
        scenery: ["🌻", "🌾", "🌼", "🍄"],
        drifters: ["☁️", "☁️"], flutter: ["🐝", "🦋"],
        base: "🏡", baseColor: RGB(0xA9774F))

    /// 星空：天空和大地
    static let starry = SceneTheme(
        id: "starry", name: "星空",
        skyTop: RGB(0x283A73), skyBottom: RGB(0x6C7FC4), celestial: "🌙",
        horizon: ["⛰️", "🌲", "⛰️", "🌲", "🏰", "🌲", "⛰️"],
        lanes: [RGB(0x7BA68C), RGB(0x89B398)], ground: .grass,
        scenery: ["🌸", "🌿", "🌼", "🍄"],
        drifters: ["⭐️", "☁️", "⭐️"],
        base: "🏰", baseColor: RGB(0x6D6A8C))

    /// 书院：小学
    static let academy = SceneTheme(
        id: "academy", name: "书院",
        skyTop: RGB(0xF6C987), skyBottom: RGB(0xFDEFD6), celestial: "☀️",
        horizon: ["⛰️", "🌲", "🏰", "⛰️", "🌸", "🌲", "⛰️"],
        lanes: [RGB(0xE4D3B0), RGB(0xEEDFC0)], ground: .stone,
        scenery: ["🌸", "🌿", "🍃", "🌷"],
        drifters: ["☁️", "🪁", "☁️"], flutter: ["🦋"],
        base: "📚", baseColor: RGB(0x9E6B47))
}

public extension SceneTheme {
    static let all: [SceneTheme] = [.meadow, .orchard, .starry, .academy]

    static func theme(id: String) -> SceneTheme? {
        all.first { $0.id == id }
    }

    /// 按这一局选中的单元挑主题：单元里写了 theme 的，选用得最多的那个；都没写就按年级
    static func choose(packs: [ContentPack], selection: ItemPool.Selection, grade: Grade) -> SceneTheme {
        var counts: [String: Int] = [:]
        var order: [String] = []
        for pack in packs {
            for unit in pack.units {
                if case .units(let keys) = selection, !keys.contains("\(pack.id)/\(unit.id)") { continue }
                guard let id = unit.theme, theme(id: id) != nil else { continue }
                if counts[id] == nil { order.append(id) }
                counts[id, default: 0] += 1
            }
        }
        // 次数相同时取先出现的
        var best: String?
        for id in order where best == nil || counts[id]! > counts[best!]! {
            best = id
        }
        return best.flatMap(theme(id:)) ?? (grade.isPreschool ? .meadow : .academy)
    }
}
