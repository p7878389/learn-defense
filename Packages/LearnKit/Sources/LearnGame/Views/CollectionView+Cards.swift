import LearnCore
import SwiftUI

private enum CardLocalArt {
    /// 普通品质卡底下的深海蓝徽章底色，保证白字高对比度
    static let commonRarityBadge = Color(red: 0.18, green: 0.38, blue: 0.58)
    /// 传说品质卡底下的古铜褐徽章底色，衬托金色传说质感
    static let legendaryRarityBadge = Color(red: 0.48, green: 0.29, blue: 0.04)
    /// 购买确认弹框中的积分消耗数字深褐金色
    static let coinText = Color(red: 0.52, green: 0.36, blue: 0.04)
}

extension CollectionView {
    func cards(level: Int) -> some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 14)], spacing: 18) {
                ForEach(items, id: \.id) { item in
                    card(item, level: level)
                }
                if slot == .defenderSkin && items.count <= 1 { comingSoonCard }
            }
            .padding(AppSpacing.xs)
        }
        .frame(minHeight: 240)
        .id(slot == .defenderSkin ? "\(slot.rawValue)-\(shooter)" : slot.rawValue)
    }

    private func card(_ item: CosmeticKind, level: Int) -> some View {
        let status = growth.state.status(of: item, level: level)
        let locked: Bool = switch status { case .locked, .conditionLocked: true; default: false }
        let selected = previewItem?.id == item.id
        let equipped = status == .equipped
        let unownedMonster = item.slot == .enemySkin && !growth.state.owns(item, level: level)
        let mutedArtwork = locked || unownedMonster
        let rarityBadgeColor: Color = switch item.rarity {
        case .common: CardLocalArt.commonRarityBadge
        case .rare: AppColor.violetEdge
        case .legendary: CardLocalArt.legendaryRarityBadge
        }
        return Button { previewID = item.id } label: {
            VStack(spacing: AppSpacing.xs) {
                ZStack(alignment: .top) {
                    VStack(spacing: AppSpacing.xxs) {
                        HStack(spacing: AppSpacing.xxs) {
                            Spacer(minLength: 0)
                            if equipped {
                                Label("已装备", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6).padding(.vertical, AppSpacing.xxs)
                                    .background(Capsule().fill(AppColor.jade))
                            }
                        }
                        .font(AppFont.rounded(11, weight: .heavy))
                        .frame(height: 22)
                        ZStack {
                            if let image = portrait(of: item) {
                                Image(decorative: image, scale: 1).resizable().scaledToFit()
                                    .frame(maxWidth: .infinity).frame(height: 100)
                            } else {
                                PictureView(emoji: item.icon, size: 72)
                                    .frame(height: 100)
                            }
                        }
                        .grayscale(mutedArtwork ? 1 : 0)
                        .opacity(locked ? 0.35 : unownedMonster ? 0.65 : 1)
                        .shadow(color: .black.opacity(0.12), radius: 3, x: 0, y: 4)
                        .overlay {
                            if locked && item.slot == .enemySkin {
                                Image(systemName: "lock.fill")
                                    .font(AppFont.rounded(30, weight: .bold))
                                    .foregroundStyle(AppColor.disabledText)
                                    .padding(10)
                                    .background(Circle().fill(AppColor.surface.opacity(0.92)))
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                    .padding(10)
                }
                .frame(height: 146)
                Text(item.name)
                    .font(AppFont.rounded(17, weight: .heavy))
                    .foregroundStyle(unownedMonster ? AppColor.muted : AppColor.ink)
                    .lineLimit(2).frame(minHeight: 42)
                    .padding(.horizontal, 6)
                Text(equipped ? "✓ 当前装备" : selected ? (item.slot == .enemySkin ? "◉ 正在预览" : "◉ 仅试看，尚未装备") : cardStatus(status))
                    .font(AppFont.caption)
                    .foregroundStyle(equipped ? AppColor.jadeEdge : selected ? AppColor.adventure : AppColor.muted)
                    .padding(.horizontal, 6)
                    .frame(height: 18)
                Text(item.rarity.displayName)
                    .font(AppFont.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, AppSpacing.xxs)
                    .background(Capsule().fill(rarityBadgeColor.opacity(locked ? 0.45 : 0.9)))
                    .overlay(Capsule().strokeBorder(rarityBadgeColor.opacity(locked ? 0.3 : 0.65), lineWidth: 1))
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 18)
            .padding(.top, 28)
            .padding(.bottom, 34)
            .frame(maxWidth: .infinity)
            .background(CollectionCardFrame(rarity: item.rarity, locked: locked, lightInterior: true)
                .shadow(color: selected && !equipped ? AppColor.adventure.opacity(0.5) : .clear, radius: 5))
        }
        .contentShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .buttonStyle(PressableStyle())
        .accessibilityLabel("\(item.name)，\(item.rarity.displayName)，\(cardStatus(status))，点击预览")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func cardStatus(_ status: GrowthState.CosmeticStatus) -> String {
        switch status {
        case .equipped: "已装备"
        case .owned: ""
        case let .forSale(price): "\(price) 积分"
        case let .locked(level): "Lv.\(level) 解锁"
        case .conditionLocked: "达成条件后可购买"
        }
    }

    /// 角色皮肤卡直接画出穿上后的样子；其他外观用图标
    func portrait(of item: CosmeticKind) -> CGImage? {
        switch item.slot {
        case .defenderSkin: UnitCatalog.defender(id: item.shooterID).flatMap { UnitSprites.portrait(of: $0, skin: item.characterSkin) }
        case .enemySkin: UnitSprites.portrait(of: item.enemyAppearance.flatMap { UnitCatalog.enemy(id: $0) } ?? .blob, skin: item.characterSkin)
        case .projectile, .defeat, .itemSkin: nil
        }
    }

    private var comingSoonCard: some View {
        VStack(spacing: 10) {
            Spacer(minLength: 0)
            Text("🎨").font(AppFont.rounded(54))
            Text("更多皮肤").font(AppFont.rounded(24, weight: .heavy)).foregroundStyle(AppColor.ink)
            Text("\(shooterKind.name)的新皮肤正在绘制中，敬请期待！")
                .font(AppFont.label).foregroundStyle(AppColor.muted)
                .multilineTextAlignment(.center)
            Spacer(minLength: 0)
            Text("即将推出")
                .font(AppFont.bodyStrong)
                .foregroundStyle(AppColor.disabledText)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .appInset(radius: AppRadius.sm, tint: AppColor.disabledFill)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 194)
        .appInset(radius: AppRadius.lg)
        .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(AppColor.cardEdge, style: StrokeStyle(lineWidth: 2, dash: [7, 5])))
    }

    @ViewBuilder
    func cardAction(_ item: CosmeticKind, status: GrowthState.CosmeticStatus, level: Int) -> some View {
        switch status {
        case .equipped:
            statusBanner(title: "已装备 ✓", tint: AppColor.jade, textColor: AppColor.jadeEdge)
                .accessibilityLabel("\(item.name)，当前已装备")
        case .owned:
            if item.slot == .enemySkin {
                VStack(spacing: 6) {
                    statusBanner(title: item.isOriginal ? "默认外观" : "自动展示 ✓", tint: AppColor.jade, textColor: AppColor.jadeEdge)
                    Text(item.isOriginal ? "没有已购外观时，仅展示默认普通怪物" : "已加入队伍，下局自动随机展示")
                        .font(AppFont.rounded(13, weight: .heavy)).foregroundStyle(AppColor.muted)
                }
            } else {
                AppButton(
                    title: item.isOriginal ? "使用原版" : "装备到\(UnitCatalog.defender(id: item.shooterID)?.name ?? shooterKind.name)",
                    role: .primary,
                    size: .large,
                    expands: true
                ) {
                    equipAndConfirm(item)
                }
            }
        case let .forSale(price):
            let short = price - growth.state.coins
            if short <= 0 {
                AppButton(
                    title: "\(price) 购买",
                    coin: true,
                    role: .adventure,
                    size: .large,
                    expands: true
                ) {
                    previewID = item.id
                    confirming = item
                }
            } else {
                VStack(spacing: AppSpacing.xxs) {
                    Text("再玩 \(max(1, Int((Double(short) / 40).rounded(.up)))) 局左右就够啦")
                        .font(AppFont.rounded(13, weight: .heavy)).foregroundStyle(AppColor.dangerText)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    HStack(spacing: 6) {
                        CoinIcon(size: 20)
                        Text("\(price) 还差 \(short)")
                    }
                    .font(AppFont.bodyStrong)
                    .foregroundStyle(AppColor.disabledText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .appInset(radius: AppRadius.sm, tint: AppColor.disabledFill)
                }
            }
        case .conditionLocked:
            VStack(spacing: 6) {
                Text(item.price > 0 ? "解锁后 \(item.price) 积分购买" : "解锁后免费获得")
                    .font(AppFont.rounded(13, weight: .heavy)).foregroundStyle(AppColor.muted)
                statusBanner(title: "尚未达成条件", tint: AppColor.disabledFill, textColor: AppColor.disabledText)
            }
        case let .locked(unlock):
            VStack(spacing: 6) {
                Text("🔒 Lv.\(unlock) 解锁").font(AppFont.label).foregroundStyle(AppColor.muted)
                Text("还差 \(unlock - level) 级就能拿到！").font(AppFont.rounded(13, weight: .heavy)).foregroundStyle(AppColor.adventure)
                    .lineLimit(1).minimumScaleFactor(0.7)
                MiniBar(value: Double(level), total: Double(unlock), tint: AppColor.adventure)
                statusBanner(title: "还没解锁", tint: AppColor.disabledFill, textColor: AppColor.disabledText)
            }
        }
    }

    private func statusBanner(title: String, tint: Color, textColor: Color) -> some View {
        Text(title)
            .font(AppFont.bodyStrong)
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .appInset(radius: AppRadius.sm, tint: tint)
    }

    @ViewBuilder
    func unlockRequirements(_ item: CosmeticKind) -> some View {
        if let badgeID = item.unlockBadge, let badge = growth.catalog.badge(id: badgeID) {
            let achieved = growth.state.badges[badgeID] != nil
            let progress = badge.progress(stats: growth.state.stats, level: growth.level.level)
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text("\(achieved ? "✓" : "🔒") 成就：\(badge.name)")
                Text(badge.summary)
                if !achieved { Text("进度 \(progress.value) / \(progress.target)") }
            }
            .font(AppFont.rounded(13, weight: .bold))
            .foregroundStyle(achieved ? AppColor.jadeEdge : AppColor.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.xs)
            .appInset(radius: AppRadius.sm, tint: achieved ? AppColor.jade : nil)
        }
        if let stat = item.unlockStat, let count = item.unlockCount {
            let value = min(growth.state.stats[stat], count)
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text("\(value >= count ? "✓" : "🔒") \(stat.displayName) \(count)")
                Text("进度 \(value) / \(count)")
                MiniBar(value: Double(value), total: Double(count), tint: value >= count ? AppColor.jade : AppColor.adventure)
            }
            .font(AppFont.rounded(13, weight: .bold))
            .foregroundStyle(value >= count ? AppColor.jadeEdge : AppColor.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.xs)
            .appInset(radius: AppRadius.sm, tint: value >= count ? AppColor.jade : nil)
        }
    }

    /// 以实际装备结果为准，失败时不显示成功提示。
    private func equipAndConfirm(_ item: CosmeticKind) {
        do { try model.equip(item, for: profileID) }
        catch { storageError = error.localizedDescription; return }
        guard growth.state.status(of: item, level: growth.level.level) == .equipped else { return }
        previewID = item.id
        equippedNotice = item
    }

    func equipmentSuccessDialog(_ item: CosmeticKind) -> some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
                .onTapGesture { equippedNotice = nil }
            CandyModalCard(
                bannerTitle: "装备成功",
                bannerIcon: "✨",
                bannerColors: [AppColor.jadeTop, AppColor.jadeBottom],
                bannerEdge: AppColor.jadeEdge,
                borderColor: AppColor.jade.opacity(0.65),
                maxWidth: 420
            ) {
                if let image = portrait(of: item) {
                    Image(decorative: image, scale: 1).resizable().scaledToFit()
                        .frame(width: 100, height: 100)
                }
                Text(item.name)
                    .font(AppFont.rounded(24, weight: .heavy))
                    .foregroundStyle(AppColor.ink)
                Text("已为\(UnitCatalog.defender(id: item.shooterID)?.name ?? shooterKind.name)换上这款皮肤，下一局生效。")
                    .font(AppFont.rounded(16, weight: .medium))
                    .foregroundStyle(AppColor.muted)
                    .multilineTextAlignment(.center)
                AppButton(title: "知道了", role: .primary, size: .large, expands: true) {
                    equippedNotice = nil
                }
            }
            .padding(AppSpacing.lg)
        }
    }

    // MARK: 购买确认

    func confirmDialog(_ item: CosmeticKind) -> some View {
        let coins = growth.state.coins
        return ZStack {
            Color.black.opacity(0.45).ignoresSafeArea().onTapGesture { confirming = nil }
            CandyModalCard(
                bannerTitle: "要买下来吗？",
                bannerIcon: "🛒",
                bannerColors: [AppColor.adventureTop, AppColor.adventureBottom],
                bannerEdge: AppColor.adventureEdge,
                borderColor: AppColor.adventure.opacity(0.55),
                maxWidth: 520
            ) {
                Group {
                    if let image = portrait(of: item) {
                        Image(decorative: image, scale: 1).resizable().scaledToFit().padding(AppSpacing.md)
                    } else {
                        PictureView(emoji: item.icon, size: 100)
                    }
                }
                .frame(width: 150, height: 150)
                .background(Circle().fill(rarityColor(item.rarity).opacity(0.15)))
                Text(item.name).font(AppFont.display).foregroundStyle(AppColor.ink)
                Text("\(item.summary) · \(item.rarity.displayName)").font(AppFont.bodyStrong)
                    .foregroundStyle(AppColor.muted)
                HStack(spacing: 14) {
                    Text("要用").foregroundStyle(AppColor.muted)
                    CoinIcon(size: 26)
                    Text("\(item.price)").foregroundStyle(CardLocalArt.coinText)
                    Text("→").foregroundStyle(AppColor.muted.opacity(0.5))
                    Text("还剩").foregroundStyle(AppColor.muted)
                    CoinIcon(size: 26)
                    Text("\(coins - item.price)").foregroundStyle(AppColor.jadeEdge)
                }
                .font(AppFont.digits(24, weight: .heavy))
                .padding(.horizontal, AppSpacing.lg).padding(.vertical, AppSpacing.sm)
                .appInset(radius: AppRadius.md)
                HStack(spacing: AppSpacing.md) {
                    AppButton(title: "再想想", role: .secondary, size: .large, expands: true) {
                        confirming = nil
                    }
                    AppButton(title: "买！", role: .primary, size: .large, expands: true) {
                        // 怪物购买即进入外观池；射手沿用原有买后装备逻辑。
                        do {
                            if try model.purchase(item, for: profileID) == .bought {
                                if item.slot != .enemySkin { equipAndConfirm(item) }
                                model.speech.speakPurchase(item)
                            }
                        } catch { storageError = error.localizedDescription }
                        confirming = nil
                    }
                }
                Text(item.slot == .enemySkin ? "购买后自动加入怪物队伍，无需装备" : "买了以后可以随时换回原版")
                    .font(AppFont.rounded(15, weight: .bold)).foregroundStyle(AppColor.muted)
            }
            .padding(AppSpacing.lg)
        }
    }
}
