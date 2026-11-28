import Combine
import LearnCore
import SwiftUI

/// 记一记：答错和没来得及答的题，结算后再看一遍、听一遍。
/// 放得下就全部列出来；错题多、弹窗放不下时只在这个框里滚动，弹窗高度不跟着错题数变，按钮始终在一屏里
struct MistakeNotebook: View {
    let mistakes: [GameSession.Mistake]
    var speech: Speech? = nil
    @State private var playingID: UUID?
    @State private var playlistTask: Task<Void, Never>?
    @State private var speechBusy = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(spacing: AppSpacing.xs) {
                Text("✏️ 记一记（\(mistakes.count)）")
                    .font(AppFont.rounded(20, weight: .heavy))
                    .foregroundStyle(AppColor.ink)
                Spacer(minLength: 0)
                if speech != nil, mistakes.contains(where: { $0.speech != nil }) {
                    AppButton(
                        title: playlistTask == nil ? "连播跟读" : "停止连播",
                        systemImage: playlistTask == nil ? "play.circle.fill" : "stop.circle.fill",
                        role: playlistTask == nil ? .secondary : .destructive,
                        size: .small
                    ) {
                        togglePlaylist()
                    }
                }
            }
            ViewThatFits(in: .vertical) {
                list
                ScrollView { list }
                    .scrollBounceBehavior(.basedOnSize)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appPanel(radius: AppRadius.lg)
        .onReceive(speech?.$isSpeaking.eraseToAnyPublisher() ?? Just(false).eraseToAnyPublisher()) { speechBusy = $0 }
        .onDisappear { stopPlaylist() }
    }

    static func summaryText(for mistake: GameSession.Mistake) -> String {
        let prompt = mistake.prompt == "🔊" ? "🔊 听音题" : mistake.prompt
        let status = mistake.missed ? "（未作答）" : ""
        return "\(prompt)\(status) → 答案：\(mistake.answer)"
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(mistakes) { m in
                let active = playingID == m.id
                HStack(alignment: .center, spacing: AppSpacing.xs) {
                    PictureView(emoji: m.missed ? "⏰" : "✏️", size: 22)
                    Text(Self.summaryText(for: m))
                        .foregroundStyle(AppColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    if let speech, let line = m.speech {
                        Button {
                            stopPlaylist()
                            speech.speak(line, interrupt: true, channel: .preview)
                        } label: {
                            Image(systemName: active ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                                .font(AppFont.rounded(15, weight: .bold))
                                .foregroundStyle(active ? AppColor.jadeEdge : AppColor.adventureEdge)
                                .frame(width: 34, height: 30)
                                .background(Capsule().fill((active ? AppColor.jade : AppColor.adventure).opacity(0.16)))
                        }
                        .buttonStyle(PressableStyle())
                        .disabled(speechBusy || playlistTask != nil)
                        .opacity((speechBusy || playlistTask != nil) && !active ? 0.45 : 1)
                        .accessibilityLabel("听读音")
                    }
                }
                .font(AppFont.rounded(17, weight: .semibold))
                .padding(.horizontal, AppSpacing.sm).padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .appInset(radius: AppRadius.sm, tint: active ? AppColor.jade : nil)
            }
        }
    }

    private func togglePlaylist() {
        if playlistTask != nil {
            stopPlaylist()
            return
        }
        guard let speech else { return }
        let items = mistakes.compactMap { m -> (UUID, String)? in
            guard let line = m.speech else { return nil }
            return (m.id, line)
        }
        guard !items.isEmpty else { return }
        playlistTask = Task { @MainActor in
            for (id, line) in items {
                guard !Task.isCancelled else { break }
                playingID = id
                speech.speak(line, interrupt: true, channel: .preview)
                try? await Task.sleep(for: .seconds(2.4))
            }
            playingID = nil
            playlistTask = nil
        }
    }

    private func stopPlaylist() {
        playlistTask?.cancel()
        playlistTask = nil
        playingID = nil
    }
}
