import LearnCore
import SwiftUI

import SpriteKit

/// 完整战斗界面，由 GameView 持有的对局状态驱动。
struct BattleScreen: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var session: GameSession
    @State private var battlefieldFrame: CGRect = .zero
    /// 拖动中的植物卡；位置只给跟手预览和战场描边读，拖动时整个战斗界面不跟着重算
    @State private var drag = PlantDragState()
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
    var onChooseBank: () -> Void = {}
    var onRequestStart: (() -> Void)? = nil
    var bankSummary: String? = nil

    private var debugOptions: SpriteView.DebugOptions {
        []
    }

    private var seedPackets: some View {
        SeedPacketStrip(
            kinds: session.plantable,
            sun: session.sun,
            enabled: session.canUseShop,
            draggingID: drag.kind?.id,
            skins: session.loadout.defenderSkins,
            onDragChanged: { kind, location in
                if drag.kind != kind { drag.kind = kind }
                drag.location = location
                session.previewSeed(at: GameScene.scenePoint(at: location, in: battlefieldFrame))
            },
            onDragEnded: { kind, location in
                // 只点一下卡牌、或拖回卡牌栏松手，都当作取消，不提示种错
                if !seedStripFrame.contains(location),
                   let point = GameScene.scenePoint(at: location, in: battlefieldFrame) {
                    _ = session.dropSeed(id: kind.id, at: point)
                }
                session.previewSeed(at: nil)
                drag.kind = nil
            },
            barricade: session.tuning.barricade,
            barricadeEnabled: session.canDropBarricade,
            onBarricade: { session.dropBarricade() }, cooldowns: [AdventureDoom.id: session.doomCooldown])
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
                    Text(session.bankConfirmed ? "这里还没有可以出的题" : "首次游戏，请先选择题库").font(.title)
                    Button("选择题库与难度", action: onChooseBank).buttonStyle(.borderedProminent).tint(Theme.jade)
                    Button("返回", action: onExit).font(.title2)
                }
            } else {
                // 工具栏与操作栏独立排布，种植区保持完整；战场使用剩余可用空间
                VStack(spacing: 6) {
                    BattleTopBar(session: session, onExit: onExit) { seedPackets }
                    BattlefieldView(session: session, debugOptions: debugOptions)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .background(
                            // 直接记下战场位置；用 PreferenceKey 传到外层时真机上一直是 .zero
                            GeometryReader { proxy in
                                Color.clear.onChange(of: proxy.frame(in: .named("gameLayout")), initial: true) { _, frame in
                                    battlefieldFrame = frame
                                }
                            })
                        .overlay { PlantDropHighlight(drag: drag, battlefield: battlefieldFrame) }
                        // 和上下的道具栏、答题区一样左右各留 10，宽度对齐
                        .padding(.horizontal, 10)
                        .layoutPriority(-1)
                    BattleActionBar(session: session)
                        .padding(.horizontal, 10)
                    Group {
                        if session.phase == .preparing {
                            PreparationPanel(session: session, onChooseBank: onChooseBank, onStart: onRequestStart, bankSummary: bankSummary)
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

            if let kind = drag.kind {
                PlantDragFollower(drag: drag, kind: kind, skin: session.loadout.defenderSkins[kind.id])
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
                PauseOverlay(onResume: session.togglePause, onFinish: session.finishGame, onQuit: onExit)
            }

            if session.phase == .resting {
                RoundRestOverlay(session: session)
            }

            if session.phase == .won || session.phase == .lost {
                ResultView(session: session, onReplay: onReplay, onExit: onExit, onOpenCollection: onOpenCollection)
            }
        }
        .coordinateSpace(name: "gameLayout")
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { session.suspend() }
        }
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
        .onDisappear {
            if scenePhase == .active { session.end() }
            else { session.suspend() }
        }
        #if os(iOS)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        #endif
    }
}
