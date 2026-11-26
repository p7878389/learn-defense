import LearnCore
import SwiftUI

/// 糖果风格通用弹窗按钮配置与模态确认框，替代系统 Alert / ConfirmationDialog。
struct CandyConfirmButton: Identifiable {
    enum Role { case primary, secondary, destructive, cancel }

    let id = UUID()
    let title: String
    var icon: String? = nil
    var systemImage: String? = nil
    var role: Role = .secondary
    let action: () -> Void

    var buttonRole: AppButtonRole {
        switch role {
        case .primary: .primary
        case .secondary, .cancel: .secondary
        case .destructive: .destructive
        }
    }
}

struct CandyConfirmModal: View {
    let title: String
    var icon: String? = nil
    let message: String
    var bannerColors: [Color] = [AppColor.gold, AppColor.accent]
    var bannerEdge: Color = AppColor.accentEdge
    var borderColor: Color = AppColor.gold.opacity(0.75)
    var maxWidth: CGFloat = 460
    let buttons: [CandyConfirmButton]
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onDismiss?() }
            CandyModalCard(
                bannerTitle: title,
                bannerIcon: icon,
                bannerColors: bannerColors,
                bannerEdge: bannerEdge,
                borderColor: borderColor,
                maxWidth: maxWidth
            ) {
                if !message.isEmpty {
                    Text(message)
                        .font(AppFont.body)
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                }
                VStack(spacing: 12) {
                    ForEach(buttons) { item in
                        AppButton(
                            title: item.title,
                            systemImage: item.systemImage,
                            icon: item.icon,
                            role: item.buttonRole,
                            size: .large,
                            expands: true,
                            action: item.action
                        )
                    }
                }
            }
            .padding(24)
        }
        .transition(.opacity)
    }
}

/// 战斗与成长弹窗共用的绘本瓷釉弹窗框体：可选顶部悬浮横幅 + 暖纸底 + 双层实体厚底
struct CandyModalCard<Content: View>: View {
    var bannerTitle: String? = nil
    var bannerIcon: String? = nil
    var bannerColors: [Color] = [AppColor.gold, AppColor.accent]
    var bannerEdge: Color = AppColor.accentEdge
    var borderColor: Color = AppColor.gold.opacity(0.75)
    var maxWidth: CGFloat = 560
    var radius: CGFloat = AppRadius.xl
    @ViewBuilder var content: () -> Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius)
        VStack(spacing: 18) {
            if let bannerTitle {
                HStack(spacing: 10) {
                    if let bannerIcon { Text(bannerIcon).font(.system(size: 24)) }
                    Text(bannerTitle)
                        .font(AppFont.title)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 28)
                .frame(height: 50)
                .padding(.bottom, 4)
                .background {
                    ZStack(alignment: .top) {
                        Capsule().fill(bannerEdge)
                            .shadow(color: bannerEdge.opacity(0.28), radius: 8, y: 4)
                        Capsule()
                            .fill(LinearGradient(colors: bannerColors, startPoint: .top, endPoint: .bottom))
                            .overlay(Capsule().strokeBorder(.white.opacity(0.75), lineWidth: 2))
                            .padding(.bottom, 4)
                    }
                }
                .padding(.top, -46)
            }
            content()
        }
        .padding(.horizontal, 28)
        .padding(.top, bannerTitle == nil ? 28 : 24)
        .padding(.bottom, 28)
        .frame(maxWidth: maxWidth)
        .background(
            ZStack {
                shape.fill(AppColor.cardEdge)
                    .shadow(color: .black.opacity(0.20), radius: 22, y: 12)
                shape.fill(LinearGradient(colors: [AppColor.paperTop, Theme.paper], startPoint: .top, endPoint: .bottom))
                    .overlay(shape.strokeBorder(borderColor, lineWidth: 2.5))
                    .padding(.bottom, 5)
            }
        )
    }
}
