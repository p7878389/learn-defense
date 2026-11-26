import LearnCore
import SwiftUI

private enum LocalArt {
    /// 道具预览舞台底部专用草地条装饰色
    static let stageGrass = Color(red: 0.46, green: 0.72, blue: 0.2)
}

struct DoomShroomUnlockView: View {
    @EnvironmentObject private var model: AppModel
    let profileID: UUID
    let onClose: () -> Void
    var embedded = false
    var wideLayout: Bool? = nil
    @State private var selected = false
    @State private var confirming = false
    @State private var error: String?

    private var growth: GrowthStore { model.growth(for: profileID) }
    private var owned: Bool { growth.state.ownsDoomShroom }
    private var locked: Bool { !owned && growth.level.level < AdventureDoom.unlockLevel }
    private var status: String {
        owned ? "已永久解锁" : locked ? "Lv.3 解锁" : "300 积分"
    }

    var body: some View {
        GeometryReader { geometry in
            let wide = wideLayout ?? (geometry.size.width >= 900 && geometry.size.height >= 650)
            VStack(spacing: AppSpacing.md) {
                if !embedded {
                    GrowthPageHeader(icon: "💥", title: "道具解锁", subtitle: "永久道具", onClose: onClose) {
                        CoinPill(coins: growth.state.coins, size: 22)
                    }
                }
                if wide {
                    HStack(alignment: .top, spacing: AppSpacing.md) {
                        ScrollView { sidebar.padding(AppSpacing.xxs) }.frame(width: 190)
                        wardrobe(wide: true)
                        details.padding(AppSpacing.xxs).frame(width: 320)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: AppSpacing.lg) {
                            sidebar
                            details
                            wardrobe(wide: false)
                        }
                        .padding(AppSpacing.xxs)
                    }
                }
            }
            .padding(embedded ? 0 : geometry.size.width < 600 ? AppSpacing.sm : AppSpacing.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(GrowthPageBackground())
        .overlay {
            if confirming { confirmOverlay }
            else if let message = error {
                CandyConfirmModal(
                    title: "解锁未完成",
                    icon: "⚠️",
                    message: message,
                    buttons: [CandyConfirmButton(title: "知道了", role: .primary) { error = nil }],
                    onDismiss: { error = nil }
                )
            }
        }
    }

    private var confirmOverlay: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea().onTapGesture { confirming = false }
            CandyModalCard(
                bannerTitle: "要买下来吗？",
                bannerIcon: "🛒",
                bannerColors: [AppColor.gold, AppColor.accent],
                bannerEdge: AppColor.accentEdge,
                maxWidth: 500
            ) {
                portrait(height: 110)
                    .frame(width: 140, height: 140)
                    .background(Circle().fill(AppColor.rarityLegendary.opacity(0.15)))
                Text("毁灭菇")
                    .font(AppFont.rounded(34, weight: .heavy))
                    .foregroundStyle(AppColor.ink)
                Text("永久解锁 · 经典与冒险模式通用")
                    .font(AppFont.bodyStrong)
                    .foregroundStyle(AppColor.muted)
                HStack(spacing: AppSpacing.sm) {
                    Text("要用").foregroundStyle(AppColor.muted)
                    CoinIcon(size: 24)
                    Text("\(AdventureDoom.unlockPrice)").foregroundStyle(AppColor.goldEdge)
                    Text("→").foregroundStyle(AppColor.muted.opacity(0.5))
                    Text("还剩").foregroundStyle(AppColor.muted)
                    CoinIcon(size: 24)
                    Text("\(growth.state.coins - AdventureDoom.unlockPrice)").foregroundStyle(AppColor.jadeEdge)
                }
                .font(AppFont.digits(22, weight: .heavy))
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.xs)
                .appInset(radius: AppRadius.md)
                HStack(spacing: AppSpacing.sm) {
                    AppButton(title: "再想想", role: .secondary, size: .large, expands: true) { confirming = false }
                    AppButton(title: "买！", role: .primary, size: .large, expands: true) { confirming = false; purchase() }
                }
            }
            .padding(AppSpacing.lg)
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("选择道具类别")
                .font(AppFont.label)
                .foregroundStyle(AppColor.muted)
            HStack(spacing: AppSpacing.sm) {
                PictureView(emoji: "💥", size: 34)
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text("种植道具")
                        .font(AppFont.bodyStrong)
                        .foregroundStyle(AppColor.ink)
                    Text("共 1 件")
                        .font(AppFont.caption)
                        .foregroundStyle(AppColor.muted)
                }
                Spacer(minLength: 0)
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
            .appInset(radius: AppRadius.md, tint: AppColor.adventure)
            Text("永久解锁后，经典地图和森林冒险均可选择；每个孩子独立拥有。")
                .font(AppFont.rounded(14, weight: .medium))
                .foregroundStyle(AppColor.muted)
        }
    }

    private func wardrobe(wide: Bool) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text("种植道具")
                    .font(AppFont.rounded(24, weight: .heavy))
                    .foregroundStyle(AppColor.ink)
                Spacer(minLength: AppSpacing.xs)
                Text("共 1 件")
                    .font(AppFont.label)
                    .foregroundStyle(AppColor.muted)
            }
            if wide { ScrollView { grid }.frame(minHeight: 240) }
            else { grid }
            Text("点卡片只预览 · 解锁后所有地图可用")
                .font(AppFont.rounded(12, weight: .medium))
                .foregroundStyle(AppColor.muted)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var grid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: AppSpacing.sm)], spacing: AppSpacing.md) {
            Button { selected = true } label: {
                VStack(spacing: AppSpacing.xs) {
                    VStack(spacing: AppSpacing.xxs) {
                        HStack {
                            Spacer(minLength: 0)
                            if owned {
                                Label("已拥有", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, AppSpacing.xxs)
                                    .background(Capsule().fill(AppColor.jade))
                            }
                        }
                        .font(AppFont.rounded(11, weight: .heavy))
                        .frame(height: 22)
                        portrait(height: 100)
                            .grayscale(locked ? 1 : 0)
                            .opacity(locked ? 0.35 : 1)
                            .shadow(color: .black.opacity(0.12), radius: 3, x: 0, y: 4)
                    }
                    .padding(AppSpacing.sm)
                    .frame(height: 146)
                    Text("毁灭菇")
                        .font(AppFont.rounded(17, weight: .heavy))
                        .foregroundStyle(AppColor.ink)
                        .frame(minHeight: 42)
                        .padding(.horizontal, 6)
                    Text(selected && !owned ? "◉ 正在预览" : status)
                        .font(AppFont.caption)
                        .foregroundStyle(owned ? AppColor.jadeEdge : selected ? AppColor.goldEdge : AppColor.muted)
                        .frame(height: 18)
                    Text("传说")
                        .font(AppFont.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, AppSpacing.xxs)
                        .background(Capsule().fill(AppColor.woodBottom.opacity(locked ? 0.45 : 0.9)))
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.lg)
                .padding(.bottom, AppSpacing.xl)
                .frame(maxWidth: .infinity)
                .background(
                    CollectionCardFrame(rarity: .legendary, locked: locked, lightInterior: true)
                        .shadow(color: selected ? AppColor.gold.opacity(0.5) : .clear, radius: 4)
                )
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("毁灭菇，传说，\(status)，点击预览")
            .accessibilityAddTraits(selected ? .isSelected : [])
        }
        .padding(AppSpacing.xs)
    }

    private func portrait(height: CGFloat) -> some View {
        Group {
            if let image = UnitSprites.portrait(of: AdventureCatalog.doomShroom, skin: nil) {
                Image(decorative: image, scale: 1).resizable().scaledToFit()
            }
        }
        .frame(maxWidth: .infinity).frame(height: height)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text("道具预览")
                    .font(AppFont.rounded(17, weight: .heavy))
                    .foregroundStyle(AppColor.ink)
                Spacer()
                Label(owned ? "已拥有" : "仅试看", systemImage: owned ? "checkmark.circle.fill" : "eye")
                    .font(AppFont.caption)
                    .foregroundStyle(owned ? AppColor.jadeEdge : AppColor.goldEdge)
                    .padding(.horizontal, AppSpacing.xs)
                    .padding(.vertical, 5)
                    .background(Capsule().fill((owned ? AppColor.jade : AppColor.gold).opacity(0.16)))
            }
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .fill(LinearGradient(colors: [AppColor.sky, AppColor.meadow], startPoint: .top, endPoint: .bottom))
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    portrait(height: 90).padding(.top, AppSpacing.lg)
                    Spacer(minLength: 0)
                    Rectangle().fill(LocalArt.stageGrass).frame(height: 14)
                }.clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                Text("👁 道具预览")
                    .font(AppFont.rounded(17, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.xs)
                    .background(Capsule().fill(AppColor.woodTop))
                    .padding(AppSpacing.md)
            }
            .frame(height: 158)
            .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).strokeBorder(AppColor.cardStroke, lineWidth: 1.5))
            HStack {
                Text("毁灭菇")
                    .font(AppFont.heading)
                    .foregroundStyle(AppColor.ink)
                Spacer()
                Text("传说")
                    .font(AppFont.caption)
                    .foregroundStyle(AppColor.rarityLegendary)
            }
            Text("一次性范围爆破，原格留下焦坑。125 阳光 · 1 秒蓄力 · 50 秒冷却 · 180 秒禁种。")
                .font(AppFont.rounded(13, weight: .medium))
                .foregroundStyle(AppColor.muted)
            unlockAction
            Text("一次购买，永久拥有 · 经典地图和森林冒险均可使用")
                .font(AppFont.rounded(12, weight: .medium))
                .foregroundStyle(AppColor.muted)
        }
        .padding(AppSpacing.sm)
        .appPanel(radius: AppRadius.lg)
    }

    @ViewBuilder private var unlockAction: some View {
        if owned {
            Label("已永久解锁", systemImage: "checkmark.circle.fill")
                .font(AppFont.bodyStrong)
                .foregroundStyle(AppColor.jadeEdge)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .appInset(radius: AppRadius.sm, tint: AppColor.jade)
        } else if locked {
            Label("Lv.3 解锁 · 还差 \(AdventureDoom.unlockLevel - growth.level.level) 级", systemImage: "lock.fill")
                .font(AppFont.label)
                .foregroundStyle(AppColor.muted)
            MiniBar(value: Double(growth.level.level), total: Double(AdventureDoom.unlockLevel), tint: AppColor.adventure)
            Text("还没解锁")
                .font(AppFont.bodyStrong)
                .foregroundStyle(AppColor.disabledText)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .appInset(radius: AppRadius.sm)
        } else if growth.state.coins < AdventureDoom.unlockPrice {
            Text("还差 \(AdventureDoom.unlockPrice - growth.state.coins) 积分")
                .font(AppFont.label)
                .foregroundStyle(AppColor.dangerText)
            HStack(spacing: AppSpacing.xs) {
                CoinIcon(size: 20)
                Text("300 积分")
                    .font(AppFont.bodyStrong)
                    .foregroundStyle(AppColor.disabledText)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .appInset(radius: AppRadius.sm)
        } else {
            AppButton(title: "300 购买", coin: true, role: .primary, size: .large, expands: true) {
                confirming = true
            }
        }
    }

    private func purchase() {
        do {
            switch try model.purchaseDoomShroom(for: profileID) {
            case .bought, .alreadyOwned: break
            case .locked: error = "达到 Lv.3 后即可购买"
            case .notEnough(let short): error = "还差 \(short) 积分"
            case .conditionLocked: error = "尚未满足解锁条件"
            }
        } catch { self.error = error.localizedDescription }
    }
}
