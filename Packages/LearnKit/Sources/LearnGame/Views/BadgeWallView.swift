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
        VStack(spacing: 18) {
            topBar(level: level, earned: earned.count, total: badges.count)
            HStack(alignment: .top, spacing: 20) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 4), spacing: 14) {
                    ForEach(badges, id: \.id) { tile($0, level: level) }
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .candyCard()
                detail(level: level, badges: badges)
                    .frame(width: 340)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(GrowthPageBackground())
    }

    private func topBar(level: Int, earned: Int, total: Int) -> some View {
        GrowthPageHeader(icon: "🏅", title: "我的徽章墙", onClose: onClose) {
            LevelPill(level: level)
            VStack(alignment: .leading, spacing: 6) {
                Text("已收集 \(earned) / \(total)").font(.system(size: 18, weight: .heavy, design: .rounded)).foregroundStyle(GrowthColors.orangeDark)
                MiniBar(value: Double(earned), total: Double(max(1, total)), tint: GrowthColors.gold).frame(width: 150)
            }
            .padding(.horizontal, 16).frame(height: 52)
            .background(RoundedRectangle(cornerRadius: 18).fill(GrowthColors.gold.opacity(0.15)))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(GrowthColors.cardEdge, lineWidth: 2))
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
        return VStack(spacing: 4) {
            MedalView(icon: badge.icon, earned: earned, size: 74)
            Text(badge.name).font(.system(size: 19, weight: .heavy, design: .rounded))
                .foregroundStyle(earned ? Theme.ink : Theme.muted)
            if let date {
                Text("✨ \(date.formatted(.dateTime.month().day()))")
                    .font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(GrowthColors.jadeDark)
            } else {
                Text("\(progress.value)/\(progress.target)")
                    .font(.system(size: 13, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(close ? Theme.accent : Theme.muted)
                MiniBar(value: Double(progress.value), total: Double(max(1, progress.target)), tint: close ? Theme.accent : Theme.jade)
                    .padding(.horizontal, 14)
            }
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 168)
        .background(RoundedRectangle(cornerRadius: 22).fill(earned || close ? GrowthColors.surface : Theme.muted.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 22)
            .stroke(selected ? Theme.accent : (close ? GrowthColors.gold : (earned ? GrowthColors.cardEdge : .clear)), lineWidth: selected ? 4 : 2))
        .overlay(alignment: .top) {
            if close {
                Text("还差 \(progress.target - progress.value)！")
                    .font(.system(size: 12, weight: .black, design: .rounded)).foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 3)
                    .background(Capsule().fill(Theme.accent))
                    .offset(y: -10)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { selectedID = badge.id }
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
        return VStack(spacing: 14) {
            if let badge {
                let date = growth.state.badges[badge.id]
                MedalView(icon: badge.icon, earned: date != nil, size: 120)
                Text(badge.name).font(.system(size: 32, weight: .heavy, design: .rounded)).foregroundStyle(Theme.ink)
                Text(badge.summary).font(.system(size: 18, weight: .bold, design: .rounded)).foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                if let date {
                    HintCapsule(icon: "📅", text: "\(date.formatted(.dateTime.month().day())) 得到 · 奖励 \(badge.coins) 积分已到账",
                                tint: GrowthColors.jadeDark)
                } else {
                    let p = badge.progress(stats: growth.state.stats, level: level)
                    HintCapsule(icon: "💪", text: "现在 \(p.value)/\(p.target)，得到后奖励 \(badge.coins) 积分")
                }
            }
            HStack(spacing: 10) {
                count("已得到", badges.count - locked.count, Theme.jade)
                count("快完成", close.count, Theme.accent)
                count("继续加油", locked.count - close.count, Theme.muted)
            }
            if let goal = nextGoal(level: level) {
                let p = goal.progress(stats: growth.state.stats, level: level)
                VStack(alignment: .leading, spacing: 6) {
                    Text("🎯 下一个目标：\(goal.icon) \(goal.name)").font(.system(size: 16, weight: .heavy, design: .rounded))
                    MiniBar(value: Double(p.value), total: Double(max(1, p.target)), tint: Theme.accent)
                    Text("\(p.value)/\(p.target)").font(.system(size: 14, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(Theme.accent)
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 18).fill(GrowthColors.gold.opacity(0.15)))
            }
            Spacer(minLength: 0)
            Button(action: onClose) {
                CandyButtonLabel(title: "去闯关，拿下一枚", icon: "▶", fill: Theme.jade, edge: GrowthColors.jadeDark)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PressableStyle())
        }
        .padding(20)
        .frame(maxHeight: .infinity)
        .candyCard()
    }

    private func count(_ title: String, _ value: Int, _ tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.system(size: 13, weight: .bold, design: .rounded))
            Text("\(value)").font(.system(size: 28, weight: .heavy, design: .rounded))
        }
        .foregroundStyle(tint)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 16).fill(tint.opacity(0.1)))
    }
}
