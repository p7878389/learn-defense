import LearnCore
import SwiftUI

/// 成长系统界面共用的颜色和小部件（等级牌、经验条、积分牌、奖章）。设计稿见 docs/ui-growth
enum GrowthColors {
    static let gold = Color(red: 1.0, green: 0.79, blue: 0.24)
    static let goldDark = Color(red: 0.88, green: 0.63, blue: 0.0)
    static let sky = Color(red: 0.87, green: 0.95, blue: 1.0)
    static let meadow = Color(red: 0.90, green: 0.96, blue: 0.84)
    static let surface = Color(red: 1.0, green: 0.975, blue: 0.93)
    static let cardEdge = Color(red: 0.92, green: 0.84, blue: 0.71)
    static let orangeDeep = Color(red: 0.79, green: 0.41, blue: 0.06)
    static let purple = Color(red: 0.55, green: 0.36, blue: 0.95)
    static let purpleDark = Color(red: 0.36, green: 0.2, blue: 0.7)
    static let jadeLight = Color(red: 0.48, green: 0.89, blue: 0.74)
    static let jadeDark = Color(red: 0.14, green: 0.45, blue: 0.36)
    static let orangeDark = Color(red: 0.78, green: 0.4, blue: 0.04)
    static let calm = Color(red: 0.36, green: 0.55, blue: 0.85)

    static func rarity(_ rarity: CosmeticRarity) -> Color {
        switch rarity {
        case .common: Color(red: 0.49, green: 0.78, blue: 0.95)
        case .rare: Color(red: 0.65, green: 0.48, blue: 0.95)
        case .legendary: gold
        }
    }
}

/// 成长系统页面共用的纸张底色：暖米色上叠一层很淡的天空蓝和浅草绿。
struct GrowthPageBackground: View {
    var body: some View {
        ZStack {
            Theme.paper
            LinearGradient(
                colors: [
                    GrowthColors.sky.opacity(0.4),
                    Theme.paper,
                    GrowthColors.meadow.opacity(0.5)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }
}

/// 设计稿里的玩具胶囊分栏：白色底槽，当前项用活力橙并带厚底。
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
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(selected ? .white : Theme.muted)
                        .frame(minWidth: 94, minHeight: 44)
                        .padding(.horizontal, 12)
                        .background(
                            Capsule()
                                .fill(selected ? Theme.accent : .clear)
                                .shadow(color: selected ? GrowthColors.orangeDeep : .clear,
                                        radius: 0, x: 0, y: 3))
                }
                .buttonStyle(PressableStyle())
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(6)
        .background(Capsule().fill(GrowthColors.surface).shadow(color: GrowthColors.cardEdge, radius: 0, x: 0, y: 4))
        .overlay(Capsule().stroke(GrowthColors.cardEdge, lineWidth: 2))
        .animation(.spring(response: 0.24, dampingFraction: 0.75), value: selection)
    }
}

/// 白底大圆角卡片 + 底部厚边，像能按下去的糖果
struct CandyCard: ViewModifier {
    var fill: Color = GrowthColors.surface
    var edge: Color = GrowthColors.cardEdge
    var radius: CGFloat = 24

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius)
                    .fill(fill)
                    .shadow(color: edge, radius: 0, x: 0, y: 5))
    }
}

extension View {
    func candyCard(fill: Color = GrowthColors.surface, edge: Color = GrowthColors.cardEdge, radius: CGFloat = 24) -> some View {
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

/// 收藏馆、徽章墙的顶栏：回主页、标题、右侧等级和积分。和主页成长卡一样放在糖果卡片上
struct GrowthPageHeader<Trailing: View>: View {
    let icon: String
    let title: String
    var subtitle: String?
    let onClose: () -> Void
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 16) {
            Button(action: onClose) {
                CandyButtonLabel(title: "回主页", icon: "←", fill: GrowthColors.surface, edge: GrowthColors.cardEdge, foreground: Theme.ink,
                                 font: .system(size: 22, weight: .heavy, design: .rounded), height: 52)
                    .overlay(Capsule().stroke(GrowthColors.cardEdge, lineWidth: 2))
            }
            .buttonStyle(PressableStyle())
            Spacer(minLength: 8)
            PictureView(emoji: icon, size: 40)
            Text(title).font(.system(size: 36, weight: .heavy, design: .rounded)).foregroundStyle(Theme.ink)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(GrowthColors.orangeDark)
                    .padding(.horizontal, 12).padding(.vertical, 4)
                    .background(Capsule().fill(GrowthColors.gold.opacity(0.25)))
            }
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .candyCard()
    }
}

/// 分类标签、单元按钮一类的糖果块：米白底、浅金描边、厚底；选中时换成主色
struct CandyTileBackground: View {
    var selected = false
    var selectedFill: Color = Theme.accent
    var selectedEdge: Color = GrowthColors.orangeDeep
    var radius: CGFloat = 22

    var body: some View {
        RoundedRectangle(cornerRadius: radius)
            .fill(selected ? selectedFill : GrowthColors.surface)
            .shadow(color: selected ? selectedEdge : GrowthColors.cardEdge, radius: 0, x: 0, y: selected ? 5 : 4)
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(selected ? selectedEdge : GrowthColors.cardEdge, lineWidth: 2))
    }
}

/// 金色积分硬币。系统的 🪙 是银色的，这里自己画，保证积分到处都是金色
struct CoinIcon: View {
    var size: CGFloat = 28

    var body: some View {
        Circle()
            .fill(RadialGradient(colors: [Color(red: 1, green: 0.92, blue: 0.55), GrowthColors.gold, GrowthColors.goldDark],
                                 center: .topLeading, startRadius: 1, endRadius: size))
            .overlay(Circle().inset(by: size * 0.14).stroke(Color(red: 0.8, green: 0.55, blue: 0.0).opacity(0.7), lineWidth: size * 0.06))
            .overlay(Image(systemName: "star.fill").font(.system(size: size * 0.42, weight: .black))
                .foregroundStyle(Color(red: 0.85, green: 0.58, blue: 0.0)))
            .frame(width: size, height: size)
            .accessibilityLabel("积分")
    }
}

/// 自己画的进度条（系统 ProgressView 在不同平台上样式不一）
struct MiniBar: View {
    let value: Double
    let total: Double
    var tint: Color = Theme.jade
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.muted.opacity(0.18))
                Capsule().fill(tint)
                    .frame(width: total <= 0 ? 0 : geo.size.width * min(1, max(0, value / total)))
            }
        }
        .frame(height: height)
    }
}

/// 粗体大按钮，带厚底
struct CandyButtonLabel: View {
    let title: String
    var icon: String?
    /// 在文字前面放一枚金币（价格按钮）
    var coin = false
    var fill: Color = Theme.jade
    var edge: Color = GrowthColors.jadeDark
    var foreground: Color = .white
    var font: Font = .system(size: 24, weight: .heavy, design: .rounded)
    var height: CGFloat = 64
    /// 收藏馆一排卡片较多时传 0，让按钮跟着卡片变窄
    var minWidth: CGFloat = 120
    /// 收藏馆操作区铺满宽度；其他页面沿用内容宽度。
    var expands = false

    var body: some View {
        HStack(spacing: 6) {
            if let icon { Text(icon) }
            if coin { CoinIcon(size: height * 0.45) }
            Text(title).lineLimit(1).minimumScaleFactor(0.6)
        }
        .font(font)
        .foregroundStyle(foreground)
        .padding(.horizontal, height < 56 ? 12 : 26)
        .frame(height: height)
        .frame(minWidth: minWidth)
        .frame(maxWidth: expands ? .infinity : nil)
        .background(Capsule().fill(fill).shadow(color: edge, radius: 0, x: 0, y: 5))
    }
}
