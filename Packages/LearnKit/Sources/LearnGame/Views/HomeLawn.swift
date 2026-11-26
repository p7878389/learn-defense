import LearnCore
import SwiftUI

/// 页面底部的草坪：书架、两株植物守卫，右边一只举着「字」牌的小僵尸
struct HomeLawn: View {
    /// 首页底部草坪专属绘本绿意装饰色（`AppColor` 主语义之外的场景插画色）
    private enum LocalArt {
        static let lawnTop = Color(red: 0.55, green: 0.82, blue: 0.38)
        static let lawnBottom = Color(red: 0.38, green: 0.66, blue: 0.26)
        static let lawnHighlight = Color(red: 0.66, green: 0.90, blue: 0.50)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [LocalArt.lawnTop, LocalArt.lawnBottom],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 64)
                .overlay(alignment: .top) { LocalArt.lawnHighlight.frame(height: 4) }

            HStack(alignment: .bottom, spacing: AppSpacing.sm) {
                PictureView(emoji: "📚", size: 52)
                PictureView(emoji: "🌻", size: 54)
                sprite("plant-inkling", size: 58)
                Spacer()
                HStack(spacing: AppSpacing.lg) {
                    PictureView(emoji: "🌼", size: 24)
                    PictureView(emoji: "🌸", size: 24)
                    PictureView(emoji: "🌼", size: 24)
                }
                .padding(.bottom, 10)
                Spacer()
                VStack(spacing: 0) {
                    Text("字 zì")
                        .font(AppFont.rounded(14, weight: .black))
                        .foregroundStyle(AppColor.woodBottom)
                        .padding(.horizontal, AppSpacing.xs)
                        .padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 6).fill(AppColor.answerTray))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppColor.woodBottom, lineWidth: 2))
                        .rotationEffect(.degrees(-6))
                    sprite("zombie-drowsy", size: 70)
                }
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.bottom, AppSpacing.xxs)
        }
        .frame(height: 96, alignment: .bottom)
        .overlay(alignment: .bottom) {
            Text("图片来自 Microsoft Fluent Emoji（MIT 许可）")
                .font(AppFont.rounded(11, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
                .padding(.bottom, AppSpacing.xxs)
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
