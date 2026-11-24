import LearnCore
import SwiftUI

struct GameHUD: View {
    @ObservedObject var session: GameSession
    let onExit: () -> Void

    /// 顶部状态栏：暂停、生命、回合进度和得分；阳光在同一工具区的种植卡栏里。
    var body: some View {
        HStack(spacing: 16) {
            if session.phase == .preparing {
                // 还没开局：直接回到上一页，不结算
                Button(action: onExit) {
                    Image(systemName: "chevron.backward.circle.fill")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(GrowthColors.orangeDark)
                        .background(Circle().fill(GrowthColors.gold.opacity(0.25)).frame(width: 34, height: 34))
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("返回")
                Label("准备", systemImage: "leaf.fill")
                    .font(.system(size: 19, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.jade)
            } else {
                Button(action: session.togglePause) {
                    Image(systemName: "pause.circle.fill")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(GrowthColors.orangeDark)
                        .background(Circle().fill(GrowthColors.gold.opacity(0.25)).frame(width: 34, height: 34))
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("暂停")
            }

            if let hearts = session.hearts, let maxHearts = session.tuning.hearts {
                HStack(spacing: 4) {
                    ForEach(0..<maxHearts, id: \.self) { i in
                        Image(systemName: i < hearts ? "heart.fill" : "heart")
                            .foregroundStyle(Theme.wrong)
                    }
                }
                .font(.title2)
            } else {
                HStack(spacing: 4) {
                    Text("不怕失败")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.jade)
                    PictureView(emoji: "💪", size: 28)
                }
            }

            Label("第 \(session.round) 回合 · \(session.roundResolved)/\(session.totalEnemies)", systemImage: "flag.fill")
                .font(.system(size: 19, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundStyle(Theme.ink)

            Label("\(session.score)", systemImage: "star.fill")
                .font(.system(size: 19, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundStyle(Theme.accent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(GrowthColors.surface)
                .shadow(color: GrowthColors.cardEdge, radius: 0, x: 0, y: 3)
        )
        .overlay(Capsule().stroke(GrowthColors.cardEdge, lineWidth: 2))
    }
}

struct PreparationPanel: View {
    @ObservedObject var session: GameSession
    var onChooseBank: () -> Void = {}
    var onStart: (() -> Void)? = nil
    var bankSummary: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                BattleMapPicker(selection: session.map, onSelect: session.selectMap)
                Spacer(minLength: 12)
                Button(action: onChooseBank) {
                    CandyButtonLabel(title: session.bankConfirmed ? "题库与难度" : "选择题库与难度", icon: "📚", fill: GrowthColors.surface, edge: GrowthColors.cardEdge,
                                     foreground: Theme.ink, font: .headline, height: 44)
                }.buttonStyle(PressableStyle())
            }
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("准备布阵")
                        .font(.title2.weight(.heavy))
                        .foregroundStyle(Theme.ink)
                    Text(session.bankConfirmed ? bankSummary ?? "\(session.config.grade.displayName) · \(session.config.difficulty.displayName)" : "首次游戏，请先手动选择并确认题库")
                        .font(.callout.weight(.semibold)).foregroundStyle(session.bankConfirmed ? GrowthColors.jadeDark : GrowthColors.orangeDark)
                        .lineLimit(2)
                    Text("把植物卡拖到战场空位。阳光足够就能继续布阵，种下后不能修改，已布阵 \(session.plantedLaneCount)/\(session.tuning.lanes) 路")
                        .font(.headline)
                        .foregroundStyle(Theme.muted)
                }

                Spacer()

                Button(action: onStart ?? session.startBattle) {
                    CandyButtonLabel(
                        title: !session.bankConfirmed ? "请先选择题库" : session.canStartBattle ? "准备好了" : "先种一株植物",
                        icon: session.canStartBattle ? "▶" : nil,
                        fill: session.canStartBattle ? Theme.jade : GrowthColors.disabledFill,
                        edge: session.canStartBattle ? GrowthColors.jadeDark : GrowthColors.disabledEdge,
                        foreground: session.canStartBattle ? .white : Theme.muted,
                        font: .system(size: 22, weight: .heavy, design: .rounded),
                        height: 56,
                        minWidth: 210
                    )
                }
                .buttonStyle(PressableStyle())
                .disabled(!session.canStartBattle)
            }
        }
    }
}

/// 道具栏：捡到的道具，点一下就用。只显示手里有的道具；
/// 不止一个时折叠成一个按钮，点开向下展开，免得一长条挡住左边的僵尸和血量
struct ItemBar: View {
    let inventory: Inventory
    let enabled: Bool
    let onUse: (Int) -> Void
    var horizontal = false
    @State private var expanded = false

    private var folds: Bool { !horizontal && inventory.items.count > 1 }

    var body: some View {
        let layout = horizontal ? AnyLayout(HStackLayout(alignment: .center, spacing: 8))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
        layout {
            if folds {
                Button { expanded.toggle() } label: {
                    HStack(spacing: 4) {
                        PictureView(emoji: "🎒", size: 30)
                        Text("×\(inventory.items.count)")
                            .font(.system(size: 18, weight: .heavy, design: .rounded).monospacedDigit())
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14, weight: .heavy))
                    }
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 10)
                    .frame(height: 54)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.jade, lineWidth: 3))
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(expanded ? "收起道具" : "展开道具，共 \(inventory.items.count) 个")
            }
            if !folds || expanded {
                ForEach(Array(inventory.items.enumerated()), id: \.offset) { i, item in
                    Button { onUse(i) } label: {
                        PictureView(emoji: item.icon, size: 38)
                            .frame(width: 54, height: 54)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.jade, lineWidth: 3))
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
