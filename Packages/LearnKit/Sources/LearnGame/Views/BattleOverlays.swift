import LearnCore
import SwiftUI

struct UltimateOverlay: View {
    let title: String
    let question: Question
    let wrongPicks: Set<Int>
    let onAnswer: (Int) -> Void
    let onReplay: () -> Void
    /// 点空白处或「先不放了」：取消这次大招
    let onCancel: () -> Void
    var retrying = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onCancel)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("取消大招")
            CandyModalCard(
                bannerTitle: title,
                bannerIcon: "⚡️",
                bannerColors: [GrowthColors.lightning, Theme.accent],
                bannerEdge: GrowthColors.lightningDark,
                borderColor: GrowthColors.lightning.opacity(0.8),
                maxWidth: 900
            ) {
                AnswerPanel(question: question, wrongPicks: wrongPicks, onAnswer: onAnswer, onReplay: onReplay, retrying: retrying)
                Button(action: onCancel) {
                    CandyButtonLabel(title: "先不放了", icon: "✕", fill: GrowthColors.surface, edge: GrowthColors.cardEdge,
                                     foreground: Theme.muted, font: .system(size: 18, weight: .heavy, design: .rounded),
                                     height: 46, minWidth: 140)
                        .overlay(Capsule().stroke(GrowthColors.cardEdge, lineWidth: 1.5))
                }
                .buttonStyle(PressableStyle())
                Text(!retrying ? "点空白处也能取消，能量会留着" : "已经答错过，答对或取消都会用掉这次能量")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.muted)
            }
            .padding(40)
        }
        .transition(.opacity)
    }
}

struct PauseOverlay: View {
    let onResume: () -> Void
    /// 结束本局并看结算页
    let onFinish: () -> Void
    /// 直接退出并放弃未结算对局，回到上一页。
    let onQuit: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            CandyModalCard(
                bannerTitle: "休息一下",
                bannerIcon: "⏸️",
                bannerColors: [GrowthColors.gold, Theme.accent],
                bannerEdge: GrowthColors.orangeDark,
                maxWidth: 440
            ) {
                VStack(spacing: 16) {
                    Button(action: onResume) {
                        CandyButtonLabel(title: "继续闯关", icon: "▶", fill: Theme.jade, edge: GrowthColors.jadeDark,
                                         font: .system(size: 26, weight: .heavy, design: .rounded), height: 64, minWidth: 240)
                    }
                    .buttonStyle(PressableStyle())
                    Button(action: onFinish) {
                        CandyButtonLabel(title: "结束并结算", icon: "🏁", fill: GrowthColors.surface, edge: GrowthColors.cardEdge,
                                         foreground: Theme.ink, font: .system(size: 22, weight: .heavy, design: .rounded), height: 56, minWidth: 240)
                            .overlay(Capsule().stroke(GrowthColors.cardEdge, lineWidth: 2))
                    }
                    .buttonStyle(PressableStyle())
                    Button(action: onQuit) {
                        Label("退出游戏", systemImage: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .frame(width: 240, height: 44)
                            .foregroundStyle(Theme.wrong)
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            .padding(24)
        }
    }
}

/// 回合只评分，所有成长奖励留到整局结束。
struct RoundRestOverlay: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var session: GameSession

    private var isReady: Bool { session.restRemaining == 0 }

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 20) {
                        Label("第 \(session.round) 回合完成", systemImage: "checkmark.seal.fill")
                            .font(.largeTitle.bold())
                            .foregroundStyle(Theme.jade)
                        Text("本回合 \(session.roundQuestions) 题 · 评分 \(session.roundScore) · 首答正确率 \(Int((session.roundAccuracy * 100).rounded()))%")
                            .font(.headline)

                        ZStack {
                            Circle().stroke(Theme.jade.opacity(0.15), lineWidth: 8)
                            Circle()
                                .trim(from: 0, to: 1 - min(1, Double(session.restRemaining) / Double(session.rules.restSeconds(afterRound: session.round))))
                                .stroke(Theme.jade, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            VStack(spacing: 2) {
                                if isReady {
                                    Image(systemName: "checkmark").font(.system(size: 44, weight: .bold))
                                    Text("准备好了").font(.subheadline.bold())
                                } else {
                                    Text("\(session.restRemaining)")
                                        .font(.system(size: 44, weight: .bold, design: .rounded))
                                        .monospacedDigit()
                                    Text("秒后可继续").font(.subheadline)
                                }
                            }
                            .foregroundStyle(Theme.jade)
                        }
                        .frame(width: 132, height: 132)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(isReady ? "休息结束，可以开始下一回合" : "休息还剩 \(session.restRemaining) 秒")

                        VStack(spacing: 6) {
                            Text(isReady ? "休息好了，按自己的节奏继续" : "放下屏幕，看看远处，伸个懒腰吧")
                                .font(.system(size: 20, weight: .heavy, design: .rounded))
                            Text("下一回合：第 \(session.round + 1) 回合 · \(session.roundQuestions + session.rules.questionIncrement[session.config.difficulty]) 题")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.muted)
                        }
                        Button(action: session.continueRound) {
                            CandyButtonLabel(
                                title: isReady ? "开始下一回合" : "休息中 · \(session.restRemaining) 秒",
                                icon: isReady ? "▶" : "⏳",
                                fill: isReady ? Theme.jade : GrowthColors.disabledFill,
                                edge: isReady ? GrowthColors.jadeDark : GrowthColors.disabledEdge,
                                foreground: isReady ? .white : Theme.muted,
                                font: .system(size: 22, weight: .heavy, design: .rounded),
                                height: 56,
                                minWidth: 0,
                                expands: true
                            )
                        }
                        .buttonStyle(PressableStyle())
                        .disabled(!isReady)
                        VStack(spacing: 8) {
                            Button(action: session.finishGame) {
                                CandyButtonLabel(
                                    title: "结束并结算",
                                    icon: "🏁",
                                    fill: GrowthColors.surface,
                                    edge: GrowthColors.cardEdge,
                                    foreground: Theme.ink,
                                    font: .system(size: 18, weight: .heavy, design: .rounded),
                                    height: 46,
                                    minWidth: 180
                                )
                                .overlay(Capsule().stroke(GrowthColors.cardEdge, lineWidth: 2))
                            }
                            .buttonStyle(PressableStyle())
                            Text("随时可以结束，积分将在整局结束后统一结算")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.muted)
                        }
                    }
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.ink)
                    .padding(28)
                    .frame(maxWidth: 560)
                    .background(
                        RoundedRectangle(cornerRadius: 28)
                            .fill(Theme.paper)
                            .shadow(color: GrowthColors.cardEdge, radius: 0, x: 0, y: 6)
                    )
                    .overlay(RoundedRectangle(cornerRadius: 28).stroke(GrowthColors.gold.opacity(0.75), lineWidth: 3))
                    .padding(16)
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                }
                .scrollIndicators(.hidden)
            }
        }
        .onAppear { session.updateRest() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { session.updateRest() }
        }
        // 面板离开后自动取消订阅，战斗阶段无需唤醒休息计时器。
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { session.updateRest(now: $0) }
    }
}
