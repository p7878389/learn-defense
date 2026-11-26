import LearnCore
import SwiftUI

/// 金砖阳光铭牌、深蓝纹章卡文字与冷银金属盾门卡专属美术色。
private enum LocalArt {
    static let sunIcon = Color(red: 0.72, green: 0.36, blue: 0.0)
    static let sunText = Color(red: 0.34, green: 0.20, blue: 0.02)
    static let cardText = Color(red: 0.97, green: 0.93, blue: 0.82)
    static let gateText = Color(red: 0.92, green: 0.96, blue: 1.0)
    static let gateTop = Color(red: 0.28, green: 0.36, blue: 0.48)
    static let gateBottom = Color(red: 0.16, green: 0.22, blue: 0.31)
    static let gateBorder = Color(red: 0.70, green: 0.79, blue: 0.90)
    static let gateMetalTop = Color(red: 0.88, green: 0.93, blue: 0.98)
    static let gateMetalBottom = Color(red: 0.56, green: 0.65, blue: 0.76)
}

/// 森林原木圆角种植托盘：暖胡桃木渐变 + 金砖阳光 + 金属纹章植物卡 + 冷银金属铁栅门卡
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
    var gestureSpace = "gameLayout"
    var cooldowns: [String: Int] = [:]

    struct Packet: Identifiable {
        let kind: DefenderKind
        let skin: CharacterSkin?
        let name: String
        var id: String { kind.id }
    }

    var packets: [Packet] {
        var seen: Set<String> = []
        return kinds.filter { seen.insert($0.id).inserted }.map { kind in
            let skin = skins[kind.id]
            let name = HeraldicArtwork.defenderName(kind: kind, skin: skin)
            return Packet(kind: kind, skin: skin, name: name)
        }
    }

    private var cardWidth: CGFloat { packets.count + (barricade == nil ? 0 : 1) > 7 ? 54 : 62 }

    var body: some View {
        let trayShape = RoundedRectangle(cornerRadius: AppRadius.md)
        HStack(spacing: 6) {
            sunBadge

            ForEach(packets) { card in
                packet(for: card)
            }
            if let barricade {
                barricadePacket(for: barricade)
            }
        }
        .padding(.horizontal, AppSpacing.xs)
        .padding(.top, 6)
        .padding(.bottom, 9)
        .background {
            ZStack {
                trayShape.fill(AppColor.woodEdge)
                    .shadow(color: AppColor.warmShadow.opacity(0.20), radius: 8, y: 4)
                trayShape
                    .fill(LinearGradient(colors: [AppColor.woodTop, AppColor.woodBottom], startPoint: .top, endPoint: .bottom))
                    .overlay(
                        trayShape.strokeBorder(
                            LinearGradient(colors: [AppColor.woodTrim.opacity(0.65), .clear], startPoint: .top, endPoint: .center),
                            lineWidth: 1.5
                        )
                    )
                    .overlay(trayShape.strokeBorder(AppColor.woodEdge.opacity(0.9), lineWidth: 1.5))
                    .padding(.bottom, 3)
            }
        }
    }

    private var sunBadge: some View {
        let shape = RoundedRectangle(cornerRadius: AppRadius.xs)
        return VStack(spacing: 2) {
            Image(systemName: "sun.max.fill")
                .font(AppFont.rounded(20, weight: .black))
                .foregroundStyle(LocalArt.sunIcon)
            Text("\(sun)")
                .font(AppFont.digits(17, weight: .black))
                .foregroundStyle(LocalArt.sunText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(width: 66, height: 61)
        .padding(.bottom, 3)
        .background {
            ZStack {
                shape.fill(AppColor.goldEdge)
                shape
                    .fill(LinearGradient(colors: [AppColor.goldLight, AppColor.gold], startPoint: .top, endPoint: .bottom))
                    .overlay(shape.strokeBorder(.white.opacity(0.65), lineWidth: 1.2))
                    .overlay(shape.strokeBorder(AppColor.goldEdge, lineWidth: 1.5))
                    .padding(.bottom, 3)
            }
        }
        .accessibilityLabel("阳光 \(sun)")
    }

    private func packet(for card: Packet) -> some View {
        let kind = card.kind
        let affordable = sun >= kind.sunCost
        let cooldown = cooldowns[kind.id] ?? 0
        let available = enabled && affordable && cooldown == 0
        let rarity = HeraldicArtwork.defenderRarity(kind: kind, skin: card.skin)
        return VStack(spacing: 0) {
            if let image = UnitSprites.portrait(of: kind, skin: card.skin) {
                Image(decorative: image, scale: 1)
                    .resizable().scaledToFit().frame(width: 34, height: 29)
            }
            Text(card.name)
                .font(AppFont.rounded(9, weight: .heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            HStack(spacing: 1.5) {
                Image(systemName: "sun.max.fill").font(AppFont.rounded(8, weight: .bold)).foregroundStyle(AppColor.gold)
                Text("\(kind.sunCost)").font(AppFont.digits(11, weight: .heavy))
            }
        }
        .foregroundStyle(LocalArt.cardText)
        .padding(.top, 5)
        .frame(width: cardWidth, height: 64)
        .background(CollectionCardFrame(rarity: rarity, locked: false))
        .overlay {
            if cooldown > 0 {
                ZStack {
                    RoundedRectangle(cornerRadius: 6).fill(.black.opacity(0.65))
                    Text("\(cooldown)s").font(AppFont.digits(16, weight: .heavy)).foregroundStyle(.white)
                }
            } else if draggingID == kind.id {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(kind.id == AdventureDoom.id ? AppColor.violetTop : AppColor.jadeTop, lineWidth: 2.5)
            }
        }
        .opacity(available ? 1 : 0.48)
        .contentShape(RoundedRectangle(cornerRadius: 6))
        .scaleEffect(draggingID == kind.id ? 0.94 : 1)
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named(gestureSpace))
                .onChanged { value in onDragChanged(kind, value.location) }
                .onEnded { value in onDragEnded(kind, value.location) }
        )
        .allowsHitTesting(available)
        .accessibilityLabel("\(card.name)，\(rarity.displayName)，需要 \(kind.sunCost) 阳光")
        .accessibilityHint(cooldown > 0 ? "冷却还有 \(cooldown) 秒" : "拖到战场空位种下")
    }

    /// 冷银蓝金属盾门卡：与植物纹章卡同高（64pt）、同圆角，彻底替代旧版简陋灰方框
    private func barricadePacket(for kind: DefenderKind) -> some View {
        let affordable = sun >= kind.sunCost
        let available = barricadeEnabled && affordable
        let shape = RoundedRectangle(cornerRadius: 8)
        return Button(action: onBarricade) {
            VStack(spacing: 1) {
                GateIcon().frame(width: 28, height: 28).padding(.top, 4)
                Text(kind.name)
                    .font(AppFont.rounded(9, weight: .heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                HStack(spacing: 1.5) {
                    Image(systemName: "sun.max.fill").font(AppFont.rounded(8, weight: .bold)).foregroundStyle(AppColor.gold)
                    Text("\(kind.sunCost)").font(AppFont.digits(11, weight: .heavy))
                }
            }
            .foregroundStyle(LocalArt.gateText)
            .frame(width: cardWidth, height: 64)
            .background(
                shape.fill(
                    LinearGradient(
                        colors: [LocalArt.gateTop, LocalArt.gateBottom],
                        startPoint: .top, endPoint: .bottom
                    )
                )
            )
            .overlay(shape.strokeBorder(LocalArt.gateBorder, lineWidth: 2))
            .overlay(shape.inset(by: 2).strokeBorder(.white.opacity(0.22), lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
        .opacity(available ? 1 : 0.48)
        .disabled(!available)
        .accessibilityLabel("\(kind.name)，需要 \(kind.sunCost) 阳光")
        .accessibilityHint("点一下，挡住正在答题的僵尸")
    }
}

/// 卡牌上的金属铁栅门：银白金属渐变栏杆
private struct GateIcon: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            let metal = GraphicsContext.Shading.linearGradient(
                Gradient(colors: [LocalArt.gateMetalTop, LocalArt.gateMetalBottom]),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: h)
            )
            for y in [h * 0.28, h * 0.72] {
                context.fill(Path(roundedRect: CGRect(x: 0, y: y, width: w, height: h * 0.1), cornerRadius: 2), with: metal)
            }
            for i in 0..<4 {
                let x = w * (CGFloat(i) + 0.5) / 4 - w * 0.055
                context.fill(Path(CGRect(x: x, y: h * 0.14, width: w * 0.11, height: h * 0.86)), with: metal)
                var tip = Path()
                tip.move(to: CGPoint(x: x - w * 0.03, y: h * 0.15))
                tip.addLine(to: CGPoint(x: x + w * 0.055, y: 0))
                tip.addLine(to: CGPoint(x: x + w * 0.14, y: h * 0.15))
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
                .foregroundStyle(AppColor.goldEdge)
            Text("\(amount)")
                .font(AppFont.digits(20, weight: .heavy))
                .foregroundStyle(AppColor.ink)
        }
        .accessibilityLabel("阳光 \(amount)")
    }
}
