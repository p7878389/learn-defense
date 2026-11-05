import LearnCore
import SpriteKit
import SwiftUI

struct GameView: View {
    @StateObject private var session: GameSession
    @State private var battlefieldFrame: CGRect = .zero
    @State private var activeDrag: PlantDrag?
    let onReplay: () -> Void
    let onExit: () -> Void

    init(config: GameConfig, model: AppModel, onReplay: @escaping () -> Void, onExit: @escaping () -> Void) {
        _session = StateObject(wrappedValue: GameSession(
            config: config,
            library: model.library,
            progress: model.progress(for: config.profileID),
            speech: model.speech))
        self.onReplay = onReplay
        self.onExit = onExit
    }

    private var debugOptions: SpriteView.DebugOptions {
        []
    }

    var body: some View {
        ZStack {
            Color(red: 0.24, green: 0.31, blue: 0.12).ignoresSafeArea()

            if session.isEmpty {
                VStack(spacing: 20) {
                    Text("这里还没有可以出的题").font(.title)
                    Button("返回", action: onExit).font(.title2)
                }
            } else {
                VStack(spacing: 8) {
                    GameHUD(session: session, onExit: onExit)
                        .padding(.vertical, 8)
                        .background(Color(red: 0.91, green: 0.80, blue: 0.53), in: RoundedRectangle(cornerRadius: 8))
                    SeedPacketStrip(
                        kinds: session.tuning.lineup,
                        sun: session.sun,
                        enabled: session.canUseShop,
                        draggingID: activeDrag?.kind.id,
                        onDragChanged: { kind, location in
                            activeDrag = PlantDrag(kind: kind, location: location)
                            session.previewSeed(at: GameScene.scenePoint(at: location, in: battlefieldFrame))
                        },
                        onDragEnded: { kind, location in
                            // 只点一下卡牌、或拖回卡牌栏松手，都当作取消，不提示种错
                            if let point = GameScene.scenePoint(at: location, in: battlefieldFrame) {
                                _ = session.dropSeed(id: kind.id, at: point)
                            }
                            session.previewSeed(at: nil)
                            activeDrag = nil
                        })
                    BattlefieldView(session: session, debugOptions: debugOptions)
                        .background(
                            // 直接记下战场位置；用 PreferenceKey 传到外层时真机上一直是 .zero
                            GeometryReader { proxy in
                                Color.clear.onChange(of: proxy.frame(in: .named("gameLayout")), initial: true) { _, frame in
                                    battlefieldFrame = frame
                                }
                            })
                        .overlay {
                            if let drag = activeDrag, battlefieldFrame.contains(drag.location) {
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Theme.jade, lineWidth: 5)
                                    .padding(4)
                                    .allowsHitTesting(false)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .layoutPriority(-1)
                    if session.phase == .preparing {
                        PreparationPanel(session: session)
                    } else {
                        AnswerPanel(
                            question: session.current,
                            wrongPicks: session.wrongPicks,
                            onAnswer: session.answer,
                            onReplay: session.replayPrompt)
                            .padding(12)
                            .background(Color(red: 0.98, green: 0.94, blue: 0.80), in: RoundedRectangle(cornerRadius: 12))
                    }
                    Spacer(minLength: 0)
                }
                .padding(10)
            }

            if let drag = activeDrag {
                PlantDragGhost(kind: drag.kind)
                    .position(drag.location)
                    .allowsHitTesting(false)
                    .zIndex(20)
            }

            if let question = session.ultimate {
                UltimateOverlay(
                    title: "\(session.tuning.ultimate.icon) \(session.tuning.ultimate.name)：\(session.tuning.ultimate.summary)",
                    question: question,
                    wrongPicks: session.ultimateWrongPicks,
                    onAnswer: session.answerUltimate,
                    onReplay: session.replayPrompt)
            }

            if session.phase == .paused {
                PauseOverlay(onResume: session.togglePause, onExit: onExit)
            }

            if session.phase == .won || session.phase == .lost {
                ResultView(session: session, onReplay: onReplay, onExit: onExit)
            }
        }
        .coordinateSpace(name: "gameLayout")
        .onDisappear { session.end() }
        #if os(iOS)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        #endif
    }
}

private struct BattlefieldView: View {
    @ObservedObject var session: GameSession
    let debugOptions: SpriteView.DebugOptions

    var body: some View {
        GeometryReader { geometry in
            SpriteView(
                scene: session.scene,
                preferredFramesPerSecond: 120,
                debugOptions: debugOptions)
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .aspectRatio(GameScene.designSize.width / GameScene.designSize.height, contentMode: .fit)
    }
}

private struct PlantDrag: Equatable {
    let kind: DefenderKind
    var location: CGPoint
}

private struct PlantDragGhost: View {
    let kind: DefenderKind

    var body: some View {
        HStack(spacing: 8) {
            if let texture = UnitSprites.frames(named: "plant-\(kind.id)").first {
                Image(decorative: texture.cgImage(), scale: 1)
                    .resizable().scaledToFit().frame(width: 54, height: 50)
            }
            Text(kind.name)
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.ink)
        }
        .padding(10)
        .background(Color(red: 0.94, green: 0.88, blue: 0.62), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.accent, lineWidth: 3))
        .shadow(color: .black.opacity(0.25), radius: 10, y: 5)
    }
}

struct GameHUD: View {
    @ObservedObject var session: GameSession
    let onExit: () -> Void

    var body: some View {
        HStack(spacing: 24) {
            if session.phase == .preparing {
                Label("准备", systemImage: "leaf.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.jade)
            } else {
                Button(action: session.togglePause) {
                    Image(systemName: "pause.circle.fill").font(.system(size: 40))
                }
                .buttonStyle(PressableStyle())
                .foregroundStyle(Theme.muted)
            }

            if let hearts = session.hearts, let maxHearts = session.tuning.hearts {
                HStack(spacing: 4) {
                    ForEach(0..<maxHearts, id: \.self) { i in
                        Image(systemName: i < hearts ? "heart.fill" : "heart")
                            .foregroundStyle(Theme.wrong)
                    }
                }
                .font(.title2)
            } else {
                HStack(spacing: 4) {
                    Text("不怕失败").font(.title3.weight(.semibold)).foregroundStyle(Theme.jade)
                    PictureView(emoji: "💪", size: 30)
                }
            }

            Label("\(session.defeated)/\(session.totalEnemies)", systemImage: "flag.fill")
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(Theme.ink)

            Label("\(session.score)", systemImage: "star.fill")
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(Theme.accent)

            SunCounter(amount: session.sun)

            Spacer()

            ItemBar(
                inventory: session.inventory,
                enabled: session.canUseItems,
                onUse: session.useItem(at:))

            UltimateButton(
                energy: session.energy,
                maxEnergy: session.tuning.ultimateEnergy,
                ready: session.ultimateReady,
                action: session.startUltimate)
        }
        .padding(.horizontal, 8)
    }
}

struct PreparationPanel: View {
    @ObservedObject var session: GameSession

    var body: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("准备布阵")
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(Theme.ink)
                Text("把植物卡拖到空草坪。阳光足够就能继续布阵，种下后不能修改，已布阵 \(session.plantedLaneCount)/\(session.tuning.lanes) 路")
                    .font(.headline)
                    .foregroundStyle(Theme.muted)
            }

            Spacer()

            Button(action: session.startBattle) {
                Text(session.canStartBattle ? "开始闯关" : "先种一株植物")
                    .font(.title2.weight(.heavy))
                    .frame(minWidth: 210, minHeight: 58)
                    .background(Capsule().fill(session.canStartBattle ? Theme.jade : Theme.muted.opacity(0.25)))
                    .foregroundStyle(session.canStartBattle ? .white : Theme.muted)
            }
            .buttonStyle(PressableStyle())
            .disabled(!session.canStartBattle)
        }
        .padding(14)
        .background(Color(red: 0.98, green: 0.94, blue: 0.80), in: RoundedRectangle(cornerRadius: 12))
    }
}

/// 道具栏：捡到的道具，点一下就用
struct ItemBar: View {
    let inventory: Inventory
    let enabled: Bool
    let onUse: (Int) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<inventory.capacity, id: \.self) { i in
                let item = i < inventory.items.count ? inventory.items[i] : nil
                Button { onUse(i) } label: {
                    Group {
                        if let item { PictureView(emoji: item.icon, size: 38) } else { Color.clear }
                    }
                        .frame(width: 54, height: 54)
                        .background(RoundedRectangle(cornerRadius: 14).fill(item == nil ? Theme.muted.opacity(0.12) : Theme.card))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(item == nil ? .clear : Theme.jade, lineWidth: 3))
                }
                .buttonStyle(PressableStyle())
                .disabled(item == nil || !enabled)
                .accessibilityLabel(item.map { "\($0.name)，\($0.summary)" } ?? "空道具格")
                .transition(.scale)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: inventory)
    }
}

struct UltimateButton: View {
    let energy: Int
    let maxEnergy: Int
    let ready: Bool
    let action: () -> Void
    @State private var glow = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(ready ? "放大招！" : "大招")
                    .font(.title3.weight(.heavy))
                HStack(spacing: 4) {
                    ForEach(0..<maxEnergy, id: \.self) { i in
                        Circle()
                            .fill(i < energy ? Theme.accent : Theme.muted.opacity(0.25))
                            .frame(width: 14, height: 14)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Capsule().fill(ready ? Theme.accent.opacity(0.25) : Theme.card))
            .overlay(Capsule().stroke(ready ? Theme.accent : Theme.muted.opacity(0.3), lineWidth: 3))
            .foregroundStyle(ready ? Theme.accent : Theme.muted)
            .scaleEffect(ready && glow ? 1.08 : 1)
        }
        .buttonStyle(PressableStyle())
        .disabled(!ready)
        .onChange(of: ready) { _, isReady in
            if isReady {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { glow = true }
            } else {
                glow = false
            }
        }
    }
}

struct UltimateOverlay: View {
    let title: String
    let question: Question
    let wrongPicks: Set<Int>
    let onAnswer: (Int) -> Void
    let onReplay: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 20) {
                Text(title)
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.accent)
                AnswerPanel(question: question, wrongPicks: wrongPicks, onAnswer: onAnswer, onReplay: onReplay)
            }
            .padding(32)
            .frame(maxWidth: 900)
            .background(RoundedRectangle(cornerRadius: 28).fill(Theme.paper))
            .padding(40)
        }
        .transition(.opacity)
    }
}

struct PauseOverlay: View {
    let onResume: () -> Void
    let onExit: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 24) {
                Text("休息一下").font(.system(size: 40, weight: .heavy, design: .rounded))
                Button(action: onResume) {
                    Text("继续").font(.title.weight(.bold)).frame(width: 240, height: 70)
                        .background(Capsule().fill(Theme.jade)).foregroundStyle(.white)
                }
                .buttonStyle(PressableStyle())
                Button(action: onExit) {
                    Text("退出").font(.title2.weight(.semibold)).frame(width: 240, height: 60)
                        .background(Capsule().stroke(Theme.muted, lineWidth: 2)).foregroundStyle(Theme.muted)
                }
                .buttonStyle(PressableStyle())
            }
            .padding(48)
            .background(RoundedRectangle(cornerRadius: 28).fill(Theme.paper))
        }
    }
}
