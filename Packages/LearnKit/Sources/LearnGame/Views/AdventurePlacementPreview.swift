import LearnCore
import SwiftUI

/// 选点辅助属于 UI。范围尺寸直接使用伤害规则的格距，不在场景中拼装视觉特效。
struct AdventurePlacementPreview: View {
    let battle: AdventureBattle
    let kindID: String?
    let cell: DefenderCell?

    var body: some View {
        GeometryReader { geometry in
            if let cell, let kindID {
                let sx = geometry.size.width / 1200
                let sy = geometry.size.height / 600
                let center = CGPoint(x: AdventureDoom.x(cell.column) * sx, y: (600 - AdventureDoom.y(cell.lane)) * sy)
                let valid = battle.canPlant(kindID, lane: cell.lane, column: cell.column)
                let color: Color = valid ? (kindID == AdventureDoom.id ? .purple : Theme.jade) : Theme.wrong
                ZStack {
                    if kindID == AdventureDoom.id {
                        Ellipse()
                            .fill(color.opacity(0.12))
                            .overlay(Ellipse().stroke(color.opacity(0.9), style: StrokeStyle(lineWidth: 2, dash: [7, 5])))
                            .frame(width: AdventureDoom.radius * 2 * AdventureDoom.columnWidth * sx,
                                   height: AdventureDoom.radius * 2 * AdventureDoom.rowHeight * sy)
                            .position(center)
                    }
                    Rectangle().fill(color.opacity(0.25))
                        .overlay(Rectangle().stroke(color, lineWidth: 2))
                        .frame(width: AdventureDoom.columnWidth * sx, height: AdventureDoom.rowHeight * sy)
                        .position(center)
                    if valid, let kind = AdventureCatalog.defender(kindID), let image = UnitSprites.portrait(of: kind, skin: nil) {
                        Image(decorative: image, scale: 1).resizable().scaledToFit()
                            .frame(width: 75 * sx, height: 80 * sy).opacity(0.65).position(center)
                    } else if !valid {
                        Text("不可放置").font(.system(size: max(10, 14 * sx), weight: .bold))
                            .foregroundStyle(.white).padding(4).background(Theme.wrong, in: Capsule()).position(center)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .mask(Rectangle().frame(width: geometry.size.width, height: 500 * sy).offset(y: 80 * sy)
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
