import LearnCore
import SwiftUI

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
            VStack(spacing: 18) {
                topBar(level: growth.level.level)
                slotTabs
                if showingTools {
                    DoomShroomUnlockView(profileID: profileID, onClose: { showingTools = false }, embedded: true, wideLayout: wide)
                        .environmentObject(model)
                } else if wide {
                    HStack(alignment: .top, spacing: 20) {
                        ScrollView { sidebar.padding(6) }
                            .frame(width: 190)
                        wardrobe
                        fittingRoom.padding(6)
                            .frame(width: 320)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 22) {
                            sidebar
                            fittingRoom
                            wardrobe
                        }
                        .padding(6)
                    }
                }
            }
            .padding(geometry.size.width < 600 ? 14 : 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(GrowthPageBackground())
        .onAppear {
            // 优先准备少量购买反馈，避免排在整套题库语音之后。
            for line in SpeechText.purchaseLines { model.speechLibrary.requestSoon(line) }
        }
        .accessibilityHidden(confirming != nil || equippedNotice != nil)
        .overlay {
            if let item = equippedNotice { equipmentSuccessDialog(item) }
            else if let item = confirming { confirmDialog(item) }
        }
        .alert("操作未完成", isPresented: Binding(get: { storageError != nil }, set: { if !$0 { storageError = nil } })) {
            Button("知道了") { storageError = nil }
        } message: { Text(storageError ?? "") }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(slot == .defenderSkin ? "选择小伙伴" : "当前分类")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.muted)
            if slot == .defenderSkin {
                shooterTabs
            } else if slot == .enemySkin {
                ForEach(["全部", "经典怪物", "森林怪物"], id: \.self) { group in
                    Button {
                        monsterGroup = group
                        previewID = nil
                    } label: {
                        Text(group)
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundStyle(monsterGroup == group ? .white : Theme.ink)
                            .padding(18).frame(maxWidth: .infinity, alignment: .leading)
                            .background(CandyTileBackground(selected: monsterGroup == group))
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityAddTraits(monsterGroup == group ? .isSelected : [])
                }
                Text("已解锁并购买的怪物会在经典模式中随机展示，只换外观，不改变能力或关卡难度。")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.muted)
            } else {
                Label(slot.displayName, systemImage: "sparkles")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(CandyTileBackground(selected: true))
                Text(slot == .enemySkin ? "装扮统一应用于怪物" : "挑选喜欢的外观，先试看再装备")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.muted)
            }
        }
    }

    private var wardrobe: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(slot == .defenderSkin ? shooterKind.name : slot.displayName)
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 8)
                Text("共 \(items.count) 件")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(GrowthColors.orangeDark)
            }
            cards(level: growth.level.level)
            Text(slot == .enemySkin ? "购买即加入怪物队伍，无需装备" : "橙色边框表示试看，绿色标记表示已装备")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.muted)
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
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("试穿小舞台")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                Spacer()
                Label(equipped ? "已装备" : ownedMonster ? "自动展示" : "仅试看",
                      systemImage: equipped || ownedMonster ? "checkmark.circle.fill" : "eye")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(equipped || ownedMonster ? GrowthColors.jadeDark : GrowthColors.orangeDark)
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .background(Capsule().fill((equipped || ownedMonster ? Theme.jade : GrowthColors.gold).opacity(0.16)))
            }
            stage
            if let item {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(item.name)
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1).minimumScaleFactor(0.85)
                        Spacer(minLength: 4)
                        Text(item.rarity.displayName)
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundStyle(GrowthColors.rarity(item.rarity))
                    }
                    Text(item.summary)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(3)
                        .accessibilityLabel(item.summary)
                }
                if slot == .defenderSkin {
                    Label("当前装备：\(equippedShooterName)", systemImage: "checkmark.seal.fill")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(GrowthColors.jadeDark)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.jade.opacity(0.12)))
                }
                unlockRequirements(item)
                cardAction(item, status: growth.state.status(of: item, level: growth.level.level), level: growth.level.level)
            }
            Text(slot == .enemySkin ? "拥有即参与随机展示 · 不改变能力" : "点卡片只试看 · 装备后下局生效")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.muted)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 26).fill(GrowthColors.surface)
            .shadow(color: GrowthColors.cardEdge, radius: 0, x: 0, y: 5))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(GrowthColors.gold.opacity(0.65), lineWidth: 3))
    }

    // MARK: 顶部和分类

    private func topBar(level: Int) -> some View {
        GrowthPageHeader(icon: "🎁", title: "收藏馆", subtitle: showingTools ? "永久道具" : "角色装扮", onClose: onClose) {
            LevelPill(level: level)
            CoinPill(coins: growth.state.coins, size: 24)
        }
    }

    private var slotTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(CosmeticSlot.allCases.filter(\.isCollectible)) { s in
                    Button {
                        showingTools = false
                        slot = s
                        previewID = nil
                    } label: {
                        HStack(spacing: 8) {
                            PictureView(emoji: s.icon, size: 24)
                            Text(s.displayName)
                                .font(.system(size: 18, weight: .heavy, design: .rounded))
                        }
                        .foregroundStyle(!showingTools && slot == s ? .white : Theme.ink)
                        .padding(.horizontal, 18)
                        .frame(height: 52)
                        .background(CandyTileBackground(selected: !showingTools && slot == s))
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityAddTraits(!showingTools && slot == s ? .isSelected : [])
                }
                Button {
                    showingTools = true
                    previewID = nil
                } label: {
                    HStack(spacing: 8) {
                        PictureView(emoji: "💥", size: 24)
                        Text("道具解锁").font(.system(size: 18, weight: .heavy, design: .rounded))
                    }
                    .foregroundStyle(showingTools ? .white : Theme.ink)
                    .padding(.horizontal, 18)
                    .frame(height: 52)
                    .background(CandyTileBackground(selected: showingTools))
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
        return VStack(spacing: 14) {
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
                    HStack(spacing: 8) {
                        if let image = UnitSprites.portrait(of: kind, skin: worn) {
                            Image(decorative: image, scale: 1).resizable().scaledToFit().frame(width: 42, height: 42)
                                .opacity(onField ? 1 : 0.5)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(kind.name).font(.system(size: 16, weight: .heavy, design: .rounded))
                            Label(wornName, systemImage: "checkmark.circle.fill")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                            Text(onField ? "✅ 已上场" : (grade?.isPreschool == true ? "🔒 上小学后上场" : "🔒 暂未上场"))
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                        }
                        .lineLimit(1).minimumScaleFactor(0.7)
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(selected ? .white : Theme.ink)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity)
                    .frame(height: 86)
                    .background(CandyTileBackground(selected: selected))
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
            RoundedRectangle(cornerRadius: 26)
                .fill(LinearGradient(colors: [GrowthColors.sky, Color(red: 0.86, green: 0.95, blue: 0.82)],
                                     startPoint: .top, endPoint: .bottom))
                .shadow(color: GrowthColors.cardEdge, radius: 0, x: 0, y: 5)
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                stageContent(item)
                Spacer(minLength: 0)
                Rectangle().fill(Color(red: 0.46, green: 0.72, blue: 0.2)).frame(height: 14)
            }
            .clipShape(RoundedRectangle(cornerRadius: 26))
            Text("👁 战场试穿")
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(Capsule().fill(Color(red: 0.63, green: 0.39, blue: 0.2)))
                .padding(16)
        }
        .frame(height: 158)
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(GrowthColors.gold.opacity(0.7), lineWidth: 4))
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
