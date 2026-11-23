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
    @State private var confirmAbandon = false
    @State private var error: String?

    private var growth: GrowthStore { model.growth(for: profileID) }

    var body: some View {
        GeometryReader { geometry in
            let landscape = geometry.size.width > geometry.size.height
            VStack(spacing: 14) {
                GrowthPageHeader(icon: "🗺️", title: "森林冒险", subtitle: "15 积分 / 局", onClose: onClose) {
                    CoinPill(coins: growth.state.coins, size: 22)
                }
                HStack {
                    GrowthSegmentedPicker(options: Difficulty.allCases, title: \.displayName, selection: $difficulty)
                    Spacer()
                    Label("\(growth.state.adventure.totalStars) / 18", systemImage: "star.fill")
                        .font(.headline).foregroundStyle(Theme.accent)
                    AdventureAction(title: "经典闯关", icon: "📖", fill: GrowthColors.surface,
                                    edge: GrowthColors.cardEdge, foreground: Theme.ink, action: onClose)
                }
                if let active = growth.state.adventure.active { savedBattle(active) }
                if landscape {
                    HStack(alignment: .top, spacing: 16) {
                        deckPanel(columns: 2, compact: geometry.size.height < 760)
                            .frame(width: 280)
                        levelGrid(columns: 3)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    VStack(spacing: 16) {
                        deckPanel(columns: 4, compact: true).frame(height: 264)
                        levelGrid(columns: 2)
                    }
                    .frame(maxHeight: .infinity)
                }
                Text(growth.state.adventure.chapterComplete ? "🏅 森林守卫纪念章 · 六关全部通关！" : "经典答题赚积分 · 布阵免费，开战扣费 · 局内只用阳光")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.muted).lineLimit(1).minimumScaleFactor(0.8)
            }
            .padding(20)
            .frame(maxWidth: 1200)
            .frame(maxWidth: .infinity)
        }
        .background(GrowthPageBackground())
        .gameCover(item: $launch, onDismiss: { model.objectWillChange.send() }) { launch in
            AdventureView(levelID: launch.levelID, model: model, profileID: profileID,
                          difficulty: launch.difficulty, deck: launch.deck, onClose: { self.launch = nil })
        }
        .confirmationDialog("放弃这场冒险？已消耗的 15 积分不会返还。", isPresented: $confirmAbandon, titleVisibility: .visible) {
            Button("放弃对局", role: .destructive) {
                do { try growth.abandonAdventure(); model.objectWillChange.send() }
                catch { self.error = error.localizedDescription }
            }
        }
        .alert("操作未完成", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("知道了") { error = nil }
        } message: { Text(error ?? "") }
        .interactiveDismissDisabled()
    }

    private func deckPanel(columns: Int, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("准备卡组", systemImage: "leaf.fill").font(.system(size: 20, weight: .heavy, design: .rounded))
                Spacer()
                Text("\(deck.count) / 4").font(.headline).foregroundStyle(validDeck ? Theme.jade : Theme.accent)
            }
            Text("带上四张卡，至少一位射手").font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.muted)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: columns), spacing: 10) {
                ForEach(AdventureCatalog.defenders) { kind in deckButton(kind, compact: compact) }
            }
        }
        .padding(14)
        .candyCard()
    }

    private func deckButton(_ kind: DefenderKind, compact: Bool) -> some View {
        let selected = deck.contains(kind.id)
        let unlocked = growth.state.canUseDefender(kind.id)
        return Button {
            guard unlocked else { return }
            if deck.contains(kind.id) { deck.removeAll { $0 == kind.id } }
            else if deck.count < 4 { deck.append(kind.id) }
        } label: {
            VStack(spacing: 4) {
                if let image = UnitSprites.portrait(of: kind, skin: growth.loadout.defenderSkins[kind.id]) {
                    Image(decorative: image, scale: 1).resizable().scaledToFit().frame(height: compact ? 30 : 40)
                }
                Text(HeraldicArtwork.defenderName(kind: kind, skin: growth.loadout.defenderSkins[kind.id]))
                    .font(.system(size: compact ? 14 : 16, weight: .bold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.8)
                HStack(spacing: 6) {
                    Text(unlocked ? "☀️ \(kind.sunCost)" : "🔒 300积分")
                        .lineLimit(1).minimumScaleFactor(0.8)
                    if selected { Image(systemName: "checkmark.circle.fill") }
                }.font(.system(size: 12, weight: .heavy, design: .rounded))
            }
            .frame(maxWidth: .infinity, minHeight: compact ? 84 : 102)
            .foregroundStyle(selected ? .white : Theme.ink)
            .background(CandyTileBackground(selected: selected, selectedFill: Theme.jade, selectedEdge: GrowthColors.jadeDark, radius: 16))
        }
        .buttonStyle(PressableStyle())
        .disabled(!unlocked)
        .opacity(unlocked ? 1 : 0.55)
        .accessibilityLabel("\(kind.name)，\(unlocked ? (selected ? "已选择" : "未选择") : "未解锁，请在收藏馆购买")")
        .accessibilityHint(unlocked ? "选入四张冒险卡牌" : "达到 Lv.3 后，在收藏馆用 300 积分永久解锁")
    }

    private var validDeck: Bool {
        deck.count == 4 && deck.allSatisfy(growth.state.canUseDefender)
            && deck.contains { AdventureCatalog.defender($0)?.canShoot == true }
    }

    private func levelGrid(columns: Int) -> some View {
        VStack(spacing: 14) {
            ForEach(0..<(6 / columns), id: \.self) { row in
                HStack(spacing: 14) {
                    ForEach(Array(AdventureCatalog.levels[(row * columns)..<((row + 1) * columns)])) { level in
                        levelCard(level)
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
    }

    private func levelCard(_ level: AdventureLevel) -> some View {
        let unlocked = growth.state.adventure.isUnlocked(level.id)
        let stars = growth.state.adventure.bestStars[String(level.id)] ?? 0
        return Button {
            if growth.state.coins < AdventureCatalog.entryCost { onClose() }
            else { launch = AdventureLaunch(levelID: level.id, difficulty: difficulty, deck: deck) }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(String(format: "%02d", level.id))
                        .font(.system(size: 24, weight: .black, design: .rounded)).foregroundStyle(Theme.jade)
                    Spacer()
                    Text((0..<3).map { $0 < stars ? "★" : "☆" }.joined())
                        .font(.system(size: 17, weight: .heavy)).foregroundStyle(Theme.accent)
                }
                Text(level.title).font(.system(size: 22, weight: .heavy, design: .rounded)).foregroundStyle(Theme.ink)
                    .lineLimit(1).minimumScaleFactor(0.85)
                Text(level.hint).font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.muted).lineLimit(2)
                Spacer(minLength: 0)
                HStack {
                    Text(!unlocked ? "通过前一关解锁" : growth.state.coins < 15 ? "去经典闯关赚积分" : !validDeck ? "请选择四张卡牌" : "15 积分 · 准备布阵")
                        .font(.system(size: 13, weight: .bold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.8)
                    Spacer(minLength: 4)
                    Image(systemName: unlocked ? "arrow.right.circle.fill" : "lock.fill")
                }.foregroundStyle(unlocked ? GrowthColors.jadeDark : Theme.muted)
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(CandyTileBackground(radius: 22))
            .opacity(unlocked ? 1 : 0.6)
        }
        .buttonStyle(PressableStyle())
        .disabled(!unlocked || (!validDeck && growth.state.coins >= 15) || growth.state.adventure.active != nil)
    }

    private func savedBattle(_ battle: AdventureBattle) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("继续上次冒险 · \(battle.level.title)").font(.headline)
                Text("第 \(battle.wave) 波 · 基地 \(battle.lives)/10 · 不再扣积分").font(.caption).foregroundStyle(Theme.muted)
            }
            Spacer()
            AdventureAction(title: "继续冒险", icon: "▶") {
                launch = AdventureLaunch(levelID: battle.level.id, difficulty: battle.difficulty, deck: battle.deck)
            }
            Button("放弃", role: .destructive) { confirmAbandon = true }.font(.headline).frame(minHeight: 44)
        }
        .padding(12)
        .candyCard(fill: GrowthColors.gold.opacity(0.16), radius: 18)
    }
}
