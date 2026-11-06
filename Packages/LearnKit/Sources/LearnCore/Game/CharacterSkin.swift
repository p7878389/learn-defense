import Foundation

/// 原创角色装扮；只改变纹理与粒子，不参与战斗数值。
/// party / pixel 在原图上加装扮，射手和普通僵尸都有；
/// bamboo「竹筒小侠」、voxel「方块工匠」、egg「弹弹蛋」整株重画，只有射手，僵尸配它们时保持原版。
/// firefly「萤火精灵」不换贴图，只加身后的金色光晕和身边忽明忽暗的萤火光团，连对越多越亮。
public enum CharacterSkin: String, Codable, CaseIterable, Sendable {
    case party, pixel, bamboo, voxel, egg, firefly

    /// 只加特效、沿用原版贴图的皮肤：没有自己的序列帧，射手也要保留它
    public var isEffectOnly: Bool { self == .firefly }
}
