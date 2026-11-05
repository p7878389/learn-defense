import Foundation

/// 年级。原始值与题库 JSON 的 `grade` 字段一致。
public enum Grade: String, Codable, CaseIterable, Identifiable, Sendable {
    case k2, k3, g1, g2, g3, g4, g5, g6

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .k2: "中班"
        case .k3: "大班"
        case .g1: "一年级"
        case .g2: "二年级"
        case .g3: "三年级"
        case .g4: "四年级"
        case .g5: "五年级"
        case .g6: "六年级"
        }
    }

    /// 幼儿园阶段：不识字，全程图片 + 语音，不设失败。
    public var isPreschool: Bool { self == .k2 || self == .k3 }
}

public enum Subject: String, Codable, CaseIterable, Identifiable, Sendable {
    case chinese, english

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .chinese: "语文"
        case .english: "英语"
        }
    }
}

public enum Term: String, Codable, Sendable {
    case up, down

    public var displayName: String {
        switch self {
        case .up: "上册"
        case .down: "下册"
        }
    }
}
