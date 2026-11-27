import LearnCore
import SwiftUI

extension AdventureScreen {
    @ViewBuilder var stateOverlay: some View {
        if session.hud.phase == .paused || session.battle.isFinished {
            ZStack {
                Color.black.opacity(0.45).ignoresSafeArea()
                if session.battle.isFinished {
                    let won = session.hud.phase == .won
                    CandyModalCard(
                        bannerTitle: won ? "守住了！" : "这次差一点",
                        bannerIcon: won ? "🎉" : "🌱",
                        bannerColors: won ? [AppColor.gold, AppColor.accent] : [AppColor.calm.opacity(0.8), AppColor.calm],
                        bannerEdge: won ? AppColor.accentEdge : LocalArt.defeatBannerEdge,
                        maxWidth: 500
                    ) {
                        HStack(spacing: 10) {
                            if won {
                                ForEach(0..<3, id: \.self) { i in
                                    Image(systemName: i < session.battle.stars ? "star.fill" : "star")
                                        .font(AppFont.rounded(42, weight: .black))
                                        .foregroundStyle(i < session.battle.stars ? AppColor.gold : AppColor.cardEdge)
                                }
                            } else {
                                PictureView(emoji: "🌱", size: 54)
                            }
                        }
                        Text(session.battle.advice)
                            .font(AppFont.bodyStrong)
                            .foregroundStyle(AppColor.ink)
                            .multilineTextAlignment(.center)
                        Text("冒险只记录关卡和星级，不发放积分与学习奖励。")
                            .font(AppFont.label)
                            .foregroundStyle(AppColor.muted)
                        if session.error == nil {
                            AppButton(title: "返回地图", systemImage: "map.fill", role: .adventure, size: .large, expands: true) {
                                if session.abandon() { onClose() }
                            }
                        }
                        if let error = session.error {
                            Text(error).font(AppFont.label).foregroundStyle(AppColor.dangerText)
                            AppButton(title: "重试保存", systemImage: "arrow.clockwise", role: .secondary, size: .large, expands: true, action: session.retrySave)
                        }
                    }
                    .padding(AppSpacing.lg)
                } else {
                    CandyModalCard(
                        bannerTitle: "冒险已暂停",
                        bannerIcon: "⏸️",
                        bannerColors: [AppColor.gold, AppColor.accent],
                        bannerEdge: AppColor.accentEdge,
                        maxWidth: 460
                    ) {
                        Text("阳光、怪物和战斗时间都已暂停，继续不会再次扣积分。")
                            .font(AppFont.body)
                            .foregroundStyle(AppColor.muted)
                            .multilineTextAlignment(.center)
                        VStack(spacing: AppSpacing.sm) {
                            AppButton(title: "继续战斗", systemImage: "play.fill", role: .primary, size: .large, expands: true, action: session.resume)
                            AppButton(title: "返回地图（结束本局）", systemImage: "map.fill", role: .destructive, size: .large, expands: true) {
                                showExit = true
                            }
                        }
                        if let error = session.error {
                            Text(error).font(AppFont.label).foregroundStyle(AppColor.dangerText)
                            AppButton(title: "重试保存", systemImage: "arrow.clockwise", role: .secondary, size: .medium, expands: true, action: session.retrySave)
                        }
                    }
                    .padding(AppSpacing.lg)
                }
            }
        }
    }

    @ViewBuilder var exitConfirmOverlay: some View {
        if showExit {
            CandyConfirmModal(
                title: "离开冒险",
                icon: "⚠️",
                message: "返回地图后本局结束，再次进入将开始新游戏。已消耗的 15 积分不返还。",
                buttons: [
                    CandyConfirmButton(title: "继续冒险", systemImage: "play.fill", role: .primary) { showExit = false },
                    CandyConfirmButton(title: "放弃并返回地图", systemImage: "map.fill", role: .destructive) {
                        showExit = false; if session.abandon() { onClose() }
                    }
                ],
                onDismiss: { showExit = false }
            )
        }
    }
}
