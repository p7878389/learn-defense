import Foundation

/// 某个知识点的答题统计
public struct ItemStats: Codable, Sendable {
    public var seen = 0
    public var correct = 0
    public var wrong = 0
    /// 连续答对次数，答错清零
    public var streak = 0
    public var lastSeen: Date?
    public var lastWrong: Date?
    /// 错题本显示用
    public var summary: String?

    public init() {}

    /// 答错过且还没连续答对 2 次
    public var needsReview: Bool { wrong > 0 && streak < 2 }
}

/// 一个孩子的学习记录，存成一个 JSON 文件。
public final class ProgressStore {
    public private(set) var stats: [String: ItemStats]
    private let url: URL?

    /// url 为 nil 时只在内存里记录（测试用）
    public init(url: URL?) {
        self.url = url
        if let url, let data = try? Data(contentsOf: url),
           let saved = try? JSONDecoder().decode([String: ItemStats].self, from: data) {
            stats = saved
        } else {
            stats = [:]
        }
    }

    /// 只记录每道题的第一次作答
    public func record(_ item: LearningItem, correct: Bool, at date: Date = Date()) {
        var s = stats[item.key] ?? ItemStats()
        s.seen += 1
        s.lastSeen = date
        s.summary = item.summary
        if correct {
            s.correct += 1
            s.streak += 1
        } else {
            s.wrong += 1
            s.streak = 0
            s.lastWrong = date
        }
        stats[item.key] = s
    }

    public var reviewKeys: Set<String> {
        Set(stats.filter { $0.value.needsReview }.keys)
    }

    public func save() {
        guard let url else { return }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(stats).write(to: url, options: .atomic)
        } catch {
            print("保存学习记录失败：\(error)")
        }
    }
}

/// 挑下一个要出的知识点：没见过的、常错的更容易被选中，掌握了的少出，最近出过的不重复。
public struct ItemScheduler: Sendable {
    private var recent: [String] = []

    public init() {}

    public static func weight(_ stats: ItemStats?) -> Double {
        guard let s = stats else { return 1.5 }
        var w = 1.0 + Double(s.wrong) * 1.5 / Double(1 + s.streak)
        if s.streak >= 3 { w *= 0.35 }
        return w
    }

    public mutating func next<R: RandomNumberGenerator>(
        from items: [LearningItem],
        stats: [String: ItemStats],
        using rng: inout R
    ) -> LearningItem? {
        guard !items.isEmpty else { return nil }
        let avoid = Set(recent.suffix(min(4, items.count - 1)))
        let candidates = items.filter { !avoid.contains($0.key) }
        let weights = candidates.map { Self.weight(stats[$0.key]) }
        let total = weights.reduce(0, +)
        var roll = Double.random(in: 0..<total, using: &rng)
        var chosen = candidates[candidates.count - 1]
        for (item, w) in zip(candidates, weights) {
            if roll < w { chosen = item; break }
            roll -= w
        }
        recent.append(chosen.key)
        if recent.count > 16 { recent.removeFirst(recent.count - 16) }
        return chosen
    }
}
