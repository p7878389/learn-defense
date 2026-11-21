import Foundation

/// 角色装扮使用 SKS 场景与动作资源，只改变外观，不参与战斗数值。
public enum CharacterSkin: String, Codable, CaseIterable, Sendable {
    case spellbook, mecha, teapot
    case emerald, astral, frost, festival
}
