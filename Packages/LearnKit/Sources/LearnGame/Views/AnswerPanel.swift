import LearnCore
import SwiftUI

/// 题目和选项按钮。答错只标记已选错项，不揭晓答案。
struct AnswerPanel: View {
    let question: Question?
    let wrongPicks: Set<Int>
    let onAnswer: (Int) -> Void
    let onReplay: () -> Void
    /// 字块题：点下第一块时通知（战场放慢），拼满时交卷
    var onStartInput: () -> Void = {}
    var onSubmitInput: ([String]) -> Void = { _ in }
    /// 横屏时答题区要矮，行距收紧，战场才能铺满宽度
    var compact = false
    var retrying = false
    /// 答错换题时展示上一题的简短纠偏
    var mistakeTip: String? = nil
    /// 开口暴击：孩子大声读出目标词即可答对并额外赢阳光
    var speechBusy = false
    var voiceListening = false
    var onBeforeListen: () -> Void = {}
    var onListeningChanged: (Bool) -> Void = { _ in }
    var onVoiceMatch: (() -> Void)? = nil
    /// 换题瞬间短暂防连点保护，防止双击慢抬手直接误判新题
    @State private var transitionLocked = false

    private var revealed: Bool { !wrongPicks.isEmpty }
    private var otherControlsLocked: Bool { speechBusy || voiceListening }

    var body: some View {
        VStack(spacing: compact ? AppSpacing.xs : AppSpacing.sm) {
            if let q = question, let spec = q.input {
                header(q)
                TileAnswerView(spec: spec, wrongCount: wrongPicks.count, compact: compact, onStart: onStartInput,
                               onSubmit: { values in guard !transitionLocked, !otherControlsLocked else { return }; onSubmitInput(values) })
                    .disabled(otherControlsLocked)
                    .opacity(otherControlsLocked ? 0.58 : 1)
                    .id(q.id)
            } else if let q = question {
                header(q)
                HStack(spacing: AppSpacing.sm) {
                    ForEach(q.options.indices, id: \.self) { i in
                        OptionButton(text: q.options[i], style: q.optionStyle, state: state(of: i, in: q)) {
                            guard !transitionLocked, !otherControlsLocked else { return }
                            onAnswer(i)
                        }
                        .disabled(otherControlsLocked)
                        .opacity(otherControlsLocked ? 0.6 : 1)
                    }
                }
                .id(q.id)
                if revealed {
                    Text("再想一想，试试其他选项")
                        .font(AppFont.bodyStrong)
                        .foregroundStyle(AppColor.muted)
                }
            } else {
                Text(speechBusy ? "🔊 正在朗读，准备下一题…" : "僵尸马上就来，准备答题！")
                    .font(AppFont.heading)
                    .foregroundStyle(speechBusy ? AppColor.jadeEdge : AppColor.muted)
                    .frame(maxWidth: .infinity, minHeight: 120)
            }
            if speechBusy, question != nil {
                Label("正在朗读，听完再操作哦…", systemImage: "speaker.wave.2.fill")
                    .font(AppFont.label)
                    .foregroundStyle(AppColor.jadeEdge)
            } else if voiceListening, question != nil {
                Label("正在听你大声读，请说完或点按钮停止", systemImage: "mic.fill")
                    .font(AppFont.label)
                    .foregroundStyle(AppColor.accentEdge)
            }
            if retrying {
                HStack(spacing: AppSpacing.sm) {
                    Label("刚才答错了，已换成新题，看清再选哦", systemImage: "arrow.triangle.2.circlepath")
                        .font(AppFont.bodyStrong)
                        .foregroundStyle(AppColor.dangerText)
                    if let tip = mistakeTip {
                        Text(tip)
                            .font(AppFont.label)
                            .foregroundStyle(AppColor.jadeEdge)
                            .padding(.horizontal, AppSpacing.xs).padding(.vertical, 3)
                            .background(Capsule().fill(AppColor.jade.opacity(0.14)))
                            .lineLimit(1)
                    }
                }
                .modifier(Shake(animatableData: transitionLocked ? 1 : 0))
            }
        }
        .onChange(of: question?.id) { oldID, newID in
            guard oldID != nil, newID != nil, oldID != newID else { return }
            transitionLocked = true
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(360))
                transitionLocked = false
            }
        }
        .animation(.easeOut(duration: 0.2), value: wrongPicks)
    }

    private func header(_ q: Question) -> some View {
        HStack(alignment: .center, spacing: AppSpacing.md) {
            Text(q.instruction)
                .font(AppFont.bodyStrong)
                .foregroundStyle(AppColor.muted)
            if q.prompt != "🔊", Pictures.image(q.prompt) != nil {
                PictureView(emoji: q.prompt, size: 70)
            } else if q.prompt != "🔊" {
                Text(q.prompt)
                    .font(AppFont.rounded(q.prompt.count > 10 ? 26 : 38, weight: .black))
                    .foregroundStyle(AppColor.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
            }
            if let hint = q.hint {
                Text(hint)
                    .font(AppFont.bodyStrong)
                    .foregroundStyle(AppColor.jadeEdge)
                    .padding(.horizontal, AppSpacing.sm).padding(.vertical, AppSpacing.xxs)
                    .background(Capsule().fill(AppColor.jade.opacity(0.14)))
            }
            if q.promptSpeech != nil {
                AppButton(title: "再听一遍", systemImage: "speaker.wave.2.fill", role: .secondary, size: .medium, action: onReplay)
                    .disabled(otherControlsLocked)
            }
            if let target = q.speakTarget, let onVoiceMatch {
                VoiceSpeakButton(
                    title: "读出来 +15☀️",
                    expected: target,
                    english: q.isEnglishSpeaking,
                    resetKey: q.id,
                    speechLocked: speechBusy,
                    onBeforeListen: onBeforeListen,
                    onListeningChanged: onListeningChanged,
                    onMatched: {
                        guard !transitionLocked, !speechBusy else { return }
                        onVoiceMatch()
                    }
                )
            }
        }
    }

    func state(of index: Int, in q: Question) -> OptionButton.State {
        if wrongPicks.contains(index) { return .wrong }
        return .normal
    }
}

struct OptionButton: View {
    enum State {
        case normal, wrong, reveal
    }

    let text: String
    let style: OptionStyle
    let state: State
    let action: () -> Void

    private var fontSize: CGFloat {
        switch style {
        case .pinyin: 40
        case .text: text.count > 4 ? 30 : 42
        }
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: AppRadius.lg)
        let lip: CGFloat = state == .wrong ? 0 : 4
        Button(action: action) {
            label
                .padding(.horizontal, AppSpacing.sm)
                .frame(maxWidth: .infinity, minHeight: 84)
                .padding(.bottom, lip)
                .background {
                    ZStack {
                        if lip > 0 {
                            shape.fill(edgeColor)
                                .shadow(color: AppColor.warmShadow.opacity(0.10), radius: 6, y: 3)
                        }
                        shape
                            .fill(
                                LinearGradient(
                                    colors: [topFill, bottomFill],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            .overlay(
                                shape.strokeBorder(
                                    LinearGradient(colors: [.white.opacity(0.85), .clear], startPoint: .top, endPoint: .center),
                                    lineWidth: 1.5
                                )
                            )
                            .overlay(shape.strokeBorder(borderColor, lineWidth: state == .reveal ? 3.5 : 1.8))
                            .padding(.bottom, lip)
                    }
                }
        }
        .buttonStyle(PressableStyle())
        .disabled(state == .wrong)
        .opacity(state == .wrong ? 0.52 : 1)
        .modifier(Shake(animatableData: state == .wrong ? 1 : 0))
        .scaleEffect(state == .reveal ? 1.04 : 1)
    }

    private var label: some View {
        Text(text)
            .font(AppFont.rounded(fontSize, weight: .heavy))
            .lineLimit(text.count > 10 ? 2 : 1)
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.5)
            .foregroundStyle(AppColor.ink)
    }

    private var topFill: Color {
        switch state {
        case .normal: AppColor.surface
        case .wrong: AppColor.dangerFill
        case .reveal: AppColor.meadow
        }
    }

    private var bottomFill: Color {
        switch state {
        case .normal: AppColor.surfaceBottom
        case .wrong: AppColor.dangerFill
        case .reveal: AppColor.jade.opacity(0.24)
        }
    }

    private var borderColor: Color {
        switch state {
        case .normal: AppColor.cardStroke
        case .wrong: AppColor.dangerText
        case .reveal: AppColor.jade
        }
    }

    private var edgeColor: Color {
        switch state {
        case .normal: AppColor.cardEdge
        case .wrong: .clear
        case .reveal: AppColor.jadeEdge
        }
    }
}
