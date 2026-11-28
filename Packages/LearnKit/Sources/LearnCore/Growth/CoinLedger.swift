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
}
