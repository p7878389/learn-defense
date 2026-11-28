import LearnCore
import SwiftUI

/// 回合休息期的「闪卡听读复盘」：
/// 优先展示本回合答错或新学的知识点，支持点读和跟读赢下回合初始阳光。
struct RoundRestFlashcardView: View {
    @ObservedObject var session: GameSession
    @State private var index = 0

    private var cards: [GameSession.RoundReviewCard] {
        Array(session.roundReviewCards.prefix(5))
    }

    var body: some View {
        if !cards.isEmpty {
            let safeIndex = min(index, cards.count - 1)
            let item = cards[safeIndex]
            let claimed = session.spokenRestCardIDs.contains(item.id)
            VStack(spacing: AppSpacing.xs) {
                HStack {
                    Label(item.wasWrong ? "本回合错题再听一遍" : "本回合闪卡磨耳朵",
                          systemImage: item.wasWrong ? "flame.fill" : "sparkles")
                        .font(AppFont.label)
                        .foregroundStyle(item.wasWrong ? AppColor.accentEdge : AppColor.jadeEdge)
                    Spacer()
                    Text("\(safeIndex + 1)/\(cards.count)")
                        .font(AppFont.digits(14, weight: .heavy))
                        .foregroundStyle(AppColor.muted)
                }

                HStack(spacing: AppSpacing.md) {
                    if let pic = item.card.picture {
                        PictureView(emoji: pic, size: 54)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        if let pinyin = item.card.pinyin {
                            Text(pinyin)
                                .font(AppFont.rounded(16, weight: .bold))
                                .foregroundStyle(AppColor.adventureEdge)
                        }
                        Text(item.card.text)
                            .font(AppFont.rounded(28, weight: .black))
                            .foregroundStyle(AppColor.ink)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                        if let detail = item.card.detail {
                            Text(detail)
                                .font(AppFont.label)
                                .foregroundStyle(AppColor.muted)
                                .lineLimit(2)
                        }
                    }
                    Spacer(minLength: 0)
                }

                HStack(spacing: AppSpacing.xs) {
                    if cards.count > 1 {
                        AppButton(title: "下一张", systemImage: "chevron.right", role: .secondary, size: .small) {
                            index = (safeIndex + 1) % cards.count
                            speakCurrent(at: index)
                        }
                        .disabled(session.isInteractionLocked)
                    }
                    if let line = item.speech {
                        AppButton(title: "听一遍", systemImage: "speaker.wave.2.fill", role: .secondary, size: .small) {
                            session.speech.speak(line, interrupt: true, channel: .preview)
                        }
                        .disabled(session.isInteractionLocked)
                    }
                    Spacer(minLength: 0)
                    if claimed {
                        Label("已领 +15☀️", systemImage: "checkmark.circle.fill")
                            .font(AppFont.label)
                            .foregroundStyle(AppColor.jadeEdge)
                    } else {
                        VoiceSpeakButton(
                            title: "跟读 +15☀️",
                            expected: item.card.text,
                            english: SpeechText.isEnglish(item.card.text),
                            resetKey: item.id,
                            speechLocked: session.isSpeechBlocking,
                            onBeforeListen: { session.speech.stop() },
                            onListeningChanged: { session.isVoiceListening = $0 },
                            onMatched: {
                                session.claimRestFlashcardBonus(cardID: item.id)
                            }
                        )
                    }
                }
            }
            .padding(AppSpacing.sm)
            .appInset(radius: AppRadius.md, tint: item.wasWrong ? AppColor.gold : AppColor.jade)
            .onAppear {
                index = 0
                speakCurrent(at: 0)
            }
        }
    }

    private func speakCurrent(at idx: Int) {
        guard cards.indices.contains(idx), let line = cards[idx].speech else { return }
        session.speech.speak(line, interrupt: true, channel: .preview)
    }
}
