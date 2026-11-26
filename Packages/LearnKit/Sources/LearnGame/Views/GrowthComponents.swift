import LearnCore
import SwiftUI

/// 成长系统界面共用的颜色和小部件（等级牌、经验条、积分牌、奖章）。
enum GrowthColors {
    static let gold = AppColor.gold
    static let goldDark = AppColor.goldEdge
    static let sky = AppColor.sky
    static let meadow = AppColor.meadow
    static let surface = AppColor.surface
    static let cardEdge = AppColor.cardEdge
    static let orangeDeep = AppColor.accentEdge
    static let purple = AppColor.violet
    static let purpleDark = AppColor.violetEdge
    static let jadeLight = AppColor.jadeLight
    static let jadeDark = AppColor.jadeEdge
    static let orangeDark = AppColor.accentEdge
    static let calm = AppColor.calm
    static let answerTray = AppColor.answerTray
    static let tileFill = AppColor.tileFill
    static let wrongDark = AppColor.dangerSolidEdge
    static let lightning = AppColor.lightning
    static let lightningDark = AppColor.lightningDark
    static let disabledFill = AppColor.disabledFill
    static let disabledEdge = AppColor.disabledEdge

    static func rarity(_ rarity: CosmeticRarity) -> Color {
        switch rarity {
        case .common: AppColor.rarityCommon
        case .rare: AppColor.rarityRare
        case .legendary: AppColor.rarityLegendary
        }
    }
}

/// 成长系统页面共用的暖羊皮绘本纸底色：顶部柔和天光、温和纸面光斑、底部极淡浅草气韵。
struct GrowthPageBackground: View {
    var body: some View {
        ZStack {
            AppColor.paper
            LinearGradient(
                colors: [
                    AppColor.sky.opacity(0.36),
                    AppColor.paper,
                    AppColor.meadow.opacity(0.42)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [Color.white.opacity(0.50), .clear],
                center: UnitPoint(x: 0.5, y: 0.12),
                startRadius: 20,
                endRadius: 520
            )
            RadialGradient(
                colors: [AppColor.paperTop.opacity(0.55), .clear],
                center: UnitPoint(x: 0.18, y: 0.45),
                startRadius: 10,
                endRadius: 420
            )
            RadialGradient(
                colors: [AppColor.meadow.opacity(0.52), AppColor.jadeLight.opacity(0.06), .clear],
                center: UnitPoint(x: 0.5, y: 1.0),
                startRadius: 20,
                endRadius: 540
            )
        }
        .ignoresSafeArea()
    }
}

/// 玩具胶囊分段器：柔和内槽 + 白色凸起滑块与深墨文字。
struct GrowthSegmentedPicker<Selection: Hashable>: View {
    let options: [Selection]
    let title: (Selection) -> String
    @Binding var selection: Selection

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { option in
                let selected = option == selection
                Button {
                    selection = option
                } label: {
                    Text(title(option))
                        .font(AppFont.bodyStrong)
                        .foregroundStyle(selected ? AppColor.ink : AppColor.muted)
                        .frame(minWidth: 92, minHeight: selected ? 41 : 44)
                        .padding(.horizontal, 14)
                        .padding(.bottom, selected ? 3 : 0)
                        .contentShape(Capsule())
                        .background {
                            if selected {
                                ZStack(alignment: .top) {
                                    Capsule().fill(AppColor.cardEdge)
                                    Capsule()
                                        .fill(LinearGradient(colors: [AppColor.surface, .white],
                                                             startPoint: .top, endPoint: .bottom))
                                        .overlay(Capsule().strokeBorder(AppColor.cardStroke.opacity(0.7), lineWidth: 1))
                                        .padding(.bottom, 3)
                                }
                            }
                        }
                }
                .buttonStyle(PressableStyle())
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(5)
        .background(
            ZStack(alignment: .top) {
                Capsule().fill(AppColor.cardEdge)
                Capsule()
                    .fill(LinearGradient(colors: [AppColor.surfaceBottom, AppColor.paper], startPoint: .top, endPoint: .bottom))
                    .overlay(Capsule().fill(AppColor.ink.opacity(0.035)))
                    .padding(.bottom, 3)
                    .overlay(Capsule().strokeBorder(AppColor.cardStroke, lineWidth: 1.5).padding(.bottom, 3))
            }
        )
        .animation(AppMotion.press, value: selection)
    }
}

/// 绘本瓷釉卡片：双层实体底边（方向恒定不翻转）+ 顶部高光 + 暖褐环境柔影
struct CandyCard: ViewModifier {
    var fill: Color = GrowthColors.surface
    var edge: Color = GrowthColors.cardEdge
    var radius: CGFloat = AppRadius.lg

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius)
        content
            .padding(.bottom, 4)
            .background(
                ZStack {
                    shape
                        .fill(edge)
                        .shadow(color: AppColor.warmShadow.opacity(0.09), radius: 12, x: 0, y: 6)
                    shape
                        .fill(
                            LinearGradient(
                                colors: [fill, fill == GrowthColors.surface ? AppColor.surfaceBottom : fill],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            shape.strokeBorder(
                                LinearGradient(colors: [.white.opacity(0.85), .clear], startPoint: .top, endPoint: .center),
                                lineWidth: 1.5
                            )
                        )
                        .overlay(shape.strokeBorder(edge.opacity(0.85), lineWidth: 1.5))
                        .padding(.bottom, 4)
                }
            )
    }
}

extension View {
    func candyCard(fill: Color = GrowthColors.surface, edge: Color = GrowthColors.cardEdge, radius: CGFloat = AppRadius.lg) -> some View {
        modifier(CandyCard(fill: fill, edge: edge, radius: radius))
    }

    /// iPad 上全屏显示收藏馆、徽章墙；macOS（只用于编译检查）退化为 sheet
    @ViewBuilder
    func growthCover<Content: View>(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View {
        #if os(iOS)
        fullScreenCover(isPresented: isPresented, content: content)
        #else
        sheet(isPresented: isPresented, content: content)
        #endif
    }
}

/// 二级页与弹窗共用的顶栏：支持按上下文指定返回文案与风格（不再在弹窗中误写“回主页”）。
struct GrowthPageHeader<Trailing: View>: View {
    let icon: String
    var systemIcon: String? = nil
    var iconTint: Color = AppColor.accent
    let title: String
    var subtitle: String?
    var backTitle: String = "返回主页"
    var backSystemImage: String = "chevron.left"
    var parentStyle = false
    let onClose: () -> Void
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 14) {
            AppButton(title: backTitle, systemImage: backSystemImage, role: .secondary, size: .medium, action: onClose)
            Spacer(minLength: 8)
            if let systemIcon {
                AppIconBadge(systemImage: systemIcon, tint: iconTint, size: 38)
            } else {
                PictureView(emoji: icon, size: 38)
            }
            Text(title)
                .font(parentStyle ? AppFont.title : AppFont.rounded(32, weight: .heavy))
                .foregroundStyle(Theme.ink)
            if let subtitle {
                Text(subtitle)
                    .font(AppFont.label)
                    .foregroundStyle(parentStyle ? AppColor.parentAccent : GrowthColors.orangeDark)
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(Capsule().fill((parentStyle ? AppColor.parentAccent : GrowthColors.gold).opacity(parentStyle ? 0.14 : 0.26)))
            }
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .modifier(HeaderCardSurface(parentStyle: parentStyle))
    }
}

private struct HeaderCardSurface: ViewModifier {
    let parentStyle: Bool
    func body(content: Content) -> some View {
        if parentStyle {
            content.parentSurfaceCard(radius: AppRadius.lg)
        } else {
            content.candyCard(radius: AppRadius.lg)
        }
    }
}

/// 分类标签、单元按钮、选择砖共用的实体立体底块：双层厚底 + strokeBorder 内高光
struct CandyTileBackground: View {
    var selected = false
    var selectedFill: Color = Theme.accent
    var selectedEdge: Color = GrowthColors.orangeDeep
    var radius: CGFloat = AppRadius.md

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius)
        let edge = selected ? selectedEdge : GrowthColors.cardEdge
        let lip: CGFloat = selected ? 4 : 3
        ZStack {
            shape.fill(edge)
            shape
                .fill(
                    LinearGradient(
                        colors: selected
                            ? [selectedFill, selectedFill.opacity(0.92)]
                            : [AppColor.surface, AppColor.surfaceBottom],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    shape.strokeBorder(
                        LinearGradient(colors: [.white.opacity(selected ? 0.45 : 0.8), .clear], startPoint: .top, endPoint: .center),
                        lineWidth: 1.2
                    )
                )
                .overlay(shape.strokeBorder(edge.opacity(0.9), lineWidth: 1.5))
                .padding(.bottom, lip)
        }
    }
}

/// 金色积分硬币。
private enum CoinLocalArt {
    /// 硬币内环与星标浮雕专用深金褐描边色
    static let rim = Color(red: 0.78, green: 0.52, blue: 0.0)
    static let star = Color(red: 0.82, green: 0.54, blue: 0.0)
}

struct CoinIcon: View {
    var size: CGFloat = 28

    var body: some View {
        Circle()
            .fill(RadialGradient(colors: [AppColor.goldLight, GrowthColors.gold, GrowthColors.goldDark],
                                 center: .topLeading, startRadius: 1, endRadius: size))
            .overlay(Circle().inset(by: size * 0.14).stroke(CoinLocalArt.rim.opacity(0.75), lineWidth: size * 0.06))
            .overlay(Image(systemName: "star.fill").font(AppFont.rounded(size * 0.42, weight: .black))
                .foregroundStyle(CoinLocalArt.star))
            .frame(width: size, height: size)
            .accessibilityLabel("积分")
    }
}

/// 统一圆角进度条（带顶部微高光）
struct MiniBar: View {
    let value: Double
    let total: Double
    var tint: Color = Theme.jade
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(AppColor.cardEdge.opacity(0.45))
                Capsule()
                    .fill(LinearGradient(colors: [tint.opacity(0.85), tint], startPoint: .top, endPoint: .bottom))
                    .overlay(alignment: .top) {
                        Capsule().fill(.white.opacity(0.38)).frame(height: max(2, height * 0.3)).padding(.horizontal, 3).padding(.top, 1.5)
                    }
                    .frame(width: total <= 0 ? 0 : geo.size.width * min(1, max(0, value / total)))
            }
        }
        .frame(height: height)
    }
}

/// 兼容旧签名的糖果瓷釉胶囊标签：双层实体厚底 + strokeBorder 内高光，彻底消除左右裁切与双重描边
struct CandyButtonLabel: View {
    let title: String
    var icon: String?
    var coin = false
    var fill: Color = Theme.jade
    var edge: Color = GrowthColors.jadeDark
    var foreground: Color = .white
    var font: Font = AppFont.heading
    var height: CGFloat = 54
    var minWidth: CGFloat = 110
    var expands = false

    private var lip: CGFloat {
        if fill == GrowthColors.disabledFill { return 0 }
        return height < 46 ? 3 : height < 62 ? 4 : 5
    }

    var body: some View {
        HStack(spacing: 6) {
            if let icon { Text(icon) }
            if coin { CoinIcon(size: height * 0.44) }
            Text(title).lineLimit(1).minimumScaleFactor(0.65)
        }
        .font(font)
        .foregroundStyle(foreground)
        .padding(.horizontal, height < 48 ? 14 : 24)
        .frame(height: height - lip)
        .frame(minWidth: minWidth)
        .frame(maxWidth: expands ? .infinity : nil)
        .padding(.bottom, lip)
        .background {
            ZStack(alignment: .top) {
                if lip > 0 {
                    Capsule()
                        .fill(edge)
                        .shadow(color: edge.opacity(0.22), radius: height < 48 ? 4 : 7, x: 0, y: 4)
                }
                Capsule()
                    .fill(LinearGradient(colors: [fill.opacity(0.95), fill], startPoint: .top, endPoint: .bottom))
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                LinearGradient(colors: [.white.opacity(lip > 0 ? 0.52 : 0.2), .clear], startPoint: .top, endPoint: .center),
                                lineWidth: 1.5
                            )
                    )
                    .overlay(Capsule().strokeBorder(edge.opacity(0.88), lineWidth: 1.5))
                    .padding(.bottom, lip)
            }
        }
    }
}
