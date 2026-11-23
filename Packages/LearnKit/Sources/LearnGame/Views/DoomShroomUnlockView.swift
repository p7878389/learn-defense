import LearnCore
import SwiftUI

struct DoomShroomUnlockView: View {
    @EnvironmentObject private var model: AppModel
    let profileID: UUID
    let onClose: () -> Void
    var embedded = false
    var wideLayout: Bool? = nil
    @State private var selected = false
    @State private var confirming = false
    @State private var error: String?

    private var growth: GrowthStore { model.growth(for: profileID) }
    private var owned: Bool { growth.state.ownsDoomShroom }
    private var locked: Bool { !owned && growth.level.level < AdventureDoom.unlockLevel }
    private var status: String {
        owned ? "已永久解锁" : locked ? "Lv.3 解锁" : "300 积分"
    }

    var body: some View {
        GeometryReader { geometry in
            let wide = wideLayout ?? (geometry.size.width >= 900 && geometry.size.height >= 650)
            VStack(spacing: 18) {
                if !embedded {
                    HStack {
                        Label("道具解锁", systemImage: "sparkles").font(.title2.bold())
                        Spacer()
                        CoinPill(coins: growth.state.coins, size: 16)
                        Button("关闭", action: onClose).buttonStyle(.bordered)
                    }
                }
                if wide {
                    HStack(alignment: .top, spacing: 20) {
                        ScrollView { sidebar.padding(6) }.frame(width: 190)
                        wardrobe(wide: true)
                        details.padding(6).frame(width: 320)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 22) {
                            sidebar
                            details
                            wardrobe(wide: false)
                        }
                        .padding(6)
                    }
                }
            }
            .padding(embedded ? 0 : geometry.size.width < 600 ? 14 : 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(GrowthPageBackground())
        .confirmationDialog("花 300 积分为这个孩子永久解锁毁灭菇？", isPresented: $confirming, titleVisibility: .visible) {
            Button("永久解锁 · 300 积分", action: purchase)
            Button("取消", role: .cancel) {}
        }
        .alert("解锁未完成", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("知道了") { error = nil }
        } message: { Text(error ?? "") }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("选择道具类别").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(Theme.muted)
            HStack(spacing: 10) {
                PictureView(emoji: "💥", size: 34)
                VStack(alignment: .leading, spacing: 4) {
                    Text("种植道具").font(.system(size: 18, weight: .heavy, design: .rounded))
                    Text("共 1 件").font(.system(size: 12, weight: .bold, design: .rounded))
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white).padding(18)
            .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
            .background(CandyTileBackground(selected: true))
            Text("永久解锁后，经典地图和森林冒险均可选择；每个孩子独立拥有。")
                .font(.system(size: 14, weight: .medium, design: .rounded)).foregroundStyle(Theme.muted)
        }
    }

    private func wardrobe(wide: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("种植道具").font(.system(size: 24, weight: .heavy, design: .rounded)).foregroundStyle(Theme.ink)
                Spacer(minLength: 8)
                Text("共 1 件").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(GrowthColors.orangeDark)
            }
            if wide { ScrollView { grid }.frame(minHeight: 240) }
            else { grid }
            Text("点卡片只预览 · 解锁后所有地图可用")
                .font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var grid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 14)], spacing: 18) {
            Button { selected = true } label: {
                VStack(spacing: 8) {
                    VStack(spacing: 4) {
                        HStack {
                            Spacer(minLength: 0)
                            if owned {
                                Label("已拥有", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.white).padding(.horizontal, 6).padding(.vertical, 4)
                                    .background(Capsule().fill(Theme.jade))
                            } else if locked { Text("未解锁").foregroundStyle(Theme.muted) }
                        }
                        .font(.system(size: 11, weight: .heavy, design: .rounded)).frame(height: 22)
                        portrait(height: 100).grayscale(locked ? 1 : 0).opacity(locked ? 0.35 : 1)
                            .shadow(color: .black.opacity(0.12), radius: 3, x: 0, y: 4)
                    }
                    .padding(10).frame(height: 146)
                    Text("毁灭菇").font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.ink).frame(minHeight: 42).padding(.horizontal, 6)
                    Text(selected && !owned ? "◉ 正在预览" : status)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(owned ? GrowthColors.jadeDark : selected ? GrowthColors.orangeDark : Theme.muted)
                        .frame(height: 18)
                    Text("传说").font(.system(size: 12, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 4)
                        .background(Capsule().fill(Color(red: 0.48, green: 0.29, blue: 0.04).opacity(locked ? 0.45 : 0.9)))
                }
                .padding(.horizontal, 18).padding(.top, 28).padding(.bottom, 34)
                .frame(maxWidth: .infinity)
                .background(CollectionCardFrame(rarity: .legendary, locked: locked, lightInterior: true)
                    .shadow(color: selected ? Theme.accent.opacity(0.5) : .clear, radius: 4))
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("毁灭菇，传说，\(status)，点击预览")
            .accessibilityAddTraits(selected ? .isSelected : [])
        }
        .padding(8)
    }

    private func portrait(height: CGFloat) -> some View {
        Group {
            if let image = UnitSprites.portrait(of: AdventureCatalog.doomShroom, skin: nil) {
                Image(decorative: image, scale: 1).resizable().scaledToFit()
            }
        }
        .frame(maxWidth: .infinity).frame(height: height)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("道具预览").font(.system(size: 17, weight: .heavy, design: .rounded))
                Spacer()
                Label(owned ? "已拥有" : "仅试看", systemImage: owned ? "checkmark.circle.fill" : "eye")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(owned ? GrowthColors.jadeDark : GrowthColors.orangeDark)
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .background(Capsule().fill((owned ? Theme.jade : GrowthColors.gold).opacity(0.16)))
            }
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 26)
                    .fill(LinearGradient(colors: [GrowthColors.sky, Color(red: 0.86, green: 0.95, blue: 0.82)], startPoint: .top, endPoint: .bottom))
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    portrait(height: 90).padding(.top, 26)
                    Spacer(minLength: 0)
                    Rectangle().fill(Color(red: 0.46, green: 0.72, blue: 0.2)).frame(height: 14)
                }.clipShape(RoundedRectangle(cornerRadius: 26))
                Text("👁 道具预览").font(.system(size: 17, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(Capsule().fill(Color(red: 0.63, green: 0.39, blue: 0.2))).padding(16)
            }
            .frame(height: 158)
            .overlay(RoundedRectangle(cornerRadius: 26).stroke(GrowthColors.gold.opacity(0.7), lineWidth: 4))
            HStack {
                Text("毁灭菇").font(.system(size: 22, weight: .heavy, design: .rounded)).foregroundStyle(Theme.ink)
                Spacer()
                Text("传说").font(.system(size: 12, weight: .heavy, design: .rounded)).foregroundStyle(GrowthColors.rarity(.legendary))
            }
            Text("一次性范围爆破，原格留下焦坑。125 阳光 · 1 秒蓄力 · 50 秒冷却 · 180 秒禁种。")
                .font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(Theme.muted)
            unlockAction
            Text("一次购买，永久拥有 · 经典地图和森林冒险均可使用")
                .font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(Theme.muted)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 26).fill(GrowthColors.surface)
            .shadow(color: GrowthColors.cardEdge, radius: 0, x: 0, y: 5))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(GrowthColors.gold.opacity(0.65), lineWidth: 3))
    }

    @ViewBuilder private var unlockAction: some View {
        let font = Font.system(size: 18, weight: .heavy, design: .rounded)
        if owned {
            CandyButtonLabel(title: "已永久解锁 ✓", fill: Theme.jade, edge: GrowthColors.jadeDark,
                             font: font, height: 50, minWidth: 0, expands: true)
        } else if locked {
            Text("🔒 Lv.3 解锁 · 还差 \(AdventureDoom.unlockLevel - growth.level.level) 级")
                .font(.system(size: 14, weight: .heavy, design: .rounded)).foregroundStyle(Theme.muted)
            MiniBar(value: Double(growth.level.level), total: Double(AdventureDoom.unlockLevel), tint: Theme.accent)
            CandyButtonLabel(title: "还没解锁", fill: Color(white: 0.9), edge: Color(white: 0.78),
                             foreground: Theme.muted, font: font, height: 46, minWidth: 0, expands: true)
        } else if growth.state.coins < AdventureDoom.unlockPrice {
            Text("还差 \(AdventureDoom.unlockPrice - growth.state.coins) 积分").font(.headline).foregroundStyle(Theme.wrong)
            CandyButtonLabel(title: "300 积分", coin: true, fill: Color(white: 0.88), edge: Color(white: 0.75),
                             foreground: Theme.muted, font: font, height: 50, minWidth: 0, expands: true)
        } else {
            Button { confirming = true } label: {
                CandyButtonLabel(title: "300 购买", coin: true, fill: Theme.accent, edge: GrowthColors.orangeDark,
                                 font: font, height: 50, minWidth: 0, expands: true)
            }
            .buttonStyle(PressableStyle())
        }
    }

    private func purchase() {
        do {
            switch try model.purchaseDoomShroom(for: profileID) {
            case .bought, .alreadyOwned: break
            case .locked: error = "达到 Lv.3 后即可购买"
            case .notEnough(let short): error = "还差 \(short) 积分"
            case .conditionLocked: error = "尚未满足解锁条件"
            }
        } catch { self.error = error.localizedDescription }
    }
}
