import LearnCore
import SpriteKit
import SwiftUI

struct AdventureView: View {
    @StateObject private var session: AdventureSession
    let onClose: () -> Void

    init(levelID: Int, model: AppModel, profileID: UUID, difficulty: Difficulty, deck: [String], onClose: @escaping () -> Void) {
        _session = StateObject(wrappedValue: AdventureSession(levelID: levelID, model: model, profileID: profileID,
                                                             difficulty: difficulty, deck: deck))
        self.onClose = onClose
    }

    var body: some View { AdventureScreen(session: session, onClose: onClose) }
}

struct AdventureScreen: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var session: AdventureSession
    @State private var frame: CGRect = .zero
    @State private var selected: String?
    @State private var shoveling = false
    @State private var placementCell: DefenderCell?
    @State private var placementMessage: String?
    @State private var showExit = false
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            topBar
            cards
            GeometryReader { geometry in
                SpriteView(scene: session.scene)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                    .overlay(RoundedRectangle(cornerRadius: AppRadius.sm).strokeBorder(AppColor.woodTop.opacity(0.85), lineWidth: 3))
                    .overlay(RoundedRectangle(cornerRadius: AppRadius.sm).inset(by: 2).strokeBorder(AppColor.goldLight.opacity(0.35), lineWidth: 1))
                    .shadow(color: AppColor.warmShadow.opacity(0.20), radius: 12, y: 5)
                    .background(GeometryReader { proxy in
                        Color.clear.onChange(of: proxy.frame(in: .named("adventure")), initial: true) { _, value in frame = value }
                    })
                    .overlay {
                        AdventurePlacementPreview(battle: session.battle, kindID: selected, cell: placementCell)
                    }
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("adventure"))
                        .onChanged { value in updatePreview(at: value.location) }
                        .onEnded { value in place(at: value.location) })
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            bottomBar
        }
        .padding(12)
        .coordinateSpace(name: "adventure")
        .background(GrowthPageBackground())
        .overlay { stateOverlay }
        .overlay { exitConfirmOverlay }
        .interactiveDismissDisabled()
        .onChange(of: scenePhase) { _, phase in if phase != .active { session.suspend() } }
        .onDisappear { session.abandon() }
    }

    private var topBar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { titleBadge; Spacer(); counters; pauseButton }
            VStack(spacing: 8) { HStack { titleBadge; Spacer(); pauseButton }; counters }
        }
    }

    /// 森林徽章关卡标牌：不再让标题和波次裸浮在米色背景上
    private var titleBadge: some View {
        HStack(spacing: 10) {
            AppIconBadge(systemImage: "leaf.fill", tint: AppColor.adventure, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.battle.level.title)
                    .font(AppFont.bodyStrong)
                    .foregroundStyle(Theme.ink)
                Text("第 \(session.hud.wave)/5 波 · \(session.battle.difficulty.displayName)")
                    .font(AppFont.caption)
                    .foregroundStyle(AppColor.adventureEdge)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .candyCard(radius: AppRadius.md)
    }

    /// 消除与下方种植托盘重复的阳光数字，专注基地生命与计时
    private var counters: some View {
        HStack(spacing: 14) {
            Label("\(session.hud.lives)/10", systemImage: "heart.fill")
                .foregroundStyle(Theme.wrong)
            RoundedRectangle(cornerRadius: 1)
                .fill(AppColor.cardEdge.opacity(0.75))
                .frame(width: 1.5, height: 18)
            Label(String(format: "%02d:%02d", session.hud.seconds / 60, session.hud.seconds % 60), systemImage: "clock.fill")
                .foregroundStyle(Theme.ink)
        }
        .font(AppFont.digits(17, weight: .heavy))
        .padding(.horizontal, 16)
        .frame(height: 46)
        .padding(.bottom, 3)
        .background {
            ZStack {
                Capsule().fill(AppColor.cardEdge)
                Capsule()
                    .fill(LinearGradient(colors: [AppColor.surface, AppColor.surfaceBottom], startPoint: .top, endPoint: .bottom))
                    .overlay(Capsule().strokeBorder(AppColor.cardStroke, lineWidth: 1.5))
                    .padding(.bottom, 3)
            }
        }
    }

    private var pauseButton: some View {
        AppButton(
            title: session.hud.phase == .playing ? "暂停" : "返回",
            systemImage: session.hud.phase == .playing ? "pause.fill" : "chevron.left",
            role: .secondary,
            size: .medium
        ) {
            if session.battle.phase == .playing { session.suspend() }
            else { showExit = true }
        }
    }

    private var cards: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                SeedPacketStrip(kinds: session.plantable, sun: session.hud.sun,
                    enabled: session.battle.canBuild, draggingID: selected, skins: session.loadout.defenderSkins,
                    onDragChanged: { kind, point in
                        selected = kind.id; shoveling = false; placementMessage = nil
                        updatePreview(at: point)
                    },
                    onDragEnded: { kind, point in
                        selected = kind.id
                        if frame.contains(point) { place(at: point) }
                    }, gestureSpace: "adventure", cooldowns: [AdventureDoom.id: session.hud.doomCooldown])

                AppButton(
                    title: shoveling ? "点击草坪铲除" : "铲除植物",
                    systemImage: shoveling ? "xmark.circle.fill" : "trash.slash.fill",
                    role: shoveling ? .accent : .secondary,
                    size: .medium
                ) {
                    shoveling.toggle(); selected = nil; placementCell = nil; placementMessage = nil
                }
                .disabled(!session.battle.canBuild)
            }
        }
    }

    /// 底部状态与操作统一收进绘本底栏卡片，信息结构均衡
    private var bottomBar: some View {
        VStack(spacing: 8) {
            if let error = session.error {
                HStack(spacing: 12) {
                    Text(error).font(AppFont.label).foregroundStyle(Theme.wrong)
                    AppButton(title: "重试保存", systemImage: "arrow.clockwise", role: .accent, size: .small, action: session.retrySave)
                }
            }
            if session.hud.phase == .preparing {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(placementPrompt ?? "点击或拖动卡牌到草坪布阵，至少种下一位射手（铲除不返阳光）")
                                .font(AppFont.label)
                                .foregroundStyle(placementPrompt != nil ? AppColor.accentEdge : Theme.ink)
                                .lineLimit(2)
                            placementCancel
                        }
                        enemyPreviewTag
                    }
                    Spacer(minLength: 8)
                    AppButton(title: "开始战斗 · 消耗 15 积分", systemImage: "play.fill", role: .primary, size: .large, action: session.start)
                        .disabled(!session.battle.towers.contains { AdventureCatalog.defender($0.kindID)?.canShoot == true })
                }
            } else {
                HStack(spacing: 16) {
                    HStack(spacing: 10) {
                        Label(
                            session.hud.rest > 0 ? "下波倒计时 \(session.hud.rest)s" : "已击败 \(session.hud.defeated) 只",
                            systemImage: session.hud.rest > 0 ? "hourglass" : "flame.fill"
                        )
                        .font(AppFont.digits(15, weight: .heavy))
                        .foregroundStyle(AppColor.adventureEdge)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Capsule().fill(AppColor.adventure.opacity(0.14)))

                        if let prompt = placementPrompt {
                            Text(prompt).font(AppFont.label).foregroundStyle(AppColor.accentEdge)
                            placementCancel
                        } else {
                            enemyPreviewTag
                        }
                    }
                    Spacer(minLength: 8)
                    ultimateButton
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .candyCard(radius: AppRadius.md)
    }

    private var enemyPreviewTag: some View {
        Label(
            "\(session.hud.rest > 0 ? "本波预告" : "敌人预告")：\(session.battle.currentWave?.preview ?? "")",
            systemImage: "eye.fill"
        )
        .font(AppFont.caption)
        .foregroundStyle(Theme.muted)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    private var ultimateButton: some View {
        let ready = session.hud.ultimateReady
        return Button(action: session.unleash) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 16, weight: .black))
                Text(ready ? "雷霆就绪 · 释放" : "雷霆大招 \(session.hud.energy)/12")
                    .font(AppFont.digits(16, weight: .black))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .frame(height: 44)
            .padding(.bottom, 3.5)
            .background {
                ZStack {
                    Capsule().fill(ready ? GrowthColors.lightningDark : AppColor.accentEdge)
                        .shadow(color: (ready ? GrowthColors.lightning : AppColor.accent).opacity(ready ? 0.45 : 0.18), radius: ready ? 10 : 4, y: 3)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: ready
                                    ? [Color(red: 0.30, green: 0.86, blue: 1.0), GrowthColors.lightning]
                                    : [AppColor.accentTop, AppColor.accentBottom],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .overlay(Capsule().strokeBorder(.white.opacity(ready ? 0.75 : 0.4), lineWidth: 1.5))
                        .padding(.bottom, 3.5)
                }
            }
            .opacity(ready ? 1 : 0.62)
        }
        .buttonStyle(PressableStyle())
        .disabled(!ready)
    }

    private var placementPrompt: String? {
        placementMessage ?? (selected == AdventureDoom.id ? "选择空格放置毁灭菇 · 原格禁种 180 秒" : nil)
    }

    @ViewBuilder private var placementCancel: some View {
        if placementPrompt != nil {
            AppButton(title: "取消", systemImage: "xmark", role: .secondary, size: .small) {
                selected = nil; placementCell = nil; placementMessage = nil
            }
        }
    }

    @ViewBuilder private var stateOverlay: some View {
        if session.hud.phase == .paused || session.battle.isFinished {
            ZStack {
                Color.black.opacity(0.45).ignoresSafeArea()
                if session.battle.isFinished {
                    let won = session.hud.phase == .won
                    CandyModalCard(
                        bannerTitle: won ? "守住了！" : "这次差一点",
                        bannerIcon: won ? "🎉" : "🌱",
                        bannerColors: won ? [AppColor.gold, AppColor.accent] : [GrowthColors.calm.opacity(0.8), GrowthColors.calm],
                        bannerEdge: won ? AppColor.accentEdge : Color(red: 0.18, green: 0.31, blue: 0.54),
                        maxWidth: 500
                    ) {
                        HStack(spacing: 10) {
                            if won {
                                ForEach(0..<3, id: \.self) { i in
                                    Image(systemName: i < session.battle.stars ? "star.fill" : "star")
                                        .font(.system(size: 42, weight: .black))
                                        .foregroundStyle(i < session.battle.stars ? AppColor.gold : AppColor.cardEdge)
                                }
                            } else {
                                PictureView(emoji: "🌱", size: 54)
                            }
                        }
                        Text(session.battle.advice)
                            .font(AppFont.bodyStrong)
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.center)
                        Text("冒险只记录关卡和星级，不发放积分与学习奖励。")
                            .font(AppFont.label)
                            .foregroundStyle(Theme.muted)
                        if session.error == nil {
                            AppButton(title: "返回地图", systemImage: "map.fill", role: .adventure, size: .large, expands: true) {
                                if session.abandon() { onClose() }
                            }
                        }
                        if let error = session.error {
                            Text(error).font(AppFont.label).foregroundStyle(Theme.wrong)
                            AppButton(title: "重试保存", systemImage: "arrow.clockwise", role: .accent, size: .large, expands: true, action: session.retrySave)
                        }
                    }
                    .padding(24)
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
                            .foregroundStyle(Theme.muted)
                            .multilineTextAlignment(.center)
                        VStack(spacing: 12) {
                            AppButton(title: "继续战斗", systemImage: "play.fill", role: .primary, size: .large, expands: true, action: session.resume)
                            AppButton(title: "返回地图（结束本局）", systemImage: "map.fill", role: .secondary, size: .large, expands: true) {
                                if session.abandon() { onClose() }
                            }
                            AppButton(title: "放弃对局", systemImage: "xmark.circle.fill", role: .destructive, size: .large, expands: true) {
                                showExit = true
                            }
                        }
                        if let error = session.error {
                            Text(error).font(AppFont.label).foregroundStyle(Theme.wrong)
                            AppButton(title: "重试保存", systemImage: "arrow.clockwise", role: .accent, size: .medium, expands: true, action: session.retrySave)
                        }
                    }
                    .padding(24)
                }
            }
        }
    }

    @ViewBuilder private var exitConfirmOverlay: some View {
        if showExit {
            if session.battle.phase == .preparing || session.battle.isFinished {
                CandyConfirmModal(
                    title: "离开冒险",
                    icon: "🗺️",
                    message: "当前尚未开始正式战斗，可以直接返回冒险地图。",
                    buttons: [
                        CandyConfirmButton(title: "返回地图", systemImage: "chevron.left", role: .primary) {
                            showExit = false; if session.abandon() { onClose() }
                        },
                        CandyConfirmButton(title: "留在这里", role: .cancel) { showExit = false }
                    ],
                    onDismiss: { showExit = false }
                )
            } else {
                CandyConfirmModal(
                    title: "离开冒险",
                    icon: "⚠️",
                    message: "返回地图后本局结束，再次进入将开始新游戏。已消耗的 15 积分不返还。",
                    buttons: [
                        CandyConfirmButton(title: "返回地图（结束本局）", systemImage: "map.fill", role: .primary) {
                            showExit = false; if session.abandon() { onClose() }
                        },
                        CandyConfirmButton(title: "继续冒险", role: .cancel) { showExit = false }
                    ],
                    onDismiss: { showExit = false }
                )
            }
        }
    }

    private func place(at location: CGPoint) {
        guard let point = AdventureScene.scenePoint(at: location, in: frame), let cell = Lawn(lanes: 5).cell(at: point) else { return }
        if shoveling { session.shovel(lane: cell.lane, column: cell.column) }
        else if let selected {
            if session.plant(selected, lane: cell.lane, column: cell.column) {
                placementCell = nil; placementMessage = nil
                if selected == AdventureDoom.id { self.selected = nil }
            } else {
                placementCell = cell
                placementMessage = session.battle.doomCraters.contains { $0.lane == cell.lane && $0.column == cell.column }
                    ? "焦坑恢复后才能种植" : "这里暂时不能放置，请选择其他空格"
            }
        }
    }

    private func updatePreview(at location: CGPoint) {
        placementCell = AdventureScene.scenePoint(at: location, in: frame).flatMap { Lawn(lanes: 5).cell(at: $0) }
    }
}
