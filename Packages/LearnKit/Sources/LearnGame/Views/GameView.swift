import LearnCore
import SpriteKit
import SwiftUI

struct GameView: View {
    @StateObject private var session: GameSession
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
            recorder: model.recorder(for: config),
            map: UserDefaults.standard.string(forKey: BattleMap.preferenceKey).flatMap(BattleMap.init(rawValue:)) ?? .woodland))
        self.onReplay = onReplay
        self.onExit = onExit
        self.onOpenCollection = onOpenCollection
    }

    var body: some View {
        BattleScreen(session: session, onReplay: onReplay, onExit: onExit, onOpenCollection: onOpenCollection)
    }
}

/// 完整战斗界面，由 GameView 持有的对局状态驱动。
struct BattleScreen: View {
    @ObservedObject var session: GameSession
    @State private var battlefieldFrame: CGRect = .zero
    @State private var activeDrag: PlantDrag?
    /// 本局答题区出现过的最高高度。战场占剩下的高度，答题区变矮时战场会跟着放大，
    /// 所以答题区只增不减；准备阶段先按样题留好高度，开局、答对、换题时画面都不跳
    @State private var answerPanelHeight: CGFloat = 0
    /// 在卡牌栏上松手（含只点一下）算取消，拖动坐标始终使用 gameLayout
    @State private var seedStripFrame: CGRect = .zero
    /// 竖屏时答题栏使用纵向布局；顶部工具栏自行按可用宽度换行
    @State private var isPortrait = false
    let onReplay: () -> Void
    let onExit: () -> Void
    let onOpenCollection: () -> Void

    private var debugOptions: SpriteView.DebugOptions {
        []
    }

    private var seedPackets: some View {
        SeedPacketStrip(
            kinds: session.tuning.plantable,
            sun: session.sun,
            enabled: session.canUseShop,
            draggingID: activeDrag?.kind.id,
            skins: session.loadout.defenderSkins,
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

    /// 横屏时左边竖排切题栏的宽度
    private static let sideTabsWidth: CGFloat = 96

    private var canAnswer: Bool { session.phase == .playing && session.ultimate == nil && !session.isUnleashing }

    /// 场上每只僵尸一道题，点了切到那道
    private var questionTabs: some View {
        ForEach(Array(session.questionIDs.enumerated()), id: \.element) { offset, id in
            Button("题目 \(offset + 1)") { session.selectQuestion(id) }
                .font(.headline)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(session.selectedQuestionID == id ? Theme.jade : Theme.card, in: Capsule())
                .foregroundStyle(session.selectedQuestionID == id ? .white : Theme.ink)
        }
    }

    @ViewBuilder private var answerPanel: some View {
        if session.isUnleashing {
            Label("雷霆正在清场", systemImage: "bolt.fill")
                .font(.title2.weight(.bold))
                .foregroundStyle(Theme.accent)
                .frame(maxWidth: .infinity, minHeight: 120)
        } else {
            AnswerPanel(
                question: session.current,
                wrongPicks: session.wrongPicks,
                onAnswer: session.answer,
                onReplay: session.replayPrompt,
                onStartInput: { session.setTyping(true) },
                onSubmitInput: session.answerInput,
                compact: !isPortrait)
            .disabled(!canAnswer)
        }
    }

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()

            if session.isEmpty {
                VStack(spacing: 20) {
                    Text("这里还没有可以出的题").font(.title)
                    Button("返回", action: onExit).font(.title2)
                }
            } else {
                // 工具栏与操作栏独立排布，种植区保持完整；战场使用剩余可用空间
                VStack(spacing: 6) {
                    BattleTopBar(session: session, onExit: onExit) { seedPackets }
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
                        .layoutPriority(-1)
                    BattleActionBar(session: session)
                        .padding(.horizontal, 10)
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
                                            onReplay: {},
                                            compact: !isPortrait)
                                            .fixedSize(horizontal: false, vertical: true)
                                            // 预留切题栏（竖屏在上面，横屏在左边），开局时战场不缩放
                                            .padding(.top, isPortrait ? 52 : 0)
                                            .padding(.leading, isPortrait ? 0 : Self.sideTabsWidth + 12)
                                            .modifier(MaxHeightReader(height: $answerPanelHeight, resetKey: isPortrait))
                                            .opacity(0)
                                            .allowsHitTesting(false)
                                            .accessibilityHidden(true)
                                    }
                                }
                        } else {
                            Group {
                                if isPortrait {
                                    VStack(spacing: 8) {
                                        ScrollView(.horizontal) {
                                            HStack(spacing: 10) { questionTabs }
                                        }
                                        .frame(height: 44)
                                        .disabled(!canAnswer)
                                        answerPanel
                                    }
                                } else {
                                    // 横屏高度紧：切题栏竖排在左边，答题区少占一行，战场才能铺满宽度。
                                    // 切题栏放在 overlay 里，高度跟着答题区走，题多了就上下滚
                                    HStack(alignment: .top, spacing: 12) {
                                        Color.clear.frame(width: Self.sideTabsWidth, height: 0)
                                        answerPanel
                                    }
                                    .overlay(alignment: .topLeading) {
                                        ScrollView(.vertical) {
                                            VStack(alignment: .leading, spacing: 8) { questionTabs }
                                        }
                                        .frame(width: Self.sideTabsWidth)
                                        .disabled(!canAnswer)
                                    }
                                }
                            }
                            .modifier(MaxHeightReader(height: $answerPanelHeight, resetKey: isPortrait))
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: answerPanelHeight)
                    .padding(.horizontal, 10)
                    .padding(.vertical, isPortrait ? 10 : 6)
                    .background(Color(red: 0.98, green: 0.94, blue: 0.80), in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 10)
                    .padding(.bottom, isPortrait ? 0 : 6)
                    // 竖屏时战场宽度到头，下面会空出一大块，去掉占位让战场和答题区整体居中
                    if !isPortrait {
                        Spacer(minLength: 0)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                // 横屏高度紧：底部的系统安全区也给答题区用（横条已隐藏），多出来的高度让给战场
                .ignoresSafeArea(.container, edges: isPortrait ? [] : .bottom)
            }

            if let drag = activeDrag {
                PlantDragGhost(kind: drag.kind, skin: session.loadout.defenderSkins[drag.kind.id])
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
                    onReplay: session.replayPrompt,
                    onCancel: session.cancelUltimate)
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
        .onChange(of: session.map) { _, map in
            UserDefaults.standard.set(map.rawValue, forKey: BattleMap.preferenceKey)
        }
        .background(
            GeometryReader { proxy in
                Color.clear.onChange(of: proxy.size, initial: true) { _, size in
                    isPortrait = size.height > size.width
                }
            })
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
    let skin: CharacterSkin?

    var body: some View {
        HStack(spacing: 8) {
            if let image = UnitSprites.portrait(of: kind, skin: skin) {
                Image(decorative: image, scale: 1)
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

    /// 顶部状态栏：暂停、生命、回合进度和得分；阳光在同一工具区的种植卡栏里。
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
        VStack(alignment: .leading, spacing: 12) {
            BattleMapPicker(selection: session.map, onSelect: session.selectMap)
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("准备布阵")
                        .font(.title2.weight(.heavy))
                        .foregroundStyle(Theme.ink)
                    Text("把植物卡拖到战场空位。阳光足够就能继续布阵，种下后不能修改，已布阵 \(session.plantedLaneCount)/\(session.tuning.lanes) 路")
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
}

/// 量出视图的自然高度，只记下更大的值
private struct MaxHeightReader: ViewModifier {
    @Binding var height: CGFloat
    /// 转屏后布局换了，之前量的最高值不再适用：这个值一变就按新布局重新记
    var resetKey = false

    func body(content: Content) -> some View {
        content.background(
            GeometryReader { proxy in
                Color.clear
                    .onChange(of: proxy.size.height, initial: true) { _, newHeight in
                        height = max(height, newHeight)
                    }
                    .onChange(of: resetKey) { _, _ in
                        height = proxy.size.height
                    }
            })
    }
}

/// 道具栏：捡到的道具，点一下就用。只显示手里有的道具；
/// 不止一个时折叠成一个按钮，点开向下展开，免得一长条挡住左边的僵尸和血量
struct ItemBar: View {
    let inventory: Inventory
    let enabled: Bool
    let onUse: (Int) -> Void
    var horizontal = false
    @State private var expanded = false

    private var folds: Bool { !horizontal && inventory.items.count > 1 }

    var body: some View {
        let layout = horizontal ? AnyLayout(HStackLayout(alignment: .center, spacing: 8))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
        layout {
            if folds {
                Button { expanded.toggle() } label: {
                    HStack(spacing: 4) {
                        PictureView(emoji: "🎒", size: 30)
                        Text("×\(inventory.items.count)")
                            .font(.system(size: 18, weight: .heavy, design: .rounded).monospacedDigit())
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14, weight: .heavy))
                    }
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 10)
                    .frame(height: 54)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.jade, lineWidth: 3))
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(expanded ? "收起道具" : "展开道具，共 \(inventory.items.count) 个")
            }
            if !folds || expanded {
                ForEach(Array(inventory.items.enumerated()), id: \.offset) { i, item in
                    Button { onUse(i) } label: {
                        PictureView(emoji: item.icon, size: 38)
                            .frame(width: 54, height: 54)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.jade, lineWidth: 3))
                    }
                    .buttonStyle(PressableStyle())
                    .disabled(!enabled)
                    .accessibilityLabel("\(item.name)，\(item.summary)")
                    .transition(.scale(scale: 0.6, anchor: .top).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: inventory)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: expanded)
        .onChange(of: folds) { _, nowFolds in
            if !nowFolds { expanded = false }
        }
    }
}

struct UltimateButton: View {
    let energy: Int
    let maxEnergy: Int
    let ready: Bool
    let action: () -> Void
    var casting = false
    @State private var glow = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var shownEnergy: Int { min(max(0, energy), max(0, maxEnergy)) }
    private var lightning: Color { Color(red: 0.12, green: 0.72, blue: 0.95) }

    private let bronze = Color(red: 0.54, green: 0.28, blue: 0.08)

    private var meter: some View {
        HStack(spacing: 1.5) {
            ForEach(0..<max(0, maxEnergy), id: \.self) { i in
                Capsule()
                    .fill(LinearGradient(colors: i < shownEnergy
                        ? [Color(red: 0.58, green: 1, blue: 1), lightning, Color(red: 0, green: 0.68, blue: 0.82)]
                        : [.white.opacity(0.85), Color(red: 0.7, green: 0.69, blue: 0.66)],
                        startPoint: .top, endPoint: .bottom))
                    .overlay(alignment: .top) {
                        Capsule().fill(.white.opacity(0.6)).frame(height: 3).padding(.horizontal, 2).padding(.top, 2)
                    }
                    .overlay(Capsule().stroke(i < shownEnergy ? Color(red: 0, green: 0.48, blue: 0.6) : bronze.opacity(0.4), lineWidth: 0.8))
            }
        }
        .padding(2)
        .frame(height: 12)
        .background(Color(red: 0.25, green: 0.32, blue: 0.32), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.9), lineWidth: 1))
        .shadow(color: ready ? lightning.opacity(0.55) : .clear, radius: 4)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: shownEnergy)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                ZStack(alignment: .topLeading) {
                    if let image = ThunderArtwork.image(.button) {
                        Image(decorative: image, scale: 1)
                            .resizable()
                            .frame(width: 160, height: 160 / 3)
                    }
                    VStack(spacing: 3) {
                        HStack(spacing: 2) {
                            Text(casting ? "释放中" : ready ? "雷霆就绪" : "蓄力中")
                                .font(.system(size: 12, weight: .black, design: .rounded))
                            Spacer(minLength: 0)
                            Text("\(shownEnergy)/\(max(0, maxEnergy))")
                                .font(.system(size: 10, weight: .heavy).monospacedDigit())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4).padding(.vertical, 1)
                                .background(bronze, in: Capsule())
                        }
                        .foregroundStyle(Color(red: 0.31, green: 0.12, blue: 0.04))
                        meter
                    }
                    .frame(width: 97)
                    .offset(x: 49, y: 11)
                }
                .frame(width: 160, height: 160 / 3)
                Text(casting ? "雷霆降临" : ready ? "点按挑战" : "答对一题 +1 能量")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(ready ? Theme.ink : bronze)
                    .fixedSize()
                    .frame(height: 14)
                    .padding(.top, 1)
            }
            .compositingGroup()
            .shadow(color: ready ? lightning.opacity(glow ? 0.6 : 0.2) : .clear, radius: ready ? 7 : 0)
            .scaleEffect(ready && glow && !reduceMotion ? 1.025 : 1)
        }
        .buttonStyle(PressableStyle())
        .disabled(!ready || casting)
        .accessibilityLabel("雷霆大招")
        .accessibilityValue("能量 \(shownEnergy)/\(max(0, maxEnergy))，\(casting ? "释放中" : ready ? "已就绪" : "蓄力中")")
        .accessibilityHint(casting ? "雷霆演出进行中" : ready ? "点按进入挑战，首次答对释放雷霆" : "答对题目积攒能量")
        .onChange(of: ready, initial: true) { _, isReady in
            glow = false
            if isReady && !reduceMotion {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { glow = true }
            }
        }
        .onChange(of: reduceMotion) { _, reduced in
            if reduced { glow = false }
        }
    }
}

struct UltimateOverlay: View {
    let title: String
    let question: Question
    let wrongPicks: Set<Int>
    let onAnswer: (Int) -> Void
    let onReplay: () -> Void
    /// 点空白处或「先不放了」：取消这次大招
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onCancel)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("取消大招")
            VStack(spacing: 20) {
                Text(title)
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.accent)
                AnswerPanel(question: question, wrongPicks: wrongPicks, onAnswer: onAnswer, onReplay: onReplay)
                Button(action: onCancel) {
                    Label("先不放了", systemImage: "xmark.circle.fill")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.muted)
                }
                .buttonStyle(.plain)
                Text(wrongPicks.isEmpty ? "点空白处也能取消，能量会留着" : "已经答错过，取消后这次能量就用掉了")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.muted)
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
