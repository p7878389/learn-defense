import LearnCore
import SwiftUI

/// 积分流水来源分类的视觉配色映射（统一复用全站设计系统语义色）。
enum CoinLedgerKindStyle {
    static func tint(for kind: CoinRecord.Kind) -> Color {
        switch kind {
        case .answers: AppColor.jade
        case .completion: AppColor.gold
        case .firstWin: AppColor.accent
        case .levelUp: AppColor.violet
        case .badge: AppColor.violet
        case .migration: AppColor.calm
        case .purchaseCosmetic: AppColor.accent
        case .purchaseDoomShroom: AppColor.dangerSolidBottom
        case .adventureEntry: AppColor.adventure
        }
    }

    static func edge(for kind: CoinRecord.Kind) -> Color {
        switch kind {
        case .answers: AppColor.jadeEdge
        case .completion: AppColor.goldEdge
        case .firstWin: AppColor.accentEdge
        case .levelUp: AppColor.violetEdge
        case .badge: AppColor.violetEdge
        case .migration: AppColor.calm
        case .purchaseCosmetic: AppColor.accentEdge
        case .purchaseDoomShroom: AppColor.dangerText
        case .adventureEntry: AppColor.adventureEdge
        }
    }
}

/// 积分概览面板所需的只读快照，避免视图构造器参数过多。
struct CoinLedgerOverviewModel {
    let coins: Int
    let today: CoinLedgerTotals
    let lifetime: CoinLedgerTotals
    let summaries: [CoinLedgerKindSummary]
    let allowances: [CoinDailyAllowance]
}

/// 宽屏左侧概览栏：固定一屏展示（不可滚动），包含积分金库余额卡与可切换的「来源分布 / 今日额度」分析卡。
struct CoinLedgerOverviewPanel: View {
    private enum InsightTab: String, CaseIterable {
        case distribution = "来源分布"
        case allowance = "今日额度"
    }

    let overview: CoinLedgerOverviewModel
    @Binding var selectedKind: CoinRecord.Kind?
    @State private var insightTab: InsightTab = .distribution

    private var maxSummaryAmount: Int {
        overview.summaries.map(\.totalAmount).max() ?? 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            vaultCard
            insightCard
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var vaultCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.xs) {
                CoinIcon(size: 28)
                Text("我的积分金库")
                    .font(AppFont.bodyStrong)
                    .foregroundStyle(AppColor.ink)
                Spacer()
                Text("可用余额")
                    .font(AppFont.caption)
                    .foregroundStyle(AppColor.muted)
            }

            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                Text("\(overview.coins)")
                    .font(AppFont.digits(40, weight: .black))
                    .foregroundStyle(AppColor.goldEdge)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("积分")
                    .font(AppFont.bodyStrong)
                    .foregroundStyle(AppColor.muted)
            }

            HintCapsule(
                icon: todayHint.icon,
                text: todayHint.text,
                tint: todayHint.tint
            )

            HStack(spacing: AppSpacing.xs) {
                statBlock(
                    title: "今日收支",
                    primary: "+\(overview.today.earned)",
                    secondary: "消耗 -\(overview.today.spent)",
                    tint: AppColor.jadeEdge
                )
                statBlock(
                    title: "流水累计",
                    primary: "+\(overview.lifetime.earned)",
                    secondary: "消耗 -\(overview.lifetime.spent)",
                    tint: AppColor.adventureEdge
                )
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appPanel(radius: AppRadius.lg, tint: AppColor.gold)
    }

    private var insightCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.xs) {
                insightTabBar
                Spacer(minLength: 4)
                if insightTab == .distribution, selectedKind != nil {
                    Button("全部") { selectedKind = nil }
                        .font(AppFont.label)
                        .foregroundStyle(AppColor.accentEdge)
                        .buttonStyle(.plain)
                }
            }

            switch insightTab {
            case .distribution:
                distributionContent
            case .allowance:
                allowanceContent
            }

            Spacer(minLength: 0)
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .appPanel(radius: AppRadius.lg)
    }

    private var insightTabBar: some View {
        HStack(spacing: 4) {
            ForEach(InsightTab.allCases, id: \.self) { tab in
                let selected = insightTab == tab
                Button {
                    insightTab = tab
                } label: {
                    Text(tab.rawValue)
                        .font(AppFont.label)
                        .foregroundStyle(selected ? AppColor.ink : AppColor.muted)
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(selected ? AppColor.surface : .clear))
                        .overlay(
                            Capsule().strokeBorder(
                                selected ? AppColor.cardStroke.opacity(0.85) : .clear,
                                lineWidth: 1
                            )
                        )
                }
                .buttonStyle(PressableStyle())
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Capsule().fill(AppColor.ink.opacity(0.05)))
    }

    @ViewBuilder
    private var distributionContent: some View {
        if overview.summaries.isEmpty {
            Text("当前筛选条件下暂无分类统计")
                .font(AppFont.label)
                .foregroundStyle(AppColor.muted)
                .padding(.vertical, AppSpacing.sm)
        } else {
            let columns = [
                GridItem(.flexible(), spacing: AppSpacing.xs),
                GridItem(.flexible(), spacing: AppSpacing.xs)
            ]
            LazyVGrid(columns: columns, spacing: AppSpacing.xs) {
                ForEach(overview.summaries) { item in
                    categoryTile(item)
                }
            }
        }
    }

    private var allowanceContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            ForEach(overview.allowances) { item in
                let full = item.limit > 0 && item.used >= item.limit
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(item.source.displayName)
                            .font(AppFont.label)
                            .foregroundStyle(AppColor.muted)
                        Spacer()
                        Text("\(item.used) / \(item.limit)")
                            .font(AppFont.digits(13, weight: .heavy))
                            .foregroundStyle(full ? AppColor.goldEdge : AppColor.ink)
                    }
                    MiniBar(
                        value: Double(item.used),
                        total: Double(max(1, item.limit)),
                        tint: full ? AppColor.gold : AppColor.jade,
                        height: 8
                    )
                }
            }
        }
        .padding(.top, AppSpacing.xxs)
    }

    private func categoryTile(_ item: CoinLedgerKindSummary) -> some View {
        let selected = selectedKind == item.kind
        let tint = CoinLedgerKindStyle.tint(for: item.kind)
        let edge = CoinLedgerKindStyle.edge(for: item.kind)
        let prefix = item.kind.isIncome ? "+" : "-"

        return Button {
            selectedKind = selected ? nil : item.kind
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    PictureView(emoji: item.kind.icon, size: 18)
                    Text(item.kind.categoryName)
                        .font(AppFont.label)
                        .foregroundStyle(AppColor.ink)
                        .lineLimit(1)
                    Spacer(minLength: 2)
                    Text("\(item.count)笔")
                        .font(AppFont.micro)
                        .foregroundStyle(AppColor.muted)
                }
                Text("\(prefix)\(item.totalAmount)")
                    .font(AppFont.digits(16, weight: .black))
                    .foregroundStyle(item.kind.isIncome ? AppColor.jadeEdge : AppColor.dangerText)
                    .lineLimit(1)
                MiniBar(
                    value: Double(item.totalAmount),
                    total: Double(max(1, maxSummaryAmount)),
                    tint: tint,
                    height: 6
                )
            }
            .padding(.horizontal, 10)
            .padding(.vertical, AppSpacing.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
            .appInset(radius: AppRadius.sm, tint: selected ? tint : nil)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.sm)
                    .strokeBorder(selected ? edge : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func statBlock(title: String, primary: String, secondary: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(AppFont.caption)
                .foregroundStyle(AppColor.muted)
            Text(primary)
                .font(AppFont.digits(22, weight: .black))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(secondary)
                .font(AppFont.caption)
                .foregroundStyle(AppColor.muted)
                .lineLimit(1)
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appInset(radius: AppRadius.sm, tint: tint)
    }

    private var todayHint: (icon: String, text: String, tint: Color) {
        if overview.today.earned == 0 && overview.today.spent == 0 {
            return ("🌱", "今天还没有积分变动，去经典闯关赚取吧！", AppColor.muted)
        }
        if overview.today.net >= 0 {
            return ("✨", "今日净增 +\(overview.today.net) 积分，表现很棒！", AppColor.jadeEdge)
        }
        return ("🛍️", "今日净消耗 \(overview.today.net) 积分", AppColor.accentEdge)
    }
}

/// 窄屏/竖屏顶部紧凑概览与横向分类胶囊。
struct CoinLedgerCompactOverview: View {
    let overview: CoinLedgerOverviewModel
    @Binding var selectedKind: CoinRecord.Kind?

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.xs) {
                compactTile(title: "可用余额", value: "\(overview.coins)", sub: "当前积分", tint: AppColor.goldEdge)
                compactTile(
                    title: "今日收支",
                    value: "+\(overview.today.earned)",
                    sub: "消耗 -\(overview.today.spent)",
                    tint: AppColor.jadeEdge
                )
                compactTile(
                    title: "流水累计",
                    value: "+\(overview.lifetime.earned)",
                    sub: "消耗 -\(overview.lifetime.spent)",
                    tint: AppColor.adventureEdge
                )
            }

            if !overview.summaries.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.xs) {
                        ForEach(overview.summaries) { item in
                            categoryChip(item)
                        }
                    }
                }
            }
        }
    }

    private func compactTile(title: String, value: String, sub: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(AppFont.caption)
                .foregroundStyle(AppColor.muted)
            Text(value)
                .font(AppFont.digits(24, weight: .black))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(sub)
                .font(AppFont.caption)
                .foregroundStyle(AppColor.muted)
                .lineLimit(1)
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appPanel(radius: AppRadius.md, tint: tint)
    }

    private func categoryChip(_ item: CoinLedgerKindSummary) -> some View {
        let selected = selectedKind == item.kind
        let tint = CoinLedgerKindStyle.tint(for: item.kind)
        let edge = CoinLedgerKindStyle.edge(for: item.kind)
        let prefix = item.kind.isIncome ? "+" : "-"

        return Button {
            selectedKind = selected ? nil : item.kind
        } label: {
            HStack(spacing: 6) {
                PictureView(emoji: item.kind.icon, size: 18)
                Text(item.kind.categoryName)
                    .font(AppFont.label)
                    .foregroundStyle(selected ? .white : AppColor.ink)
                Text("\(prefix)\(item.totalAmount)")
                    .font(AppFont.digits(13, weight: .black))
                    .foregroundStyle(selected ? .white.opacity(0.95) : (item.kind.isIncome ? AppColor.jadeEdge : AppColor.dangerText))
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .background(Capsule().fill(selected ? edge : AppColor.surface))
            .overlay(Capsule().strokeBorder(selected ? edge : tint.opacity(0.45), lineWidth: 1.5))
        }
        .buttonStyle(PressableStyle())
    }
}
