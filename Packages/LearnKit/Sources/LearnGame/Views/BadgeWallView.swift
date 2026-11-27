import LearnCore
import SwiftUI

/// 徽章墙：得到的徽章是彩色奖章 + 日期；没得到的是灰色奖章，但保留进度，快完成的特别标出来。
/// 设计稿 docs/ui-growth/04
struct BadgeWallView: View {
    @EnvironmentObject private var model: AppModel
    let profileID: UUID
    let onClose: () -> Void

    @State private var selectedID: String?

    private var growth: GrowthStore { model.growth(for: profileID) }

    var body: some View {
        let level = growth.level.level
        let badges = growth.catalog.badges
        let earned = badges.filter { growth.state.badges[$0.id] != nil }
        GeometryReader { geo in
            let wide = geo.size.width >= 780
            VStack(spacing: AppSpacing.md) {
                topBar(level: level, earned: earned.count, total: badges.count)
                if wide {
                    HStack(alignment: .top, spacing: AppSpacing.md) {
                        ScrollView {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: AppSpacing.sm), count: 4), spacing: AppSpacing.sm) {
                                ForEach(badges, id: \.id) { tile($0, level: level) }
                            }
                            .padding(AppSpacing.md)
                        }
                        .scrollBounceBehavior(.basedOnSize)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .appPanel(radius: AppRadius.lg)
                        detail(level: level, badges: badges)
                            .frame(width: 340)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: AppSpacing.md) {
                            detail(level: level, badges: badges)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: AppSpacing.sm)], spacing: AppSpacing.sm) {
                                ForEach(badges, id: \.id) { tile($0, level: level) }
                            }
                            .padding(AppSpacing.md)
                            .appPanel(radius: AppRadius.lg)
                        }
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(GrowthPageBackground())
    }

    private func topBar(level: Int, earned: Int, total: Int) -> some View {
        GrowthPageHeader(icon: "🏅", title: "我的徽章墙", onClose: onClose) {
            LevelPill(level: level)
            VStack(alignment: .leading, spacing: 6) {
                Text("已收集 \(earned) / \(total)")
                    .font(AppFont.bodyStrong)
                    .foregroundStyle(AppColor.violetEdge)
                MiniBar(value: Double(earned), total: Double(max(1, total)), tint: AppColor.violet)
                    .frame(width: 150)
            }
            .padding(.horizontal, AppSpacing.md)
            .frame(height: 52)
            .appInset(radius: AppRadius.md, tint: AppColor.violet)
        }
    }

    // MARK: 奖章格子

    private func fraction(_ badge: BadgeKind, level: Int) -> Double {
        let p = badge.progress(stats: growth.state.stats, level: level)
        return p.target == 0 ? 0 : Double(p.value) / Double(p.target)
    }

    private func tile(_ badge: BadgeKind, level: Int) -> some View {
        let date = growth.state.badges[badge.id]
        let earned = date != nil
        let progress = badge.progress(stats: growth.state.stats, level: level)
        let close = !earned && fraction(badge, level: level) >= 0.6
        let selected = (selectedID ?? defaultSelection(level: level)?.id) == badge.id
        let tint: Color? = earned ? AppColor.jade : (close ? AppColor.adventure : AppColor.disabledFill)
        let borderColor: Color = selected ? AppColor.violet : (close ? AppColor.adventure : (earned ? AppColor.cardStroke : .clear))
        return Button { selectedID = badge.id } label: {
            VStack(spacing: AppSpacing.xxs) {
                MedalView(icon: badge.icon, earned: earned, size: 74)
                Text(badge.name).font(AppFont.rounded(19, weight: .heavy))
                    .foregroundStyle(earned ? AppColor.ink : AppColor.muted)
                if let date {
                    Text("✨ \(date.formatted(.dateTime.month().day()))")
                        .font(AppFont.rounded(13, weight: .bold))
                        .foregroundStyle(AppColor.jadeEdge)
                } else {
                    Text("\(progress.value)/\(progress.target)")
                        .font(AppFont.digits(13, weight: .heavy))
                        .foregroundStyle(close ? AppColor.adventure : AppColor.muted)
                    MiniBar(value: Double(progress.value), total: Double(max(1, progress.target)), tint: close ? AppColor.adventure : AppColor.jade)
                        .padding(.horizontal, AppSpacing.sm)
                }
            }
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 168)
            .appInset(radius: AppRadius.lg, tint: tint)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .strokeBorder(borderColor, lineWidth: selected ? 3.5 : 1.5)
            )
            .overlay(alignment: .top) {
                if close {
                    Text("还差 \(progress.target - progress.value)！")
                        .font(AppFont.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 3)
                        .background(Capsule().fill(AppColor.adventure))
                        .offset(y: -10)
                }
            }
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// 默认显示最近得到的徽章；一个都没有时显示最快能得到的
    private func defaultSelection(level: Int) -> BadgeKind? {
        let badges = growth.catalog.badges
        if let recent = badges.filter({ growth.state.badges[$0.id] != nil })
            .max(by: { growth.state.badges[$0.id]! < growth.state.badges[$1.id]! }) {
            return recent
        }
        return nextGoal(level: level)
    }

    /// 还没得到、进度最高的那枚
    private func nextGoal(level: Int) -> BadgeKind? {
        growth.catalog.badges
            .filter { growth.state.badges[$0.id] == nil }
            .max { fraction($0, level: level) < fraction($1, level: level) }
    }

    // MARK: 右侧详情

    private func detail(level: Int, badges: [BadgeKind]) -> some View {
        let badge = selectedID.flatMap { id in badges.first { $0.id == id } } ?? defaultSelection(level: level)
        let locked = badges.filter { growth.state.badges[$0.id] == nil }
        let close = locked.filter { fraction($0, level: level) >= 0.6 }
        return VStack(spacing: AppSpacing.sm) {
            if let badge {
                let date = growth.state.badges[badge.id]
                MedalView(icon: badge.icon, earned: date != nil, size: 120)
                Text(badge.name).font(AppFont.rounded(32, weight: .heavy)).foregroundStyle(AppColor.ink)
                Text(badge.summary).font(AppFont.bodyStrong).foregroundStyle(AppColor.muted)
                    .multilineTextAlignment(.center)
                if let date {
                    HintCapsule(icon: "📅", text: "\(date.formatted(.dateTime.month().day())) 得到 · 奖励 \(badge.coins) 积分已到账",
                                tint: AppColor.jadeEdge)
                } else {
                    let p = badge.progress(stats: growth.state.stats, level: level)
                    HintCapsule(icon: "💪", text: "现在 \(p.value)/\(p.target)，得到后奖励 \(badge.coins) 积分",
                                tint: AppColor.violetEdge)
                }
            }
            HStack(spacing: 10) {
                count("已得到", badges.count - locked.count, AppColor.jadeEdge)
                count("快完成", close.count, AppColor.adventure)
                count("继续加油", locked.count - close.count, AppColor.muted)
            }
            if let goal = nextGoal(level: level) {
                let p = goal.progress(stats: growth.state.stats, level: level)
                VStack(alignment: .leading, spacing: 6) {
                    Text("🎯 下一个目标：\(goal.icon) \(goal.name)")
                        .font(AppFont.body)
                        .foregroundStyle(AppColor.ink)
                    MiniBar(value: Double(p.value), total: Double(max(1, p.target)), tint: AppColor.violet)
                    Text("\(p.value)/\(p.target)")
                        .font(AppFont.digits(14, weight: .bold))
                        .foregroundStyle(AppColor.violetEdge)
                }
                .padding(AppSpacing.sm)
                .appInset(radius: AppRadius.md, tint: AppColor.violet)
            }
            Spacer(minLength: 0)
            AppButton(title: "去闯关，拿下一枚", systemImage: "play.fill", role: .primary, size: .large, expands: true, action: onClose)
        }
        .padding(20)
        .frame(maxHeight: .infinity)
        .appPanel(radius: AppRadius.lg)
    }

    private func count(_ title: String, _ value: Int, _ tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(title).font(AppFont.rounded(13, weight: .bold))
            Text("\(value)").font(AppFont.digits(28, weight: .heavy))
        }
        .foregroundStyle(tint)
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xs)
        .appInset(radius: AppRadius.sm, tint: tint)
    }
}
