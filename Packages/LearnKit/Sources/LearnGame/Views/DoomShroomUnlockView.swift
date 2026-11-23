import LearnCore
import SwiftUI

struct DoomShroomUnlockView: View {
    @EnvironmentObject private var model: AppModel
    let profileID: UUID
    let onClose: () -> Void
    @State private var confirming = false
    @State private var error: String?

    private var growth: GrowthStore { model.growth(for: profileID) }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("道具解锁", systemImage: "sparkles").font(.title2.bold()).lineLimit(1)
                        Spacer()
                        Button("关闭", action: onClose).font(.headline).buttonStyle(.bordered)
                            .frame(minHeight: 44)
                    }
                    HStack {
                        Text("当前孩子专属 · 永久拥有").font(.caption).foregroundStyle(Theme.muted)
                        Spacer(minLength: 8)
                        CoinPill(coins: growth.state.coins, size: 16)
                    }
                }
                .padding(14).candyCard()
                if let image = UnitSprites.portrait(of: AdventureCatalog.doomShroom, skin: nil) {
                    Image(decorative: image, scale: 1).resizable().scaledToFit().frame(height: 120)
                }
                Text("毁灭菇").font(.largeTitle.bold())
                Text("经典模式所有地图、森林冒险均可选择")
                    .font(.headline).multilineTextAlignment(.center)
                Text("消耗 125 阳光 · 蓄力 1 秒 · 冷却 50 秒\n大范围爆破后，原格禁种 180 秒")
                    .multilineTextAlignment(.center).foregroundStyle(Theme.muted)
                if growth.state.ownsDoomShroom {
                    Label("已永久解锁", systemImage: "checkmark.seal.fill")
                        .font(.title2.bold()).foregroundStyle(Theme.jade)
                } else {
                    Text("Lv.3 后可购买 · 当前 Lv.\(growth.level.level)").font(.headline)
                    Button("300 积分 · 永久解锁") { confirming = true }
                        .font(.headline).buttonStyle(.borderedProminent).tint(Theme.jade)
                        .disabled(growth.level.level < AdventureDoom.unlockLevel || growth.state.coins < AdventureDoom.unlockPrice)
                    if growth.level.level < AdventureDoom.unlockLevel {
                        Text("达到 Lv.3 后即可用积分解锁").foregroundStyle(Theme.muted)
                    } else if growth.state.coins < AdventureDoom.unlockPrice {
                        Text("还差 \(AdventureDoom.unlockPrice - growth.state.coins) 积分").foregroundStyle(Theme.muted)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .background(GrowthPageBackground())
        .confirmationDialog("花 300 积分为这个孩子永久解锁毁灭菇？", isPresented: $confirming, titleVisibility: .visible) {
            Button("永久解锁 · 300 积分") {
                do {
                    switch try model.purchaseDoomShroom(for: profileID) {
                    case .bought, .alreadyOwned: break
                    case .locked: error = "达到 Lv.3 后即可购买"
                    case .notEnough(let short): error = "还差 \(short) 积分"
                    case .conditionLocked: error = "尚未满足解锁条件"
                    }
                } catch { self.error = error.localizedDescription }
            }
            Button("取消", role: .cancel) {}
        }
        .alert("解锁未完成", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("知道了") { error = nil }
        } message: { Text(error ?? "") }
    }
}
