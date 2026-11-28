import LearnCore
import SwiftUI

/// 积分流水独立全屏页面：展示金库余额、来源分类汇总，以及支持方向/时间/分类组合筛选的按日流水时间轴。
struct CoinLedgerView: View {
    @EnvironmentObject private var model: AppModel
    let profileID: UUID
    var backTitle: String = "返回主页"
    let onClose: () -> Void

    @State private var direction: CoinLedgerDirection = .all
    @State private var range: CoinLedgerRange = .all
    @State private var selectedKind: CoinRecord.Kind?

    private var profile: Profile? {
        model.profiles.first { $0.id == profileID }
    }

    private var growth: GrowthStore {
        model.growth(for: profileID)
    }

    private var activeQuery: CoinLedgerQuery {
        CoinLedgerQuery(direction: direction, range: range, kind: selectedKind)
    }

    var body: some View {
        let state = growth.state
        let todayRaw = state.dayCoinsSummary()
        let today = CoinLedgerTotals(earned: todayRaw.earned, spent: todayRaw.spent)
        let lifetime = CoinLedgerTotals(earned: state.totalCoinsEarned, spent: state.totalCoinsSpent)
        let summaries = state.coinKindSummaries(query: activeQuery)
        let groups = state.groupedCoinRecords(query: activeQuery)
        let filteredRecords = groups.flatMap(\.records)
        let filteredTotals = CoinLedgerTotals.summarize(filteredRecords)
        let overview = CoinLedgerOverviewModel(
            coins: state.coins,
            today: today,
            lifetime: lifetime,
            summaries: summaries,
            allowances: state.dailyCoinAllowances(rules: growth.rules)
        )

        GeometryReader { geo in
            let wide = geo.size.width >= 780
            VStack(spacing: AppSpacing.md) {
                topBar(level: growth.level.level, coins: state.coins)
                if wide {
                    HStack(alignment: .top, spacing: AppSpacing.md) {
                        CoinLedgerOverviewPanel(
                            overview: overview,
                            selectedKind: $selectedKind
                        )
                        .frame(width: 332)

                        ledgerListPanel(
                            groups: groups,
                            recordCount: filteredRecords.count,
                            totals: filteredTotals
                        )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                } else {
                    VStack(spacing: AppSpacing.md) {
                        CoinLedgerCompactOverview(overview: overview, selectedKind: $selectedKind)
                        ledgerListPanel(
                            groups: groups,
                            recordCount: filteredRecords.count,
                            totals: filteredTotals
                        )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
            .padding(geo.size.width < 600 ? AppSpacing.sm : AppSpacing.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(GrowthPageBackground())
        .onChange(of: direction) { _, newValue in
            if let kind = selectedKind, !newValue.matches(kind: kind) {
                selectedKind = nil
            }
        }
        #if os(macOS)
        .frame(minWidth: 900, idealWidth: 1080, minHeight: 620, idealHeight: 740)
        #endif
    }

    private func topBar(level: Int, coins: Int) -> some View {
        let owner = profile?.name ?? "小守卫"
        return GrowthPageHeader(
            icon: "🪙",
            title: "积分流水",
            subtitle: "\(owner) · 保留最近 \(CoinRecord.maxStoredCount) 条",
            backTitle: backTitle,
            onClose: onClose
        ) {
            LevelPill(level: level)
            CoinPill(coins: coins, size: 22)
        }
    }

    private func ledgerListPanel(
        groups: [CoinLedgerDayGroup],
        recordCount: Int,
        totals: CoinLedgerTotals
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            filterToolbar
            statusSummaryBar(recordCount: recordCount, totals: totals)

            if groups.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: AppSpacing.md) {
                        ForEach(groups) { group in
                            daySection(group)
                        }
                    }
                    .padding(.bottom, AppSpacing.sm)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .appPanel(radius: AppRadius.lg)
    }

    private var filterToolbar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: AppSpacing.sm) {
                GrowthSegmentedPicker(options: CoinLedgerDirection.allCases, title: \.displayName, selection: $direction)
                Spacer(minLength: AppSpacing.xs)
                rangePills
            }
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                GrowthSegmentedPicker(options: CoinLedgerDirection.allCases, title: \.displayName, selection: $direction)
                rangePills
            }
        }
    }

    private var rangePills: some View {
        HStack(spacing: 6) {
            ForEach(CoinLedgerRange.allCases, id: \.self) { option in
                let selected = range == option
                Button {
                    range = option
                } label: {
                    Text(option.displayName)
                        .font(AppFont.label)
                        .foregroundStyle(selected ? .white : AppColor.muted)
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(selected ? AppColor.adventure : AppColor.surface))
                        .overlay(
                            Capsule().strokeBorder(
                                selected ? AppColor.adventureEdge : AppColor.cardStroke.opacity(0.75),
                                lineWidth: 1.2
                            )
                        )
                }
                .buttonStyle(PressableStyle())
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    private func statusSummaryBar(recordCount: Int, totals: CoinLedgerTotals) -> some View {
        HStack(spacing: AppSpacing.xs) {
            if let kind = selectedKind {
                Button { selectedKind = nil } label: {
                    HStack(spacing: 4) {
                        Text(kind.icon)
                        Text("分类：\(kind.categoryName)")
                        Image(systemName: "xmark.circle.fill")
                            .font(AppFont.caption)
                    }
                    .font(AppFont.label)
                    .foregroundStyle(CoinLedgerKindStyle.edge(for: kind))
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(CoinLedgerKindStyle.tint(for: kind).opacity(0.16)))
                }
                .buttonStyle(.plain)
            }

            Text("共 \(recordCount) 条")
                .font(AppFont.label)
                .foregroundStyle(AppColor.muted)

            Spacer()

            if recordCount > 0 {
                HStack(spacing: AppSpacing.sm) {
                    if totals.earned > 0 {
                        Text("获取 +\(totals.earned)")
                            .font(AppFont.digits(14, weight: .bold))
                            .foregroundStyle(AppColor.jadeEdge)
                    }
                    if totals.spent > 0 {
                        Text("消耗 -\(totals.spent)")
                            .font(AppFont.digits(14, weight: .bold))
                            .foregroundStyle(AppColor.dangerText)
                    }
                }
            }
        }
        .padding(.horizontal, AppSpacing.xs)
    }

    private func daySection(_ group: CoinLedgerDayGroup) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(spacing: AppSpacing.xs) {
                Text(Self.dayHeading(for: group.day, calendar: .current))
                    .font(AppFont.bodyStrong)
                    .foregroundStyle(AppColor.ink)
                Text("· \(group.records.count) 笔")
                    .font(AppFont.caption)
                    .foregroundStyle(AppColor.muted)
                Spacer()
                if group.earned > 0 {
                    Text("+\(group.earned)")
                        .font(AppFont.digits(14, weight: .black))
                        .foregroundStyle(AppColor.jadeEdge)
                }
                if group.spent > 0 {
                    Text("-\(group.spent)")
                        .font(AppFont.digits(14, weight: .black))
                        .foregroundStyle(AppColor.dangerText)
                }
            }
            .padding(.horizontal, AppSpacing.xs)

            ForEach(group.records) { record in
                CoinLedgerRow(record: record)
            }
        }
    }

    private var emptyState: some View {
        let hasLedgerData = !growth.state.coinLedger.isEmpty
        return VStack(spacing: AppSpacing.sm) {
            PictureView(emoji: emptyEmoji, size: 64)
            Text(emptyTitle(hasLedgerData: hasLedgerData))
                .font(AppFont.heading)
                .foregroundStyle(AppColor.ink)
            Text(emptySubtitle(hasLedgerData: hasLedgerData))
                .font(AppFont.body)
                .foregroundStyle(AppColor.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            if hasLedgerData && activeQuery.hasActiveFilter {
                AppButton(title: "查看全部记录", systemImage: "arrow.counterclockwise", role: .secondary, size: .medium) {
                    direction = .all
                    range = .all
                    selectedKind = nil
                }
                .padding(.top, AppSpacing.xs)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AppSpacing.lg)
        .appInset(radius: AppRadius.md)
    }

    private var emptyEmoji: String {
        if let kind = selectedKind { return kind.icon }
        return direction == .expense ? "🛍️" : "🪙"
    }

    private func emptyTitle(hasLedgerData: Bool) -> String {
        if hasLedgerData && activeQuery.hasActiveFilter {
            return "当前筛选下没有积分记录"
        }
        switch direction {
        case .all: return "还没有积分记录"
        case .income: return "还没有获取记录"
        case .expense: return "还没有消耗记录"
        }
    }

    private func emptySubtitle(hasLedgerData: Bool) -> String {
        if hasLedgerData && activeQuery.hasActiveFilter {
            return "试试切换时间范围、收支方向，或清除分类筛选查看完整流水。"
        }
        switch direction {
        case .all, .income:
            return "去「经典闯关」答题过关就能赚取积分，每笔获取、升级和徽章奖励都会记在这里。"
        case .expense:
            return "在「收藏馆」购买外观、解锁毁灭菇或参加「冒险闯关」的积分消耗会记在这里。"
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        return formatter
    }()

    private static func dayHeading(for day: Date, calendar: Calendar) -> String {
        if calendar.isDateInToday(day) { return "今天" }
        if calendar.isDateInYesterday(day) { return "昨天" }
        return dateFormatter.string(from: day)
    }
}

/// 单条积分流水行：来源图标、标题、分类胶囊、时间与详情、右侧变动数额与余额。
private struct CoinLedgerRow: View {
    let record: CoinRecord

    private var isIncome: Bool { record.delta > 0 }
    private var tint: Color { CoinLedgerKindStyle.tint(for: record.kind) }
    private var edge: Color { CoinLedgerKindStyle.edge(for: record.kind) }

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            PictureView(emoji: record.kind.icon, size: 28)
                .frame(width: 46, height: 46)
                .background(Circle().fill(tint.opacity(0.16)))
                .overlay(Circle().strokeBorder(tint.opacity(0.32), lineWidth: 1))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: AppSpacing.xs) {
                    Text(record.title)
                        .font(AppFont.bodyStrong)
                        .foregroundStyle(AppColor.ink)
                        .lineLimit(1)
                    Text(record.kind.categoryName)
                        .font(AppFont.caption)
                        .foregroundStyle(edge)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
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
                Text(isIncome ? "+\(record.delta)" : "\(record.delta)")
                    .font(AppFont.digits(22, weight: .black))
                    .foregroundStyle(isIncome ? AppColor.jadeEdge : AppColor.dangerText)
                Text("余额 \(record.balance)")
                    .font(AppFont.caption)
                    .foregroundStyle(AppColor.muted)
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .appInset(radius: AppRadius.md)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}
