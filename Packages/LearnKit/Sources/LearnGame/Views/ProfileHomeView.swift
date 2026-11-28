import LearnCore
import SwiftUI

/// 孩子的主页（守护者营地）：顶部荣誉卡 + 三大模式成长入口 + 经典答题主作战卡片 + 底部绘本草坪地景。
struct ProfileHomeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var model: AppModel
    let profileID: UUID

    @State private var activeGame: GameConfig?
    @State private var showWrongBook = false
    @State private var editing: EditingProfile?
    /// 游戏结束后刷新错题数
    @State private var refresh = 0
    @State private var showCollection = false
    @State private var showBadges = false
    @State private var showCoinLedger = false
    /// 结算页点了「去收藏馆看看」：等游戏页关掉后再打开收藏馆
    @State private var openCollectionAfterGame = false
    @State private var showAdventure = false

    private var profile: Profile? {
        model.profiles.first { $0.id == profileID }
    }

    var body: some View {
        Group {
            if let profile {
                content(profile)
            } else {
                Text("档案不存在").font(AppFont.title).foregroundStyle(Theme.ink)
            }
        }
        .background(GrowthPageBackground())
        .gameCover(item: $activeGame, onDismiss: {
            refresh += 1
            if openCollectionAfterGame {
                openCollectionAfterGame = false
                showCollection = true
            }
        }) { config in
            GameView(
                config: config,
                model: model,
                onReplay: { activeGame = $0 },
                onExit: { activeGame = nil },
                onOpenCollection: {
                    openCollectionAfterGame = true
                    activeGame = nil
                })
        }
        .growthCover(isPresented: $showCollection) {
            CollectionView(profileID: profileID, onClose: { showCollection = false })
                .environmentObject(model)
        }
        .growthCover(isPresented: $showBadges) {
            BadgeWallView(profileID: profileID, onClose: { showBadges = false })
                .environmentObject(model)
        }
        .growthCover(isPresented: $showAdventure) {
            AdventureLobbyView(profileID: profileID, onClose: { showAdventure = false })
                .environmentObject(model)
        }
        .growthCover(isPresented: $showCoinLedger) {
            CoinLedgerView(profileID: profileID, backTitle: "返回主页", onClose: { showCoinLedger = false })
                .environmentObject(model)
        }
        .sheet(isPresented: $showWrongBook) {
            if let profile {
                let progress = model.progress(for: profile.id)
                let review = GamePreparation.reviewConfig(for: profile, library: model.library, reviewKeys: progress.reviewKeys)
                WrongBookView(
                    profile: profile,
                    progress: progress,
                    speech: model.speech,
                    onStartReview: review.map { config in { activeGame = config } }
                )
                .presentationDetents([.large])
            }
        }
        .profileEditorCover(
            item: $editing,
            onSave: { model.save($0) },
            onDelete: { model.delete($0); dismiss() }
        )
    }

    @ViewBuilder
    private func content(_ profile: Profile) -> some View {
        let progress = model.progress(for: profile.id)
        let reviewConfig = GamePreparation.reviewConfig(for: profile, library: model.library, reviewKeys: progress.reviewKeys)
        let reviewCount = GamePreparation.reviewItemCount(in: model.library, reviewKeys: progress.reviewKeys)
        let growth = model.growth(for: profile.id)

        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height
            let maxContentWidth: CGFloat = 1120
            let availableWidth = min(maxContentWidth, max(0, geo.size.width - AppSpacing.xl * 2))
            let leftColumnWidth = (availableWidth - AppSpacing.md) * 0.60

            VStack(spacing: 0) {
                Spacer(minLength: AppSpacing.sm)

                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    if let issue = growth.loadError {
                        HStack(spacing: AppSpacing.sm) {
                            Text(issue).font(AppFont.label).foregroundStyle(AppColor.dangerText)
                            Spacer()
                            AppButton(title: "重试读取", systemImage: "arrow.clockwise", role: .secondary, size: .small) {
                                do { try model.reloadGrowth(for: profile.id) }
                                catch { /* 读取错误继续显示，原存档保持受保护。 */ }
                            }
                        }
                        .padding(AppSpacing.sm)
                        .appPanel(radius: AppRadius.md, tint: AppColor.dangerText)
                    }

                    GrowthCard(profile: profile, growth: growth, onCoins: {
                        showCoinLedger = true
                    }) {
                        editing = EditingProfile(profile: profile, isNew: false)
                    }

                    if landscape {
                        HStack(alignment: .top, spacing: AppSpacing.md) {
                            classicBattlePanel(profile: profile, reviewCount: reviewCount, reviewConfig: reviewConfig)
                                .frame(width: leftColumnWidth)
                            GrowthEntryCards(
                                growth: growth,
                                onCollection: { showCollection = true },
                                onBadges: { showBadges = true },
                                onAdventure: { showAdventure = true },
                                axis: .vertical
                            )
                            .frame(maxWidth: .infinity)
                        }
                    } else {
                        classicBattlePanel(profile: profile, reviewCount: reviewCount, reviewConfig: reviewConfig)
                        GrowthEntryCards(
                            growth: growth,
                            onCollection: { showCollection = true },
                            onBadges: { showBadges = true },
                            onAdventure: { showAdventure = true },
                            axis: .vertical
                        )
                    }

                    if !model.issues.isEmpty {
                        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                            Text("题库问题").font(AppFont.bodyStrong).foregroundStyle(AppColor.dangerText)
                            ForEach(model.issues.prefix(2), id: \.self) {
                                Text($0).font(AppFont.caption).foregroundStyle(AppColor.muted).lineLimit(1)
                            }
                        }
                        .padding(AppSpacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .appPanel(radius: AppRadius.md, tint: AppColor.dangerText)
                    }
                }
                .padding(.horizontal, AppSpacing.xl)
                .frame(maxWidth: maxContentWidth, alignment: .leading)
                .frame(maxWidth: .infinity)
                .id(refresh)

                Spacer(minLength: AppSpacing.xs)
                HomeMeadowStrip(height: landscape ? 96 : 200)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private func classicBattlePanel(profile: Profile, reviewCount: Int, reviewConfig: GameConfig?) -> some View {
        let packCount = model.library.packs.filter { $0.grade == profile.grade }.count
        let hasReview = reviewCount > 0 && reviewConfig != nil
        return VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.sm) {
                AppIconBadge(systemImage: "books.vertical.fill", tint: AppColor.jade, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text("经典答题 · 边学边闯关")
                        .font(AppFont.heading)
                        .foregroundStyle(AppColor.ink)
                    Text("默认沿用上次题库；开战前可在准备界面修改题库、单元与布阵")
                        .font(AppFont.label)
                        .foregroundStyle(AppColor.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                Spacer(minLength: AppSpacing.xs)
                Label("\(profile.grade.displayName) · \(packCount) 本题库", systemImage: "checkmark.seal.fill")
                    .font(AppFont.label)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .foregroundStyle(AppColor.jadeEdge)
                    .padding(.horizontal, AppSpacing.sm).padding(.vertical, 6)
                    .background(Capsule().fill(AppColor.jade.opacity(0.14)))
            }

            HStack(spacing: AppSpacing.md) {
                Text("难度")
                    .font(AppFont.bodyStrong)
                    .foregroundStyle(AppColor.ink)
                GrowthSegmentedPicker(options: Difficulty.allCases, title: \.displayName, selection: Binding(
                    get: { profile.difficulty },
                    set: { var p = profile; p.difficulty = $0; model.save(p) }
                ))
                Spacer(minLength: 0)
            }

            AppButton(title: "经典闯关", systemImage: "play.fill", role: .primary, size: .hero, expands: true) {
                activeGame = GameConfig(
                    profileID: profile.id,
                    grade: profile.grade,
                    packIDs: [],
                    selection: .all,
                    difficulty: profile.difficulty)
            }

            HStack(spacing: AppSpacing.sm) {
                AppButton(
                    title: hasReview ? "错题复习（\(reviewCount)）" : "错题复习（暂无）",
                    systemImage: "target",
                    role: hasReview ? .accent : .subtle,
                    size: .large,
                    expands: true
                ) {
                    if let reviewConfig { activeGame = reviewConfig }
                }
                .disabled(!hasReview)

                AppButton(title: "错题本", systemImage: "book.closed.fill", role: .secondary, size: .large, expands: true) {
                    showWrongBook = true
                }
            }
        }
        .padding(AppSpacing.lg)
        .appPanel(radius: AppRadius.lg)
    }
}
