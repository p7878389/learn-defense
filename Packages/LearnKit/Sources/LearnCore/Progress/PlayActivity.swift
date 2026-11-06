import Foundation

/// 首页孩子卡片上的游玩概况，由对局记录（每局的开始时间）算出来
public struct PlayActivity: Sendable, Equatable {
    /// 最近一次开局的时间；从没玩过（或升级前的老记录）为 nil
    public var lastPlayedAt: Date?
    /// 连续几天每天都玩过，算到今天；今天还没玩时算到昨天。最近一次已经是前天或更早时为 0
    public var streakDays: Int

    public static let none = PlayActivity(lastPlayedAt: nil, streakDays: 0)

    public init(lastPlayedAt: Date?, streakDays: Int) {
        self.lastPlayedAt = lastPlayedAt
        self.streakDays = streakDays
    }

    /// - Parameter dates: 各局的开始时间，顺序不限。晚于 now 的（改过系统时间）不算
    public init(playedAt dates: [Date], now: Date = Date(), calendar: Calendar = .current) {
        let past = dates.filter { $0 <= now }
        lastPlayedAt = past.max()
        let days = Set(past.map { calendar.startOfDay(for: $0) })
        let today = calendar.startOfDay(for: now)
        guard var day = days.contains(today) ? today : calendar.date(byAdding: .day, value: -1, to: today) else {
            streakDays = 0
            return
        }
        var count = 0
        while days.contains(day) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        streakDays = count
    }

    /// 最近一次玩距今几天（今天玩过为 0，昨天为 1）；从没玩过为 nil
    public func daysSinceLastPlay(now: Date = Date(), calendar: Calendar = .current) -> Int? {
        guard let lastPlayedAt else { return nil }
        let days = calendar.dateComponents(
            [.day], from: calendar.startOfDay(for: lastPlayedAt), to: calendar.startOfDay(for: now)).day
        return max(0, days ?? 0)
    }

    /// 首页轮播的顺序：玩过的按最近游玩时间排（最近的在前），没玩过的排在后面并保持原来的顺序
    public static func homeOrder(_ profiles: [Profile], activity: [UUID: PlayActivity]) -> [Profile] {
        profiles.enumerated()
            .sorted { a, b in
                let da = activity[a.element.id]?.lastPlayedAt
                let db = activity[b.element.id]?.lastPlayedAt
                switch (da, db) {
                case let (x?, y?) where x != y: return x > y
                case (_?, nil): return true
                case (nil, _?): return false
                default: return a.offset < b.offset
                }
            }
            .map(\.element)
    }
}
