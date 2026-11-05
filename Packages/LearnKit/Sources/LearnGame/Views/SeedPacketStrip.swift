import LearnCore
import SwiftUI

/// 阳光和植物卡：把卡牌拖到草坪空位种下。
struct SeedPacketStrip: View {
    let kinds: [DefenderKind]
    let sun: Int
    let enabled: Bool
    let draggingID: String?
    let onDragChanged: (DefenderKind, CGPoint) -> Void
    let onDragEnded: (DefenderKind, CGPoint) -> Void

    var body: some View {
        HStack(spacing: 6) {
            Label("\(sun)", systemImage: "sun.max.fill")
                .font(.system(size: 16, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundStyle(Color(red: 0.34, green: 0.22, blue: 0.04))
                .frame(width: 70, height: 58)
                .background(Color(red: 1.0, green: 0.78, blue: 0.16), in: RoundedRectangle(cornerRadius: 5))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color(red: 0.48, green: 0.31, blue: 0.06), lineWidth: 2))
                .accessibilityLabel("阳光 \(sun)")

            ForEach(kinds) { kind in
                packet(for: kind)
            }
        }
        .padding(6)
        .background(Color(red: 0.43, green: 0.32, blue: 0.16), in: RoundedRectangle(cornerRadius: 6))
    }

    private func packet(for kind: DefenderKind) -> some View {
        let affordable = sun >= kind.sunCost
        let available = enabled && affordable
        return VStack(spacing: 0) {
            if let texture = UnitSprites.frames(named: "plant-\(kind.id)").first {
                Image(decorative: texture.cgImage(), scale: 1)
                    .resizable().scaledToFit().frame(width: 38, height: 36)
            }
            Text(kind.name)
                .font(.system(size: 9, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text("☀️\(kind.sunCost)")
                .font(.system(size: 11, weight: .heavy, design: .rounded).monospacedDigit())
        }
        .foregroundStyle(Color(red: 0.20, green: 0.27, blue: 0.10))
        .frame(width: 62, height: 58)
        .background(
            Color(red: affordable ? 0.94 : 0.72, green: affordable ? 0.88 : 0.72,
                  blue: affordable ? 0.62 : 0.68),
            in: RoundedRectangle(cornerRadius: 3))
        .overlay(
            RoundedRectangle(cornerRadius: 3)
                .stroke(Color(red: 0.38, green: 0.29, blue: 0.12), lineWidth: 2))
        .opacity(available ? 1 : 0.52)
        .contentShape(RoundedRectangle(cornerRadius: 3))
        .scaleEffect(draggingID == kind.id ? 0.94 : 1)
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named("gameLayout"))
                .onChanged { value in onDragChanged(kind, value.location) }
                .onEnded { value in onDragEnded(kind, value.location) }
        )
        .allowsHitTesting(available)
        .accessibilityLabel("\(kind.name)，需要 \(kind.sunCost) 阳光")
        .accessibilityHint("拖到草坪空位种下")
    }
}

/// 顶栏上的阳光数量，也给不显示卡牌的场景测试和小屏布局复用。
struct SunCounter: View {
    let amount: Int

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "sun.max.fill")
                .foregroundStyle(Theme.accent)
            Text("\(amount)")
                .font(.title3.weight(.heavy).monospacedDigit())
                .foregroundStyle(Theme.ink)
        }
        .accessibilityLabel("阳光 \(amount)")
    }
}
