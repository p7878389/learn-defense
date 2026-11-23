import LearnCore
import SwiftUI

/// 孩子的主页：成长与模式入口；题库在进入经典游戏后通过弹窗确认。
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
                Text("档案不存在").font(.title)
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

        ScrollView {
            // 题库配置已移入游戏弹窗，主页只保留一屏内的成长、模式与难度操作。
            VStack(alignment: .leading, spacing: 16) {
                // 三个模式/成长入口共用一行，不再纵向叠加题库配置。
                let growth = model.growth(for: profile.id)
                if let issue = growth.loadError {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(issue).foregroundStyle(Theme.wrong)
                        Button("重试读取成长档案") {
                            do { try model.reloadGrowth(for: profile.id) }
                            catch { /* 读取错误继续显示，原存档保持受保护。 */ }
                        }
                        .buttonStyle(.bordered)
                    }
                }
                GrowthCard(profile: profile, growth: growth) {
                    editing = EditingProfile(profile: profile, isNew: false)
                }
                GrowthEntryCards(growth: growth, onCollection: { showCollection = true }, onBadges: { showBadges = true },
                                 onAdventure: { showAdventure = true })

                Text("经典答题 · 边学边闯关").font(.title3.bold()).foregroundStyle(Theme.ink)
                difficultySection(profile)
                actions(profile: profile, reviewCount: reviewCount)
                Text("游戏默认沿用上次题库；准备界面可改题库与难度，准备好后核对配置再开战。")
                    .font(.callout).foregroundStyle(Theme.muted)

                if !model.issues.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("题库问题").font(.headline).foregroundStyle(Theme.wrong)
                        ForEach(model.issues, id: \.self) { Text($0).font(.callout) }
                    }
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 20)
            .frame(maxWidth: 1000, alignment: .leading)
            .frame(maxWidth: .infinity)
            .id(refresh)
        }
        // 主页只显示模式与成长入口，主要操作在 iPad 横竖屏内完整排下。
        .scrollDisabled(true)
    }

    private func difficultySection(_ profile: Profile) -> some View {
        HStack(spacing: 20) {
            Text("难度").font(.title2.weight(.bold))
            GrowthSegmentedPicker(options: Difficulty.allCases, title: \.displayName, selection: Binding(
                get: { profile.difficulty },
                set: { var p = profile; p.difficulty = $0; model.save(p) }
            ))
        }
    }

    private func actions(profile: Profile, reviewCount: Int) -> some View {
        HStack(spacing: 20) {
            // 开始闯关直接进入经典模式
            Button {
                activeGame = GameConfig(
                    profileID: profile.id,
                    grade: profile.grade,
                    packIDs: [],
                    selection: .all,
                    difficulty: profile.difficulty)
            } label: {
                Label("经典闯关", systemImage: "play.fill")
                    .font(.title.weight(.heavy))
                    .frame(width: 280, height: 80)
                    .background(Capsule().fill(Theme.jade).shadow(color: GrowthColors.jadeDark, radius: 0, x: 0, y: 6))
                    .foregroundStyle(.white)
            }
            .buttonStyle(PressableStyle())

            Button {
                activeGame = GameConfig(
                    profileID: profile.id,
                    grade: profile.grade,
                    packIDs: model.library.packs.filter { $0.grade == profile.grade }.map(\.id),
                    selection: .review(model.progress(for: profile.id).reviewKeys),
                    difficulty: profile.difficulty)
            } label: {
                Text("错题复习（\(reviewCount)）")
                    .font(.title2.weight(.bold))
                    .frame(width: 240, height: 80)
                    .background(Capsule().fill(reviewCount > 0 ? Theme.accent : Theme.muted.opacity(0.3))
                        .shadow(color: reviewCount > 0 ? GrowthColors.orangeDark : .clear, radius: 0, x: 0, y: 6))
                    .foregroundStyle(.white)
            }
            .buttonStyle(PressableStyle())
            .disabled(reviewCount == 0)

            // 设计稿 01b：白色糖果胶囊，浅金描边加厚底
            Button { showWrongBook = true } label: {
                CandyButtonLabel(title: "错题本", icon: "📖", fill: GrowthColors.surface, edge: GrowthColors.cardEdge,
                                 foreground: Theme.ink, font: .title2.weight(.bold), height: 68)
                    .overlay(Capsule().stroke(GrowthColors.cardEdge, lineWidth: 2))
            }
            .buttonStyle(PressableStyle())
        }
    }

}

struct Chip: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if selected { Text("✓") }
                Text(title)
            }
            .font(.title3.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(selected ? Theme.jade : GrowthColors.surface)
                    .shadow(color: selected ? GrowthColors.jadeDark : GrowthColors.cardEdge,
                            radius: 0, x: 0, y: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(selected ? GrowthColors.jadeDark : GrowthColors.cardEdge, lineWidth: 2))
            .foregroundStyle(selected ? .white : Theme.ink)
        }
        .buttonStyle(PressableStyle())
    }
}

struct WrongBookView: View {
    @Environment(\.dismiss) private var dismiss
    let profile: Profile
    let progress: ProgressStore

    private var entries: [(key: String, stats: ItemStats)] {
        progress.stats
            .filter { $0.value.wrong > 0 }
            .map { (key: $0.key, stats: $0.value) }
            .sorted {
                if $0.stats.needsReview != $1.stats.needsReview { return $0.stats.needsReview }
                return $0.stats.wrong > $1.stats.wrong
            }
    }

    var body: some View {
        NavigationStack {
            List {
                if entries.isEmpty {
                    Text("还没有错题，真棒！").font(.title3)
                }
                ForEach(entries, id: \.key) { entry in
                    HStack(spacing: 14) {
                        Text(entry.stats.needsReview ? "待复习" : "已掌握")
                            .font(.callout.weight(.bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(entry.stats.needsReview ? Theme.accent.opacity(0.25) : Theme.jade.opacity(0.25)))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.stats.summary ?? entry.key).font(.title3)
                            Text("错 \(entry.stats.wrong) 次 · 连续答对 \(entry.stats.streak) 次")
                                .font(.callout)
                                .foregroundStyle(Theme.muted)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("\(profile.name)的错题本")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
