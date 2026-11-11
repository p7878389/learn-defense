import LearnCore
import SwiftUI

/// 阳光和植物卡：把卡牌拖到草坪空位种下。最后一张铁栅门卡点一下就放在正在答题的僵尸面前
struct SeedPacketStrip: View {
    let kinds: [DefenderKind]
    let sun: Int
    let enabled: Bool
    let draggingID: String?
    /// 射手 id → 装备的皮肤，卡面跟着换
    var skins: [String: CharacterSkin] = [:]
    let onDragChanged: (DefenderKind, CGPoint) -> Void
    let onDragEnded: (DefenderKind, CGPoint) -> Void
    var barricade: DefenderKind? = nil
    var barricadeEnabled = false
    var onBarricade: () -> Void = {}

    /// 卡牌多时窄一点，免得挡住右上角的按钮
    private var cardWidth: CGFloat { kinds.count + (barricade == nil ? 0 : 1) > 7 ? 54 : 62 }

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
            if let barricade {
                barricadePacket(for: barricade)
            }
        }
        .padding(6)
        .background(Color(red: 0.43, green: 0.32, blue: 0.16), in: RoundedRectangle(cornerRadius: 6))
    }

    private func packet(for kind: DefenderKind) -> some View {
        let affordable = sun >= kind.sunCost
        let available = enabled && affordable
        return VStack(spacing: 0) {
            if let image = UnitSprites.portrait(of: kind, skin: skins[kind.id]) {
                Image(decorative: image, scale: 1)
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
        .frame(width: cardWidth, height: 58)
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
        .accessibilityHint("拖到战场空位种下")
    }

    private func barricadePacket(for kind: DefenderKind) -> some View {
        let affordable = sun >= kind.sunCost
        let available = barricadeEnabled && affordable
        return Button(action: onBarricade) {
            VStack(spacing: 0) {
                GateIcon().frame(width: 30, height: 34).padding(.vertical, 1)
                Text(kind.name)
                    .font(.system(size: 9, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text("☀️\(kind.sunCost)")
                    .font(.system(size: 11, weight: .heavy, design: .rounded).monospacedDigit())
            }
            .foregroundStyle(Color(red: 0.16, green: 0.18, blue: 0.22))
            .frame(width: cardWidth, height: 58)
            .background(
                Color(red: affordable ? 0.82 : 0.70, green: affordable ? 0.86 : 0.70, blue: affordable ? 0.90 : 0.70),
                in: RoundedRectangle(cornerRadius: 3))
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color(red: 0.25, green: 0.28, blue: 0.33), lineWidth: 2))
        }
        .buttonStyle(.plain)
        .opacity(available ? 1 : 0.52)
        .disabled(!available)
        .accessibilityLabel("\(kind.name)，需要 \(kind.sunCost) 阳光")
        .accessibilityHint("点一下，挡住正在答题的僵尸")
    }
}

/// 卡牌上的铁栅门：两道横梁、四根竖栏
private struct GateIcon: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            let metal = GraphicsContext.Shading.color(Color(white: 0.45))
            for y in [h * 0.28, h * 0.72] {
                context.fill(Path(CGRect(x: 0, y: y, width: w, height: h * 0.09)), with: metal)
            }
            for i in 0..<4 {
                let x = w * (CGFloat(i) + 0.5) / 4 - w * 0.05
                context.fill(Path(CGRect(x: x, y: h * 0.12, width: w * 0.1, height: h * 0.88)), with: metal)
                var tip = Path()
                tip.move(to: CGPoint(x: x - w * 0.03, y: h * 0.13))
                tip.addLine(to: CGPoint(x: x + w * 0.05, y: 0))
                tip.addLine(to: CGPoint(x: x + w * 0.13, y: h * 0.13))
                tip.closeSubpath()
                context.fill(tip, with: metal)
            }
        }
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
