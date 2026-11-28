import LearnCore
import SwiftUI

/// 积分记录独立全屏页：横屏左右分栏（左侧收支概览与今日额度、右侧按日分组流水），竖屏上下排布。
struct CoinLedgerView: View {
    enum Filter: String, CaseIterable {
        case all = "全部"
        case income = "获取"
        case expense = "消耗"
    }

    @EnvironmentObject private var model: AppModel
    let profileID: UUID
    let onClose: () -> Void
    @State private var filter: Filter = .all

    private var profileName: String {
        model.profiles.first(where: { $0.id == profileID })?.name ?? "小守卫"
    }

    private var growth: GrowthStore { model.growth(for: profileID) }
    private var allRecords: [CoinRecord] { growth.state.coinLedger }

    private var filteredRecords: [CoinRecord] {
        switch filter {
        case .all: allRecords
        case .income: allRecords.filter { $0.delta > 0 }
        case .expense: allRecords.filter { $0.delta < 0 }
        }
    }

    private var groupedRecords: [(dayTitle: String, records: [CoinRecord])] {
        let calendar = Calendar.current
        var groups: [(key: Date, title: String, items: [CoinRecord])] = []
        for record in filteredRecords {
            let day = calendar.startOfDay(for: record.date)
            if let idx = groups.firstIndex(where: { $0.key == day }) {
                groups[idx].items.append(record)
            } else {
                groups.append((day, Self.dayHeading(for: day, calendar: calendar), [record]))
            }
        }
        return groups.map { ($0.title, $0.items) }
    }

    var body: some View {
        let today = growth.state.dayCoinsSummary()
        GeometryReader { geo in
            let wide = geo.size.width >= 820
            VStack(spacing: AppSpacing.md) {
                GrowthPageHeader(icon: "🪙", title: "积分记录", subtitle: "\(profileName)的获取与消耗明细", onClose: onClose) {
                    LevelPill(level: growth.level.level)
                    CoinPill(coins: growth.state.coins, size: 24)
                }

                if wide {
                    HStack(alignment: .top, spacing: AppSpacing.md) {
                        ScrollView {
                            overviewColumn(today: today)
                        }
                        .scrollBounceBehavior(.basedOnSize)
                        .frame(width: 340)

                        ledgerPanel
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    VStack(spacing: AppSpacing.md) {
                        compactSummaryRow(today: today)
                        ledgerPanel
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .padding(geo.size.width < 600 ? AppSpacing.sm : AppSpacing.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(GrowthPageBackground())
    }

    private func overviewColumn(today: (earned: Int, spent: Int)) -> some View {
        VStack(spacing: AppSpacing.sm) {
            summaryTile(title: "当前余额", value: "\(growth.state.coins)", sub: "可用于收藏馆外观、毁灭菇与冒险闯关",
                        tint: AppColor.gold, valueColor: AppColor.goldEdge, showCoin: true)
            summaryTile(title: "今日收支", value: "+\(today.earned)", sub: "今日消耗 -\(today.spent)",
                        tint: AppColor.jade, valueColor: AppColor.jadeEdge, showCoin: false)
            summaryTile(title: "累计记录", value: "+\(growth.state.totalCoinsEarned)",
                        sub: "累计消耗 -\(growth.state.totalCoinsSpent) · 保留最近 \(CoinRecord.maxStoredCount) 条",
                        tint: AppColor.adventure, valueColor: AppColor.adventureEdge, showCoin: false)
            dailyAllowanceCard
        }
    }

    private func compactSummaryRow(today: (earned: Int, spent: Int)) -> some View {
        HStack(spacing: AppSpacing.sm) {
            summaryTile(title: "当前余额", value: "\(growth.state.coins)", sub: "可用积分",
                        tint: AppColor.gold, valueColor: AppColor.goldEdge, showCoin: true)
            summaryTile(title: "今日收支", value: "+\(today.earned)", sub: "消耗 -\(today.spent)",
                        tint: AppColor.jade, valueColor: AppColor.jadeEdge, showCoin: false)
            summaryTile(title: "累计记录", value: "+\(growth.state.totalCoinsEarned)", sub: "消耗 -\(growth.state.totalCoinsSpent)",
                        tint: AppColor.adventure, valueColor: AppColor.adventureEdge, showCoin: false)
        }
    }

    private var dailyAllowanceCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("今日各来源额度")
                .font(AppFont.bodyStrong)
                .foregroundStyle(AppColor.ink)
            ForEach(CoinSource.allCases, id: \.rawValue) { source in
                let used = max(0, growth.state.stats.coinsToday[source.rawValue] ?? 0)
                let limit = growth.rules.coinLimit(source)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(Self.sourceTitle(source))
                            .font(AppFont.label)
                            .foregroundStyle(AppColor.muted)
                        Spacer()
                        Text("\(used) / \(limit)")
                            .font(AppFont.digits(14, weight: .heavy))
                            .foregroundStyle(AppColor.ink)
                    }
                    MiniBar(value: Double(used), total: Double(max(1, limit)), tint: AppColor.jade)
                }
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appPanel(radius: AppRadius.lg)
    }

    private var ledgerPanel: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                GrowthSegmentedPicker(options: Filter.allCases, title: \.rawValue, selection: $filter)
                Spacer()
                Text("共 \(filteredRecords.count) 条")
                    .font(AppFont.label)
                    .foregroundStyle(AppColor.muted)
            }

            if filteredRecords.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: AppSpacing.sm) {
                        ForEach(groupedRecords, id: \.dayTitle) { group in
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                Text(group.dayTitle)
                                    .font(AppFont.label)
                                    .foregroundStyle(AppColor.muted)
                                    .padding(.horizontal, AppSpacing.xs)
                                ForEach(group.records) { record in
                                    recordRow(record)
                                }
                            }
                        }
                    }
                    .padding(.bottom, AppSpacing.xs)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .appPanel(radius: AppRadius.lg)
    }

    private func summaryTile(
        title: String,
        value: String,
        sub: String,
        tint: Color,
        valueColor: Color,
        showCoin: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(AppFont.label)
                .foregroundStyle(AppColor.muted)
            HStack(spacing: 6) {
                if showCoin { CoinIcon(size: 24) }
                Text(value)
                    .font(AppFont.digits(28, weight: .black))
                    .foregroundStyle(valueColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Text(sub)
                .font(AppFont.caption)
                .foregroundStyle(AppColor.muted)
                .lineLimit(2)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appPanel(radius: AppRadius.md, tint: tint)
    }

    private func recordRow(_ record: CoinRecord) -> some View {
        let income = record.delta > 0
        let tint = income ? AppColor.jade : AppColor.accent
        return HStack(spacing: AppSpacing.sm) {
            PictureView(emoji: record.kind.icon, size: 28)
                .frame(width: 44, height: 44)
                .background(Circle().fill(tint.opacity(0.15)))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: AppSpacing.xs) {
                    Text(record.title)
                        .font(AppFont.bodyStrong)
                        .foregroundStyle(AppColor.ink)
                        .lineLimit(1)
                    Text(record.kind.categoryName)
                        .font(AppFont.caption)
                        .foregroundStyle(income ? AppColor.jadeEdge : AppColor.accentEdge)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(Capsule().fill(tint.opacity(0.16)))
                }
                HStack(spacing: AppSpacing.xs) {
                    Text(Self.timeFormatter.string(from: record.date))
                    if let detail = record.detail, !detail.isEmpty {
                        Text("·")
                        Text(detail).lineLimit(1)
                    }
                }
                .font(AppFont.caption)
                .foregroundStyle(AppColor.muted)
            }

            Spacer(minLength: AppSpacing.xs)

            VStack(alignment: .trailing, spacing: 2) {
                Text(income ? "+\(record.delta)" : "\(record.delta)")
                    .font(AppFont.digits(22, weight: .black))
                    .foregroundStyle(income ? AppColor.jadeEdge : AppColor.dangerText)
                Text("余额 \(record.balance)")
                    .font(AppFont.caption)
                    .foregroundStyle(AppColor.muted)
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .appInset(radius: AppRadius.md)
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.sm) {
            PictureView(emoji: filter == .expense ? "🛍️" : "🪙", size: 58)
            Text(emptyTitle)
                .font(AppFont.heading)
                .foregroundStyle(AppColor.ink)
            Text(emptySubtitle)
                .font(AppFont.body)
                .foregroundStyle(AppColor.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AppSpacing.lg)
    }

    private var emptyTitle: String {
        switch filter {
        case .all: "还没有积分记录"
        case .income: "还没有获取记录"
        case .expense: "还没有消耗记录"
        }
    }

    private var emptySubtitle: String {
        switch filter {
        case .all, .income: "去「经典闯关」答题过关就能赚取积分，每笔获取都会记在这里。"
        case .expense: "在「收藏馆」购买外观、解锁毁灭菇或参加「冒险闯关」的消耗会记在这里。"
        }
    }

    private static func sourceTitle(_ source: CoinSource) -> String {
        switch source {
        case .answers: "经典答题"
        case .completion: "过关评分"
        case .firstWin: "每日首胜"
        case .level: "升级奖励"
        case .badge: "徽章奖励"
        }
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M月d日"
        return f
    }()

    private static func dayHeading(for day: Date, calendar: Calendar) -> String {
        if calendar.isDateInToday(day) { return "今天" }
        if calendar.isDateInYesterday(day) { return "昨天" }
        return dateFormatter.string(from: day)
    }
}
