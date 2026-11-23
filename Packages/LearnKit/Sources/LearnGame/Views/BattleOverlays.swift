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
