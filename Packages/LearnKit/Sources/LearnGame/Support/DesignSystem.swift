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
    static let dangerFillBottom = Color(red: 0.97, green: 0.87, blue: 0.86)
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
