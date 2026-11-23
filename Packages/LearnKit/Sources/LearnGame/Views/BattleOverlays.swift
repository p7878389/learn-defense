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
    /// 结束本局并看结算页
    let onFinish: () -> Void
    /// 直接退出并放弃未结算对局，回到上一页。
    let onQuit: () -> Void

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
                Button(action: onFinish) {
                    Text("结束并结算").font(.title2.weight(.semibold)).frame(width: 240, height: 60)
                        .background(Capsule().stroke(Theme.muted, lineWidth: 2)).foregroundStyle(Theme.muted)
                }
                .buttonStyle(PressableStyle())
                Button(action: onQuit) {
                    Label("退出游戏", systemImage: "rectangle.portrait.and.arrow.right")
                        .font(.title3.weight(.semibold)).frame(width: 240, height: 52)
                        .foregroundStyle(Theme.wrong)
                }
                .buttonStyle(PressableStyle())
            }
            .padding(48)
            .background(RoundedRectangle(cornerRadius: 28).fill(Theme.paper))
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
                                .font(.title3.bold())
                            Text("下一回合：第 \(session.round + 1) 回合 · \(session.roundQuestions + session.rules.questionIncrement[session.config.difficulty]) 题")
                                .foregroundStyle(Theme.muted)
                        }
                        Button(action: session.continueRound) {
                            Text(isReady ? "开始下一回合" : "休息中 · \(session.restRemaining) 秒")
                                .font(.title2.bold())
                                .frame(maxWidth: .infinity, minHeight: 52)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.jade)
                        .disabled(!isReady)
                        VStack(spacing: 8) {
                            Button("结束并结算", action: session.finishGame)
                                .font(.headline)
                                .buttonStyle(.bordered)
                            Text("随时可以结束，积分将在整局结束后统一结算")
                                .font(.footnote)
                                .foregroundStyle(Theme.muted)
                        }
                    }
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.ink)
                    .padding(28)
                    .frame(maxWidth: 560)
                    .background(Theme.paper, in: RoundedRectangle(cornerRadius: 24))
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
