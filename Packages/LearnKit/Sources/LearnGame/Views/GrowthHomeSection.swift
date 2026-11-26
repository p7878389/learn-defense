import LearnCore
import SwiftUI

/// 主页顶部的守护者荣誉卡：柔和光晕头像 + 等级牌、名字、光泽经验条、积分、编辑档案。
struct GrowthCard: View {
    let profile: Profile
    let growth: GrowthStore
    let onEdit: () -> Void

    private var avatarTint: Color { AvatarTint.color(for: profile.avatar) }

    var body: some View {
        let level = growth.level
        HStack(spacing: 22) {
            ZStack(alignment: .bottom) {
                Circle()
                    .fill(RadialGradient(colors: [avatarTint.opacity(0.55), avatarTint.opacity(0.1), .clear],
                                         center: .center, startRadius: 24, endRadius: 60))
                    .frame(width: 112, height: 112)
                Circle()
                    .fill(LinearGradient(colors: [.white.opacity(0.55), avatarTint], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(Circle().strokeBorder(.white, lineWidth: 4.5))
                    .overlay(Circle().strokeBorder(AppColor.gold.opacity(0.8), lineWidth: 2))
                    .shadow(color: avatarTint.opacity(0.45), radius: 8, y: 4)
                    .frame(width: 96, height: 96)
                    .overlay(PictureView(emoji: profile.avatar, size: 68))
                    .padding(.bottom, 10)
                LevelBadge(level: level.level, size: 17)
            }
            .frame(width: 112, height: 114)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Text(profile.name)
                        .font(AppFont.rounded(34, weight: .black))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("\(profile.grade.displayName) · \(profile.difficulty.displayName)难度")
                        .font(AppFont.label)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .foregroundStyle(GrowthColors.orangeDark)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(Capsule().fill(AppColor.gold.opacity(0.24)))
                        .overlay(Capsule().strokeBorder(AppColor.gold.opacity(0.45), lineWidth: 1))
                }
                HStack(spacing: 10) {
                    XPBar(progress: level, height: 30)
                    HStack(spacing: 5) {
                        PictureView(emoji: "🎁", size: 24)
                        Text("Lv.\(level.level + 1)")
                            .font(AppFont.digits(14, weight: .black))
                            .foregroundStyle(AppColor.accentEdge)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(AppColor.gold.opacity(0.22)))
                    .overlay(Capsule().strokeBorder(AppColor.gold.opacity(0.45), lineWidth: 1))
                }
                Text(nextLevelHint(level))
                    .font(AppFont.label)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            VStack(alignment: .trailing, spacing: 10) {
                CoinPill(coins: growth.state.coins, size: 22)
                AppButton(title: "编辑档案", systemImage: "pencil", role: .secondary, size: .medium, minWidth: 140, action: onEdit)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
        .candyCard(radius: AppRadius.lg)
    }

    private func nextLevelHint(_ level: LevelProgress) -> String {
        let next = level.level + 1
        let base = "再得 \(level.xpToGo) 经验升到 Lv.\(next)"
        if let item = growth.catalog.cosmetics.first(where: { $0.unlockLevel == next && !$0.isOriginal }) {
            return "\(base)，解锁 \(item.icon) \(item.name)"
        }
        return "\(base)，送 \(growth.catalog.pacing.coins.perLevel) 积分"
    }
}

/// 主页三张模式与成长入口卡：松林青蓝（冒险）/ 琥珀金橙（收藏）/ 星光紫（徽章），保留右下角精致低干扰装饰微景。
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
        let adventureStars = growth.state.adventure.totalStars
        HStack(spacing: 14) {
            if let onAdventure {
                Button(action: onAdventure) {
                    entry(
                        title: "冒险闯关",
                        subtitle: "15 积分一局 · 专心布阵",
                        icon: "🗺️",
                        colors: [AppColor.adventureTop, AppColor.adventureBottom],
                        edge: AppColor.adventureEdge,
                        badge: adventureStars > 0 ? "★ \(adventureStars)/18" : nil,
                        badgeFill: AppColor.goldEdge,
                        watermark: "leaf.fill"
                    )
                }
            }
            Button(action: onCollection) {
                entry(
                    title: "收藏馆",
                    subtitle: "用积分换喜欢的外观",
                    icon: "🎁",
                    colors: [AppColor.gold, AppColor.accentBottom],
                    edge: AppColor.accentEdge,
                    badge: newItems.isEmpty ? nil : "可买 \(newItems.count) 件",
                    badgeFill: Theme.wrong,
                    watermark: "sparkles"
                )
            }
            Button(action: onBadges) {
                entry(
                    title: "徽章墙",
                    subtitle: "已收集 \(earned.count) / \(catalog.badges.count)",
                    icon: "🏅",
                    colors: [AppColor.violetTop, AppColor.violet],
                    edge: AppColor.violetEdge,
                    badge: nil,
                    badgeFill: Theme.wrong,
                    watermark: "rosette"
                )
            }
        }
        .buttonStyle(PressableStyle())
    }

    private func entry(
        title: String,
        subtitle: String,
        icon: String,
        colors: [Color],
        edge: Color,
        badge: String?,
        badgeFill: Color,
        watermark: String
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: AppRadius.lg)
        return ZStack(alignment: .top) {
            shape.fill(edge)
                .shadow(color: edge.opacity(0.24), radius: 10, y: 5)
            ZStack(alignment: .bottomTrailing) {
                // 右下角柔和装饰水印，增强绘本层次感而不抢文字可读性
                Image(systemName: watermark)
                    .font(.system(size: 62, weight: .black))
                    .foregroundStyle(.white.opacity(0.14))
                    .rotationEffect(.degrees(-12))
                    .offset(x: -10, y: 12)
                    .allowsHitTesting(false)

                HStack(spacing: 12) {
                    PictureView(emoji: icon, size: 38)
                        .padding(8)
                        .background(Circle().fill(.white.opacity(0.22)))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(AppFont.heading)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text(subtitle)
                            .font(AppFont.label)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .opacity(0.92)
                    }
                    Spacer(minLength: 0)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
            .clipShape(shape)
            .background(
                shape.fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(
                shape.strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.5), .clear], startPoint: .top, endPoint: .center),
                    lineWidth: 1.5
                )
            )
            .overlay(shape.strokeBorder(edge.opacity(0.85), lineWidth: 1.5))
            .padding(.bottom, 5)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 104)
        .overlay(alignment: .topTrailing) {
            if let badge {
                Text(badge)
                    .font(AppFont.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(badgeFill))
                    .overlay(Capsule().strokeBorder(.white, lineWidth: 2))
                    .shadow(color: badgeFill.opacity(0.3), radius: 4, y: 2)
                    .offset(x: 4, y: -10)
            }
        }
    }
}

/// 主页底部低矮柔和绘本草坪装饰：消除大面积纯色留白，不抢夺主按钮注意力。
struct HomeMeadowStrip: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            Ellipse()
                .fill(GrowthColors.meadow.opacity(0.75))
                .frame(height: 68)
                .scaleEffect(x: 1.35, y: 1)
                .offset(y: 34)
            HStack(alignment: .bottom, spacing: 18) {
                PictureView(emoji: "🌱", size: 22)
                PictureView(emoji: "🌼", size: 18)
                Spacer()
                Text("每天一点小进步，守护书本更轻松")
                    .font(AppFont.caption)
                    .foregroundStyle(AppColor.jadeEdge.opacity(0.72))
                    .padding(.bottom, 2)
                Spacer()
                PictureView(emoji: "🌸", size: 18)
                PictureView(emoji: "🌿", size: 22)
            }
            .padding(.horizontal, 44)
            .padding(.bottom, 8)
        }
        .frame(height: 44)
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
