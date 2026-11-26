import LearnCore
import SwiftUI

extension CollectionView {
    func cards(level: Int) -> some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 14)], spacing: 18) {
                ForEach(items, id: \.id) { item in
                    card(item, level: level)
                }
                if slot == .defenderSkin && items.count <= 1 { comingSoonCard }
            }
            .padding(8)
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
        let rarityText: Color = switch item.rarity {
        case .common: Color(red: 0.18, green: 0.38, blue: 0.58)
        case .rare: GrowthColors.purpleDark
        case .legendary: Color(red: 0.48, green: 0.29, blue: 0.04)
        }
        return Button { previewID = item.id } label: {
            VStack(spacing: 8) {
                ZStack(alignment: .top) {
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Spacer(minLength: 0)
                            if equipped {
                                Label("已装备", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6).padding(.vertical, 4)
                                    .background(Capsule().fill(Theme.jade))
                            }
                        }
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
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
                                    .font(.system(size: 30, weight: .bold))
                                    .foregroundStyle(Color(white: 0.48))
                                    .padding(10)
                                    .background(Circle().fill(Color(white: 0.93).opacity(0.92)))
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                    .padding(10)
                }
                .frame(height: 146)
                Text(item.name)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(unownedMonster ? Theme.muted : Theme.ink)
                    .lineLimit(2).frame(minHeight: 42)
                    .padding(.horizontal, 6)
                Text(equipped ? "✓ 当前装备" : selected ? (item.slot == .enemySkin ? "◉ 正在预览" : "◉ 仅试看，尚未装备") : cardStatus(status))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(equipped ? GrowthColors.jadeDark : selected ? GrowthColors.orangeDark : Theme.muted)
                    .padding(.horizontal, 6)
                    .frame(height: 18)
                Text(item.rarity.displayName)
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 4)
                    .background(Capsule().fill(rarityText.opacity(locked ? 0.45 : 0.9)))
                    .overlay(Capsule().strokeBorder(rarityText.opacity(locked ? 0.3 : 0.65), lineWidth: 1))
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 18)
            .padding(.top, 28)
            .padding(.bottom, 34)
            .frame(maxWidth: .infinity)
            .background(CollectionCardFrame(rarity: item.rarity, locked: locked, lightInterior: true)
                .shadow(color: selected && !equipped ? Theme.accent.opacity(0.5) : .clear, radius: 4))
        }
        .contentShape(RoundedRectangle(cornerRadius: 26))
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
            Text("🎨").font(.system(size: 54))
            Text("更多皮肤").font(.system(size: 24, weight: .heavy, design: .rounded)).foregroundStyle(Theme.ink)
            Text("\(shooterKind.name)的新皮肤正在绘制中，敬请期待！")
                .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
            Spacer(minLength: 0)
            CandyButtonLabel(title: "即将推出", fill: GrowthColors.disabledFill, edge: GrowthColors.disabledEdge, foreground: Theme.muted,
                             font: .system(size: 18, weight: .heavy, design: .rounded), height: 46, minWidth: 0)
                .frame(maxWidth: .infinity)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 194)
        .background(RoundedRectangle(cornerRadius: 26).fill(GrowthColors.surface.opacity(0.6)))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(GrowthColors.cardEdge, style: StrokeStyle(lineWidth: 2, dash: [7, 5])))
    }

    private func cornerTag(_ text: String, fill: Color, text color: Color) -> some View {
        Text(text).font(.system(size: 13, weight: .black, design: .rounded)).foregroundStyle(color)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(Capsule().fill(fill))
            .overlay(Capsule().stroke(.white, lineWidth: 2))
            .offset(y: -12)
    }

    @ViewBuilder
    func cardAction(_ item: CosmeticKind, status: GrowthState.CosmeticStatus, level: Int) -> some View {
        let actionFont = Font.system(size: 18, weight: .heavy, design: .rounded)
        let hintFont = Font.system(size: 13, weight: .heavy, design: .rounded)
        switch status {
        case .equipped:
            CandyButtonLabel(title: "已装备 ✓", fill: Theme.jade, edge: GrowthColors.jadeDark,
                             font: actionFont, height: 50, minWidth: 0, expands: true)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("\(item.name)，当前已装备")
        case .owned:
            if item.slot == .enemySkin {
                VStack(spacing: 6) {
                    CandyButtonLabel(title: item.isOriginal ? "默认外观" : "自动展示 ✓", fill: Theme.jade,
                                     edge: GrowthColors.jadeDark, font: actionFont, height: 50, minWidth: 0, expands: true)
                        .frame(maxWidth: .infinity)
                    Text(item.isOriginal ? "没有已购外观时，仅展示默认普通怪物" : "已加入队伍，下局自动随机展示")
                        .font(hintFont).foregroundStyle(Theme.muted)
                }
            } else {
                Button {
                    equipAndConfirm(item)
                } label: {
                    CandyButtonLabel(title: item.isOriginal ? "使用原版" : "装备到\(UnitCatalog.defender(id: item.shooterID)?.name ?? shooterKind.name)",
                                     fill: Theme.jade, edge: GrowthColors.jadeDark, foreground: .white,
                                     font: actionFont, height: 50, minWidth: 0, expands: true)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PressableStyle())
            }
        case let .forSale(price):
            let short = price - growth.state.coins
            if short <= 0 {
                Button {
                    previewID = item.id
                    confirming = item
                } label: {
                    CandyButtonLabel(title: "\(price) 购买", coin: true, fill: Theme.accent, edge: GrowthColors.orangeDark,
                                     font: actionFont, height: 50, minWidth: 0, expands: true)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PressableStyle())
            } else {
                VStack(spacing: 4) {
                    Text("再玩 \(max(1, Int((Double(short) / 40).rounded(.up)))) 局左右就够啦")
                        .font(hintFont).foregroundStyle(Theme.wrong)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    CandyButtonLabel(title: "\(price) 还差 \(short)", coin: true, fill: GrowthColors.disabledFill, edge: GrowthColors.disabledEdge,
                                     foreground: Theme.muted, font: actionFont, height: 50, minWidth: 0, expands: true)
                        .frame(maxWidth: .infinity)
                }
            }
        case .conditionLocked:
            VStack(spacing: 6) {
                Text(item.price > 0 ? "解锁后 \(item.price) 积分购买" : "解锁后免费获得")
                    .font(hintFont).foregroundStyle(Theme.muted)
                CandyButtonLabel(title: "尚未达成条件", fill: GrowthColors.disabledFill, edge: GrowthColors.disabledEdge,
                                 foreground: Theme.muted, font: actionFont, height: 46, minWidth: 0, expands: true)
                    .frame(maxWidth: .infinity)
            }
        case let .locked(unlock):
            VStack(spacing: 6) {
                Text("🔒 Lv.\(unlock) 解锁").font(.system(size: 14, weight: .heavy, design: .rounded)).foregroundStyle(Theme.muted)
                Text("还差 \(unlock - level) 级就能拿到！").font(hintFont).foregroundStyle(Theme.accent)
                    .lineLimit(1).minimumScaleFactor(0.7)
                MiniBar(value: Double(level), total: Double(unlock), tint: Theme.accent)
                CandyButtonLabel(title: "还没解锁", fill: GrowthColors.disabledFill, edge: GrowthColors.disabledEdge, foreground: Theme.muted,
                                 font: actionFont, height: 46, minWidth: 0, expands: true)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    func unlockRequirements(_ item: CosmeticKind) -> some View {
        if let badgeID = item.unlockBadge, let badge = growth.catalog.badge(id: badgeID) {
            let achieved = growth.state.badges[badgeID] != nil
            let progress = badge.progress(stats: growth.state.stats, level: growth.level.level)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(achieved ? "✓" : "🔒") 成就：\(badge.name)")
                Text(badge.summary)
                if !achieved { Text("进度 \(progress.value) / \(progress.target)") }
            }
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(achieved ? GrowthColors.jadeDark : Theme.muted)
        }
        if let stat = item.unlockStat, let count = item.unlockCount {
            let value = min(growth.state.stats[stat], count)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(value >= count ? "✓" : "🔒") \(stat.displayName) \(count)")
                Text("进度 \(value) / \(count)")
                MiniBar(value: Double(value), total: Double(count), tint: Theme.accent)
            }
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(value >= count ? GrowthColors.jadeDark : Theme.muted)
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
                bannerColors: [Theme.jade, GrowthColors.jadeDark],
                bannerEdge: GrowthColors.jadeDark,
                borderColor: Theme.jade.opacity(0.65),
                maxWidth: 420
            ) {
                if let image = portrait(of: item) {
                    Image(decorative: image, scale: 1).resizable().scaledToFit()
                        .frame(width: 100, height: 100)
                }
                Text(item.name)
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Text("已为\(UnitCatalog.defender(id: item.shooterID)?.name ?? shooterKind.name)换上这款皮肤，下一局生效。")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                Button { equippedNotice = nil } label: {
                    CandyButtonLabel(title: "知道了", fill: Theme.jade, edge: GrowthColors.jadeDark,
                                     height: 50, minWidth: 0, expands: true)
                }
                .buttonStyle(PressableStyle())
            }
            .padding(24)
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
                bannerColors: [GrowthColors.gold, Theme.accent],
                bannerEdge: GrowthColors.orangeDark,
                maxWidth: 520
            ) {
                Group {
                    if let image = portrait(of: item) {
                        Image(decorative: image, scale: 1).resizable().scaledToFit().padding(16)
                    } else {
                        PictureView(emoji: item.icon, size: 100)
                    }
                }
                .frame(width: 150, height: 150)
                .background(Circle().fill(GrowthColors.rarity(item.rarity).opacity(0.15)))
                Text(item.name).font(.system(size: 36, weight: .heavy, design: .rounded)).foregroundStyle(Theme.ink)
                Text("\(item.summary) · \(item.rarity.displayName)").font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.muted)
                HStack(spacing: 14) {
                    Text("要用").foregroundStyle(Theme.muted)
                    CoinIcon(size: 26)
                    Text("\(item.price)").foregroundStyle(GrowthColors.orangeDark)
                    Text("→").foregroundStyle(Theme.muted.opacity(0.5))
                    Text("还剩").foregroundStyle(Theme.muted)
                    CoinIcon(size: 26)
                    Text("\(coins - item.price)").foregroundStyle(GrowthColors.jadeDark)
                }
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .padding(.horizontal, 24).padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 18).fill(GrowthColors.surface))
                HStack(spacing: 16) {
                    Button { confirming = nil } label: {
                        CandyButtonLabel(title: "再想想", fill: GrowthColors.surface, edge: GrowthColors.cardEdge, foreground: Theme.ink,
                                         expands: true)
                    }
                    Button {
                        // 怪物购买即进入外观池；射手沿用原有买后装备逻辑。
                        do {
                            if try model.purchase(item, for: profileID) == .bought {
                                if item.slot != .enemySkin { equipAndConfirm(item) }
                                model.speech.speakPurchase(item)
                            }
                        } catch { storageError = error.localizedDescription }
                        confirming = nil
                    } label: {
                        CandyButtonLabel(title: "买！", fill: Theme.accent, edge: GrowthColors.orangeDark, expands: true)
                    }
                }
                .buttonStyle(PressableStyle())
                Text(item.slot == .enemySkin ? "购买后自动加入怪物队伍，无需装备" : "买了以后可以随时换回原版")
                    .font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(Theme.muted)
            }
            .padding(24)
        }
    }
}
