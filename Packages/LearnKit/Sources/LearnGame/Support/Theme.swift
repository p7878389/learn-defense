import SpriteKit
import SwiftUI

/// SwiftUI 界面颜色
enum Theme {
    static let paper = Color(red: 0.98, green: 0.95, blue: 0.87)
    static let card = Color.white
    static let ink = Color(red: 0.17, green: 0.17, blue: 0.22)
    static let accent = Color(red: 0.95, green: 0.55, blue: 0.18)
    static let jade = Color(red: 0.24, green: 0.66, blue: 0.52)
    static let wrong = Color(red: 0.90, green: 0.33, blue: 0.30)
    static let muted = Color(red: 0.55, green: 0.52, blue: 0.47)
}

/// SpriteKit 场景颜色
enum Palette {
    static let paper = SKColor(red: 0.98, green: 0.95, blue: 0.87, alpha: 1)
    static let laneA = SKColor(red: 0.93, green: 0.89, blue: 0.78, alpha: 1)
    static let laneB = SKColor(red: 0.96, green: 0.92, blue: 0.82, alpha: 1)
    static let shelf = SKColor(red: 0.62, green: 0.42, blue: 0.28, alpha: 1)
    static let ink = SKColor(red: 0.17, green: 0.17, blue: 0.22, alpha: 1)
    static let signBorder = SKColor(red: 0.55, green: 0.52, blue: 0.47, alpha: 1)
    static let target = SKColor(red: 0.95, green: 0.55, blue: 0.18, alpha: 1)
    static let jade = SKColor(red: 0.24, green: 0.66, blue: 0.52, alpha: 1)
    static let jadeDark = SKColor(red: 0.14, green: 0.45, blue: 0.36, alpha: 1)
    static let hurt = SKColor(red: 0.90, green: 0.33, blue: 0.30, alpha: 1)
    static let bullet = SKColor(red: 1.00, green: 0.80, blue: 0.25, alpha: 1)
}

extension View {
    /// iOS 上全屏显示游戏，macOS（只用于编译检查）退化为 sheet
    @ViewBuilder
    func gameCover<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        #if os(iOS)
        fullScreenCover(item: item, onDismiss: onDismiss, content: content)
        #else
        sheet(item: item, onDismiss: onDismiss, content: content)
        #endif
    }
}

/// 按下时缩小一点，适合孩子的大按钮
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// 答错时左右抖动
struct Shake: GeometryEffect {
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 10 * sin(animatableData * .pi * 4), y: 0))
    }
}
