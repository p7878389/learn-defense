import SwiftUI

struct ResultView: View {
    @ObservedObject var session: GameSession
    let onReplay: () -> Void
    let onExit: () -> Void

    private var won: Bool { session.phase == .won }

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 22) {
                HStack(spacing: 16) {
                    if won {
                        PictureView(emoji: "🎉", size: 52)
                        PictureView(emoji: "🏆", size: 76)
                        PictureView(emoji: "🎉", size: 52).scaleEffect(x: -1)
                    } else {
                        PictureView(emoji: "💪", size: 64)
                    }
                }
                Text(won ? "书本守住了！" : "书被偷走了……")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(won ? Theme.jade : Theme.wrong)

                HStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: i < session.stars ? "star.fill" : "star")
                            .font(.system(size: 54))
                            .foregroundStyle(Theme.accent)
                    }
                }

                HStack(spacing: 40) {
                    stat("击退", "\(session.defeated)")
                    stat("一次答对", session.attempted == 0 ? "-" : "\(Int((session.accuracy * 100).rounded()))%")
                    stat("得分", "\(session.score)")
                }

                if !session.mistakes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("记一记").font(.title3.weight(.bold)).foregroundStyle(Theme.ink)
                        ScrollView {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(session.mistakes) { m in
                                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                                        PictureView(emoji: m.missed ? "⏰" : "✏️", size: 26)
                                        Text(m.explanation ?? "\(m.prompt) → \(m.answer)")
                                            .foregroundStyle(Theme.ink)
                                    }
                                    .font(.title3)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 220)
                    }
                    .padding(20)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Theme.card))
                }

                HStack(spacing: 24) {
                    Button(action: onReplay) {
                        Text("再来一局").font(.title2.weight(.bold)).frame(width: 220, height: 66)
                            .background(Capsule().fill(Theme.jade)).foregroundStyle(.white)
                    }
                    .buttonStyle(PressableStyle())
                    Button(action: onExit) {
                        Text("返回").font(.title2.weight(.semibold)).frame(width: 180, height: 66)
                            .background(Capsule().stroke(Theme.muted, lineWidth: 2)).foregroundStyle(Theme.muted)
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            .padding(36)
            .frame(maxWidth: 820)
            .background(RoundedRectangle(cornerRadius: 28).fill(Theme.paper))
            .padding(32)
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 36, weight: .bold, design: .rounded).monospacedDigit()).foregroundStyle(Theme.ink)
            Text(title).font(.headline).foregroundStyle(Theme.muted)
        }
    }
}
