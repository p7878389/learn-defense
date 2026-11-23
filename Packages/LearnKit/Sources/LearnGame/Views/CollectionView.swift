import LearnCore
import SwiftUI

/// 收藏馆：按类别看外观，用积分买、装备、换回原版。设计稿 docs/ui-growth/03、03b~03e
struct CollectionView: View {
    @EnvironmentObject private var model: AppModel
    let profileID: UUID
    let onClose: () -> Void

    @State private var slot: CosmeticSlot = .defenderSkin
    /// 射手皮肤按射手分开装备，这里是正在看的射手
    @State private var shooter: String = DefenderKind.inkling.id
    /// 点过的卡片，在预览舞台上试看
    @State private var previewID: String?
    @State private var monsterGroup = "全部"
    @State private var confirming: CosmeticKind?
    @State private var equippedNotice: CosmeticKind?
    @State private var showingTools = false

    private var growth: GrowthStore { model.growth(for: profileID) }

    private var shooterKind: DefenderKind { UnitCatalog.defender(id: shooter) ?? .inkling }

    /// 当前分类下的外观；射手皮肤只列正在看的射手
    private var items: [CosmeticKind] {
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

    private var previewItem: CosmeticKind? {
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

    private func cards(level: Int) -> some View {
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
    private func portrait(of item: CosmeticKind) -> CGImage? {
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
            CandyButtonLabel(title: "即将推出", fill: Color(white: 0.9), edge: Color(white: 0.78), foreground: Theme.muted,
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
    private func cardAction(_ item: CosmeticKind, status: GrowthState.CosmeticStatus, level: Int) -> some View {
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
                        .overlay(Capsule().stroke(GrowthColors.jadeDark.opacity(0.6), lineWidth: 2))
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
                    CandyButtonLabel(title: "\(price) 还差 \(short)", coin: true, fill: Color(white: 0.88), edge: Color(white: 0.75),
                                     foreground: Theme.muted, font: actionFont, height: 50, minWidth: 0, expands: true)
                        .frame(maxWidth: .infinity)
                }
            }
        case .conditionLocked:
            VStack(spacing: 6) {
                Text(item.price > 0 ? "解锁后 \(item.price) 积分购买" : "解锁后免费获得")
                    .font(hintFont).foregroundStyle(Theme.muted)
                CandyButtonLabel(title: "尚未达成条件", fill: Color(white: 0.9), edge: Color(white: 0.78),
                                 foreground: Theme.muted, font: actionFont, height: 46, minWidth: 0, expands: true)
                    .frame(maxWidth: .infinity)
            }
        case let .locked(unlock):
            VStack(spacing: 6) {
                Text("🔒 Lv.\(unlock) 解锁").font(.system(size: 14, weight: .heavy, design: .rounded)).foregroundStyle(Theme.muted)
                Text("还差 \(unlock - level) 级就能拿到！").font(hintFont).foregroundStyle(Theme.accent)
                    .lineLimit(1).minimumScaleFactor(0.7)
                MiniBar(value: Double(level), total: Double(unlock), tint: Theme.accent)
                CandyButtonLabel(title: "还没解锁", fill: Color(white: 0.9), edge: Color(white: 0.78), foreground: Theme.muted,
                                 font: actionFont, height: 46, minWidth: 0, expands: true)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private func unlockRequirements(_ item: CosmeticKind) -> some View {
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
        model.equip(item, for: profileID)
        guard growth.state.status(of: item, level: growth.level.level) == .equipped else { return }
        previewID = item.id
        equippedNotice = item
    }

    private func equipmentSuccessDialog(_ item: CosmeticKind) -> some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
                .onTapGesture { equippedNotice = nil }
            VStack(spacing: 16) {
                Label("装备成功", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(GrowthColors.jadeDark)
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
            .frame(maxWidth: 420)
            .background(RoundedRectangle(cornerRadius: 30).fill(Theme.paper))
            .overlay(RoundedRectangle(cornerRadius: 30).stroke(GrowthColors.gold, lineWidth: 3))
            .padding(24)
        }
    }

    // MARK: 购买确认

    private func confirmDialog(_ item: CosmeticKind) -> some View {
        let coins = growth.state.coins
        return ZStack {
            Color.black.opacity(0.45).ignoresSafeArea().onTapGesture { confirming = nil }
            VStack(spacing: 16) {
                Text("要买下来吗？").font(.system(size: 30, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                    .padding(.horizontal, 32).frame(height: 60)
                    .background(Capsule().fill(Theme.accent).shadow(color: GrowthColors.orangeDark, radius: 0, x: 0, y: 5))
                    .padding(.top, -56)
                Group {
                    if let image = portrait(of: item) {
                        Image(decorative: image, scale: 1).resizable().scaledToFit().padding(16)
                    } else {
                        PictureView(emoji: item.icon, size: 100)
                    }
                }
                    .frame(width: 150, height: 150)
                    .background(Circle().fill(GrowthColors.rarity(item.rarity).opacity(0.15)))
                Text(item.name).font(.system(size: 40, weight: .heavy, design: .rounded)).foregroundStyle(Theme.ink)
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
                        CandyButtonLabel(title: "再想想", fill: GrowthColors.surface, edge: GrowthColors.cardEdge, foreground: Theme.ink)
                            .frame(maxWidth: .infinity)
                    }
                    Button {
                        // 怪物购买即进入外观池；射手沿用原有买后装备逻辑。
                        if model.purchase(item, for: profileID) == .bought {
                            if item.slot != .enemySkin { equipAndConfirm(item) }
                            model.speech.speakPurchase(item)
                        }
                        confirming = nil
                    } label: {
                        CandyButtonLabel(title: "买！", fill: Theme.accent, edge: GrowthColors.orangeDark)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(PressableStyle())
                Text(item.slot == .enemySkin ? "购买后自动加入怪物队伍，无需装备" : "买了以后可以随时换回原版").font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(Theme.muted)
            }
            .padding(32)
            .frame(width: 520)
            .background(RoundedRectangle(cornerRadius: 36).fill(Theme.paper))
            .overlay(RoundedRectangle(cornerRadius: 36).stroke(GrowthColors.gold, lineWidth: 4))
        }
    }
}
