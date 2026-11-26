import LearnCore
import SpriteKit
import SwiftUI

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

    private var debugOptions: SpriteView.DebugOptions { [] }

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

    private static let sideTabsWidth: CGFloat = 104

    private var canAnswer: Bool { session.phase == .playing && session.ultimate == nil && !session.isUnleashing }

    /// 场上每只僵尸一道题，点了切到那道
    private var questionTabs: some View {
        ForEach(Array(session.questionIDs.enumerated()), id: \.element) { offset, id in
            let selected = session.selectedQuestionID == id
            Button { session.selectQuestion(id) } label: {
                HStack(spacing: 5) {
                    Circle()
                        .fill(selected ? .white : AppColor.accent)
                        .frame(width: 7, height: 7)
                    Text("题目 \(offset + 1)")
                        .font(AppFont.label)
                }
                .padding(.horizontal, 12)
                .frame(height: 36)
                .padding(.bottom, 3)
                .foregroundStyle(selected ? .white : Theme.ink)
                .background {
                    ZStack {
                        Capsule().fill(selected ? AppColor.jadeEdge : AppColor.cardEdge)
                        Capsule()
                            .fill(selected ? AppColor.jade : AppColor.surface)
                            .overlay(Capsule().strokeBorder(selected ? AppColor.jadeEdge : AppColor.cardStroke, lineWidth: 1.5))
                            .padding(.bottom, 3)
                    }
                }
            }
            .buttonStyle(PressableStyle())
        }
    }

    @ViewBuilder private var answerPanel: some View {
        if session.isUnleashing {
            Label("雷霆正在清场", systemImage: "bolt.fill")
                .font(AppFont.heading)
                .foregroundStyle(Theme.accent)
                .frame(maxWidth: .infinity, minHeight: 120)
        } else {
            let shownQuestion = session.current
            AnswerPanel(
                question: shownQuestion,
                wrongPicks: session.wrongPicks,
                onAnswer: { session.answer($0, questionID: shownQuestion?.id) },
                onReplay: session.replayPrompt,
                onStartInput: {
                    if session.current?.id == shownQuestion?.id { session.setTyping(true) }
                },
                onSubmitInput: { session.answerInput($0, questionID: shownQuestion?.id) },
                compact: !isPortrait, retrying: session.retrying)
            .disabled(!canAnswer)
        }
    }

    var body: some View {
        ZStack {
            GrowthPageBackground()

            if session.isEmpty {
                CandyModalCard(
                    bannerTitle: session.bankConfirmed ? "暂无可用题目" : "请先选择题库",
                    bannerIcon: "📚",
                    maxWidth: 440
                ) {
                    Text(session.bankConfirmed ? "当前范围还没有可以出的题，换一个题库或单元试试吧。" : "首次游戏需要先选择适合的课本和难度。")
                        .font(AppFont.body)
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                    VStack(spacing: 12) {
                        AppButton(title: "选择题库与难度", systemImage: "books.vertical.fill", role: .primary, size: .large, expands: true, action: onChooseBank)
                        AppButton(title: "返回主页", systemImage: "chevron.left", role: .secondary, size: .medium, expands: true, action: onExit)
                    }
                }
                .padding(24)
            } else {
                VStack(spacing: 6) {
                    BattleTopBar(session: session, onExit: onExit) { seedPackets }

                    // 森林木艺细画框装裱战场，让古树秘境草坪具备立体舞台景深
                    BattlefieldView(session: session, debugOptions: debugOptions)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.sm)
                                .strokeBorder(AppColor.woodTop.opacity(0.85), lineWidth: 3)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.sm)
                                .inset(by: 2)
                                .strokeBorder(AppColor.goldLight.opacity(0.35), lineWidth: 1)
                        )
                        .shadow(color: AppColor.warmShadow.opacity(0.18), radius: 10, y: 4)
                        .background(
                            GeometryReader { proxy in
                                Color.clear.onChange(of: proxy.frame(in: .named("gameLayout")), initial: true) { _, frame in
                                    battlefieldFrame = frame
                                }
                            })
                        .overlay { PlantDropHighlight(drag: drag, battlefield: battlefieldFrame) }
                        .padding(.horizontal, 10)
                        .layoutPriority(-1)

                    // 准备与战斗阶段均保留紧凑工具条，确保开战瞬间草坪位置与缩放 0 跳动
                    BattleActionBar(session: session)
                        .padding(.horizontal, 10)

                    Group {
                        if session.phase == .preparing {
                            PreparationPanel(session: session, onChooseBank: onChooseBank, onStart: onRequestStart, bankSummary: bankSummary)
                                .background(alignment: .top) {
                                    if let sample = session.layoutSample {
                                        AnswerPanel(
                                            question: sample,
                                            wrongPicks: sample.input != nil ? [1]
                                                : Set(sample.options.indices.filter { $0 != sample.answerIndex }.prefix(1)),
                                            onAnswer: { _ in },
                                            onReplay: {},
                                            compact: !isPortrait)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .padding(.top, isPortrait ? 52 : 0)
                                            .padding(.leading, isPortrait ? 0 : Self.sideTabsWidth + 14)
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
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 8) { questionTabs }
                                        }
                                        .frame(height: 42)
                                        .disabled(!canAnswer)
                                        answerPanel
                                    }
                                } else {
                                    HStack(alignment: .top, spacing: 14) {
                                        Color.clear.frame(width: Self.sideTabsWidth, height: 0)
                                        answerPanel
                                    }
                                    .overlay(alignment: .topLeading) {
                                        ScrollView(.vertical, showsIndicators: false) {
                                            VStack(alignment: .leading, spacing: 8) { questionTabs }
                                                .padding(6)
                                        }
                                        .frame(width: Self.sideTabsWidth)
                                        .background(RoundedRectangle(cornerRadius: AppRadius.sm).fill(AppColor.surface.opacity(0.65)))
                                        .disabled(!canAnswer)
                                    }
                                }
                            }
                            .modifier(MaxHeightReader(height: $answerPanelHeight, resetKey: isPortrait))
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: answerPanelHeight)
                    .padding(.horizontal, 12)
                    .padding(.vertical, isPortrait ? 10 : 8)
                    .candyCard(fill: GrowthColors.answerTray, radius: AppRadius.md)
                    .padding(.horizontal, 10)
                    .padding(.bottom, isPortrait ? 0 : 6)

                    if !isPortrait {
                        Spacer(minLength: 0)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
                    onAnswer: { session.answerUltimate($0, questionID: question.id) },
                    onReplay: session.replayPrompt,
                    onCancel: session.cancelUltimate,
                    retrying: session.ultimateRetrying)
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
