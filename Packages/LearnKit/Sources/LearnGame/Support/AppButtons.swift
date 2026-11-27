import LearnCore
import SwiftUI

// MARK: - 统一模态脚手架（固定顶栏 + 自适应滚动内容区 + 固定底部操作栏）

struct AppModalScaffold<Trailing: View, Content: View, Footer: View>: View {
    let systemImage: String
    var iconTint: Color = AppColor.jade
    let title: String
    var subtitle: String? = nil
    var scrollable: Bool = true
    @ViewBuilder var trailing: () -> Trailing
    @ViewBuilder var content: () -> Content
    @ViewBuilder var footer: () -> Footer

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: AppSpacing.sm) {
                AppIconBadge(systemImage: systemImage, tint: iconTint, size: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppFont.title)
                        .foregroundStyle(AppColor.ink)
                    if let subtitle {
                        Text(subtitle)
                            .font(AppFont.label)
                            .foregroundStyle(AppColor.muted)
                    }
                }
                Spacer(minLength: AppSpacing.xs)
                trailing()
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.lg)
            .padding(.bottom, AppSpacing.md)

            if scrollable {
                ScrollView {
                    content()
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.vertical, AppSpacing.xs)
                }
                .scrollBounceBehavior(.basedOnSize)
            } else {
                content()
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, AppSpacing.xs)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            VStack(spacing: 0) {
                Rectangle()
                    .fill(AppColor.cardStroke.opacity(0.45))
                    .frame(height: 1)
                footer()
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, AppSpacing.md)
            }
        }
        .background(GrowthPageBackground())
    }
}

extension AppModalScaffold where Trailing == EmptyView {
    init(
        systemImage: String,
        iconTint: Color = AppColor.jade,
        title: String,
        subtitle: String? = nil,
        scrollable: Bool = true,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.init(
            systemImage: systemImage,
            iconTint: iconTint,
            title: title,
            subtitle: subtitle,
            scrollable: scrollable,
            trailing: { EmptyView() },
            content: content,
            footer: footer
        )
    }
}

// MARK: - 统一按钮体系（6 语义 × 4 档尺寸 × 物理下沉厚底）

enum AppButtonRole {
    case primary
    case accent
    case adventure
    case secondary
    case destructive
    case destructiveSolid
    case subtle

    var topColor: Color {
        switch self {
        case .primary: AppColor.jadeTop
        case .accent: AppColor.accentTop
        case .adventure: AppColor.adventureTop
        case .secondary: AppColor.surface
        case .destructive: AppColor.dangerFill
        case .destructiveSolid: AppColor.dangerSolidTop
        case .subtle: Color.white.opacity(0.84)
        }
    }

    var bottomColor: Color {
        switch self {
        case .primary: AppColor.jadeBottom
        case .accent: AppColor.accentBottom
        case .adventure: AppColor.adventureBottom
        case .secondary: AppColor.surfaceBottom
        case .destructive: AppColor.dangerFillBottom
        case .destructiveSolid: AppColor.dangerSolidBottom
        case .subtle: Color.white.opacity(0.72)
        }
    }

    var edgeColor: Color {
        switch self {
        case .primary: AppColor.jadeEdge
        case .accent: AppColor.accentEdge
        case .adventure: AppColor.adventureEdge
        case .secondary: AppColor.cardEdge
        case .destructive: AppColor.dangerEdge
        case .destructiveSolid: AppColor.dangerSolidEdge
        case .subtle: AppColor.cardStroke.opacity(0.75)
        }
    }

    var foreground: Color {
        switch self {
        case .primary, .accent, .adventure, .destructiveSolid: .white
        case .secondary: AppColor.ink
        case .destructive: AppColor.dangerText
        case .subtle: AppColor.muted
        }
    }

    var hasLip: Bool { self != .subtle }
}

enum AppButtonSize {
    case hero
    case large
    case medium
    case small

    var height: CGFloat {
        switch self {
        case .hero: 68
        case .large: 54
        case .medium: 46
        case .small: 40
        }
    }

    var lip: CGFloat {
        switch self {
        case .hero: 5
        case .large: 4
        case .medium: 3.5
        case .small: 3
        }
    }

    var font: Font {
        switch self {
        case .hero: AppFont.rounded(26, weight: .black)
        case .large: AppFont.rounded(20, weight: .heavy)
        case .medium: AppFont.rounded(17, weight: .heavy)
        case .small: AppFont.rounded(14, weight: .heavy)
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .hero: 28
        case .large: 22
        case .medium: 18
        case .small: 14
        }
    }
}

/// 统一瓷釉立体按钮：双层实体厚底 + strokeBorder 内高光（绝不裁切）+ 物理下沉按压 + 统一暖灰禁用态
struct AppButton: View {
    let title: String
    var systemImage: String? = nil
    var icon: String? = nil
    var coin = false
    var role: AppButtonRole = .primary
    var size: AppButtonSize = .medium
    var minWidth: CGFloat = 0
    var expands = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            AppButtonContent(
                title: title,
                systemImage: systemImage,
                icon: icon,
                coin: coin,
                font: size.font,
                height: size.height,
                horizontalPadding: size.horizontalPadding
            )
        }
        .buttonStyle(AppCapsuleButtonStyle(role: role, size: size, minWidth: minWidth, expands: expands))
    }
}

private struct AppButtonContent: View {
    let title: String
    var systemImage: String?
    var icon: String?
    var coin: Bool
    let font: Font
    let height: CGFloat
    let horizontalPadding: CGFloat

    var body: some View {
        HStack(spacing: 7) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(font)
            } else if let icon {
                Text(icon)
            }
            if coin {
                CoinIcon(size: height * 0.44)
            }
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .font(font)
        .padding(.horizontal, horizontalPadding)
    }
}

struct AppCapsuleButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    let role: AppButtonRole
    let size: AppButtonSize
    var minWidth: CGFloat = 0
    var expands = false

    func makeBody(configuration: Configuration) -> some View {
        let activeLip: CGFloat = (isEnabled && role.hasLip) ? size.lip : 0
        let pressed = isEnabled && configuration.isPressed
        let drop: CGFloat = pressed ? max(0, activeLip - 1) : 0
        let top = isEnabled ? role.topColor : AppColor.disabledFill
        let bottom = isEnabled ? role.bottomColor : AppColor.disabledFill
        let edge = isEnabled ? role.edgeColor : AppColor.disabledEdge
        let fg = isEnabled ? role.foreground : AppColor.disabledText

        configuration.label
            .foregroundStyle(fg)
            .frame(height: size.height - activeLip)
            .frame(minWidth: minWidth)
            .frame(maxWidth: expands ? .infinity : nil)
            .offset(y: drop)
            .padding(.bottom, activeLip)
            .background {
                ZStack(alignment: .top) {
                    if activeLip > 0 {
                        Capsule()
                            .fill(edge)
                            .shadow(color: edge.opacity(pressed ? 0.12 : 0.22), radius: pressed ? 2 : 7, x: 0, y: pressed ? 1 : 4)
                    }
                    Capsule()
                        .fill(LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom))
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [.white.opacity(isEnabled ? 0.55 : 0.25), .clear],
                                        startPoint: .top,
                                        endPoint: .center
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(edge.opacity(role.hasLip ? 0.88 : 0.65), lineWidth: 1.5)
                        )
                        .padding(.bottom, activeLip)
                        .offset(y: drop)
                }
            }
            .scaleEffect(pressed ? 0.985 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.68), value: pressed)
    }
}

// MARK: - 统一图标微徽章（用于家长设置、核对网格、标题等）

struct AppIconBadge: View {
    let systemImage: String
    var tint: Color = AppColor.accent
    var size: CGFloat = 34

    var body: some View {
        Image(systemName: systemImage)
            .font(AppFont.rounded(size * 0.48, weight: .bold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: AppRadius.xs).fill(tint.opacity(0.14)))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.xs).strokeBorder(tint.opacity(0.24), lineWidth: 1))
    }
}
