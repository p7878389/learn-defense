import LearnCore
import SwiftUI

/// 宽屏并排，空间不足时分行，避免两个独立 overlay 互相覆盖。
struct BattleTopBar<Seeds: View>: View {
    @ObservedObject var session: GameSession
    let onExit: () -> Void
    @ViewBuilder let seeds: () -> Seeds

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                seeds()
                GameHUD(session: session, onExit: onExit)
            }
            .fixedSize(horizontal: true, vertical: false)
            VStack(alignment: .leading, spacing: 6) {
                GameHUD(session: session, onExit: onExit)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                seeds()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Theme.paper)
    }
}

/// 大招与道具拥有独立操作空间，不盖住第一列植物。
struct BattleActionBar: View {
    @ObservedObject var session: GameSession

    var body: some View {
        HStack(spacing: 14) {
            UltimateButton(energy: session.energy, maxEnergy: session.tuning.ultimateEnergy,
                           ready: session.ultimateReady, action: session.startUltimate,
                           casting: session.isUnleashing, challenging: session.ultimate != nil)
            Rectangle().fill(Theme.muted.opacity(0.25)).frame(width: 1, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text("道具").font(.caption.weight(.bold)).foregroundStyle(Theme.muted)
                if session.inventory.items.isEmpty {
                    Text("击败怪物有机会获得").font(.caption).foregroundStyle(Theme.muted)
                } else {
                    ItemBar(inventory: session.inventory, enabled: session.canUseItems,
                            onUse: session.useItem(at:), horizontal: true)
                }
            }
            Spacer(minLength: 0)
            Label(session.map.name, systemImage: "map.fill")
                .font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
        }
        .frame(minHeight: 72)
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.accent.opacity(0.4), lineWidth: 1))
    }
}
