import LearnCore
import SwiftUI

/// 页面底部的草坪：书架、两株植物守卫，右边一只举着「字」牌的小僵尸
struct HomeLawn: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [Color(red: 0.55, green: 0.82, blue: 0.38), Color(red: 0.38, green: 0.66, blue: 0.26)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 64)
                .overlay(alignment: .top) { Color(red: 0.66, green: 0.9, blue: 0.5).frame(height: 4) }

            HStack(alignment: .bottom, spacing: 14) {
                PictureView(emoji: "📚", size: 52)
                PictureView(emoji: "🌻", size: 54)
                sprite("plant-inkling", size: 58)
                Spacer()
                HStack(spacing: 28) {
                    PictureView(emoji: "🌼", size: 24)
                    PictureView(emoji: "🌸", size: 24)
                    PictureView(emoji: "🌼", size: 24)
                }
                .padding(.bottom, 10)
                Spacer()
                VStack(spacing: 0) {
                    Text("字 zì")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(Color(red: 0.47, green: 0.25, blue: 0.06))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color(red: 1.0, green: 0.93, blue: 0.75)))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(red: 0.47, green: 0.25, blue: 0.06), lineWidth: 2))
                        .rotationEffect(.degrees(-6))
                    sprite("zombie-drowsy", size: 70)
                }
            }
            .padding(.horizontal, 36)
            .padding(.bottom, 4)
        }
        .frame(height: 96, alignment: .bottom)
        .overlay(alignment: .bottom) {
            Text("图片来自 Microsoft Fluent Emoji（MIT 许可）")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
                .padding(.bottom, 4)
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func sprite(_ name: String, size: CGFloat) -> some View {
        if let texture = UnitSprites.frames(named: name).first {
            Image(decorative: texture.cgImage(), scale: 1)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        }
    }
}
