import LearnCore
import SwiftUI

/// 孩子的主页（守护者营地）：顶部荣誉卡 + 三大模式成长入口 + 经典答题主作战卡片 + 底部绘本草坪地景。
struct ProfileHomeView: View {
    @EnvironmentObject private var model: AppModel
    let profileID: UUID

    @State private var activeGame: GameConfig?
    @State private var showWrongBook = false
    @State private var editing: EditingProfile?
    /// 游戏结束后刷新错题数
    @State private var refresh = 0
    @State private var showCollection = false
    @State private var showBadges = false
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
        .sheet(isPresented: $showWrongBook) {
            if let profile { WrongBookView(profile: profile, progress: model.progress(for: profile.id)) }
        }
        .profileEditorCover(item: $editing) { model.save($0) }
    }

    @ViewBuilder
    private func content(_ profile: Profile) -> some View {
        let progress = model.progress(for: profile.id)
        let reviewCount = ItemPool(packs: model.library.packs.filter { $0.grade == profile.grade },
                                   selection: .review(progress.reviewKeys)).items.count
        let growth = model.growth(for: profile.id)

        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                if let issue = growth.loadError {
                    HStack(spacing: 12) {
                        Text(issue).font(AppFont.label).foregroundStyle(Theme.wrong)
                        Spacer()
                        AppButton(title: "重试读取", systemImage: "arrow.clockwise", role: .secondary, size: .small) {
                            do { try model.reloadGrowth(for: profile.id) }
                            catch { /* 读取错误继续显示，原存档保持受保护。 */ }
                        }
                    }
                    .padding(12)
                    .candyCard(radius: AppRadius.md)
                }

                GrowthCard(profile: profile, growth: growth) {
                    editing = EditingProfile(profile: profile, isNew: false)
                }

                GrowthEntryCards(
                    growth: growth,
                    onCollection: { showCollection = true },
                    onBadges: { showBadges = true },
                    onAdventure: { showAdventure = true }
                )

                classicBattlePanel(profile: profile, reviewCount: reviewCount)

                if !model.issues.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("题库问题").font(AppFont.bodyStrong).foregroundStyle(Theme.wrong)
                        ForEach(model.issues.prefix(2), id: \.self) {
                            Text($0).font(AppFont.caption).foregroundStyle(Theme.muted).lineLimit(1)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .candyCard(radius: AppRadius.md)
                }
            }
            .padding(.horizontal, 36)
            .padding(.top, 18)
            .padding(.bottom, 12)
            .frame(maxWidth: 1020, alignment: .leading)
            .frame(maxWidth: .infinity)
            .id(refresh)

            Spacer(minLength: 0)
            HomeMeadowStrip()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func classicBattlePanel(profile: Profile, reviewCount: Int) -> some View {
        let packCount = model.library.packs.filter { $0.grade == profile.grade }.count
        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                AppIconBadge(systemImage: "books.vertical.fill", tint: AppColor.jade, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text("经典答题 · 边学边闯关")
                        .font(AppFont.heading)
                        .foregroundStyle(Theme.ink)
                    Text("默认沿用上次题库；开战前可在准备界面修改题库、单元与布阵")
                        .font(AppFont.label)
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 8)
                Label("\(profile.grade.displayName) · \(packCount) 本题库", systemImage: "checkmark.seal.fill")
                    .font(AppFont.label)
                    .foregroundStyle(AppColor.jadeEdge)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Capsule().fill(AppColor.jade.opacity(0.14)))
            }

            HStack(spacing: 16) {
                Text("难度")
                    .font(AppFont.bodyStrong)
                    .foregroundStyle(Theme.ink)
                GrowthSegmentedPicker(options: Difficulty.allCases, title: \.displayName, selection: Binding(
                    get: { profile.difficulty },
                    set: { var p = profile; p.difficulty = $0; model.save(p) }
                ))
                Spacer(minLength: 0)
            }

            HStack(spacing: 16) {
                AppButton(title: "经典闯关", systemImage: "play.fill", role: .primary, size: .hero, minWidth: 240, expands: true) {
                    activeGame = GameConfig(
                        profileID: profile.id,
                        grade: profile.grade,
                        packIDs: [],
                        selection: .all,
                        difficulty: profile.difficulty)
                }

                AppButton(
                    title: "错题复习（\(reviewCount)）",
                    systemImage: "target",
                    role: .accent,
                    size: .hero,
                    minWidth: 200
                ) {
                    activeGame = GameConfig(
                        profileID: profile.id,
                        grade: profile.grade,
                        packIDs: model.library.packs.filter { $0.grade == profile.grade }.map(\.id),
                        selection: .review(model.progress(for: profile.id).reviewKeys),
                        difficulty: profile.difficulty)
                }
                .disabled(reviewCount == 0)

                AppButton(title: "错题本", systemImage: "book.closed.fill", role: .secondary, size: .hero, minWidth: 156) {
                    showWrongBook = true
                }
            }
        }
        .padding(20)
        .candyCard(radius: AppRadius.lg)
    }
}

struct Chip: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if selected { Image(systemName: "checkmark").font(AppFont.label) }
                Text(title)
            }
            .font(AppFont.bodyStrong)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(CandyTileBackground(selected: selected, selectedFill: Theme.jade, selectedEdge: GrowthColors.jadeDark, radius: AppRadius.md))
            .foregroundStyle(selected ? .white : Theme.ink)
        }
        .buttonStyle(PressableStyle())
    }
}

struct WrongBookView: View {
    enum Filter: String, CaseIterable {
        case all = "全部"
        case review = "待复习"
        case mastered = "已掌握"
    }

    @Environment(\.dismiss) private var dismiss
    let profile: Profile
    let progress: ProgressStore
    @State private var filter: Filter = .all

    private var entries: [(key: String, stats: ItemStats)] {
        progress.stats
            .filter { $0.value.wrong > 0 }
            .map { (key: $0.key, stats: $0.value) }
            .sorted {
                if $0.stats.needsReview != $1.stats.needsReview { return $0.stats.needsReview }
                return $0.stats.wrong > $1.stats.wrong
            }
    }

    private var filteredEntries: [(key: String, stats: ItemStats)] {
        switch filter {
        case .all: entries
        case .review: entries.filter(\.stats.needsReview)
        case .mastered: entries.filter { !$0.stats.needsReview }
        }
    }

    private var reviewCount: Int { entries.filter(\.stats.needsReview).count }

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                PictureView(emoji: "📖", size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(profile.name)的错题本")
                        .font(AppFont.title)
                        .foregroundStyle(Theme.ink)
                    Text("连续答对即可转为已掌握 · 待复习 \(reviewCount) 题 / 共 \(entries.count) 题")
                        .font(AppFont.label)
                        .foregroundStyle(Theme.muted)
                }
                Spacer()
                AppButton(title: "完成", systemImage: "checkmark", role: .primary, size: .medium, minWidth: 96) {
                    dismiss()
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .candyCard()

            if entries.isEmpty {
                VStack(spacing: 12) {
                    PictureView(emoji: "🌟", size: 64)
                    Text("还没有错题，真棒！")
                        .font(AppFont.heading)
                        .foregroundStyle(Theme.ink)
                    Text("在闯关中答错的知识点会自动记在这里，方便随时温习。")
                        .font(AppFont.body)
                        .foregroundStyle(Theme.muted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(24)
                .candyCard()
            } else {
                HStack {
                    GrowthSegmentedPicker(options: Filter.allCases, title: \.rawValue, selection: $filter)
                    Spacer()
                }
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredEntries, id: \.key) { entry in
                            HStack(spacing: 14) {
                                Label(entry.stats.needsReview ? "待复习" : "已掌握",
                                      systemImage: entry.stats.needsReview ? "flame.fill" : "checkmark.circle.fill")
                                    .font(AppFont.label)
                                    .foregroundStyle(entry.stats.needsReview ? GrowthColors.orangeDark : GrowthColors.jadeDark)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule().fill(entry.stats.needsReview ? GrowthColors.gold.opacity(0.32) : Theme.jade.opacity(0.16))
                                    )
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.stats.summary ?? entry.key)
                                        .font(AppFont.bodyStrong)
                                        .foregroundStyle(Theme.ink)
                                    Text("答错 \(entry.stats.wrong) 次 · 连续答对 \(entry.stats.streak) 次")
                                        .font(AppFont.label)
                                        .foregroundStyle(Theme.muted)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .candyCard(radius: AppRadius.md)
                        }
                    }
                    .padding(4)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .padding(20)
        .background(GrowthPageBackground())
    }
}
