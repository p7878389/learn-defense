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

struct AdventureView: View {
    @StateObject private var session: AdventureSession
    let onClose: () -> Void

    init(levelID: Int, model: AppModel, profileID: UUID, difficulty: Difficulty, deck: [String], onClose: @escaping () -> Void) {
        _session = StateObject(wrappedValue: AdventureSession(levelID: levelID, model: model, profileID: profileID,
                                                             difficulty: difficulty, deck: deck))
        self.onClose = onClose
    }

    var body: some View { AdventureScreen(session: session, onClose: onClose) }
}

struct AdventureScreen: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var session: AdventureSession
    @State private var frame: CGRect = .zero
    @State private var selected: String?
    @State private var shoveling = false
    @State private var placementCell: DefenderCell?
    @State private var placementMessage: String?
    @State private var showExit = false
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            topBar
            cards
            GeometryReader { geometry in
                let size = CGSize(width: min(geometry.size.width, geometry.size.height * 2),
                                  height: min(geometry.size.height, geometry.size.width / 2))
                SpriteView(scene: session.scene)
                    .frame(width: size.width, height: size.height)
                    .background(GeometryReader { proxy in
                        Color.clear.onChange(of: proxy.frame(in: .named("adventure")), initial: true) { _, value in frame = value }
                    })
                    .overlay {
                        LawnGuide(selected: selected != nil || shoveling)
                        AdventurePlacementPreview(battle: session.battle, kindID: selected, cell: placementCell)
                    }
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("adventure"))
                        .onChanged { value in updatePreview(at: value.location) }
                        .onEnded { value in place(at: value.location) })
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            bottomBar
        }
        .padding(12)
        .coordinateSpace(name: "adventure")
        .background(Theme.paper)
        .overlay { stateOverlay }
        .interactiveDismissDisabled()
        .onChange(of: scenePhase) { _, phase in if phase != .active { session.suspend() } }
        .onDisappear { session.suspend() }
        .confirmationDialog("离开冒险", isPresented: $showExit, titleVisibility: .visible) {
            if session.battle.phase == .preparing || session.battle.isFinished {
                Button("返回地图") { if session.abandon() { onClose() } }
            } else {
                Button("保存并返回地图") { session.suspend(); if session.error == nil { onClose() } }
                Button("放弃对局（不返还积分）", role: .destructive) { if session.abandon() { onClose() } }
            }
        }
    }

    private var topBar: some View {
        ViewThatFits(in: .horizontal) {
            HStack { title; Spacer(); counters; pauseButton }
            VStack(spacing: 8) { HStack { title; Spacer(); pauseButton }; counters }
        }
    }

    private var title: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(session.battle.level.title).font(.title3.bold())
            Text("第 \(session.hud.wave)/5 波 · \(session.battle.difficulty.displayName)").font(.caption).foregroundStyle(Theme.muted)
        }
    }

    private var counters: some View {
        HStack(spacing: 18) {
            Label("\(session.hud.lives)/10", systemImage: "heart.fill").foregroundStyle(Theme.wrong)
            Label("\(session.hud.sun)", systemImage: "sun.max.fill").foregroundStyle(Theme.accent)
            Text(String(format: "%02d:%02d", session.hud.seconds / 60, session.hud.seconds % 60)).monospacedDigit()
        }
        .font(.headline)
    }

    private var pauseButton: some View {
        AdventureAction(title: session.hud.phase == .playing ? "暂停" : "返回", icon: session.hud.phase == .playing ? "⏸" : "←",
                        fill: GrowthColors.surface, edge: GrowthColors.cardEdge, foreground: Theme.ink) {
            if session.battle.phase == .playing { session.suspend() }
            else { showExit = true }
        }
    }

    private var cards: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                SeedPacketStrip(kinds: session.plantable, sun: session.hud.sun,
                    enabled: session.battle.canBuild, draggingID: selected, skins: session.loadout.defenderSkins,
                    onDragChanged: { kind, point in
                        selected = kind.id; shoveling = false; placementMessage = nil
                        updatePreview(at: point)
                    },
                    onDragEnded: { kind, point in
                        selected = kind.id
                        if frame.contains(point) { place(at: point) }
                    }, gestureSpace: "adventure", cooldowns: [AdventureDoom.id: session.hud.doomCooldown])
                AdventureAction(title: shoveling ? "铲子已选中" : "铲除", icon: "🛠",
                                fill: shoveling ? Theme.accent : GrowthColors.surface,
                                edge: shoveling ? GrowthColors.orangeDark : GrowthColors.cardEdge,
                                foreground: shoveling ? .white : Theme.ink) {
                    shoveling.toggle(); selected = nil; placementCell = nil; placementMessage = nil
                }
                .disabled(!session.battle.canBuild)
            }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            if let error = session.error {
                Text(error).font(.callout).foregroundStyle(Theme.wrong)
                AdventureAction(title: "重试保存", action: session.retrySave)
            }
            if session.hud.phase == .preparing {
                HStack {
                    Text(placementPrompt ?? "点击卡牌再点草坪，或拖动卡牌布阵；铲除不返还阳光。毁灭菇开战后引爆，至少种下一位射手。")
                        .font(.callout).foregroundStyle(Theme.muted).lineLimit(2)
                    placementCancel
                }
                .frame(height: 44)
                AdventureAction(title: "开始战斗 · 消耗 15 积分", icon: "▶", height: 52, action: session.start)
                    .disabled(!session.battle.towers.contains { AdventureCatalog.defender($0.kindID)?.canShoot == true })
            } else {
                HStack {
                    Text(placementPrompt ?? (session.hud.rest > 0 ? "下一波将在 \(session.hud.rest) 秒后到来" : "击败 \(session.hud.defeated) 只怪物"))
                        .font(.callout).foregroundStyle(Theme.muted)
                    placementCancel
                    Spacer()
                    AdventureAction(title: "雷霆大招 \(session.hud.energy)/12", icon: "⚡️", fill: Theme.accent,
                                    edge: GrowthColors.orangeDark, action: session.unleash).disabled(!session.hud.ultimateReady)
                }
            }
            Text("\(session.hud.rest > 0 ? "本波预告" : "敌人预告")：\(session.battle.currentWave?.preview ?? "")")
                .font(.caption).foregroundStyle(Theme.muted).lineLimit(2)
        }
    }

    private var placementPrompt: String? {
        placementMessage ?? (selected == AdventureDoom.id ? "选择空格放置毁灭菇 · 原格禁种 180 秒" : nil)
    }

    @ViewBuilder private var placementCancel: some View {
        if placementPrompt != nil {
            Button("取消") { selected = nil; placementCell = nil; placementMessage = nil }
                .font(.headline).frame(minHeight: 44)
        }
    }

    @ViewBuilder private var stateOverlay: some View {
        if session.hud.phase == .paused || session.battle.isFinished {
            ZStack {
                Color.black.opacity(0.35).ignoresSafeArea()
                VStack(spacing: 18) {
                    if session.battle.isFinished {
                        Text(session.hud.phase == .won ? "守住了！" : "这次差一点").font(.largeTitle.bold())
                        Text(session.battle.phase == .won ? String(repeating: "⭐️", count: session.battle.stars) : "🌱").font(.system(size: 48))
                        Text(session.battle.advice).multilineTextAlignment(.center)
                        Text("冒险只记录关卡和星级，不发放积分与学习奖励。")
                            .font(.callout).foregroundStyle(Theme.muted)
                        if session.error == nil {
                            AdventureAction(title: "返回地图", icon: "🗺️") { if session.abandon() { onClose() } }
                        }
                    } else {
                        Text("冒险已暂停").font(.largeTitle.bold())
                        Text("阳光、怪物和战斗时间都已暂停，继续不会再次扣积分。")
                            .foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                        AdventureAction(title: "继续战斗", icon: "▶", action: session.resume)
                        AdventureAction(title: "保存并返回地图", fill: GrowthColors.surface, edge: GrowthColors.cardEdge, foreground: Theme.ink) {
                            session.suspend(); if session.error == nil { onClose() }
                        }
                        Button("放弃对局", role: .destructive) { showExit = true }
                    }
                    if let error = session.error {
                        Text(error).foregroundStyle(Theme.wrong)
                        AdventureAction(title: "重试保存", action: session.retrySave)
                    }
                }
                .padding(30).frame(maxWidth: 520)
                .candyCard(radius: 26)
                .padding(20)
            }
        }
    }

    private func place(at location: CGPoint) {
        guard let point = GameScene.scenePoint(at: location, in: frame), let cell = Lawn(lanes: 5).cell(at: point) else { return }
        if shoveling { session.shovel(lane: cell.lane, column: cell.column) }
        else if let selected {
            if session.plant(selected, lane: cell.lane, column: cell.column) {
                placementCell = nil; placementMessage = nil
                if selected == AdventureDoom.id { self.selected = nil }
            } else {
                placementCell = cell
                placementMessage = session.battle.doomCraters.contains { $0.lane == cell.lane && $0.column == cell.column }
                    ? "焦坑恢复后才能种植" : "这里暂时不能放置，请选择其他空格"
            }
        }
    }

    private func updatePreview(at location: CGPoint) {
        placementCell = GameScene.scenePoint(at: location, in: frame).flatMap { Lawn(lanes: 5).cell(at: $0) }
    }
}

/// 草坪格属于交互界面；特效仍全部使用现有 .sks 资源。
private struct LawnGuide: View {
    let selected: Bool
    var body: some View {
        GeometryReader { proxy in
            if selected {
                let sx = proxy.size.width / 1200
                let sy = proxy.size.height / 600
                Path { path in
                    for column in 0...9 {
                        let x = (144 + 750 * CGFloat(column) / 9) * sx
                        path.move(to: CGPoint(x: x, y: 80 * sy))
                        path.addLine(to: CGPoint(x: x, y: 580 * sy))
                    }
                    for row in 0...5 {
                        let y = (80 + CGFloat(row) * 100) * sy
                        path.move(to: CGPoint(x: 144 * sx, y: y))
                        path.addLine(to: CGPoint(x: 894 * sx, y: y))
                    }
                }
                .stroke(.white.opacity(0.6), lineWidth: 1)
            }
        }
        .allowsHitTesting(false)
    }
}

/// 冒险各页面沿用成长系统的糖果胶囊与按压反馈。
private struct AdventureAction: View {
    @Environment(\.isEnabled) private var isEnabled
    let title: String
    var icon: String? = nil
    var fill: Color = Theme.jade
    var edge: Color = GrowthColors.jadeDark
    var foreground: Color = .white
    var height: CGFloat = 44
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            CandyButtonLabel(title: title, icon: icon, fill: fill, edge: edge, foreground: foreground,
                             font: .system(size: 17, weight: .heavy, design: .rounded), height: height, minWidth: 0)
                .opacity(isEnabled ? 1 : 0.45)
        }
        .buttonStyle(PressableStyle())
    }
}
