import LearnCore
import SwiftUI

private enum LocalArt {
    /// 试穿小舞台底部的战场草坪专色
    static let stageGrass = Color(red: 0.46, green: 0.72, blue: 0.2)
}

/// 收藏馆：按类别看外观，用积分买、装备、换回原版。设计稿 docs/ui-growth/03、03b~03e
struct CollectionView: View {
    @EnvironmentObject var model: AppModel
    let profileID: UUID
    let onClose: () -> Void

    @State var slot: CosmeticSlot = .defenderSkin
    /// 射手皮肤按射手分开装备，这里是正在看的射手
    @State var shooter: String = DefenderKind.inkling.id
    /// 点过的卡片，在预览舞台上试看
    @State var previewID: String?
    @State private var monsterGroup = "全部"
    @State var confirming: CosmeticKind?
    @State var equippedNotice: CosmeticKind?
    @State private var showingTools = false
    @State private var showCoinLedger = false
    @State var storageError: String?

    var growth: GrowthStore { model.growth(for: profileID) }

    var shooterKind: DefenderKind { UnitCatalog.defender(id: shooter) ?? .inkling }

    /// 当前分类下的外观；射手皮肤只列正在看的射手
    var items: [CosmeticKind] {
        if slot == .defenderSkin {
            let skins = growth.catalog.shooterSkins(for: shooter)
            guard let equipped = skins.first(where: { growth.state.status(of: $0, level: growth.level.level) == .equipped }) else { return skins }
            return [equipped] + skins.filter { $0.id != equipped.id }
        }
        let candidates = growth.catalog.cosmetics(in: slot)
        guard slot == .enemySkin, monsterGroup != "全部" else { return candidates }
        let forestIDs = Set(UnitCatalog.forestEnemies.map(\.id))
        return candidates.filter { item in
            guard let appearance = item.enemyAppearance else { return true }
            return forestIDs.contains(appearance) == (monsterGroup == "森林怪物")
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let wide = geometry.size.width >= 900 && geometry.size.height >= 650
            VStack(spacing: AppSpacing.md) {
                topBar(level: growth.level.level)
                slotTabs
                if showingTools {
                    DoomShroomUnlockView(profileID: profileID, onClose: { showingTools = false }, embedded: true, wideLayout: wide)
                        .environmentObject(model)
                } else if wide {
                    HStack(alignment: .top, spacing: AppSpacing.md) {
                        ScrollView { sidebar.padding(6) }
                            .frame(width: 190)
                        wardrobe
                        fittingRoom.padding(6)
                            .frame(width: 320)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: AppSpacing.lg) {
                            sidebar
                            fittingRoom
                            wardrobe
                        }
                        .padding(6)
                    }
                }
            }
            .padding(geometry.size.width < 600 ? AppSpacing.sm : AppSpacing.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(GrowthPageBackground())
        .growthCover(isPresented: $showCoinLedger) {
            CoinLedgerView(profileID: profileID, onClose: { showCoinLedger = false })
                .environmentObject(model)
        }
        .onAppear {
            // 优先准备少量购买反馈，避免排在整套题库语音之后。
            for line in SpeechText.purchaseLines { model.speechLibrary.requestSoon(line) }
        }
        .accessibilityHidden(confirming != nil || equippedNotice != nil || storageError != nil)
        .overlay {
            if let message = storageError {
                CandyConfirmModal(
                    title: "操作未完成",
                    icon: "⚠️",
                    message: message,
                    buttons: [CandyConfirmButton(title: "知道了", role: .primary) { storageError = nil }],
                    onDismiss: { storageError = nil }
                )
            } else if let item = equippedNotice { equipmentSuccessDialog(item) }
            else if let item = confirming { confirmDialog(item) }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(slot == .defenderSkin ? "选择小伙伴" : "当前分类")
                .font(AppFont.label)
                .foregroundStyle(AppColor.muted)
            if slot == .defenderSkin {
                shooterTabs
            } else if slot == .enemySkin {
                ForEach(["全部", "经典怪物", "森林怪物"], id: \.self) { group in
                    Button {
                        monsterGroup = group
                        previewID = nil
                    } label: {
                        Text(group)
                            .font(AppFont.bodyStrong)
                            .foregroundStyle(monsterGroup == group ? .white : AppColor.ink)
                            .padding(AppSpacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(CandyTileBackground(selected: monsterGroup == group, selectedFill: AppColor.adventure, selectedEdge: AppColor.adventureEdge))
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityAddTraits(monsterGroup == group ? .isSelected : [])
                }
                Text("已解锁并购买的怪物会在经典模式中随机展示，只换外观，不改变能力或关卡难度。")
                    .font(AppFont.rounded(14, weight: .medium))
                    .foregroundStyle(AppColor.muted)
            } else {
                Label(slot.displayName, systemImage: "sparkles")
                    .font(AppFont.bodyStrong)
                    .foregroundStyle(AppColor.ink)
                    .padding(AppSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .appInset(radius: AppRadius.md, tint: AppColor.adventure)
                Text(slot == .enemySkin ? "装扮统一应用于怪物" : "挑选喜欢的外观，先试看再装备")
                    .font(AppFont.rounded(14, weight: .medium))
                    .foregroundStyle(AppColor.muted)
            }
        }
    }

    private var wardrobe: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text(slot == .defenderSkin ? shooterKind.name : slot.displayName)
                    .font(AppFont.rounded(24, weight: .heavy))
                    .foregroundStyle(AppColor.ink)
                Spacer(minLength: AppSpacing.xs)
                Text("共 \(items.count) 件")
                    .font(AppFont.rounded(13, weight: .bold))
                    .foregroundStyle(AppColor.muted)
            }
            cards(level: growth.level.level)
            Text(slot == .enemySkin ? "购买即加入怪物队伍，无需装备" : "青色边框表示试看，绿色标记表示已装备")
                .font(AppFont.rounded(12, weight: .medium))
                .foregroundStyle(AppColor.muted)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    /// 显示实际生效的配置，而不是当前试看的皮肤。
    private var equippedShooterName: String {
        let skin = growth.loadout.defenderSkins[shooter]
        return growth.catalog.shooterSkins(for: shooter).first { $0.characterSkin == skin }?.name ?? "原版"
    }

    private var fittingRoom: some View {
        let item = previewItem
        let equipped = item.map { growth.state.status(of: $0, level: growth.level.level) == .equipped } ?? false
        let ownedMonster = slot == .enemySkin && item.map { growth.state.owns($0, level: growth.level.level) } == true
        let activeBadge = equipped || ownedMonster
        return VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                Text("试穿小舞台")
                    .font(AppFont.rounded(17, weight: .heavy))
                    .foregroundStyle(AppColor.ink)
                Spacer()
                Label(equipped ? "已装备" : ownedMonster ? "自动展示" : "仅试看",
                      systemImage: activeBadge ? "checkmark.circle.fill" : "eye")
                    .font(AppFont.caption)
                    .foregroundStyle(activeBadge ? AppColor.jadeEdge : AppColor.adventure)
                    .padding(.horizontal, AppSpacing.xs)
                    .padding(.vertical, AppSpacing.xxs)
                    .background(Capsule().fill((activeBadge ? AppColor.jade : AppColor.adventure).opacity(0.14)))
            }
            stage
            if let item {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(item.name)
                            .font(AppFont.heading)
                            .foregroundStyle(AppColor.ink)
                            .lineLimit(1).minimumScaleFactor(0.85)
                        Spacer(minLength: AppSpacing.xxs)
                        Text(item.rarity.displayName)
                            .font(AppFont.caption)
                            .foregroundStyle(rarityColor(item.rarity))
                    }
                    Text(item.summary)
                        .font(AppFont.rounded(13, weight: .medium))
                        .foregroundStyle(AppColor.muted)
                        .lineLimit(3)
                        .accessibilityLabel(item.summary)
                }
                if slot == .defenderSkin {
                    Label("当前装备：\(equippedShooterName)", systemImage: "checkmark.seal.fill")
                        .font(AppFont.rounded(13, weight: .bold))
                        .foregroundStyle(AppColor.jadeEdge)
                        .padding(AppSpacing.xs)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .appInset(radius: AppRadius.sm, tint: AppColor.jade)
                }
                unlockRequirements(item)
                cardAction(item, status: growth.state.status(of: item, level: growth.level.level), level: growth.level.level)
            }
            Text(slot == .enemySkin ? "拥有即参与随机展示 · 不改变能力" : "点卡片只试看 · 装备后下局生效")
                .font(AppFont.rounded(12, weight: .medium))
                .foregroundStyle(AppColor.muted)
        }
        .padding(AppSpacing.sm)
        .appPanel(radius: AppRadius.lg)
    }

    func rarityColor(_ rarity: CosmeticRarity) -> Color {
        switch rarity {
        case .common: AppColor.rarityCommon
        case .rare: AppColor.rarityRare
        case .legendary: AppColor.rarityLegendary
        }
    }

    // MARK: 顶部和分类

    private func topBar(level: Int) -> some View {
        GrowthPageHeader(icon: "🎁", title: "收藏馆", subtitle: showingTools ? "永久道具" : "角色装扮", onClose: onClose) {
            LevelPill(level: level)
            Button { showCoinLedger = true } label: {
                CoinPill(coins: growth.state.coins, size: 24)
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("查看积分记录，当前 \(growth.state.coins) 积分")
        }
    }

    private var slotTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                ForEach(CosmeticSlot.allCases.filter(\.isCollectible)) { s in
                    let isSelected = !showingTools && slot == s
                    Button {
                        showingTools = false
                        slot = s
                        previewID = nil
                    } label: {
                        HStack(spacing: AppSpacing.xs) {
                            PictureView(emoji: s.icon, size: 24)
                            Text(s.displayName)
                                .font(AppFont.bodyStrong)
                        }
                        .foregroundStyle(isSelected ? .white : AppColor.ink)
                        .padding(.horizontal, AppSpacing.md)
                        .frame(height: 52)
                        .background(CandyTileBackground(selected: isSelected, selectedFill: AppColor.adventure, selectedEdge: AppColor.adventureEdge))
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
                Button {
                    showingTools = true
                    previewID = nil
                } label: {
                    HStack(spacing: AppSpacing.xs) {
                        PictureView(emoji: "💥", size: 24)
                        Text("道具解锁").font(AppFont.bodyStrong)
                    }
                    .foregroundStyle(showingTools ? .white : AppColor.ink)
                    .padding(.horizontal, AppSpacing.md)
                    .frame(height: 52)
                    .background(CandyTileBackground(selected: showingTools, selectedFill: AppColor.adventure, selectedEdge: AppColor.adventureEdge))
                }
                .buttonStyle(PressableStyle())
                .accessibilityAddTraits(showingTools ? .isSelected : [])
            }
            .padding(6)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: 射手分类

    /// 每种射手一格：现在穿着哪套、这个年级能不能上场
    private var shooterTabs: some View {
        let loadout = growth.loadout
        let grade = model.profiles.first { $0.id == profileID }?.grade
        let playable = grade.map { Set(GameTuning.defenders(for: $0).map(\.id)) }
        return VStack(spacing: AppSpacing.sm) {
            // 只列会射击的植物；坚果墙、土豆雷这类防御植物没有射手皮肤
            ForEach(UnitCatalog.defenders.filter(\.canShoot), id: \.id) { kind in
                let selected = shooter == kind.id
                let worn = loadout.defenderSkins[kind.id]
                let wornName = worn.flatMap { skin in
                    growth.catalog.shooterSkins(for: kind.id).first { $0.characterSkin == skin }?.name
                } ?? "原版"
                let onField = playable?.contains(kind.id) ?? true
                Button {
                    shooter = kind.id
                    previewID = nil
                } label: {
                    HStack(spacing: AppSpacing.xs) {
                        if let image = UnitSprites.portrait(of: kind, skin: worn) {
                            Image(decorative: image, scale: 1).resizable().scaledToFit().frame(width: 42, height: 42)
                                .opacity(onField ? 1 : 0.5)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(kind.name).font(AppFont.rounded(16, weight: .heavy))
                            Label(wornName, systemImage: "checkmark.circle.fill")
                                .font(AppFont.caption)
                            Text(onField ? "✅ 已上场" : (grade?.isPreschool == true ? "🔒 上小学后上场" : "🔒 暂未上场"))
                                .font(AppFont.rounded(11, weight: .heavy))
                        }
                        .lineLimit(1).minimumScaleFactor(0.7)
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(selected ? .white : AppColor.ink)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity)
                    .frame(height: 86)
                    .background(CandyTileBackground(selected: selected, selectedFill: AppColor.adventure, selectedEdge: AppColor.adventureEdge))
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("\(kind.name)，穿着\(wornName)，\(onField ? "已上场" : "暂未上场")")
            }
        }
    }

    // MARK: 预览舞台

    var previewItem: CosmeticKind? {
        let items = items
        if let previewID, let item = items.first(where: { $0.id == previewID }) { return item }
        return items.first { growth.state.isEquipped($0) && !$0.isOriginal } ?? items.first
    }

    private var stage: some View {
        let item = previewItem
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: AppRadius.md)
                .fill(LinearGradient(colors: [AppColor.sky, AppColor.meadow],
                                     startPoint: .top, endPoint: .bottom))
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                stageContent(item)
                Spacer(minLength: 0)
                Rectangle().fill(LocalArt.stageGrass).frame(height: 14)
            }
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            Text("👁 战场试穿")
                .font(AppFont.label)
                .foregroundStyle(.white)
                .padding(.horizontal, AppSpacing.sm).padding(.vertical, 6)
                .background(Capsule().fill(AppColor.woodTop.opacity(0.92)))
                .padding(AppSpacing.sm)
        }
        .frame(height: 158)
        .overlay(RoundedRectangle(cornerRadius: AppRadius.md).strokeBorder(AppColor.cardStroke, lineWidth: 1.5))
    }

    @ViewBuilder
    private func stageContent(_ item: CosmeticKind?) -> some View {
        switch slot {
        case .defenderSkin, .enemySkin:
            CharacterSkinPreview(kind: shooterKind, skin: item?.characterSkin, enemy: slot == .enemySkin,
                                 enemyAppearance: item?.enemyAppearance, compact: true)
                .padding(.top, 26)
        case .projectile, .defeat, .itemSkin:
            EmptyView() // 退役槽位仅保留旧数据兼容，不再提供换装入口。

        }
    }

    // MARK: 卡片
}
