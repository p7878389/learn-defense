import LearnCore
import SpriteKit
import SwiftUI

private struct AdventureLaunch: Identifiable {
    let id = UUID()
    let levelID: Int
    let difficulty: Difficulty
    let deck: [String]
}

struct AdventureLobbyView: View {
    @EnvironmentObject private var model: AppModel
    let profileID: UUID
    let onClose: () -> Void
    @State private var difficulty: Difficulty = .normal
    @State private var deck = AdventureCatalog.defaultDeck
    @State private var launch: AdventureLaunch?
    @State private var showInsufficientCoins = false

    private var growth: GrowthStore { model.growth(for: profileID) }
    private var regularDefenders: [DefenderKind] { AdventureCatalog.defenders.filter { $0.id != AdventureDoom.id } }
    private var doomDefender: DefenderKind? { AdventureCatalog.defenders.first { $0.id == AdventureDoom.id } }
    private var recommendedLevelID: Int? {
        let adventure = growth.state.adventure
        return AdventureCatalog.levels
            .filter { adventure.isUnlocked($0.id) && (adventure.bestStars[String($0.id)] ?? 0) < 3 }
            .map(\.id)
            .max()
    }

    var body: some View {
        GeometryReader { geometry in
            let landscape = geometry.size.width > geometry.size.height
            let compact = geometry.size.height < 760
            VStack(spacing: compact ? AppSpacing.xs : AppSpacing.sm) {
                GrowthPageHeader(icon: "🗺️", title: "森林冒险", subtitle: "15 积分 / 局", backTitle: "返回主页", onClose: onClose) {
                    CoinPill(coins: growth.state.coins, size: 20)
                }
                HStack(spacing: AppSpacing.sm) {
                    GrowthSegmentedPicker(options: Difficulty.allCases, title: \.displayName, selection: $difficulty)
                    Spacer()
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "star.fill")
                            .font(AppFont.rounded(15, weight: .bold))
                            .foregroundStyle(AppColor.gold)
                        Text("\(growth.state.adventure.totalStars) / 18")
                            .font(AppFont.digits(17, weight: .black))
                            .foregroundStyle(AppColor.goldEdge)
                    }
                    .padding(.horizontal, AppSpacing.sm)
                    .frame(height: 44)
                    .appInset(radius: 22, tint: AppColor.gold)
                }
                if landscape {
                    HStack(alignment: .top, spacing: AppSpacing.sm) {
                        deckPanel(columns: 2, compact: compact)
                            .frame(width: 286)
                        levelGrid(columns: 3, compact: compact)
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                } else {
                    VStack(spacing: AppSpacing.sm) {
                        deckPanel(columns: 3, compact: true)
                        levelGrid(columns: 2, compact: compact)
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                }
                Text(growth.state.adventure.chapterComplete ? "🏅 森林守卫纪念章 · 六关全部通关！" : "经典答题赚积分 · 布阵免费，开战扣费 · 局内只用阳光")
                    .font(AppFont.caption)
                    .foregroundStyle(AppColor.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, compact ? AppSpacing.sm : AppSpacing.md)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(GrowthPageBackground())
        .gameCover(item: $launch, onDismiss: { model.objectWillChange.send() }) { launch in
            AdventureView(levelID: launch.levelID, model: model, profileID: profileID,
                          difficulty: launch.difficulty, deck: launch.deck, onClose: { self.launch = nil })
        }
        .overlay {
            if showInsufficientCoins {
                CandyConfirmModal(
                    title: "积分还差一点",
                    icon: "🪙",
                    message: "进入森林冒险每局需要 \(AdventureCatalog.entryCost) 积分（当前 \(growth.state.coins) 积分）。先回主页通过经典答题闯关赚取积分吧！",
                    buttons: [
                        CandyConfirmButton(title: "回主页赚积分", systemImage: "play.fill", role: .primary) {
                            showInsufficientCoins = false; onClose()
                        },
                        CandyConfirmButton(title: "留在地图", role: .cancel) { showInsufficientCoins = false }
                    ],
                    onDismiss: { showInsufficientCoins = false }
                )
            }
        }
        .interactiveDismissDisabled()
    }

    private func deckPanel(columns: Int, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? AppSpacing.xs : AppSpacing.sm) {
            HStack {
                Label("准备卡组", systemImage: "leaf.fill")
                    .font(AppFont.rounded(19, weight: .heavy))
                    .foregroundStyle(AppColor.ink)
                Spacer()
                Text("\(deck.count) / 4")
                    .font(AppFont.digits(15, weight: .black))
                    .foregroundStyle(validDeck ? AppColor.jadeEdge : AppColor.dangerText)
                    .padding(.horizontal, AppSpacing.sm).padding(.vertical, 3)
                    .background(Capsule().fill((validDeck ? AppColor.jade : AppColor.dangerText).opacity(0.14)))
            }
            Text("带上四张卡，至少一位射手")
                .font(AppFont.caption)
                .foregroundStyle(AppColor.muted)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: AppSpacing.xs), count: columns), spacing: AppSpacing.xs) {
                ForEach(regularDefenders) { kind in deckButton(kind, compact: compact) }
            }
            if let doom = doomDefender {
                doomDeckBanner(doom, compact: compact)
            }
        }
        .padding(compact ? AppSpacing.sm : AppSpacing.md)
        .appPanel(radius: AppRadius.lg)
    }

    private func deckButton(_ kind: DefenderKind, compact: Bool) -> some View {
        let selected = deck.contains(kind.id)
        let unlocked = growth.state.canUseDefender(kind.id)
        return Button {
            toggleDeck(kind.id, unlocked: unlocked)
        } label: {
            VStack(spacing: 3) {
                if let image = UnitSprites.portrait(of: kind, skin: growth.loadout.defenderSkins[kind.id]) {
                    Image(decorative: image, scale: 1).resizable().scaledToFit().frame(height: compact ? 28 : 36)
                }
                Text(HeraldicArtwork.defenderName(kind: kind, skin: growth.loadout.defenderSkins[kind.id]))
                    .font(AppFont.rounded(compact ? 13 : 14, weight: .heavy))
                    .lineLimit(1).minimumScaleFactor(0.8)
                HStack(spacing: AppSpacing.xxs) {
                    Image(systemName: "sun.max.fill")
                        .font(AppFont.rounded(10, weight: .bold))
                        .foregroundStyle(selected ? AppColor.goldLight : AppColor.goldEdge)
                    Text("\(kind.sunCost)").font(AppFont.digits(12, weight: .heavy))
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(AppFont.rounded(11, weight: .bold))
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: compact ? 74 : 90)
            .foregroundStyle(selected ? .white : AppColor.ink)
            .background(CandyTileBackground(selected: selected, selectedFill: AppColor.adventure, selectedEdge: AppColor.adventureEdge, radius: AppRadius.sm))
        }
        .buttonStyle(PressableStyle())
        .disabled(!unlocked)
        .opacity(unlocked ? 1 : 0.58)
        .accessibilityLabel("\(kind.name)，\(unlocked ? (selected ? "已选择" : "未选择") : "未解锁，请在收藏馆购买")")
        .accessibilityHint(unlocked ? "选入四张冒险卡牌" : "达到 Lv.3 后，在收藏馆用 300 积分永久解锁")
    }

    /// 毁灭菇横跨整行，消除 7 卡 2 列排版缺角
    private func doomDeckBanner(_ kind: DefenderKind, compact: Bool) -> some View {
        let selected = deck.contains(kind.id)
        let unlocked = growth.state.canUseDefender(kind.id)
        return Button {
            toggleDeck(kind.id, unlocked: unlocked)
        } label: {
            HStack(spacing: AppSpacing.sm) {
                if let image = UnitSprites.portrait(of: kind, skin: growth.loadout.defenderSkins[kind.id]) {
                    Image(decorative: image, scale: 1).resizable().scaledToFit().frame(width: 34, height: 34)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(kind.name).font(AppFont.rounded(14, weight: .heavy))
                    Text(unlocked ? "范围爆破 · \(kind.sunCost) 阳光" : "Lv.3 后收藏馆 300 积分解锁")
                        .font(AppFont.caption)
                        .opacity(selected ? 0.9 : 0.72)
                        .lineLimit(1).minimumScaleFactor(0.75)
                }
                Spacer(minLength: AppSpacing.xxs)
                Image(systemName: unlocked ? (selected ? "checkmark.circle.fill" : "plus.circle") : "lock.fill")
                    .font(AppFont.rounded(16, weight: .bold))
            }
            .padding(.horizontal, AppSpacing.sm)
            .frame(maxWidth: .infinity, minHeight: compact ? 52 : 60)
            .foregroundStyle(selected ? .white : (unlocked ? AppColor.ink : AppColor.muted))
            .background(
                CandyTileBackground(
                    selected: selected,
                    selectedFill: AppColor.violet,
                    selectedEdge: AppColor.violetEdge,
                    radius: AppRadius.sm
                )
            )
        }
        .buttonStyle(PressableStyle())
        .disabled(!unlocked)
        .opacity(unlocked ? 1 : 0.68)
        .accessibilityLabel("\(kind.name)，\(unlocked ? (selected ? "已选择" : "未选择") : "未解锁，请在收藏馆购买")")
    }

    private func toggleDeck(_ id: String, unlocked: Bool) {
        guard unlocked else { return }
        if deck.contains(id) { deck.removeAll { $0 == id } }
        else if deck.count < 4 { deck.append(id) }
    }

    private var validDeck: Bool {
        deck.count == 4 && deck.allSatisfy(growth.state.canUseDefender)
            && deck.contains { AdventureCatalog.defender($0)?.canShoot == true }
    }

    private func levelGrid(columns: Int, compact: Bool) -> some View {
        VStack(spacing: compact ? AppSpacing.xs : AppSpacing.sm) {
            ForEach(0..<(6 / columns), id: \.self) { row in
                HStack(spacing: compact ? AppSpacing.xs : AppSpacing.sm) {
                    ForEach(Array(AdventureCatalog.levels[(row * columns)..<((row + 1) * columns)])) { level in
                        levelCard(level, compact: compact)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func levelTint(_ id: Int) -> Color {
        switch id {
        case 1: AppColor.jade
        case 2: AppColor.adventure
        case 3: AppColor.calm
        case 4: AppColor.woodTrim
        case 5: AppColor.violet
        default: AppColor.dangerSolidBottom
        }
    }

    private func levelCard(_ level: AdventureLevel, compact: Bool) -> some View {
        let unlocked = growth.state.adventure.isUnlocked(level.id)
        let stars = growth.state.adventure.bestStars[String(level.id)] ?? 0
        let tint = levelTint(level.id)
        let isBoss = level.id == 6
        let isRecommended = level.id == recommendedLevelID
        return Button {
            if growth.state.coins < AdventureCatalog.entryCost { showInsufficientCoins = true }
            else { launch = AdventureLaunch(levelID: level.id, difficulty: difficulty, deck: deck) }
        } label: {
            let cardContent = VStack(alignment: .leading, spacing: compact ? AppSpacing.xxs : AppSpacing.xs) {
                HStack(spacing: 6) {
                    Text(String(format: "%02d", level.id))
                        .font(AppFont.digits(14, weight: .black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, AppSpacing.xs).padding(.vertical, 3)
                        .background(Capsule().fill(unlocked ? tint : AppColor.disabledText))
                    if isBoss {
                        Label("首领关", systemImage: "crown.fill")
                            .font(AppFont.caption)
                            .foregroundStyle(unlocked ? AppColor.dangerText : AppColor.muted)
                            .padding(.horizontal, AppSpacing.xs).padding(.vertical, 3)
                            .background(Capsule().fill(unlocked ? AppColor.dangerFill : AppColor.disabledFill))
                            .lineLimit(1)
                    }
                    Spacer(minLength: AppSpacing.xxs)
                    if isRecommended {
                        Text("推荐")
                            .font(AppFont.caption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, AppSpacing.xs).padding(.vertical, 3)
                            .background(Capsule().fill(AppColor.jade))
                            .lineLimit(1)
                    }
                    HStack(spacing: 2) {
                        ForEach(0..<3, id: \.self) { idx in
                            Image(systemName: idx < stars ? "star.fill" : "star")
                                .font(AppFont.rounded(13, weight: .bold))
                                .foregroundStyle(idx < stars ? AppColor.gold : (unlocked ? AppColor.cardEdge : AppColor.disabledEdge))
                        }
                    }
                }
                Text(level.title)
                    .font(AppFont.rounded(compact ? 18 : 20, weight: .heavy))
                    .foregroundStyle(unlocked ? AppColor.ink : AppColor.ink.opacity(0.55))
                    .lineLimit(1).minimumScaleFactor(0.85)
                Text(level.hint)
                    .font(AppFont.label)
                    .foregroundStyle(AppColor.muted)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: AppSpacing.xs)
                HStack(spacing: 6) {
                    Text(!unlocked ? "通过前一关解锁" : growth.state.coins < 15 ? "回主页赚积分" : !validDeck ? "请选择四张卡牌" : "15 积分 · 准备布阵")
                        .font(AppFont.label)
                        .lineLimit(1).minimumScaleFactor(0.8)
                    Spacer(minLength: AppSpacing.xxs)
                    Image(systemName: unlocked ? "arrow.right.circle.fill" : "lock.fill")
                        .font(AppFont.rounded(15, weight: .bold))
                }
                .foregroundStyle(unlocked ? (isRecommended || stars > 0 ? AppColor.jadeEdge : tint) : AppColor.muted)
                .padding(.horizontal, AppSpacing.sm).padding(.vertical, 6)
                .background(Capsule().fill(unlocked ? (isRecommended ? AppColor.jade : tint).opacity(0.12) : AppColor.disabledFill))
            }
            .padding(compact ? AppSpacing.sm : AppSpacing.md)
            .padding(.bottom, unlocked ? 3 : 0)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            if unlocked {
                cardContent
                    .background(CandyTileBackground(selected: false, radius: AppRadius.lg))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.lg)
                            .strokeBorder(isRecommended ? AppColor.jade : tint.opacity(0.42), lineWidth: isRecommended ? 2.5 : 2)
                            .padding(.bottom, 3)
                    )
            } else {
                cardContent
                    .appPanel(radius: AppRadius.lg)
            }
        }
        .buttonStyle(PressableStyle())
        .disabled(!unlocked || (!validDeck && growth.state.coins >= 15))
    }

}
