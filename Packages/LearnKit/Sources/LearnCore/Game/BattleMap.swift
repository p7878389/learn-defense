import Foundation

/// 经典模式的地图外观；所有地图共用相同的五行九列种植几何，不改变战斗规则。
public enum BattleMap: String, CaseIterable, Identifiable, Sendable {
    case courtyard
    case woodland

    public var id: String { rawValue }
    public static let preferenceKey = "classicBattleMap"

    public var name: String {
        switch self {
        case .courtyard: "庭院"
        case .woodland: "林间草坪"
        }
    }
}
