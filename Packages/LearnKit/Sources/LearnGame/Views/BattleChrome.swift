import LearnCore
import SwiftUI

/// 宽屏并排，空间不足时分行，避免两个独立 overlay 互相覆盖。
struct BattleTopBar<Seeds: View>: View {
    @ObservedObject var session: GameSession
    let onExit: () -> Void
    @ViewBuilder let seeds: () -> Seeds

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: AppSpacing.sm) {
                seeds()
                Spacer(minLength: 0)
                GameHUD(session: session, onExit: onExit)
            }
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                GameHUD(session: session, onExit: onExit)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                seeds()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .appPanel(radius: AppRadius.md)
        .padding(.horizontal, AppSpacing.sm)
    }
}

/// 经典战斗中栏：左侧雷霆大招 + 中间 3 格可视化道具凹槽（不再大面积空荡）+ 右侧绘本地图标签。
struct BattleActionBar: View {
    @ObservedObject var session: GameSession

    private var slotCount: Int { max(3, session.inventory.capacity) }

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            UltimateButton(energy: session.energy, maxEnergy: session.tuning.ultimateEnergy,
                           ready: session.ultimateReady, action: session.startUltimate,
                           casting: session.isUnleashing, challenging: session.ultimate != nil)

            RoundedRectangle(cornerRadius: 1)
                .fill(AppColor.cardEdge.opacity(0.65))
                .frame(width: 1.5, height: 44)

            HStack(spacing: AppSpacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("战场道具")
                        .font(AppFont.label)
                        .foregroundStyle(AppColor.ink)
                    Text(session.inventory.items.isEmpty ? "击败怪物掉落" : "点按即可使用")
                        .font(AppFont.caption)
                        .foregroundStyle(AppColor.muted)
                }

                HStack(spacing: AppSpacing.xs) {
                    ForEach(0..<slotCount, id: \.self) { index in
                        if index < session.inventory.items.count {
                            let item = session.inventory.items[index]
                            Button { session.useItem(at: index) } label: {
                                PictureView(emoji: item.icon, size: 34)
                                    .frame(width: 50, height: 50)
                                    .background(
                                        CandyTileBackground(
                                            selected: false,
                                            radius: AppRadius.sm
                                        )
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppRadius.sm)
                                            .strokeBorder(AppColor.jade, lineWidth: 2)
                                            .padding(.bottom, 3)
                                    )
                            }
                            .buttonStyle(PressableStyle())
                            .disabled(!session.canUseItems)
                            .accessibilityLabel("\(item.name)，\(item.summary)")
                            .transition(.scale(scale: 0.7).combined(with: .opacity))
                        } else {
                            RoundedRectangle(cornerRadius: AppRadius.sm)
                                .fill(AppColor.paper.opacity(0.85))
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppRadius.sm)
                                        .strokeBorder(AppColor.cardEdge.opacity(0.75), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                                )
                                .overlay(
                                    Image(systemName: "sparkles")
                                        .font(AppFont.rounded(14, weight: .semibold))
                                        .foregroundStyle(AppColor.cardEdge)
                                )
                                .frame(width: 50, height: 50)
                                .accessibilityHidden(true)
                        }
                    }
                }
                .animation(.spring(response: 0.28, dampingFraction: 0.65), value: session.inventory)
            }

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                Circle().fill(AppColor.jade).frame(width: 8, height: 8)
                Image(systemName: "map.fill").font(AppFont.rounded(12, weight: .bold))
                Text(session.map.name).font(AppFont.label)
            }
            .foregroundStyle(AppColor.jadeEdge)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, 7)
            .background(Capsule().fill(AppColor.jade.opacity(0.14)))
            .overlay(Capsule().strokeBorder(AppColor.jade.opacity(0.32), lineWidth: 1))
        }
        .frame(minHeight: 68)
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.xs)
        .appPanel(radius: AppRadius.md)
    }
}
