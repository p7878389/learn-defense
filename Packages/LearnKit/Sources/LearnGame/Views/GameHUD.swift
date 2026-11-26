import LearnCore
import SwiftUI

struct GameHUD: View {
    @ObservedObject var session: GameSession
    let onExit: () -> Void

    /// 顶部状态内嵌栏：平铺于 BattleTopBar 面板内，去掉厚底与卡套卡，统一 SF Rounded 等宽数字。
    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            if session.phase == .preparing {
                Button(action: onExit) {
                    circleControl(systemImage: "chevron.left")
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("返回")

                Label("准备", systemImage: "leaf.fill")
                    .font(AppFont.bodyStrong)
                    .foregroundStyle(AppColor.jadeEdge)
            } else {
                Button(action: session.togglePause) {
                    circleControl(systemImage: "pause.fill")
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("暂停")
            }

            divider

            if let hearts = session.hearts, let maxHearts = session.tuning.hearts {
                HStack(spacing: AppSpacing.xxs) {
                    ForEach(0..<maxHearts, id: \.self) { i in
                        Image(systemName: i < hearts ? "heart.fill" : "heart")
                            .font(AppFont.rounded(20, weight: .bold))
                            .foregroundStyle(i < hearts ? AppColor.dangerText : AppColor.cardEdge)
                    }
                }
            } else {
                HStack(spacing: AppSpacing.xxs) {
                    Text("不怕失败")
                        .font(AppFont.bodyStrong)
                        .foregroundStyle(AppColor.jadeEdge)
                    PictureView(emoji: "💪", size: 24)
                }
            }

            divider

            Label("第 \(session.round) 回合 · \(session.roundResolved)/\(session.totalEnemies)", systemImage: "flag.fill")
                .font(AppFont.digits(18, weight: .heavy))
                .foregroundStyle(AppColor.ink)

            divider

            Label("\(session.score)", systemImage: "star.fill")
                .font(AppFont.digits(18, weight: .heavy))
                .foregroundStyle(AppColor.goldEdge)
        }
        .padding(.horizontal, AppSpacing.sm)
        .frame(height: 52)
        .appInset(radius: AppRadius.md)
    }

    private var divider: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(AppColor.cardEdge.opacity(0.75))
            .frame(width: 1.5, height: 22)
    }

    private func circleControl(systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(AppFont.rounded(16, weight: .black))
            .foregroundStyle(AppColor.ink)
            .frame(width: 36, height: 36)
            .background(
                Circle().fill(LinearGradient(colors: [AppColor.surface, AppColor.surfaceBottom], startPoint: .top, endPoint: .bottom))
            )
            .overlay(Circle().strokeBorder(AppColor.cardStroke, lineWidth: 1.5))
            .shadow(color: AppColor.warmShadow.opacity(0.10), radius: 3, y: 2)
    }
}

struct PreparationPanel: View {
    @ObservedObject var session: GameSession
    var onChooseBank: () -> Void = {}
    var onStart: (() -> Void)? = nil
    var bankSummary: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.sm) {
                BattleMapPicker(selection: session.map, onSelect: session.selectMap)
                Spacer(minLength: AppSpacing.sm)
                AppButton(
                    title: session.bankConfirmed ? "题库与难度" : "选择题库与难度",
                    systemImage: "books.vertical.fill",
                    role: .secondary,
                    size: .medium,
                    action: onChooseBank
                )
            }
            HStack(spacing: AppSpacing.md) {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    HStack(spacing: AppSpacing.xs) {
                        Text("准备布阵")
                            .font(AppFont.heading)
                            .foregroundStyle(AppColor.ink)
                        Text(session.bankConfirmed ? bankSummary ?? "\(session.config.grade.displayName) · \(session.config.difficulty.displayName)" : "请先手动选择题库")
                            .font(AppFont.label)
                            .foregroundStyle(session.bankConfirmed ? AppColor.jadeEdge : AppColor.dangerText)
                            .padding(.horizontal, AppSpacing.sm).padding(.vertical, 3)
                            .background(Capsule().fill(session.bankConfirmed ? AppColor.jade.opacity(0.14) : AppColor.dangerFill))
                            .lineLimit(1)
                    }
                    Text("把植物卡拖到草坪空位。种下后不能修改，已布阵 \(session.plantedLaneCount)/\(session.tuning.lanes) 路")
                        .font(AppFont.body)
                        .foregroundStyle(AppColor.muted)
                }

                Spacer(minLength: AppSpacing.xs)

                AppButton(
                    title: !session.bankConfirmed ? "请先选择题库" : session.canStartBattle ? "准备好了" : "先种一株植物",
                    systemImage: session.canStartBattle ? "play.fill" : nil,
                    role: .primary,
                    size: .large,
                    minWidth: 200,
                    action: onStart ?? session.startBattle
                )
                .disabled(!session.canStartBattle)
            }
        }
    }
}

/// 道具栏：捡到的道具，点一下就用（供独立测试或窄屏折叠复用）。
struct ItemBar: View {
    let inventory: Inventory
    let enabled: Bool
    let onUse: (Int) -> Void
    var horizontal = false
    @State private var expanded = false

    private var folds: Bool { !horizontal && inventory.items.count > 1 }

    var body: some View {
        let layout = horizontal ? AnyLayout(HStackLayout(alignment: .center, spacing: AppSpacing.xs))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: AppSpacing.xs))
        layout {
            if folds {
                Button { expanded.toggle() } label: {
                    HStack(spacing: AppSpacing.xxs) {
                        PictureView(emoji: "🎒", size: 28)
                        Text("×\(inventory.items.count)")
                            .font(AppFont.digits(17, weight: .heavy))
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(AppFont.rounded(13, weight: .heavy))
                    }
                    .foregroundStyle(AppColor.ink)
                    .padding(.horizontal, AppSpacing.sm)
                    .frame(height: 52)
                    .background(CandyTileBackground(radius: AppRadius.sm))
                    .overlay(RoundedRectangle(cornerRadius: AppRadius.sm).strokeBorder(AppColor.jade, lineWidth: 2).padding(.bottom, 3))
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(expanded ? "收起道具" : "展开道具，共 \(inventory.items.count) 个")
            }
            if !folds || expanded {
                ForEach(Array(inventory.items.enumerated()), id: \.offset) { i, item in
                    Button { onUse(i) } label: {
                        PictureView(emoji: item.icon, size: 36)
                            .frame(width: 52, height: 52)
                            .background(CandyTileBackground(radius: AppRadius.sm))
                            .overlay(RoundedRectangle(cornerRadius: AppRadius.sm).strokeBorder(AppColor.jade, lineWidth: 2).padding(.bottom, 3))
                    }
                    .buttonStyle(PressableStyle())
                    .disabled(!enabled)
                    .accessibilityLabel("\(item.name)，\(item.summary)")
                    .transition(.scale(scale: 0.6, anchor: .top).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: inventory)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: expanded)
        .onChange(of: folds) { _, nowFolds in
            if !nowFolds { expanded = false }
        }
    }
}
