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

    private var growth: GrowthStore { model.growth(for: profileID) }
    private var regularDefenders: [DefenderKind] { AdventureCatalog.defenders.filter { $0.id != AdventureDoom.id } }
    private var doomDefender: DefenderKind? { AdventureCatalog.defenders.first { $0.id == AdventureDoom.id } }

    var body: some View {
        GeometryReader { geometry in
            let landscape = geometry.size.width > geometry.size.height
            let hasSaved = growth.state.adventure.active != nil
            let compact = geometry.size.height < 760 || hasSaved
            VStack(spacing: compact ? 10 : 14) {
                GrowthPageHeader(icon: "🗺️", title: "森林冒险", subtitle: "15 积分 / 局", backTitle: "返回主页", onClose: onClose) {
                    CoinPill(coins: growth.state.coins, size: 20)
                }
                HStack(spacing: 12) {
                    GrowthSegmentedPicker(options: Difficulty.allCases, title: \.displayName, selection: $difficulty)
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill").foregroundStyle(AppColor.gold)
                        Text("\(growth.state.adventure.totalStars) / 18")
                            .font(AppFont.digits(17, weight: .black))
                            .foregroundStyle(AppColor.accentEdge)
                    }
                    .padding(.horizontal, 14).frame(height: 44)
                    .background(Capsule().fill(AppColor.surface).overlay(Capsule().strokeBorder(AppColor.cardStroke, lineWidth: 1.5)))
                }
                if landscape {
                    HStack(alignment: .top, spacing: 14) {
                        deckPanel(columns: 2, compact: compact)
                            .frame(width: 286)
                        levelGrid(columns: 3, compact: compact)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    VStack(spacing: 14) {
                        deckPanel(columns: 3, compact: true)
                        levelGrid(columns: 2, compact: compact)
                    }
                    .frame(maxHeight: .infinity)
                }
                Text(growth.state.adventure.chapterComplete ? "🏅 森林守卫纪念章 · 六关全部通关！" : "经典答题赚积分 · 布阵免费，开战扣费 · 局内只用阳光")
                    .font(AppFont.caption)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, compact ? 12 : 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(GrowthPageBackground())
        .gameCover(item: $launch, onDismiss: { model.objectWillChange.send() }) { launch in
            AdventureView(levelID: launch.levelID, model: model, profileID: profileID,
                          difficulty: launch.difficulty, deck: launch.deck, onClose: { self.launch = nil })
        }
        .interactiveDismissDisabled()
    }

    private func deckPanel(columns: Int, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            HStack {
                Label("准备卡组", systemImage: "leaf.fill")
                    .font(AppFont.rounded(19, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("\(deck.count) / 4")
                    .font(AppFont.digits(15, weight: .black))
                    .foregroundStyle(validDeck ? AppColor.jadeEdge : AppColor.accentEdge)
                    .padding(.horizontal, 10).padding(.vertical, 3)
                    .background(Capsule().fill((validDeck ? AppColor.jade : AppColor.accent).opacity(0.15)))
            }
            Text("带上四张卡，至少一位射手")
                .font(AppFont.caption)
                .foregroundStyle(Theme.muted)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columns), spacing: 8) {
                ForEach(regularDefenders) { kind in deckButton(kind, compact: compact) }
            }
            if let doom = doomDefender {
                doomDeckBanner(doom, compact: compact)
            }
        }
        .padding(compact ? 12 : 14)
        .candyCard(radius: AppRadius.lg)
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
                HStack(spacing: 4) {
                    Image(systemName: "sun.max.fill").font(.system(size: 10, weight: .bold))
                        .foregroundStyle(selected ? AppColor.goldLight : AppColor.accent)
                    Text("\(kind.sunCost)").font(AppFont.digits(12, weight: .heavy))
                    if selected { Image(systemName: "checkmark.circle.fill").font(.system(size: 11, weight: .bold)) }
                }
            }
            .frame(maxWidth: .infinity, minHeight: compact ? 74 : 90)
            .foregroundStyle(selected ? .white : Theme.ink)
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
            HStack(spacing: 10) {
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
                Spacer(minLength: 4)
                Image(systemName: unlocked ? (selected ? "checkmark.circle.fill" : "plus.circle") : "lock.fill")
                    .font(.system(size: 16, weight: .bold))
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: compact ? 52 : 60)
            .foregroundStyle(selected ? .white : (unlocked ? Theme.ink : Theme.muted))
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
        VStack(spacing: compact ? 10 : 14) {
            ForEach(0..<(6 / columns), id: \.self) { row in
                HStack(spacing: compact ? 10 : 14) {
                    ForEach(Array(AdventureCatalog.levels[(row * columns)..<((row + 1) * columns)])) { level in
                        levelCard(level, compact: compact)
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
    }

    private func levelTint(_ id: Int) -> Color {
        switch id {
        case 1: AppColor.jade
        case 2: AppColor.adventure
        case 3: Color(red: 0.30, green: 0.49, blue: 0.78)
        case 4: AppColor.accent
        case 5: AppColor.violet
        default: Color(red: 0.84, green: 0.34, blue: 0.24)
        }
    }

    private func levelCard(_ level: AdventureLevel, compact: Bool) -> some View {
        let unlocked = growth.state.adventure.isUnlocked(level.id)
        let stars = growth.state.adventure.bestStars[String(level.id)] ?? 0
        let tint = levelTint(level.id)
        let isBoss = level.id == 6
        return Button {
            if growth.state.coins < AdventureCatalog.entryCost { onClose() }
            else { launch = AdventureLaunch(levelID: level.id, difficulty: difficulty, deck: deck) }
        } label: {
            VStack(alignment: .leading, spacing: compact ? 6 : 8) {
                HStack(spacing: 8) {
                    Text(String(format: "%02d", level.id))
                        .font(AppFont.digits(15, weight: .black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(unlocked ? tint : AppColor.disabledEdge))
                    if isBoss {
                        Label("首领关", systemImage: "crown.fill")
                            .font(AppFont.caption)
                            .foregroundStyle(AppColor.accentEdge)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule().fill(AppColor.gold.opacity(0.28)))
                    }
                    Spacer()
                    HStack(spacing: 2) {
                        ForEach(0..<3, id: \.self) { idx in
                            Image(systemName: idx < stars ? "star.fill" : "star")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(idx < stars ? AppColor.gold : AppColor.cardEdge)
                        }
                    }
                }
                Text(level.title)
                    .font(AppFont.rounded(compact ? 19 : 21, weight: .heavy))
                    .foregroundStyle(unlocked ? Theme.ink : Theme.muted)
                    .lineLimit(1).minimumScaleFactor(0.85)
                Text(level.hint)
                    .font(AppFont.label)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(2)
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    Text(!unlocked ? "通过前一关解锁" : growth.state.coins < 15 ? "回主页赚积分" : !validDeck ? "请选择四张卡牌" : "15 积分 · 准备布阵")
                        .font(AppFont.label)
                        .lineLimit(1).minimumScaleFactor(0.8)
                    Spacer(minLength: 4)
                    Image(systemName: unlocked ? "arrow.right.circle.fill" : "lock.fill")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundStyle(unlocked ? (stars > 0 ? AppColor.jadeEdge : tint) : Theme.muted)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Capsule().fill(unlocked ? tint.opacity(0.12) : AppColor.disabledFill.opacity(0.65)))
            }
            .padding(compact ? 12 : 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                CandyTileBackground(
                    selected: false,
                    radius: AppRadius.lg
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .strokeBorder(unlocked ? tint.opacity(0.42) : .clear, lineWidth: 2)
                    .padding(.bottom, 3)
            )
            .opacity(unlocked ? 1 : 0.68)
        }
        .buttonStyle(PressableStyle())
        .disabled(!unlocked || (!validDeck && growth.state.coins >= 15))
    }

}
