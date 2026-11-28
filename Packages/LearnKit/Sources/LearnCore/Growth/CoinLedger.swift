import Foundation

/// 一条积分变动流水：记录获取与消耗的来源、时间、变化量及变动后余额。
public struct CoinRecord: Codable, Sendable, Equatable, Identifiable {
    public enum Kind: String, Codable, CaseIterable, Sendable {
        case answers
        case completion
        case firstWin
        case levelUp
        case badge
        case migration
        case purchaseCosmetic
        case purchaseDoomShroom
        case adventureEntry

        public var isIncome: Bool {
            switch self {
            case .answers, .completion, .firstWin, .levelUp, .badge, .migration: true
            case .purchaseCosmetic, .purchaseDoomShroom, .adventureEntry: false
            }
        }

        public var icon: String {
            switch self {
            case .answers: "📝"
            case .completion: "🏆"
            case .firstWin: "🔥"
            case .levelUp: "⬆️"
            case .badge: "🏅"
            case .migration: "🎁"
            case .purchaseCosmetic: "✨"
            case .purchaseDoomShroom: "🍄"
            case .adventureEntry: "🗺️"
            }
        }

        public var categoryName: String {
            switch self {
            case .answers: "答题"
            case .completion: "过关"
            case .firstWin: "首胜"
            case .levelUp: "升级"
            case .badge: "徽章"
            case .migration: "补发"
            case .purchaseCosmetic: "外观"
            case .purchaseDoomShroom: "道具"
            case .adventureEntry: "冒险"
            }
        }
    }

    public static let maxStoredCount = 200

    public let id: UUID
    public let date: Date
    public let kind: Kind
    /// 正数表示获取，负数表示消耗
    public let delta: Int
    /// 本次变动后的积分余额
    public let balance: Int
    public let title: String
    public let detail: String?

    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        kind: Kind,
        delta: Int,
        balance: Int,
        title: String,
        detail: String? = nil
    ) {
        self.id = id
        self.date = date
        self.kind = kind
        self.delta = delta
        self.balance = max(0, balance)
        self.title = title
        self.detail = detail
    }
}

public extension GrowthState {
    /// 追加一条积分变动记录；变化量为 0 时不记录。
    mutating func appendCoinRecord(
        kind: CoinRecord.Kind,
        delta: Int,
        title: String,
        detail: String? = nil,
        date: Date = Date()
    ) {
        guard delta != 0 else { return }
        let record = CoinRecord(
            date: date,
            kind: kind,
            delta: delta,
            balance: coins,
            title: title,
            detail: detail
        )
        coinLedger.insert(record, at: 0)
        if coinLedger.count > CoinRecord.maxStoredCount {
            coinLedger.removeLast(coinLedger.count - CoinRecord.maxStoredCount)
        }
    }

    /// 流水累计获取积分
    var totalCoinsEarned: Int {
        coinLedger.reduce(0) { $0 + max(0, $1.delta) }
    }

    /// 流水累计消耗积分（正数）
    var totalCoinsSpent: Int {
        coinLedger.reduce(0) { $0 + max(0, -$1.delta) }
    }

    /// 指定日期的积分收支统计
    func dayCoinsSummary(at date: Date = Date(), calendar: Calendar = .current) -> (earned: Int, spent: Int) {
        var earned = 0
        var spent = 0
        for record in coinLedger where calendar.isDate(record.date, inSameDayAs: date) {
            if record.delta > 0 { earned += record.delta }
            else { spent += -record.delta }
        }
        return (earned, spent)
    }

    /// 今日各常规来源的积分额度使用情况；跨自然日未结算时自动归零。
    func dailyCoinAllowances(
        rules: GameRules = .defaults,
        at date: Date = Date(),
        calendar: Calendar = .current
    ) -> [CoinDailyAllowance] {
        let isToday = stats.day == Self.dayKey(date, calendar: calendar)
        return CoinSource.allCases.map { source in
            let used = isToday ? max(0, stats.coinsToday[source.rawValue] ?? 0) : 0
            return CoinDailyAllowance(source: source, used: used, limit: rules.coinLimit(source))
        }
    }

    /// 按筛选条件过滤积分流水
    func filteredCoinRecords(
        query: CoinLedgerQuery,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> [CoinRecord] {
        coinLedger.filter { record in
            matchesDirection(record, direction: query.direction)
                && matchesRange(record, range: query.range, referenceDate: referenceDate, calendar: calendar)
                && (query.kind == nil || record.kind == query.kind)
        }
    }

    /// 按自然日分组的积分流水，每组附带当日获取与消耗小计
    func groupedCoinRecords(
        query: CoinLedgerQuery,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> [CoinLedgerDayGroup] {
        let records = filteredCoinRecords(query: query, referenceDate: referenceDate, calendar: calendar)
        var groups: [CoinLedgerDayGroup] = []
        for record in records {
            let day = calendar.startOfDay(for: record.date)
            if let index = groups.firstIndex(where: { $0.day == day }) {
                groups[index].append(record)
            } else {
                groups.append(CoinLedgerDayGroup(day: day, firstRecord: record))
            }
        }
        return groups
    }

    /// 按来源分类聚合统计（沿用方向与时间范围，不限制单分类，便于页面侧栏切换筛选）
    func coinKindSummaries(
        query: CoinLedgerQuery,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> [CoinLedgerKindSummary] {
        let baseQuery = CoinLedgerQuery(direction: query.direction, range: query.range, kind: nil)
        let records = filteredCoinRecords(query: baseQuery, referenceDate: referenceDate, calendar: calendar)
        var buckets: [CoinRecord.Kind: (count: Int, total: Int)] = [:]
        for record in records {
            let current = buckets[record.kind] ?? (0, 0)
            buckets[record.kind] = (current.count + 1, current.total + abs(record.delta))
        }
        return buckets
            .map { CoinLedgerKindSummary(kind: $0.key, count: $0.value.count, totalAmount: $0.value.total) }
            .sorted { lhs, rhs in
                if lhs.totalAmount != rhs.totalAmount { return lhs.totalAmount > rhs.totalAmount }
                return lhs.kind.rawValue < rhs.kind.rawValue
            }
    }

    private func matchesDirection(_ record: CoinRecord, direction: CoinLedgerDirection) -> Bool {
        switch direction {
        case .all: true
        case .income: record.delta > 0
        case .expense: record.delta < 0
        }
    }

    private func matchesRange(
        _ record: CoinRecord,
        range: CoinLedgerRange,
        referenceDate: Date,
        calendar: Calendar
    ) -> Bool {
        switch range {
        case .all:
            return true
        case .today:
            return calendar.isDate(record.date, inSameDayAs: referenceDate)
        case .last7Days:
            let todayStart = calendar.startOfDay(for: referenceDate)
            let recordDay = calendar.startOfDay(for: record.date)
            guard let earliest = calendar.date(byAdding: .day, value: -6, to: todayStart) else {
                return true
            }
            return recordDay >= earliest && recordDay <= todayStart
        }
    }
}

/// 积分流水收支方向筛选
public enum CoinLedgerDirection: String, CaseIterable, Sendable {
    case all
    case income
    case expense

    public var displayName: String {
        switch self {
        case .all: "全部"
        case .income: "获取"
        case .expense: "消耗"
        }
    }

    public func matches(kind: CoinRecord.Kind) -> Bool {
        switch self {
        case .all: true
        case .income: kind.isIncome
        case .expense: !kind.isIncome
        }
    }
}

/// 积分流水时间范围筛选
public enum CoinLedgerRange: String, CaseIterable, Sendable {
    case all
    case today
    case last7Days

    public var displayName: String {
        switch self {
        case .all: "全部时间"
        case .today: "今天"
        case .last7Days: "近 7 天"
        }
    }
}

/// 积分流水组合查询条件
public struct CoinLedgerQuery: Sendable, Equatable {
    public var direction: CoinLedgerDirection
    public var range: CoinLedgerRange
    public var kind: CoinRecord.Kind?

    public init(
        direction: CoinLedgerDirection = .all,
        range: CoinLedgerRange = .all,
        kind: CoinRecord.Kind? = nil
    ) {
        self.direction = direction
        self.range = range
        self.kind = kind
    }

    public var hasActiveFilter: Bool {
        direction != .all || range != .all || kind != nil
    }
}

/// 一组流水的收支汇总
public struct CoinLedgerTotals: Sendable, Equatable {
    public let earned: Int
    public let spent: Int

    public var net: Int { earned - spent }

    public init(earned: Int = 0, spent: Int = 0) {
        self.earned = earned
        self.spent = spent
    }

    public static func summarize(_ records: [CoinRecord]) -> CoinLedgerTotals {
        var earned = 0
        var spent = 0
        for record in records {
            if record.delta > 0 { earned += record.delta }
            else { spent += -record.delta }
        }
        return CoinLedgerTotals(earned: earned, spent: spent)
    }
}

/// 按自然日分组的积分流水
public struct CoinLedgerDayGroup: Identifiable, Sendable, Equatable {
    public let day: Date
    public private(set) var records: [CoinRecord]
    public private(set) var earned: Int
    public private(set) var spent: Int

    public var id: Date { day }

    init(day: Date, firstRecord: CoinRecord) {
        self.day = day
        self.records = [firstRecord]
        self.earned = max(0, firstRecord.delta)
        self.spent = max(0, -firstRecord.delta)
    }

    mutating func append(_ record: CoinRecord) {
        records.append(record)
        if record.delta > 0 { earned += record.delta }
        else { spent += -record.delta }
    }
}

/// 按来源分类统计的积分汇总
public struct CoinLedgerKindSummary: Identifiable, Sendable, Equatable {
    public let kind: CoinRecord.Kind
    public let count: Int
    /// 该分类累计变动绝对值（获取或消耗总额）
    public let totalAmount: Int

    public var id: CoinRecord.Kind { kind }
}

/// 今日单个积分来源的获取额度
public struct CoinDailyAllowance: Identifiable, Sendable, Equatable {
    public let source: CoinSource
    public let used: Int
    public let limit: Int

    public var id: CoinSource { source }
    public var remaining: Int { max(0, limit - used) }
}

public extension CoinSource {
    var displayName: String {
        switch self {
        case .answers: "经典答题"
        case .completion: "过关评分"
        case .firstWin: "每日首胜"
        case .level: "升级奖励"
        case .badge: "徽章奖励"
        }
    }
}
