import LearnCore
import SwiftUI

// MARK: - 设计系统使用规范
//
// 1. 新增或修改界面代码必须使用 `AppColor` / `AppFont` / `AppSpacing` / `AppRadius` / `AppShadow` / `AppMotion`。
// 2. Views 中不再新增 `Color(red:` 和 `.font(.system(size:`；特殊字号请使用 `AppFont.rounded(_:weight:)` 或 `AppFont.digits(_:weight:)`。
// 3. 表面层级：L0 背景（GrowthPageBackground）→ L1 面板（`.appPanel()`）/ L1 内嵌格（`.appInset()`）→ L2 可点击元素（`.candyCard()`、`AppButton`）。

// MARK: - 统一色彩语义（绘本瓷釉 × 森林木艺）

enum AppColor {
    // 背景与纸面
    static let paper = Theme.paper
    static let paperTop = Color(red: 0.995, green: 0.985, blue: 0.955)
    static let surface = Color(red: 1.0, green: 0.985, blue: 0.95)
    static let surfaceBottom = Color(red: 0.985, green: 0.955, blue: 0.895)
    static let cardEdge = Color(red: 0.89, green: 0.81, blue: 0.68)
    static let cardStroke = Color(red: 0.86, green: 0.77, blue: 0.63)
    static let warmShadow = Color(red: 0.36, green: 0.25, blue: 0.12)

    // 文字
    static let ink = Theme.ink
    static let muted = Theme.muted

    // 主行动：翡翠绿（唯一 Primary CTA）
    static let jadeTop = Color(red: 0.27, green: 0.78, blue: 0.60)
    static let jade = Theme.jade
    static let jadeBottom = Color(red: 0.16, green: 0.58, blue: 0.44)
    static let jadeEdge = Color(red: 0.11, green: 0.43, blue: 0.33)

    // 激励 / 积分 / 阳光 / 激活态：琥珀金橙
    static let goldLight = Color(red: 1.0, green: 0.90, blue: 0.50)
    static let gold = Color(red: 1.0, green: 0.79, blue: 0.24)
    static let goldEdge = Color(red: 0.84, green: 0.58, blue: 0.04)
    static let accentTop = Color(red: 1.0, green: 0.68, blue: 0.24)
    static let accent = Theme.accent
    static let accentBottom = Color(red: 0.90, green: 0.47, blue: 0.12)
    static let accentEdge = Color(red: 0.73, green: 0.36, blue: 0.05)

    // 冒险探索专属：松林青蓝（与经典翡翠绿明确区分主次）
    static let adventureTop = Color(red: 0.22, green: 0.64, blue: 0.66)
    static let adventure = Color(red: 0.15, green: 0.52, blue: 0.56)
    static let adventureBottom = Color(red: 0.11, green: 0.41, blue: 0.46)
    static let adventureEdge = Color(red: 0.07, green: 0.29, blue: 0.34)

    // 荣誉与徽章：星光紫
    static let violetTop = Color(red: 0.62, green: 0.44, blue: 0.98)
    static let violet = Color(red: 0.51, green: 0.34, blue: 0.91)
    static let violetEdge = Color(red: 0.33, green: 0.19, blue: 0.66)

    // 危险 / 生命 / 警示：珊瑚红
    static let dangerFill = Color(red: 0.99, green: 0.92, blue: 0.91)
    static let dangerEdge = Color(red: 0.89, green: 0.58, blue: 0.56)
    static let dangerText = Theme.wrong
    static let dangerSolidTop = Color(red: 0.94, green: 0.40, blue: 0.36)
    static let dangerSolidBottom = Theme.wrong
    static let dangerSolidEdge = Color(red: 0.68, green: 0.20, blue: 0.18)

    // 禁用态（全站统一柔和暖灰）
    static let disabledFill = Color(red: 0.91, green: 0.89, blue: 0.85)
    static let disabledEdge = Color(red: 0.80, green: 0.77, blue: 0.72)
    static let disabledText = Color(red: 0.58, green: 0.55, blue: 0.50)

    // 森林原木（战斗种植托盘与战场画框）
    static let woodTop = Color(red: 0.52, green: 0.36, blue: 0.21)
    static let woodBottom = Color(red: 0.36, green: 0.23, blue: 0.12)
    static let woodEdge = Color(red: 0.25, green: 0.15, blue: 0.07)
    static let woodTrim = Color(red: 0.72, green: 0.55, blue: 0.34)

    // 家长端清雅子主题
    static let parentSurface = Color(red: 1.0, green: 0.99, blue: 0.97)
    static let parentStroke = Color(red: 0.87, green: 0.82, blue: 0.74)
    static let parentAccent = Color(red: 0.19, green: 0.56, blue: 0.53)
    static let parentAccentEdge = Color(red: 0.12, green: 0.39, blue: 0.37)

    // 绘本氛围、战场托盘与扩展语义色
    static let sky = Color(red: 0.87, green: 0.95, blue: 1.0)
    static let meadow = Color(red: 0.90, green: 0.96, blue: 0.84)
    static let jadeLight = Color(red: 0.48, green: 0.89, blue: 0.74)
    static let calm = Color(red: 0.36, green: 0.55, blue: 0.85)
    static let answerTray = Color(red: 0.985, green: 0.95, blue: 0.84)
    static let tileFill = Color(red: 1.0, green: 0.98, blue: 0.91)
    static let lightning = Color(red: 0.12, green: 0.72, blue: 0.95)
    static let lightningDark = Color(red: 0.04, green: 0.48, blue: 0.68)

    // 外观稀有度
    static let rarityCommon = Color(red: 0.45, green: 0.74, blue: 0.94)
    static let rarityRare = Color(red: 0.62, green: 0.44, blue: 0.96)
    static let rarityLegendary = gold

    // 浅色入口卡柔边
    static let adventureSoftEdge = Color(red: 0.64, green: 0.81, blue: 0.81)
    static let accentSoftEdge = Color(red: 0.95, green: 0.79, blue: 0.60)
    static let violetSoftEdge = Color(red: 0.79, green: 0.73, blue: 0.94)
}

// MARK: - 统一间距体系（7 档）

enum AppSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: - 统一阴影体系（3 档）

enum AppShadow {
    case panel
    case raised
    case floating

    var color: Color {
        switch self {
        case .panel: AppColor.warmShadow.opacity(0.08)
        case .raised: AppColor.warmShadow.opacity(0.12)
        case .floating: Color.black.opacity(0.20)
        }
    }

    var radius: CGFloat {
        switch self {
        case .panel: 14
        case .raised: 8
        case .floating: 22
        }
    }

    var y: CGFloat {
        switch self {
        case .panel: 6
        case .raised: 4
        case .floating: 12
        }
    }
}

// MARK: - 统一动效体系

enum AppMotion {
    static let press = Animation.spring(response: 0.22, dampingFraction: 0.66)
    static let appear = Animation.spring(response: 0.45, dampingFraction: 0.82)
    static let celebrate = Animation.spring(response: 0.5, dampingFraction: 0.6)

    static func stagger(_ i: Int) -> Animation {
        appear.delay(Double(max(0, i)) * 0.05)
    }
}

private struct AppAppearModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let index: Int
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: (appeared || reduceMotion) ? 0 : 12)
            .onAppear {
                withAnimation(AppMotion.stagger(index)) {
                    appeared = true
                }
            }
    }
}

// MARK: - L1 表面层（面板与内嵌信息格，无厚底）

private struct AppPanelModifier: ViewModifier {
    var radius: CGFloat = AppRadius.lg
    var tint: Color? = nil

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius)
        content
            .background(
                ZStack {
                    shape
                        .fill(LinearGradient(colors: [AppColor.surface, AppColor.surfaceBottom],
                                             startPoint: .top, endPoint: .bottom))
                    if let tint {
                        shape.fill(tint.opacity(0.06))
                    }
                }
                .appShadow(.panel)
            )
            .overlay(
                shape.strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.85), .clear], startPoint: .top, endPoint: .center),
                    lineWidth: 1
                )
            )
            .overlay(
                shape.strokeBorder(tint?.opacity(0.32) ?? AppColor.cardStroke, lineWidth: 1)
            )
    }
}

private struct AppInsetModifier: ViewModifier {
    var radius: CGFloat = AppRadius.md
    var tint: Color? = nil

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius)
        content
            .background(
                ZStack {
                    shape.fill(AppColor.surface)
                    shape.fill(tint?.opacity(0.08) ?? AppColor.ink.opacity(0.035))
                }
            )
            .overlay(
                shape.strokeBorder(AppColor.cardStroke.opacity(0.5), lineWidth: 1)
            )
    }
}

extension View {
    func appShadow(_ shadow: AppShadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: 0, y: shadow.y)
    }

    func appAppear(index: Int = 0) -> some View {
        modifier(AppAppearModifier(index: index))
    }

    func appPanel(radius: CGFloat = AppRadius.lg, tint: Color? = nil) -> some View {
        modifier(AppPanelModifier(radius: radius, tint: tint))
    }

    func appInset(radius: CGFloat = AppRadius.md, tint: Color? = nil) -> some View {
        modifier(AppInsetModifier(radius: radius, tint: tint))
    }
}

// MARK: - 统一模态脚手架（固定顶栏 + 自适应滚动内容区 + 固定底部操作栏）

struct AppModalScaffold<Trailing: View, Content: View, Footer: View>: View {
    let systemImage: String
    var iconTint: Color = AppColor.jade
    let title: String
    var subtitle: String? = nil
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

            ScrollView {
                content()
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, AppSpacing.xs)
            }
            .scrollBounceBehavior(.basedOnSize)

            VStack(spacing: 0) {
                Rectangle()
                    .fill(AppColor.cardStroke.opacity(0.45))
                    .frame(height: 1)
                footer()
                    .padding(AppSpacing.md)
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
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.init(
            systemImage: systemImage,
            iconTint: iconTint,
            title: title,
            subtitle: subtitle,
            trailing: { EmptyView() },
            content: content,
            footer: footer
        )
    }
}

// MARK: - 统一圆角体系（5 档）

enum AppRadius {
    static let xs: CGFloat = 10
    static let sm: CGFloat = 14
    static let md: CGFloat = 18
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
}

// MARK: - 统一字体系统（100% SF Rounded，8 档字阶 + 答题专用）

enum AppFont {
    static let display = Font.system(size: 36, weight: .black, design: .rounded)
    static let title = Font.system(size: 28, weight: .heavy, design: .rounded)
    static let heading = Font.system(size: 22, weight: .heavy, design: .rounded)
    static let bodyStrong = Font.system(size: 18, weight: .bold, design: .rounded)
    static let body = Font.system(size: 16, weight: .semibold, design: .rounded)
    static let label = Font.system(size: 14, weight: .bold, design: .rounded)
    static let caption = Font.system(size: 12, weight: .bold, design: .rounded)
    static let micro = Font.system(size: 10, weight: .heavy, design: .rounded)

    static func rounded(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func digits(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
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
        case .destructive: Color(red: 0.97, green: 0.87, blue: 0.86)
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
            .font(.system(size: size * 0.48, weight: .bold, design: .rounded))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: AppRadius.xs).fill(tint.opacity(0.14)))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.xs).strokeBorder(tint.opacity(0.24), lineWidth: 1))
    }
}

// MARK: - 家长端清雅容器

struct ParentSurfaceCard: ViewModifier {
    var radius: CGFloat = AppRadius.md

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius)
                    .fill(AppColor.parentSurface)
                    .shadow(color: AppColor.warmShadow.opacity(0.07), radius: 10, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(AppColor.parentStroke, lineWidth: 1.2)
            )
    }
}

extension View {
    func parentSurfaceCard(radius: CGFloat = AppRadius.md) -> some View {
        modifier(ParentSurfaceCard(radius: radius))
    }
}
