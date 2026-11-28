import LearnCore
import SwiftUI

struct UltimateOverlay: View {
    let title: String
    let question: Question
    let wrongPicks: Set<Int>
    let onAnswer: (Int) -> Void
    let onReplay: () -> Void
    let onCancel: () -> Void
    var speechBusy = false
    var voiceListening = false
    var onBeforeListen: () -> Void = {}
    var onListeningChanged: (Bool) -> Void = { _ in }
    var onVoiceMatch: (() -> Void)? = nil
    var retrying = false

    private var lockedOtherControls: Bool { speechBusy || voiceListening }

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            CandyModalCard(
                bannerTitle: title,
                bannerIcon: "⚡️",
                bannerColors: [AppColor.lightning, AppColor.accent],
                bannerEdge: AppColor.lightningDark,
                borderColor: AppColor.lightning.opacity(0.8),
                maxWidth: 900
            ) {
                if let spell = question.speakTarget, let onVoiceMatch {
                    HStack(spacing: AppSpacing.sm) {
                        Text("⚡️ 大声念出咒语「\(spell)」直接清场，或点选下方答案")
                            .font(AppFont.bodyStrong)
                            .foregroundStyle(AppColor.ink)
                        VoiceSpeakButton(
                            title: "大声念咒语",
                            expected: spell,
                            english: question.isEnglishSpeaking,
                            resetKey: question.id,
                            speechLocked: speechBusy,
                            onBeforeListen: onBeforeListen,
                            onListeningChanged: onListeningChanged,
                            onMatched: onVoiceMatch
                        )
                    }
                    .padding(.horizontal, AppSpacing.md).padding(.vertical, AppSpacing.xs)
                    .appInset(radius: AppRadius.md, tint: AppColor.gold)
                }
                AnswerPanel(
                    question: question,
                    wrongPicks: wrongPicks,
                    onAnswer: onAnswer,
                    onReplay: onReplay,
                    retrying: retrying,
                    speechBusy: speechBusy,
                    voiceListening: voiceListening
                )
                AppButton(title: "先不放了", systemImage: "xmark", role: .secondary, size: .medium, minWidth: 140, action: onCancel)
                    .disabled(lockedOtherControls)
                Text(!retrying ? "点「先不放了」可取消，能量会留着下次用" : "已经答错过，答对或取消都会用掉这次能量")
                    .font(AppFont.label)
                    .foregroundStyle(AppColor.muted)
            }
            .padding(40)
        }
        .transition(.opacity)
    }
}

struct PauseOverlay: View {
    let onResume: () -> Void
    let onFinish: () -> Void
    let onQuit: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            CandyModalCard(
                bannerTitle: "休息一下",
                bannerIcon: "⏸️",
                bannerColors: [AppColor.gold, AppColor.accent],
                bannerEdge: AppColor.accentEdge,
                maxWidth: 440
            ) {
                VStack(spacing: AppSpacing.sm) {
                    AppButton(title: "继续闯关", systemImage: "play.fill", role: .primary, size: .large, expands: true, action: onResume)
                    AppButton(title: "结束并结算", systemImage: "flag.checkered", role: .secondary, size: .large, expands: true, action: onFinish)
                    AppButton(title: "退出游戏", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive, size: .large, expands: true, action: onQuit)
                }
            }
            .padding(AppSpacing.lg)
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
                    CandyModalCard(
                        bannerTitle: "第 \(session.round) 回合完成",
                        bannerIcon: "🎉",
                        bannerColors: [AppColor.jadeTop, AppColor.jadeBottom],
                        bannerEdge: AppColor.jadeEdge,
                        borderColor: AppColor.jade.opacity(0.65),
                        maxWidth: 560
                    ) {
                        Text("本回合 \(session.roundQuestions) 题 · 评分 \(session.roundScore) · 首答正确率 \(Int((session.roundAccuracy * 100).rounded()))%")
                            .font(AppFont.bodyStrong)
                            .foregroundStyle(AppColor.ink)

                        ZStack {
                            Circle().stroke(AppColor.jade.opacity(0.15), lineWidth: 8)
                            Circle()
                                .trim(from: 0, to: 1 - min(1, Double(session.restRemaining) / Double(session.rules.restSeconds(afterRound: session.round))))
                                .stroke(AppColor.jade, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            VStack(spacing: 2) {
                                if isReady {
                                    Image(systemName: "checkmark").font(AppFont.rounded(42, weight: .black))
                                    Text("准备好了").font(AppFont.label)
                                } else {
                                    Text("\(session.restRemaining)").font(AppFont.digits(42, weight: .black))
                                    Text("秒后可继续").font(AppFont.caption)
                                }
                            }
                            .foregroundStyle(AppColor.jade)
                        }
                        .frame(width: 132, height: 132)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(isReady ? "休息结束，可以开始下一回合" : "休息还剩 \(session.restRemaining) 秒")

                        VStack(spacing: 6) {
                            Text(isReady ? "休息好了，按自己的节奏继续" : "看看远处，顺便听听本回合的词卡吧")
                                .font(AppFont.heading)
                            Text("下一回合：第 \(session.round + 1) 回合 · \(session.roundQuestions + session.rules.questionIncrement[session.config.difficulty]) 题")
                                .font(AppFont.label)
                                .foregroundStyle(AppColor.muted)
                        }

                        RoundRestFlashcardView(session: session)

                        AppButton(
                            title: isReady ? "开始下一回合" : "休息中 · \(session.restRemaining) 秒",
                            systemImage: isReady ? "play.fill" : "hourglass",
                            role: .primary,
                            size: .large,
                            expands: true,
                            action: session.continueRound
                        )
                        .disabled(!isReady || session.isInteractionLocked)

                        VStack(spacing: AppSpacing.xs) {
                            AppButton(title: "结束并结算", systemImage: "flag.checkered", role: .secondary, size: .medium, minWidth: 180, action: session.finishGame)
                                .disabled(session.isInteractionLocked)
                            Text("随时可以结束，积分将在整局结束后统一结算")
                                .font(AppFont.caption)
                                .foregroundStyle(AppColor.muted)
                        }
                    }
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppColor.ink)
                    .padding(.top, 26)
                    .padding(AppSpacing.md)
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                }
                .scrollIndicators(.hidden)
            }
        }
        .onAppear { session.updateRest() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { session.updateRest() }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { session.updateRest(now: $0) }
    }
}
