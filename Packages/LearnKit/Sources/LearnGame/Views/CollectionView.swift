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
    @State private var confirming: CosmeticKind?

    private var growth: GrowthStore { model.growth(for: profileID) }

    private var shooterKind: DefenderKind { UnitCatalog.defender(id: shooter) ?? .inkling }

    /// 当前分类下的外观；射手皮肤只列正在看的射手
    private var items: [CosmeticKind] {
        slot == .defenderSkin ? growth.catalog.shooterSkins(for: shooter) : growth.catalog.cosmetics(in: slot)
    }

    var body: some View {
        GeometryReader { geometry in
            let wide = geometry.size.width >= 900
            VStack(spacing: 18) {
                topBar(level: growth.level.level)
                slotTabs
                if wide {
                    HStack(alignment: .top, spacing: 20) {
                        ScrollView { sidebar.padding(6) }
                            .frame(width: 190)
                        wardrobe
                        ScrollView { fittingRoom.padding(6) }
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
        .overlay { if let item = confirming { confirmDialog(item) } }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(slot == .defenderSkin ? "选择小伙伴" : "当前分类")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.muted)
            if slot == .defenderSkin {
                shooterTabs
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
            Text("金边表示试看，绿色标记表示已装备")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var fittingRoom: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("试穿小舞台")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                Spacer()
                Text(previewItem.map { growth.state.isEquipped($0) } == true ? "已装备" : "仅预览")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(GrowthColors.jadeDark)
            }
            stage
            if let item = previewItem {
                Text(item.rarity.displayName)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(GrowthColors.rarity(item.rarity))
                Text(item.name)
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Text(item.summary)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.muted)
                if let skin = item.itemSkin, let base = UnitCatalog.item(id: skin.item) {
                    Text("原来是 \(base.icon) \(base.name)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.muted)
                }
                cardAction(item, status: growth.state.status(of: item, level: growth.level.level), level: growth.level.level)
            }
            Text("只换外观，不改变战力")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.muted)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 26).fill(GrowthColors.surface)
            .shadow(color: GrowthColors.cardEdge, radius: 0, x: 0, y: 5))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(GrowthColors.gold.opacity(0.65), lineWidth: 3))
    }

    // MARK: 顶部和分类

    private func topBar(level: Int) -> some View {
        GrowthPageHeader(icon: "🎁", title: "收藏馆", subtitle: "外观与特效", onClose: onClose) {
            LevelPill(level: level)
            CoinPill(coins: growth.state.coins, size: 24)
        }
    }

    private var slotTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(CosmeticSlot.allCases) { s in
                    Button {
                        slot = s
                        previewID = nil
                    } label: {
                        HStack(spacing: 8) {
                            PictureView(emoji: s.icon, size: 24)
                            Text(s.displayName)
                                .font(.system(size: 18, weight: .heavy, design: .rounded))
                        }
                        .foregroundStyle(slot == s ? .white : Theme.ink)
                        .padding(.horizontal, 18)
                        .frame(height: 52)
                        .background(CandyTileBackground(selected: slot == s))
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityAddTraits(slot == s ? .isSelected : [])
                }
                Text("🔒 命中特效 · 待开放")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.muted)
                    .padding(.horizontal, 16)
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
                            Text("穿着：\(wornName)").font(.system(size: 12, weight: .bold, design: .rounded))
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
        .frame(height: 230)
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(GrowthColors.gold.opacity(0.7), lineWidth: 4))
    }

    @ViewBuilder
    private func stageContent(_ item: CosmeticKind?) -> some View {
        switch slot {
        case .defenderSkin, .enemySkin:
            CharacterSkinPreview(kind: shooterKind, skin: item?.characterSkin, enemy: slot == .enemySkin)
                .padding(.top, 30)
        case .projectile:
            HStack {
                PictureView(emoji: "🌱", size: 42)
                Spacer()
                PictureView(emoji: item?.icon ?? "🟢", size: 46)
                Spacer()
                PictureView(emoji: "🧟", size: 42)
            }
            .padding(.horizontal, 16)
        case .defeat:
            VStack(spacing: 8) {
                ZStack {
                    PictureView(emoji: "🧟", size: 76).opacity(item?.isOriginal == false ? 0.3 : 1)
                    if let item, !item.isOriginal {
                        ForEach(0..<6, id: \.self) { i in
                            PictureView(emoji: item.icon, size: 30)
                                .offset(x: cos(Double(i) * .pi / 3) * 56, y: sin(Double(i) * .pi / 3) * 40)
                        }
                    }
                }
                .frame(width: 200)
                Text(item.map { "僵尸被打败时\n\($0.summary)！" } ?? "")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(GrowthColors.orangeDark)
            }
        case .itemSkin:
            let loadout = growth.loadout
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    ForEach([ItemKind.frostCharm, .heartLeaf, .luckyStar], id: \.id) { base in
                        let shown = loadout.skin(base)
                        VStack(spacing: 2) {
                            PictureView(emoji: shown.icon, size: 34)
                            Text(shown.name).font(.system(size: 14, weight: .heavy, design: .rounded)).foregroundStyle(Theme.ink)
                        }
                        .frame(width: 64, height: 70)
                        .background(RoundedRectangle(cornerRadius: 18).fill(GrowthColors.surface))
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 24).fill(Color(red: 0.48, green: 0.29, blue: 0.13).opacity(0.85)))
                Text("只换样子和名字\n道具效果不变！")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(GrowthColors.orangeDark)
            }
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
        let locked: Bool = if case .locked = status { true } else { false }
        let selected = previewItem?.id == item.id
        return Button { previewID = item.id } label: {
            VStack(spacing: 8) {
                HStack {
                    Text(item.rarity.displayName)
                        .foregroundStyle(GrowthColors.rarity(item.rarity))
                    Spacer(minLength: 0)
                    if status == .equipped {
                        Text("已装备").foregroundStyle(GrowthColors.jadeDark)
                    } else if locked {
                        Text("🔒").foregroundStyle(Theme.muted)
                    }
                }
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                ZStack {
                    Circle().fill(GrowthColors.rarity(item.rarity).opacity(0.12))
                        .frame(width: 86, height: 86)
                    if let image = portrait(of: item) {
                        Image(decorative: image, scale: 1).resizable().scaledToFit()
                            .frame(width: 80, height: 80)
                    } else {
                        PictureView(emoji: item.icon, size: 58)
                    }
                }
                .grayscale(locked ? 1 : 0).opacity(locked ? 0.5 : 1)
                Text(item.name)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2).frame(minHeight: 42)
                Text(selected ? "◉ 正在试看" : cardStatus(status))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(selected ? GrowthColors.orangeDark : Theme.muted)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 194)
            .background(RoundedRectangle(cornerRadius: 24)
                .fill(selected ? GrowthColors.gold.opacity(0.12) : GrowthColors.surface)
                .shadow(color: selected ? GrowthColors.goldDark : GrowthColors.cardEdge, radius: 0, x: 0, y: 5))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(
                selected ? GrowthColors.gold : GrowthColors.cardEdge,
                style: StrokeStyle(lineWidth: selected ? 3 : 2, dash: locked ? [7, 5] : [])))
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("\(item.name)，\(cardStatus(status))，点击预览")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func cardStatus(_ status: GrowthState.CosmeticStatus) -> String {
        switch status {
        case .equipped: "已装备"
        case .owned: "已拥有"
        case let .forSale(price): "\(price) 积分"
        case let .locked(level): "Lv.\(level) 解锁"
        }
    }

    /// 角色皮肤卡直接画出穿上后的样子；其他外观用图标
    private func portrait(of item: CosmeticKind) -> CGImage? {
        switch item.slot {
        case .defenderSkin: UnitCatalog.defender(id: item.shooterID).flatMap { UnitSprites.portrait(of: $0, skin: item.characterSkin) }
        case .enemySkin: UnitSprites.portrait(of: EnemyKind.blob, skin: item.characterSkin)
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
            VStack(spacing: 4) {
                CandyButtonLabel(title: "使用中 ✓", fill: Theme.jade, edge: GrowthColors.jadeDark, font: actionFont, height: 50, minWidth: 0)
                    .frame(maxWidth: .infinity)
                if !item.isOriginal {
                    Button("换回原版") { model.unequip(key: item.equipKey, for: profileID) }
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.muted)
                }
            }
        case .owned:
            Button { model.equip(item, for: profileID) } label: {
                CandyButtonLabel(title: "装备", fill: GrowthColors.surface, edge: GrowthColors.jadeDark, foreground: GrowthColors.jadeDark,
                                 font: actionFont, height: 50, minWidth: 0)
                    .frame(maxWidth: .infinity)
                    .overlay(Capsule().stroke(GrowthColors.jadeDark.opacity(0.6), lineWidth: 2))
            }
            .buttonStyle(PressableStyle())
        case let .forSale(price):
            let short = price - growth.state.coins
            if short <= 0 {
                Button {
                    previewID = item.id
                    confirming = item
                } label: {
                    CandyButtonLabel(title: "\(price) 购买", coin: true, fill: Theme.accent, edge: GrowthColors.orangeDark,
                                     font: actionFont, height: 50, minWidth: 0)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PressableStyle())
            } else {
                VStack(spacing: 4) {
                    Text("再玩 \(max(1, Int((Double(short) / 40).rounded(.up)))) 局左右就够啦")
                        .font(hintFont).foregroundStyle(Theme.wrong)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    CandyButtonLabel(title: "\(price) 还差 \(short)", coin: true, fill: Color(white: 0.88), edge: Color(white: 0.75),
                                     foreground: Theme.muted, font: actionFont, height: 50, minWidth: 0)
                        .frame(maxWidth: .infinity)
                }
            }
        case let .locked(unlock):
            VStack(spacing: 6) {
                Text("🔒 Lv.\(unlock) 解锁").font(.system(size: 14, weight: .heavy, design: .rounded)).foregroundStyle(Theme.muted)
                Text("还差 \(unlock - level) 级就能拿到！").font(hintFont).foregroundStyle(Theme.accent)
                    .lineLimit(1).minimumScaleFactor(0.7)
                MiniBar(value: Double(level), total: Double(unlock), tint: Theme.accent)
                CandyButtonLabel(title: "还没解锁", fill: Color(white: 0.9), edge: Color(white: 0.78), foreground: Theme.muted,
                                 font: actionFont, height: 46, minWidth: 0)
                    .frame(maxWidth: .infinity)
            }
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
                PictureView(emoji: item.icon, size: 100)
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
                        // 买完直接穿上，孩子马上能看到效果；随时可以换回原版
                        if model.purchase(item, for: profileID) == .bought {
                            model.equip(item, for: profileID)
                            model.speech.speak(SpeechText.Line.bought(item.name), interrupt: true)
                        }
                        confirming = nil
                    } label: {
                        CandyButtonLabel(title: "买！", fill: Theme.accent, edge: GrowthColors.orangeDark)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(PressableStyle())
                Text("买了以后可以随时换回原版").font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(Theme.muted)
            }
            .padding(32)
            .frame(width: 520)
            .background(RoundedRectangle(cornerRadius: 36).fill(Theme.paper))
            .overlay(RoundedRectangle(cornerRadius: 36).stroke(GrowthColors.gold, lineWidth: 4))
        }
    }
}
