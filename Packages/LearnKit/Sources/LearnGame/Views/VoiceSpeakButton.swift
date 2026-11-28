import LearnCore
import SwiftUI

/// 通用「开口读出来」声波按钮：
/// 点击后暂停朗读并开启端侧语音识别，实时显示音量波纹与识别文本；命中目标后自动回调 onMatched。
struct VoiceSpeakButton: View {
    let title: String
    let expected: String
    let english: Bool
    let resetKey: AnyHashable
    /// 语音播报中时锁定，等所有语音播完后才允许开始跟读
    var speechLocked: Bool = false
    var onBeforeListen: () -> Void = {}
    var onListeningChanged: (Bool) -> Void = { _ in }
    let onMatched: () -> Void

    @StateObject private var voice = VoiceInput()

    private var lockedBySpeech: Bool { speechLocked && !voice.isListening }

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            Button(action: toggle) {
                HStack(spacing: 6) {
                    Image(systemName: voice.isListening ? "waveform.circle.fill" : "mic.fill")
                        .font(AppFont.rounded(17, weight: .bold))
                        .symbolEffect(.bounce, value: voice.isListening)
                    Text(buttonLabel)
                        .font(AppFont.rounded(15, weight: .heavy))
                        .lineLimit(1)
                    if voice.isListening {
                        waveBars
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, AppSpacing.sm)
                .frame(height: 40)
                .padding(.bottom, 3)
                .background {
                    let shape = Capsule()
                    ZStack {
                        shape.fill(voice.isListening ? AppColor.dangerSolidBottom : AppColor.jadeEdge)
                        shape
                            .fill(
                                LinearGradient(
                                    colors: voice.isListening
                                        ? [AppColor.accentTop, AppColor.dangerSolidBottom]
                                        : [AppColor.jadeTop, AppColor.jadeBottom],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            .overlay(shape.strokeBorder(.white.opacity(0.65), lineWidth: 1.4))
                            .padding(.bottom, 3)
                    }
                }
            }
            .buttonStyle(PressableStyle())
            .disabled(lockedBySpeech)
            .opacity(lockedBySpeech ? 0.52 : 1)

            if voice.isListening, !voice.transcript.isEmpty {
                Text("听到：\(voice.transcript)")
                    .font(AppFont.caption)
                    .foregroundStyle(AppColor.jadeEdge)
                    .lineLimit(1)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(AppColor.jade.opacity(0.14)))
            } else if case .unavailable(let reason) = voice.state {
                Text(reason)
                    .font(AppFont.caption)
                    .foregroundStyle(AppColor.dangerText)
                    .lineLimit(1)
            }
        }
        .onChange(of: resetKey) { _, _ in voice.stop() }
        .onChange(of: voice.isListening) { _, listening in onListeningChanged(listening) }
        .onDisappear {
            voice.stop()
            onListeningChanged(false)
        }
    }

    private var buttonLabel: String {
        if voice.isListening { return "请大声读…" }
        if lockedBySpeech { return "请先听完…" }
        return title
    }

    private var waveBars: some View {
        HStack(spacing: 2.5) {
            ForEach(0..<3, id: \.self) { index in
                let scale = max(0.25, min(1.0, voice.level * (index == 1 ? 1.3 : 0.9) + 0.2))
                Capsule()
                    .fill(.white)
                    .frame(width: 3, height: 16 * scale)
                    .animation(.easeOut(duration: 0.08), value: voice.level)
            }
        }
        .frame(height: 16)
    }

    private func toggle() {
        if voice.isListening {
            voice.stop()
            return
        }
        onBeforeListen()
        voice.start(expected: expected, english: english, onMatch: onMatched)
    }
}
