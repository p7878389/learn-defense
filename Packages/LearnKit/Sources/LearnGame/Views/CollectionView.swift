import LearnCore
import SwiftUI

/// 收藏馆：按类别看外观，用积分买、装备、换回原版。设计稿 docs/ui-growth/03、03b~03e
struct CollectionView: View {
    @EnvironmentObject private var model: AppModel
    let profileID: UUID
    let onClose: () -> Void

    @State private var slot: CosmeticSlot = .projectile
    /// 点过的卡片，在预览舞台上试看
    @State private var previewID: String?
    @State private var confirming: CosmeticKind?

    private var growth: GrowthStore { model.growth(for: profileID) }

    var body: some View {
        let level = growth.level.level
        VStack(spacing: 18) {
            topBar(level: level)
            HStack(alignment: .top, spacing: 22) {
                slotTabs
                VStack(spacing: 18) {
                    stage
                    cards(level: level)
                    HintCapsule(icon: "💡", text: "积分怎么来？通关、拿星星、升级、得徽章都能拿积分！", tint: GrowthColors.orangeDark)
                }
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(GrowthPageBackground())
        .overlay { if let item = confirming { confirmDialog(item) } }
    }

    // MARK: 顶部和分类

    private func topBar(level: Int) -> some View {
        HStack(spacing: 16) {
            Button(action: onClose) {
                CandyButtonLabel(title: "回主页", icon: "←", fill: GrowthColors.surface, edge: GrowthColors.cardEdge, foreground: Theme.ink,
                                 font: .system(size: 22, weight: .heavy, design: .rounded), height: 56)
            }
            .buttonStyle(PressableStyle())
            Spacer()
            PictureView(emoji: "🎁", size: 44)
            Text("收藏馆").font(.system(size: 40, weight: .heavy, design: .rounded)).foregroundStyle(Theme.ink)
            Spacer()
            LevelPill(level: level)
            CoinPill(coins: growth.state.coins, size: 24)
        }
    }

    private var slotTabs: some View {
        VStack(spacing: 14) {
            ForEach(CosmeticSlot.allCases) { s in
                Button {
                    slot = s
                    previewID = nil
                } label: {
                    HStack(spacing: 10) {
                        PictureView(emoji: s.icon, size: 30)
                        Text(s.displayName).font(.system(size: 22, weight: .heavy, design: .rounded))
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(slot == s ? .white : Theme.ink)
                    .padding(.horizontal, 20)
                    .frame(height: 64)
                    .background(
                        Capsule()
                            .fill(slot == s ? Theme.accent : Theme.paper.opacity(0.72))
                            .shadow(color: slot == s ? GrowthColors.orangeDeep : GrowthColors.cardEdge.opacity(0.55),
                                    radius: 0, x: 0, y: slot == s ? 5 : 2))
                    .overlay(Capsule().stroke(slot == s ? GrowthColors.orangeDeep : GrowthColors.cardEdge,
                                              lineWidth: slot == s ? 0 : 2))
                }
                .buttonStyle(PressableStyle())
            }
            HStack(spacing: 8) {
                Text("🔒")
                Text("命中特效").font(.system(size: 18, weight: .bold, design: .rounded))
                Spacer()
                Text("待开放").font(.system(size: 13, weight: .bold, design: .rounded))
            }
            .foregroundStyle(Theme.muted)
            .padding(.horizontal, 20)
            .frame(height: 54)
            .background(Capsule().fill(Theme.muted.opacity(0.12)))
        }
        .frame(width: 230)
    }

    // MARK: 预览舞台

    private var previewItem: CosmeticKind? {
        let items = growth.catalog.cosmetics(in: slot)
        if let previewID, let item = items.first(where: { $0.id == previewID }) { return item }
        return items.first { growth.state.isEquipped($0) && !$0.isOriginal } ?? items.first
    }

    private var stage: some View {
        let item = previewItem
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 26)
                .fill(LinearGradient(colors: [Color(red: 0.87, green: 0.95, blue: 1), Color(red: 0.86, green: 0.95, blue: 0.82)],
                                     startPoint: .top, endPoint: .bottom))
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                stageContent(item)
                Spacer(minLength: 0)
                Rectangle().fill(Color(red: 0.46, green: 0.72, blue: 0.2)).frame(height: 14)
            }
            .clipShape(RoundedRectangle(cornerRadius: 26))
            Text("👁 战场试穿：\(item?.name ?? "")")
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(Capsule().fill(Color(red: 0.63, green: 0.39, blue: 0.2)))
                .padding(16)
        }
        .frame(height: 190)
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(GrowthColors.gold.opacity(0.7), lineWidth: 4))
    }

    @ViewBuilder
    private func stageContent(_ item: CosmeticKind?) -> some View {
        switch slot {
        case .projectile:
            HStack {
                PictureView(emoji: "🌱", size: 70)
                Spacer()
                PictureView(emoji: item?.icon ?? "🟢", size: 46)
                Spacer()
                PictureView(emoji: "🧟", size: 70)
            }
            .padding(.horizontal, 60)
        case .defeat:
            HStack(spacing: 40) {
                PictureView(emoji: "🌱", size: 60).opacity(0.7)
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
            HStack(spacing: 24) {
                HStack(spacing: 12) {
                    ForEach([ItemKind.frostCharm, .heartLeaf, .luckyStar], id: \.id) { base in
                        let shown = loadout.skin(base)
                        VStack(spacing: 2) {
                            PictureView(emoji: shown.icon, size: 44)
                            Text(shown.name).font(.system(size: 14, weight: .heavy, design: .rounded)).foregroundStyle(Theme.ink)
                        }
                        .frame(width: 90, height: 86)
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
        let items = growth.catalog.cosmetics(in: slot)
        return HStack(alignment: .top, spacing: 14) {
            ForEach(items, id: \.id) { card($0, level: level) }
        }
        .padding(.horizontal, slot == .itemSkin ? 70 : 0)
    }

    private func card(_ item: CosmeticKind, level: Int) -> some View {
        let status = growth.state.status(of: item, level: level)
        let locked: Bool = if case .locked = status { true } else { false }
        let isNew = !locked && status == .forSale(price: item.price) && item.unlockLevel == level
        return VStack(spacing: 8) {
            Text(item.rarity.displayName)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(item.rarity == .legendary ? Color(red: 0.4, green: 0.28, blue: 0) : GrowthColors.rarity(item.rarity))
                .padding(.horizontal, 12).padding(.vertical, 3)
                .background(Capsule().fill(GrowthColors.rarity(item.rarity).opacity(item.rarity == .legendary ? 0.8 : 0.18)))
            ZStack {
                Circle().fill(locked ? Color(white: 0.9) : GrowthColors.rarity(item.rarity).opacity(0.15)).frame(width: 96, height: 96)
                PictureView(emoji: item.icon, size: 60).grayscale(locked ? 1 : 0).opacity(locked ? 0.35 : 1)
                if locked { Text("🔒").font(.system(size: 34)) }
            }
            Text(item.name).font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(locked ? Theme.muted : Theme.ink)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(item.summary).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(Theme.muted)
                .lineLimit(2).multilineTextAlignment(.center).frame(minHeight: 36)
            if let skin = item.itemSkin, let base = UnitCatalog.item(id: skin.item) {
                Text("原来是 \(base.icon) \(base.name)").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 0)
            cardAction(item, status: status, level: level)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 330)
        .background(
            RoundedRectangle(cornerRadius: 26)
                .fill(status == .equipped ? GrowthColors.gold.opacity(0.12) : GrowthColors.surface)
                .shadow(color: GrowthColors.cardEdge, radius: 0, x: 0, y: 5))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(status == .equipped ? GrowthColors.gold : .clear, lineWidth: 4))
        .overlay(alignment: .topTrailing) {
            if status == .equipped { cornerTag("✨ 装扮中", fill: GrowthColors.gold, text: Color(red: 0.36, green: 0.25, blue: 0)) }
        }
        .overlay(alignment: .topLeading) {
            if isNew { cornerTag("新解锁！", fill: Theme.wrong, text: .white) }
        }
        .contentShape(Rectangle())
        .onTapGesture { previewID = item.id }
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
        switch status {
        case .equipped:
            VStack(spacing: 4) {
                CandyButtonLabel(title: "使用中 ✓", fill: Theme.jade, edge: GrowthColors.jadeDark, font: actionFont, height: 50)
                if !item.isOriginal {
                    Button("换回原版") { model.unequip(key: item.equipKey, for: profileID) }
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.muted)
                }
            }
        case .owned:
            Button { model.equip(item, for: profileID) } label: {
                CandyButtonLabel(title: "装备", fill: GrowthColors.surface, edge: GrowthColors.jadeDark, foreground: GrowthColors.jadeDark,
                                 font: actionFont, height: 50)
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
                                     font: actionFont, height: 50)
                }
                .buttonStyle(PressableStyle())
            } else {
                VStack(spacing: 4) {
                    Text("再玩 \(max(1, Int((Double(short) / 40).rounded(.up)))) 局左右就够啦")
                        .font(.system(size: 13, weight: .heavy, design: .rounded)).foregroundStyle(Theme.wrong)
                    CandyButtonLabel(title: "\(price) 还差 \(short)", coin: true, fill: Color(white: 0.88), edge: Color(white: 0.75),
                                     foreground: Theme.muted, font: actionFont, height: 50)
                }
            }
        case let .locked(unlock):
            VStack(spacing: 6) {
                Text("🔒 Lv.\(unlock) 解锁").font(.system(size: 14, weight: .heavy, design: .rounded)).foregroundStyle(Theme.muted)
                Text("还差 \(unlock - level) 级就能拿到！").font(.system(size: 14, weight: .heavy, design: .rounded)).foregroundStyle(Theme.accent)
                MiniBar(value: Double(level), total: Double(unlock), tint: Theme.accent)
                CandyButtonLabel(title: "还没解锁", fill: Color(white: 0.9), edge: Color(white: 0.78), foreground: Theme.muted,
                                 font: actionFont, height: 46)
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
                            model.speech.speak("买到\(item.name)啦，已经换上了！", interrupt: true)
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
