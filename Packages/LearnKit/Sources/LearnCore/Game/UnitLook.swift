import Foundation

/// 角色配色。这里只有名字，具体颜色在 LearnGame 里，方便组合，以后也能写进配置文件
public enum UnitColor: String, CaseIterable, Sendable {
    case ink, indigo, crimson, plum, moss, sky, gold, coral, jade
}

/// 怪物外观 = 身体 + 颜色 + 配件 + 眼睛 + 退场特效，各部分可以任意搭配
public struct EnemyLook: Hashable, Sendable {
    public enum Body: String, CaseIterable, Sendable {
        /// 扁扁的墨团
        case blob
        /// 圆球
        case ball
        /// 瘦高个
        case tall
        /// 软软的云朵
        case cloud
        /// 一圈尖刺
        case spiky
    }

    public enum Accessory: String, CaseIterable, Sendable {
        case none, sprout, horns, helmet, crown
    }

    public enum Eyes: String, CaseIterable, Sendable {
        case pair, single, sleepy
    }

    public var body: Body
    public var color: UnitColor
    public var accessory: Accessory
    public var eyes: Eyes
    /// 相对普通怪物的大小
    public var scale: Double
    public var defeat: DefeatEffect

    public init(body: Body, color: UnitColor, accessory: Accessory = .none, eyes: Eyes = .pair,
                scale: Double = 1, defeat: DefeatEffect = .inkBurst) {
        self.body = body
        self.color = color
        self.accessory = accessory
        self.eyes = eyes
        self.scale = scale
        self.defeat = defeat
    }
}

/// 怪物被打败时的特效
public enum DefeatEffect: String, CaseIterable, Sendable {
    /// 墨点四散
    case inkBurst
    /// 一圈圈涟漪散开
    case ripple
    /// 变成星星飞走
    case sparkle
}

/// 字灵外观 = 身体 + 颜色 + 配件
public struct DefenderLook: Hashable, Sendable {
    public enum Body: String, CaseIterable, Sendable {
        /// 圆圆的
        case round
        /// 水滴
        case drop
        /// 方印章
        case seal
    }

    public enum Accessory: String, CaseIterable, Sendable {
        case none, brush, scholarHat, bow, leaf
    }

    public var body: Body
    public var color: UnitColor
    public var accessory: Accessory

    public init(body: Body, color: UnitColor, accessory: Accessory = .none) {
        self.body = body
        self.color = color
        self.accessory = accessory
    }
}

/// 子弹外观
public struct ProjectileLook: Hashable, Sendable {
    public enum Shape: String, CaseIterable, Sendable {
        case orb, star, snowflake, petal
    }

    public var shape: Shape
    public var color: UnitColor
    /// 半径
    public var size: Double

    public init(shape: Shape, color: UnitColor, size: Double = 11) {
        self.shape = shape
        self.color = color
        self.size = size
    }
}
