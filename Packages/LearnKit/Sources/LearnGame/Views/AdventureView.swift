import LearnCore
import SpriteKit
import SwiftUI

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
struct AdventureAction: View {
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
