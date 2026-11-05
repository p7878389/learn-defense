import LearnCore
import SwiftUI

/// 孩子的主页：选学科、单元、难度，开始闯关或复习错题
struct ProfileHomeView: View {
    @EnvironmentObject private var model: AppModel
    let profileID: UUID

    @State private var subject: Subject = .chinese
    /// 主页上临时换的年级，只影响这次选题和本局规则，不改档案；为空表示用档案里的年级
    @State private var chosenGrade: Grade?
    /// 选中的教材版本，为空表示该年级的第一个版本
    @State private var chosenEdition: String?
    @State private var packID: String?
    /// 当前展开的下拉菜单
    @State private var openMenu: String?
    /// 为空表示全部单元
    @State private var selectedUnits: Set<String> = []
    @State private var activeGame: GameConfig?
    @State private var showWrongBook = false
    @State private var editing: EditingProfile?
    /// 游戏结束后刷新错题数
    @State private var refresh = 0
    @State private var showCollection = false
    @State private var showBadges = false
    /// 结算页点了「去收藏馆看看」：等游戏页关掉后再打开收藏馆
    @State private var openCollectionAfterGame = false

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
                onReplay: { activeGame = config.again() },
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
        .sheet(isPresented: $showWrongBook) {
            if let profile { WrongBookView(profile: profile, progress: model.progress(for: profile.id)) }
        }
        .sheet(item: $editing) { item in
            ProfileEditor(profile: item.profile, isNew: false) { model.save($0) }
        }
    }

    @ViewBuilder
    private func content(_ profile: Profile) -> some View {
        let grade = chosenGrade ?? profile.grade
        // 这个年级、学科的全部题库（错题复习用全部），再按版本挑出要选的几册
        let gradePacks = model.library.packs(grade: grade, subject: subject)
        let editions = QuestionBankChoice.editions(in: gradePacks)
        let edition = chosenEdition.flatMap { editions.contains($0) ? $0 : nil } ?? editions.first
        let packs = edition.map { QuestionBankChoice.packs(gradePacks, edition: $0) } ?? []
        let pack = packs.first { $0.id == packID } ?? packs.first
        let progress = model.progress(for: profile.id)
        let reviewCount = ItemPool(packs: gradePacks, selection: .review(progress.reviewKeys)).items.count

        ScrollView {
            // iPad 11 寸横屏可用高度约 776pt：间距收紧、年级/版本/课程用一排下拉菜单、难度标题和分栏同一行，一屏放得下
            VStack(alignment: .leading, spacing: 20) {
                // 成长卡和两个入口在主页顶部，下面选学科、题库、难度
                let growth = model.growth(for: profile.id)
                GrowthCard(profile: profile, growth: growth) {
                    editing = EditingProfile(profile: profile, isNew: false)
                }
                GrowthEntryCards(growth: growth, onCollection: { showCollection = true }, onBadges: { showBadges = true })

                GrowthSegmentedPicker(options: Subject.allCases, title: \.displayName, selection: $subject)
                .onChange(of: subject) { _, _ in
                    chosenEdition = nil
                    packID = nil
                    selectedUnits = []
                    openMenu = nil
                }

                bankSection(grade: grade, editions: editions, edition: edition, pack: pack)

                if let pack {
                    difficultySection(profile)
                    actions(profile: profile, grade: grade, reviewPacks: gradePacks, pack: pack, reviewCount: reviewCount)
                } else {
                    emptyHint(grade)
                }

                if !model.issues.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("题库问题").font(.headline).foregroundStyle(Theme.wrong)
                        ForEach(model.issues, id: \.self) { Text($0).font(.callout) }
                    }
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 24)
            .frame(maxWidth: 1000, alignment: .leading)
            .frame(maxWidth: .infinity)
            .id(refresh)
        }
        // 内容放得下时不能上下拖动、也不回弹；放不下时照常滚动
        .scrollBounceBehavior(.basedOnSize)
        // 下拉菜单画在滚动区域外面，不会被裁掉
        .candyDropdownLayer(openID: $openMenu) { id in
            menuItems(id, profile: profile, grade: grade, gradePacks: gradePacks, editions: editions, edition: edition,
                      packs: packs, pack: pack)
        }
    }

    // MARK: - 选题库：年级、版本、课程（具体到单元）

    private func bankSection(grade: Grade, editions: [String], edition: String?, pack: ContentPack?) -> some View {
        HStack(spacing: 14) {
            Text("题库").font(.title2.weight(.bold))
            CandyDropdownButton(id: BankMenu.grade, caption: "年级", value: grade.displayName, openID: $openMenu)
                .frame(width: 160)
            CandyDropdownButton(id: BankMenu.edition, caption: "版本", value: edition ?? "暂无题库",
                                enabled: !editions.isEmpty, openID: $openMenu)
                .frame(width: 230)
            CandyDropdownButton(id: BankMenu.course, caption: "课程 · 单元",
                                value: pack.map { QuestionBankChoice.courseSummary(pack: $0, selectedUnits: selectedUnits) } ?? "暂无题库",
                                enabled: pack != nil, openID: $openMenu)
        }
    }

    private enum BankMenu {
        static let grade = "grade"
        static let edition = "edition"
        static let course = "course"
    }

    private func menuItems(_ id: String, profile: Profile, grade: Grade, gradePacks: [ContentPack], editions: [String],
                           edition: String?, packs: [ContentPack], pack: ContentPack?) -> [CandyMenuItem] {
        switch id {
        case BankMenu.grade:
            return Grade.allCases.map { g in
                let count = model.library.packs(grade: g, subject: subject).count
                var detail = count == 0 ? "暂无题库" : "\(count) 套题库"
                if g == profile.grade { detail = "我的年级 · " + detail }
                return CandyMenuItem(id: g.rawValue, title: g.displayName, detail: detail, selected: g == grade) {
                    chosenGrade = g == profile.grade ? nil : g
                    chosenEdition = nil
                    packID = nil
                    selectedUnits = []
                }
            }
        case BankMenu.edition:
            return editions.map { name in
                let count = QuestionBankChoice.packs(gradePacks, edition: name).count
                return CandyMenuItem(id: name, title: name, detail: "\(count) 册", selected: name == edition) {
                    chosenEdition = name
                    packID = nil
                    selectedUnits = []
                }
            }
        case BankMenu.course:
            var items: [CandyMenuItem] = []
            for p in packs {
                let current = p.id == pack?.id
                items.append(CandyMenuItem(id: p.id, title: QuestionBankChoice.volumeTitle(p), detail: "\(p.units.count) 个单元",
                                           style: .header) {
                    packID = p.id
                    selectedUnits = []
                })
                items.append(CandyMenuItem(id: "\(p.id)/*", title: "全部单元", selected: current && selectedUnits.isEmpty,
                                           style: .child) {
                    packID = p.id
                    selectedUnits = []
                })
                for unit in p.units {
                    let key = QuestionBankChoice.unitKey(pack: p, unit: unit)
                    // 单元可以多选，点完不收起；换到另一册时从这个单元重新选
                    items.append(CandyMenuItem(id: key, title: unit.title, detail: "\(unit.lessons.count) 课",
                                               selected: current && selectedUnits.contains(key), style: .child, closesMenu: false) {
                        if !current {
                            packID = p.id
                            selectedUnits = [key]
                        } else if selectedUnits.contains(key) {
                            selectedUnits.remove(key)
                        } else {
                            selectedUnits.insert(key)
                        }
                    })
                }
            }
            return items
        default:
            return []
        }
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

    private func actions(profile: Profile, grade: Grade, reviewPacks: [ContentPack], pack: ContentPack, reviewCount: Int) -> some View {
        HStack(spacing: 20) {
            Button {
                activeGame = GameConfig(
                    profileID: profile.id,
                    grade: grade,
                    packIDs: [pack.id],
                    selection: selectedUnits.isEmpty ? .all : .units(selectedUnits),
                    difficulty: profile.difficulty)
            } label: {
                Label("开始闯关", systemImage: "play.fill")
                    .font(.title.weight(.heavy))
                    .frame(width: 280, height: 80)
                    .background(Capsule().fill(Theme.jade).shadow(color: GrowthColors.jadeDark, radius: 0, x: 0, y: 6))
                    .foregroundStyle(.white)
            }
            .buttonStyle(PressableStyle())

            Button {
                activeGame = GameConfig(
                    profileID: profile.id,
                    grade: grade,
                    packIDs: reviewPacks.map(\.id),
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

    private func emptyHint(_ grade: Grade) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(grade.displayName)\(subject.displayName)还没有题库")
                .font(.title2.weight(.bold))
            Text("把 JSON 题库放到「文件」App →「我的 iPad」→「字灵守卫」→「Packs」文件夹，再点下面的按钮。")
                .foregroundStyle(Theme.muted)
            Button("重新加载题库") { model.reloadLibrary() }
                .font(.title3.weight(.semibold))
        }
        .padding(24)
        .background(RoundedRectangle(cornerRadius: 20).fill(GrowthColors.surface))
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
