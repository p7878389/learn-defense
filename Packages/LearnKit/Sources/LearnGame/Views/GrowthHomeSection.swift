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

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack(spacing: AppSpacing.sm) {
                    Text(profile.name)
                        .font(AppFont.rounded(34, weight: .black))
                        .foregroundStyle(AppColor.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("\(profile.grade.displayName) · \(profile.difficulty.displayName)难度")
                        .font(AppFont.label)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .foregroundStyle(AppColor.accentEdge)
                        .padding(.horizontal, AppSpacing.sm).padding(.vertical, 5)
                        .background(Capsule().fill(AppColor.gold.opacity(0.24)))
                        .overlay(Capsule().strokeBorder(AppColor.gold.opacity(0.45), lineWidth: 1))
                }
                HStack(spacing: AppSpacing.sm) {
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
                    .foregroundStyle(AppColor.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            VStack(alignment: .trailing, spacing: AppSpacing.sm) {
                CoinPill(coins: growth.state.coins, size: 22)
                AppButton(title: "编辑档案", systemImage: "pencil", role: .secondary, size: .medium, minWidth: 140, action: onEdit)
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.md)
        .appPanel(radius: AppRadius.lg)
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

/// 主页三张模式与成长入口卡：浅色立体卡片配合语义柔边（松林青蓝冒险 / 琥珀橙收藏 / 星光紫徽章），支持横竖排切换。
struct GrowthEntryCards: View {
    let growth: GrowthStore
    let onCollection: () -> Void
    let onBadges: () -> Void
    var onAdventure: (() -> Void)? = nil
    var axis: Axis = .horizontal

    var body: some View {
        let level = growth.level.level
        let catalog = growth.catalog
        let newItems = catalog.cosmetics.filter {
            !$0.isOriginal && $0.unlockLevel <= level && growth.state.status(of: $0, level: level) == .forSale(price: $0.price)
        }
        let earned = catalog.badges.filter { growth.state.badges[$0.id] != nil }
        let adventureStars = growth.state.adventure.totalStars
        let layout = axis == .horizontal
            ? AnyLayout(HStackLayout(spacing: AppSpacing.sm))
            : AnyLayout(VStackLayout(spacing: AppSpacing.sm))

        layout {
            if let onAdventure {
                Button(action: onAdventure) {
                    entry(
                        title: "冒险闯关",
                        subtitle: "15 积分一局 · 专心布阵",
                        icon: "🗺️",
                        tint: AppColor.adventure,
                        edge: AppColor.adventureSoftEdge,
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
                    tint: AppColor.accent,
                    edge: AppColor.accentSoftEdge,
                    badge: newItems.isEmpty ? nil : "可买 \(newItems.count) 件",
                    badgeFill: AppColor.dangerText,
                    watermark: "sparkles"
                )
            }
            Button(action: onBadges) {
                entry(
                    title: "徽章墙",
                    subtitle: "已收集 \(earned.count) / \(catalog.badges.count)",
                    icon: "🏅",
                    tint: AppColor.violet,
                    edge: AppColor.violetSoftEdge,
                    badge: nil,
                    badgeFill: AppColor.dangerText,
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
        tint: Color,
        edge: Color,
        badge: String?,
        badgeFill: Color,
        watermark: String
    ) -> some View {
        ZStack(alignment: .bottomTrailing) {
            Image(systemName: watermark)
                .font(AppFont.rounded(54, weight: .black))
                .foregroundStyle(tint.opacity(0.10))
                .rotationEffect(.degrees(-12))
                .offset(x: -18, y: 12)
                .allowsHitTesting(false)

            HStack(spacing: AppSpacing.sm) {
                PictureView(emoji: icon, size: 32)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(tint.opacity(0.16)))
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(title)
                        .font(AppFont.heading)
                        .foregroundStyle(AppColor.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(subtitle)
                        .font(AppFont.label)
                        .foregroundStyle(AppColor.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: AppSpacing.xs)
                Image(systemName: "chevron.right")
                    .font(AppFont.bodyStrong)
                    .foregroundStyle(tint)
            }
            .padding(.horizontal, AppSpacing.md)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .frame(height: axis == .vertical ? 92 : 104)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .candyCard(fill: AppColor.surface, edge: edge, radius: AppRadius.lg)
        .overlay(alignment: .topTrailing) {
            if let badge {
                Text(badge)
                    .font(AppFont.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(badgeFill))
                    .overlay(Capsule().strokeBorder(.white, lineWidth: 2))
                    .appShadow(.raised)
                    .offset(x: -10, y: -9)
            }
        }
    }
}

/// 主页底部多层草丘地景：左守卫豌豆、右举牌瞌睡僵尸、花草与标语，仅作氛围衬托不拦截交互。
struct HomeMeadowStrip: View {
    var height: CGFloat = 96

    private var isTall: Bool { height >= 150 }

    var body: some View {
        ZStack(alignment: .bottom) {
            // 远景草丘
            MeadowHillShape(leftRatio: 0.72, crestRatio: 0.88, rightRatio: 0.54, crestX: 0.28)
                .fill(
                    LinearGradient(
                        colors: [AppColor.meadow.opacity(0.82), AppColor.jadeLight.opacity(0.32)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            // 中景草丘
            MeadowHillShape(leftRatio: 0.44, crestRatio: 0.78, rightRatio: 0.68, crestX: 0.74)
                .fill(
                    LinearGradient(
                        colors: [AppColor.meadow, AppColor.jadeLight.opacity(0.50)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            // 前景草坪
            MeadowHillShape(leftRatio: 0.34, crestRatio: 0.56, rightRatio: 0.40, crestX: 0.50)
                .fill(
                    LinearGradient(
                        colors: [AppColor.meadow, AppColor.jadeLight.opacity(0.68)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            HStack(alignment: .bottom, spacing: AppSpacing.md) {
                HStack(alignment: .bottom, spacing: AppSpacing.sm) {
                    sprite("plant-inkling", size: isTall ? 92 : 58)
                    PictureView(emoji: "🌱", size: isTall ? 28 : 20)
                    PictureView(emoji: "🌼", size: isTall ? 24 : 18)
                }

                Spacer(minLength: AppSpacing.sm)

                VStack(spacing: isTall ? AppSpacing.xs : 2) {
                    HStack(spacing: AppSpacing.lg) {
                        PictureView(emoji: "🌸", size: isTall ? 26 : 18)
                        PictureView(emoji: "🌼", size: isTall ? 24 : 16)
                        PictureView(emoji: "🌿", size: isTall ? 26 : 18)
                    }
                    Text("每天一点小进步，守护书本更轻松")
                        .font(AppFont.caption)
                        .foregroundStyle(AppColor.jadeEdge.opacity(0.82))
                }
                .padding(.bottom, isTall ? AppSpacing.md : AppSpacing.xs)

                Spacer(minLength: AppSpacing.sm)

                HStack(alignment: .bottom, spacing: AppSpacing.sm) {
                    PictureView(emoji: "🌸", size: isTall ? 24 : 18)
                    VStack(spacing: 2) {
                        Text("字 zì")
                            .font(AppFont.rounded(isTall ? 14 : 12, weight: .black))
                            .foregroundStyle(AppColor.woodEdge)
                            .padding(.horizontal, AppSpacing.xs)
                            .padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 6).fill(AppColor.tileFill))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppColor.woodEdge, lineWidth: 2))
                            .rotationEffect(.degrees(-6))
                        sprite("zombie-drowsy", size: isTall ? 102 : 62)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.bottom, isTall ? AppSpacing.sm : AppSpacing.xxs)
        }
        .frame(height: height)
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func sprite(_ name: String, size: CGFloat) -> some View {
        if let texture = UnitSprites.frames(named: name).first {
            Image(decorative: texture.cgImage(), scale: 1)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        }
    }
}

private struct MeadowHillShape: Shape {
    let leftRatio: CGFloat
    let crestRatio: CGFloat
    let rightRatio: CGFloat
    let crestX: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let leftY = rect.height * (1 - leftRatio)
        let crestY = rect.height * (1 - crestRatio)
        let rightY = rect.height * (1 - rightRatio)
        p.move(to: CGPoint(x: 0, y: rect.height))
        p.addLine(to: CGPoint(x: 0, y: leftY))
        p.addQuadCurve(
            to: CGPoint(x: rect.width * crestX, y: crestY),
            control: CGPoint(x: rect.width * crestX * 0.5, y: min(leftY, crestY) - rect.height * 0.08)
        )
        p.addQuadCurve(
            to: CGPoint(x: rect.width, y: rightY),
            control: CGPoint(x: rect.width * (crestX + (1 - crestX) * 0.5), y: min(crestY, rightY) - rect.height * 0.08)
        )
        p.addLine(to: CGPoint(x: rect.width, y: rect.height))
        p.closeSubpath()
        return p
    }
}
