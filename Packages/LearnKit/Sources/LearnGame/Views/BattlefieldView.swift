import LearnCore
import SwiftUI

import SpriteKit

struct BattlefieldView: View {
    @ObservedObject var session: GameSession
    let debugOptions: SpriteView.DebugOptions

    var body: some View {
        BattlefieldLayout {
            GeometryReader { geometry in
                SpriteView(
                    scene: session.scene,
                    preferredFramesPerSecond: 120,
                    debugOptions: debugOptions)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .simultaneousGesture(SpatialTapGesture().onEnded { value in
                        guard session.phase == .playing, session.ultimate == nil,
                              let point = GameScene.scenePoint(at: value.location,
                                  in: CGRect(origin: .zero, size: geometry.size)) else { return }
                        session.scene.selectTarget(at: point)
                    })
            }
        }
    }
}

/// 战场尺寸按 GameScene.battlefieldSize：横屏时可以比 2:1 宽，两侧由场景画出地图延伸，不留空白
private struct BattlefieldLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        GameScene.battlefieldSize(fitting: proposal.replacingUnspecifiedDimensions(by: GameScene.designSize))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for subview in subviews {
            subview.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
        }
    }
}

/// 拖动中的植物卡。DragGesture 每帧都改 location，用 Observation 只让读到它的小视图刷新
@MainActor @Observable
final class PlantDragState {
    var kind: DefenderKind?
    var location: CGPoint = .zero
}

/// 跟着手指走的植物卡预览
struct PlantDragFollower: View {
    let drag: PlantDragState
    let kind: DefenderKind
    let skin: CharacterSkin?

    var body: some View {
        PlantDragGhost(kind: kind, skin: skin)
            .position(drag.location)
            .allowsHitTesting(false)
    }
}

/// 拖到战场上方时给战场描一圈绿边
struct PlantDropHighlight: View {
    let drag: PlantDragState
    let battlefield: CGRect

    var body: some View {
        if drag.kind != nil, battlefield.contains(drag.location) {
            RoundedRectangle(cornerRadius: 6)
                .stroke(AppColor.jade, lineWidth: 5)
                .padding(AppSpacing.xxs)
                .allowsHitTesting(false)
        }
    }
}

private struct PlantDragGhost: View {
    let kind: DefenderKind
    let skin: CharacterSkin?

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            if let image = UnitSprites.portrait(of: kind, skin: skin) {
                Image(decorative: image, scale: 1)
                    .resizable().scaledToFit().frame(width: 54, height: 50)
            }
            Text(HeraldicArtwork.defenderName(kind: kind, skin: skin))
                .font(AppFont.bodyStrong)
                .foregroundStyle(AppColor.ink)
        }
        .padding(AppSpacing.xs)
        .background(AppColor.goldLight.opacity(0.92), in: RoundedRectangle(cornerRadius: AppRadius.sm))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.sm).strokeBorder(AppColor.goldEdge, lineWidth: 2.5))
        .shadow(color: AppColor.warmShadow.opacity(0.28), radius: 10, y: 5)
    }
}

/// 量出视图的自然高度，只记下更大的值
struct MaxHeightReader: ViewModifier {
    @Binding var height: CGFloat
    /// 转屏后布局换了，之前量的最高值不再适用：这个值一变就按新布局重新记
    var resetKey = false

    func body(content: Content) -> some View {
        content.background(
            GeometryReader { proxy in
                Color.clear
                    .onChange(of: proxy.size.height, initial: true) { _, newHeight in
                        height = max(height, newHeight)
                    }
                    .onChange(of: resetKey) { _, _ in
                        height = proxy.size.height
                    }
            })
    }
}
