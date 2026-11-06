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

    private var revealed: Bool { !wrongPicks.isEmpty }

    var body: some View {
        VStack(spacing: compact ? 8 : 14) {
            if let q = question, let spec = q.input {
                header(q)
                TileAnswerView(spec: spec, wrongCount: wrongPicks.count, compact: compact, onStart: onStartInput, onSubmit: onSubmitInput)
            } else if let q = question {
                header(q)
                HStack(spacing: 16) {
                    ForEach(q.options.indices, id: \.self) { i in
                        OptionButton(text: q.options[i], style: q.optionStyle, state: state(of: i, in: q)) {
                            onAnswer(i)
                        }
                    }
                }
                if revealed {
                    Text("再想一想，试试其他选项")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(Theme.muted)
                }
            } else {
                Text("僵尸马上就来，准备答题！")
                    .font(.title2)
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity, minHeight: 120)
            }
        }
        .id(question?.id)
        .animation(.easeOut(duration: 0.2), value: wrongPicks)
    }

    private func header(_ q: Question) -> some View {
        HStack(alignment: .center, spacing: 18) {
            Text(q.instruction)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.muted)
            if q.promptSpeech == nil, Pictures.image(q.prompt) != nil {
                PictureView(emoji: q.prompt, size: 72)
            } else if q.promptSpeech == nil {
                Text(q.prompt)
                    .font(.system(size: q.prompt.count > 10 ? 26 : 38, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
            }
            if let hint = q.hint {
                Text(hint)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(Theme.accent)
            }
            if q.promptSpeech != nil {
                Button(action: onReplay) {
                    Label("再听一遍", systemImage: "speaker.wave.2.fill")
                        .font(.title2.weight(.bold))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Theme.accent))
                        .foregroundStyle(.white)
                }
                .buttonStyle(PressableStyle())
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
        case .emoji: 64
        case .pinyin: 40
        case .text: text.count > 4 ? 30 : 44
        }
    }

    var body: some View {
        Button(action: action) {
            label
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, minHeight: style == .emoji ? 116 : 86)
                .background(RoundedRectangle(cornerRadius: 22).fill(background))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(border, lineWidth: state == .reveal ? 5 : 2))
                .shadow(color: .black.opacity(0.08), radius: 4, y: 3)
        }
        .buttonStyle(PressableStyle())
        .disabled(state == .wrong)
        .opacity(state == .wrong ? 0.45 : 1)
        .modifier(Shake(animatableData: state == .wrong ? 1 : 0))
        .scaleEffect(state == .reveal ? 1.05 : 1)
    }

    @ViewBuilder
    private var label: some View {
        if style == .emoji {
            PictureView(emoji: text, size: 92)
        } else {
            // 句子意思这类长选项可以折成两行
            Text(text)
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .lineLimit(text.count > 10 ? 2 : 1)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)
                .foregroundStyle(Theme.ink)
        }
    }

    private var background: Color {
        switch state {
        case .normal: Theme.card
        case .wrong: Theme.wrong.opacity(0.25)
        case .reveal: Theme.jade.opacity(0.25)
        }
    }

    private var border: Color {
        switch state {
        case .normal: Theme.muted.opacity(0.4)
        case .wrong: Theme.wrong
        case .reveal: Theme.jade
        }
    }
}
