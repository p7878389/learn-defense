import LearnCore
import SwiftUI

/// 主页顶部的成长卡：头像 + 等级牌、名字、经验条、积分、编辑档案。设计稿 docs/ui-growth/01b
struct GrowthCard: View {
    let profile: Profile
    let growth: GrowthStore
    let onEdit: () -> Void

    var body: some View {
        let level = growth.level
        HStack(spacing: 24) {
            VStack(spacing: -12) {
                PictureView(emoji: profile.avatar, size: 76)
                    .frame(width: 104, height: 104)
                    .background(Circle().fill(Theme.paper))
                    .overlay(Circle().stroke(LinearGradient(colors: [GrowthColors.gold, Theme.accent], startPoint: .top, endPoint: .bottom), lineWidth: 6))
                LevelBadge(level: level.level, size: 20)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Text(profile.name).font(.system(size: 36, weight: .heavy, design: .rounded)).foregroundStyle(Theme.ink)
                    Text("\(profile.grade.displayName) · \(profile.difficulty.displayName)难度")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(GrowthColors.orangeDark)
                        .padding(.horizontal, 12).padding(.vertical, 4)
                        .background(Capsule().fill(GrowthColors.gold.opacity(0.25)))
                }
                HStack(spacing: 10) {
                    XPBar(progress: level, height: 32)
                    PictureView(emoji: "🎁", size: 40)
                }
                Text(nextLevelHint(level))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            VStack(alignment: .trailing, spacing: 14) {
                CoinPill(coins: growth.state.coins)
                Button(action: onEdit) {
                    Label("编辑档案", systemImage: "pencil")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.muted)
                        .padding(.horizontal, 18).frame(height: 46)
                        .background(Capsule().fill(GrowthColors.surface).shadow(color: GrowthColors.cardEdge, radius: 0, x: 0, y: 3))
                        .overlay(Capsule().stroke(GrowthColors.cardEdge, lineWidth: 1.5))
                }
                .buttonStyle(PressableStyle())
            }
        }
        .padding(22)
        .candyCard()
    }

    /// 「再得 70 经验升到 Lv.6，解锁 🎉 彩纸礼花」；下一级没有外观时说送多少积分
    private func nextLevelHint(_ level: LevelProgress) -> String {
        let next = level.level + 1
        let base = "再得 \(level.xpToGo) 经验升到 Lv.\(next)"
        if let item = growth.catalog.cosmetics.first(where: { $0.unlockLevel == next && !$0.isOriginal }) {
            return "\(base)，解锁 \(item.icon) \(item.name)"
        }
        return "\(base)，送 \(growth.catalog.pacing.coins.perLevel) 积分"
    }
}

/// 主页共用的糖果入口；冒险与收藏、徽章共用一行，不额外占用纵向空间。
struct GrowthEntryCards: View {
    let growth: GrowthStore
    let onCollection: () -> Void
    let onBadges: () -> Void
    var onAdventure: (() -> Void)? = nil

    var body: some View {
        let level = growth.level.level
        let catalog = growth.catalog
        let newItems = catalog.cosmetics.filter {
            !$0.isOriginal && $0.unlockLevel <= level && growth.state.status(of: $0, level: level) == .forSale(price: $0.price)
        }
        let earned = catalog.badges.filter { growth.state.badges[$0.id] != nil }
        HStack(spacing: onAdventure == nil ? 20 : 14) {
            if let onAdventure {
                Button(action: onAdventure) {
                    entry(title: "冒险闯关", subtitle: "15 积分一局 · 专心布阵", icon: "🗺️",
                          colors: [Theme.jade, GrowthColors.jadeDark], edge: GrowthColors.jadeDark,
                          badge: nil) { EmptyView() }
                }
            }
            Button(action: onCollection) {
                entry(title: "收藏馆", subtitle: "用积分换喜欢的外观", icon: "🎁",
                      colors: [GrowthColors.gold, Theme.accent], edge: GrowthColors.orangeDark,
                      badge: newItems.isEmpty ? nil : "可以买 \(newItems.count) 件") {
                    HStack(spacing: 4) { ForEach(["⭐", "🌸", "🎉"], id: \.self) { PictureView(emoji: $0, size: 40) } }
                }
            }
            Button(action: onBadges) {
                entry(title: "徽章墙", subtitle: "已收集 \(earned.count) / \(catalog.badges.count)", icon: "🏅",
                      colors: [GrowthColors.purple, Color(red: 0.4, green: 0.42, blue: 0.95)], edge: GrowthColors.purpleDark,
                      badge: nil) {
                    HStack(spacing: -10) {
                        ForEach(earned.suffix(3).map(\.icon), id: \.self) { MedalView(icon: $0, earned: true, size: 46) }
                        if earned.count < catalog.badges.count { MedalView(icon: "❔", earned: false, size: 46) }
                    }
                }
            }
        }
        .buttonStyle(PressableStyle())
    }

    private func entry<Art: View>(title: String, subtitle: String, icon: String, colors: [Color], edge: Color,
                                  badge: String?, @ViewBuilder art: () -> Art) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    PictureView(emoji: icon, size: onAdventure == nil ? 38 : 32)
                    Text(title).font(.system(size: onAdventure == nil ? 32 : 24, weight: .heavy, design: .rounded))
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
                Text(subtitle).font(.system(size: onAdventure == nil ? 18 : 14, weight: .bold, design: .rounded))
                    .lineLimit(1).minimumScaleFactor(0.8).opacity(0.9)
            }
            if onAdventure == nil {
                Spacer(minLength: 8)
                art()
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, onAdventure == nil ? 24 : 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: onAdventure == nil ? 120 : 100)
        .background(
            RoundedRectangle(cornerRadius: 26)
                .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: edge, radius: 0, x: 0, y: 6))
        .overlay(alignment: .topTrailing) {
            if let badge {
                Text(badge)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(Theme.wrong))
                    .overlay(Capsule().stroke(.white, lineWidth: 2))
                    .offset(x: 6, y: -10)
            }
        }
    }
}
