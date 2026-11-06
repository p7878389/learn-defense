import LearnCore
import SpriteKit
import SwiftUI

struct GameView: View {
    @StateObject private var session: GameSession
    @State private var battlefieldFrame: CGRect = .zero
    @State private var activeDrag: PlantDrag?
    /// 本局答题区出现过的最高高度。战场占剩下的高度，答题区变矮时战场会跟着放大，
    /// 所以答题区只增不减；准备阶段先按样题留好高度，开局、答对、换题时画面都不跳
    @State private var answerPanelHeight: CGFloat = 0
    /// 卡牌栏叠在战场上，在它上面松手（含只点一下）算取消
    @State private var seedStripFrame: CGRect = .zero
    let onReplay: () -> Void
    let onExit: () -> Void
    let onOpenCollection: () -> Void

    init(config: GameConfig, model: AppModel, onReplay: @escaping () -> Void, onExit: @escaping () -> Void,
         onOpenCollection: @escaping () -> Void = {}) {
        _session = StateObject(wrappedValue: GameSession(
            config: config,
            library: model.library,
            progress: model.progress(for: config.profileID),
            speech: model.speech,
            growth: model.growth(for: config.profileID),
            recorder: model.recorder(for: config)))
        self.onReplay = onReplay
        self.onExit = onExit
        self.onOpenCollection = onOpenCollection
    }

    private var debugOptions: SpriteView.DebugOptions {
        []
    }

    private var seedPackets: some View {
        SeedPacketStrip(
            kinds: session.tuning.plantable,
            sun: session.sun,
            enabled: session.canUseShop,
            draggingID: activeDrag?.kind.id,
            onDragChanged: { kind, location in
                activeDrag = PlantDrag(kind: kind, location: location)
                session.previewSeed(at: GameScene.scenePoint(at: location, in: battlefieldFrame))
            },
            onDragEnded: { kind, location in
                // 只点一下卡牌、或拖回卡牌栏松手，都当作取消，不提示种错
                if !seedStripFrame.contains(location),
                   let point = GameScene.scenePoint(at: location, in: battlefieldFrame) {
                    _ = session.dropSeed(id: kind.id, at: point)
                }
                session.previewSeed(at: nil)
                activeDrag = nil
            },
            barricade: session.tuning.barricade,
            barricadeEnabled: session.canDropBarricade,
            onBarricade: { session.dropBarricade() })
            .background(
                GeometryReader { proxy in
                    Color.clear.onChange(of: proxy.frame(in: .named("gameLayout")), initial: true) { _, frame in
                        seedStripFrame = frame
                    }
                })
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
                // 战场铺满宽度；卡牌栏、状态栏叠在顶部篱笆上，道具和大招叠在左边房子前，不占草坪
                VStack(spacing: 6) {
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
                        .overlay(alignment: .topLeading) {
                            seedPackets.padding(6)
                        }
                        .overlay(alignment: .topTrailing) {
                            GameHUD(session: session, onExit: onExit).padding(6)
                        }
                        .overlay(alignment: .bottomLeading) {
                            VStack(spacing: 8) {
                                UltimateButton(
                                    energy: session.energy,
                                    maxEnergy: session.tuning.ultimateEnergy,
                                    ready: session.ultimateReady,
                                    action: session.startUltimate)
                                ItemBar(
                                    inventory: session.inventory,
                                    enabled: session.canUseItems,
                                    onUse: session.useItem(at:))
                            }
                            .padding(8)
                        }
                        .layoutPriority(-1)
                    Group {
                        if session.phase == .preparing {
                            PreparationPanel(session: session)
                                .background(alignment: .top) {
                                    // 按本局出题方式量一道答错后的样题，开局前就把答题区的高度留出来
                                    if let sample = session.layoutSample {
                                        AnswerPanel(
                                            question: sample,
                                            // 字块题按答错一次量（多一行提示）
                                            wrongPicks: sample.input != nil ? [1]
                                                : Set(sample.options.indices.filter { $0 != sample.answerIndex }.prefix(1)),
                                            onAnswer: { _ in },
                                            onReplay: {})
                                            .fixedSize(horizontal: false, vertical: true)
                                            .padding(.top, 52) // 预留切题栏，开局时战场不缩放
                                            .modifier(MaxHeightReader(height: $answerPanelHeight))
                                            .opacity(0)
                                            .allowsHitTesting(false)
                                            .accessibilityHidden(true)
                                    }
                                }
                        } else {
                            VStack(spacing: 8) {
                                ScrollView(.horizontal) {
                                    HStack(spacing: 10) {
                                        ForEach(Array(session.questionIDs.enumerated()), id: \.element) { offset, id in
                                            Button("题目 \(offset + 1)") { session.selectQuestion(id) }
                                                .font(.headline)
                                                .padding(.horizontal, 14).padding(.vertical, 8)
                                                .background(session.selectedQuestionID == id ? Theme.jade : Theme.card, in: Capsule())
                                                .foregroundStyle(session.selectedQuestionID == id ? .white : Theme.ink)
                                        }
                                    }
                                }
                                .frame(height: 44)
                                .disabled(session.phase != .playing || session.ultimate != nil)
                                AnswerPanel(
                                    question: session.current,
                                    wrongPicks: session.wrongPicks,
                                    onAnswer: session.answer,
                                    onReplay: session.replayPrompt,
                                    onStartInput: { session.setTyping(true) },
                                    onSubmitInput: session.answerInput)
                                .disabled(session.phase != .playing || session.ultimate != nil)
                            }
                            .modifier(MaxHeightReader(height: $answerPanelHeight))
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: answerPanelHeight)
                    .padding(10)
                    .background(Color(red: 0.98, green: 0.94, blue: 0.80), in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 10)
                    Spacer(minLength: 0)
                }
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
                PauseOverlay(onResume: session.togglePause, onExit: session.finishGame)
            }

            if session.phase == .resting {
                RoundRestOverlay(session: session)
            }

            if session.phase == .won || session.phase == .lost {
                ResultView(session: session, onReplay: onReplay, onExit: onExit, onOpenCollection: onOpenCollection)
            }
        }
        .coordinateSpace(name: "gameLayout")
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { session.updateRest(now: $0) }
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
                .simultaneousGesture(SpatialTapGesture().onEnded { value in
                    guard session.phase == .playing, session.ultimate == nil,
                          let point = GameScene.scenePoint(at: value.location,
                              in: CGRect(origin: .zero, size: geometry.size)) else { return }
                    session.scene.selectTarget(at: point)
                })
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

    /// 叠在战场右上角的状态：暂停、生命、进度、得分。阳光在卡牌栏里，道具和大招在战场左下角
    var body: some View {
        HStack(spacing: 18) {
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

            Label("第 \(session.round) 回合 · \(session.roundResolved)/\(session.totalEnemies)", systemImage: "flag.fill")
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(Theme.ink)

            Label("\(session.score)", systemImage: "star.fill")
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(Theme.accent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Color(red: 0.91, green: 0.80, blue: 0.53).opacity(0.92), in: Capsule())
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
    }
}

/// 量出视图的自然高度，只记下更大的值
private struct MaxHeightReader: ViewModifier {
    @Binding var height: CGFloat

    func body(content: Content) -> some View {
        content.background(
            GeometryReader { proxy in
                Color.clear.onChange(of: proxy.size.height, initial: true) { _, newHeight in
                    height = max(height, newHeight)
                }
            })
    }
}

/// 道具栏：捡到的道具，点一下就用。竖着排在战场左边房子前
struct ItemBar: View {
    let inventory: Inventory
    let enabled: Bool
    let onUse: (Int) -> Void

    var body: some View {
        VStack(spacing: 8) {
            ForEach(0..<inventory.capacity, id: \.self) { i in
                let item = i < inventory.items.count ? inventory.items[i] : nil
                Button { onUse(i) } label: {
                    Group {
                        if let item { PictureView(emoji: item.icon, size: 38) } else { Color.clear }
                    }
                        .frame(width: 54, height: 54)
                        .background(RoundedRectangle(cornerRadius: 14).fill(item == nil ? Theme.card.opacity(0.5) : Theme.card))
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
            // 文字在上、能量点在下，窄一些才放得进房子前
            VStack(spacing: 6) {
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
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 16).fill(ready ? Theme.accent.opacity(0.25) : Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(ready ? Theme.accent : Theme.muted.opacity(0.3), lineWidth: 3))
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
                    Text("结束并结算").font(.title2.weight(.semibold)).frame(width: 240, height: 60)
                        .background(Capsule().stroke(Theme.muted, lineWidth: 2)).foregroundStyle(Theme.muted)
                }
                .buttonStyle(PressableStyle())
            }
            .padding(48)
            .background(RoundedRectangle(cornerRadius: 28).fill(Theme.paper))
        }
    }
}

/// 回合只评分，所有成长奖励留到整局结束。
private struct RoundRestOverlay: View {
    @ObservedObject var session: GameSession

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 18) {
                Text("第 \(session.round) 回合完成").font(.largeTitle.bold())
                Text("本回合评分 \(session.roundScore) · 首答正确率 \(Int((session.roundAccuracy * 100).rounded()))%")
                    .font(.title2)
                Text("本回合 \(session.roundQuestions) 题 · 积分将在整局结束后统一结算")
                    .foregroundStyle(Theme.muted)
                Text(session.restRemaining > 0 ? "休息 \(session.restRemaining) 秒，看看远处吧" : "休息好了，准备下一回合")
                    .font(.title2.bold())
                HStack(spacing: 24) {
                    Button("结束并结算", action: session.finishGame)
                    Button("继续下一回合", action: session.continueRound)
                        .disabled(session.restRemaining > 0)
                }
                .font(.title2.bold())
                .buttonStyle(.borderedProminent)
            }
            .padding(32)
            .background(Theme.paper, in: RoundedRectangle(cornerRadius: 24))
            .padding(24)
        }
    }
}
