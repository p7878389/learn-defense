import LearnCore
import SwiftUI

/// 积分记录弹窗：展示当前余额、今日/累计收支概览，以及按日期分组的获取与消耗流水。
struct CoinLedgerView: View {
    enum Filter: String, CaseIterable {
        case all = "全部"
        case income = "获取"
        case expense = "消耗"
    }

    @Environment(\.dismiss) private var dismiss
    let profile: Profile
    let growth: GrowthStore
    @State private var filter: Filter = .all

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
        AppModalScaffold(
            systemImage: "list.bullet.rectangle.portrait.fill",
            iconTint: AppColor.goldEdge,
            title: "\(profile.name)的积分记录",
            subtitle: "记录每笔答题、通关、升级、徽章奖励与外观、冒险消耗（保留最近 \(CoinRecord.maxStoredCount) 条）",
            scrollable: false
        ) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                summaryStrip(today: today)

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
                        }
                        .scrollBounceBehavior(.basedOnSize)
                    }
                }
                .padding(AppSpacing.md)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .appPanel()
            }
        } footer: {
            AppButton(title: "完成", systemImage: "checkmark", role: .primary, size: .large, minWidth: 180) {
                dismiss()
            }
        }
        #if os(macOS)
        .frame(minWidth: 660, idealWidth: 820, minHeight: 500, idealHeight: 660)
        #endif
    }

    private func summaryStrip(today: (earned: Int, spent: Int)) -> some View {
        HStack(spacing: AppSpacing.sm) {
            summaryTile(
                title: "当前余额",
                value: "\(growth.state.coins)",
                sub: "可用积分",
                tint: AppColor.gold,
                valueColor: AppColor.goldEdge,
                showCoin: true
            )
            summaryTile(
                title: "今日收支",
                value: "+\(today.earned)",
                sub: "今日消耗 -\(today.spent)",
                tint: AppColor.jade,
                valueColor: AppColor.jadeEdge,
                showCoin: false
            )
            summaryTile(
                title: "累计记录",
                value: "+\(growth.state.totalCoinsEarned)",
                sub: "累计消耗 -\(growth.state.totalCoinsSpent)",
                tint: AppColor.adventure,
                valueColor: AppColor.adventureEdge,
                showCoin: false
            )
        }
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
                .lineLimit(1)
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
        .appPanel()
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
