import LearnCore
import SwiftUI

/// 孩子的主页：选学科、单元、难度，开始闯关或复习错题
struct ProfileHomeView: View {
    @EnvironmentObject private var model: AppModel
    let profileID: UUID

    @State private var subject: Subject = .chinese
    @State private var packID: String?
    /// 为空表示全部单元
    @State private var selectedUnits: Set<String> = []
    @State private var activeGame: GameConfig?
    @State private var showWrongBook = false
    @State private var editing: EditingProfile?
    /// 游戏结束后刷新错题数
    @State private var refresh = 0

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
        .background(Theme.paper.ignoresSafeArea())
        .gameCover(item: $activeGame, onDismiss: { refresh += 1 }) { config in
            GameView(
                config: config,
                model: model,
                onReplay: { activeGame = config.again() },
                onExit: { activeGame = nil })
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
        let packs = model.library.packs(grade: profile.grade, subject: subject)
        let pack = packs.first { $0.id == packID } ?? packs.first
        let progress = model.progress(for: profile.id)
        let reviewCount = ItemPool(packs: packs, selection: .review(progress.reviewKeys)).items.count

        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack(spacing: 20) {
                    PictureView(emoji: profile.avatar, size: 84)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.name).font(.largeTitle.weight(.heavy)).foregroundStyle(Theme.ink)
                        Text(profile.grade.displayName).font(.title3).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Button("编辑档案") { editing = EditingProfile(profile: profile, isNew: false) }
                        .font(.title3)
                }

                Picker("学科", selection: $subject) {
                    ForEach(Subject.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 360)
                .onChange(of: subject) { _, _ in
                    packID = nil
                    selectedUnits = []
                }

                if let pack {
                    packSection(packs: packs, pack: pack)
                    difficultySection(profile)
                    actions(profile: profile, packs: packs, pack: pack, reviewCount: reviewCount)
                } else {
                    emptyHint(profile)
                }

                if !model.library.issues.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("题库问题").font(.headline).foregroundStyle(Theme.wrong)
                        ForEach(model.library.issues, id: \.self) { Text($0).font(.callout) }
                    }
                }
            }
            .padding(40)
            .frame(maxWidth: 1000, alignment: .leading)
            .frame(maxWidth: .infinity)
            .id(refresh)
        }
    }

    private func packSection(packs: [ContentPack], pack: ContentPack) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("题库").font(.title2.weight(.bold))
                if packs.count > 1 {
                    Picker("题库", selection: Binding(get: { pack.id }, set: { packID = $0; selectedUnits = [] })) {
                        ForEach(packs) { Text($0.title).tag($0.id) }
                    }
                } else {
                    Text(pack.title).font(.title3).foregroundStyle(Theme.muted)
                }
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 12)], alignment: .leading, spacing: 12) {
                Chip(title: "全部单元", selected: selectedUnits.isEmpty) { selectedUnits = [] }
                ForEach(pack.units) { unit in
                    let key = "\(pack.id)/\(unit.id)"
                    Chip(title: unit.title, selected: selectedUnits.contains(key)) {
                        if selectedUnits.contains(key) { selectedUnits.remove(key) } else { selectedUnits.insert(key) }
                    }
                }
            }
        }
    }

    private func difficultySection(_ profile: Profile) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("难度").font(.title2.weight(.bold))
            Picker("难度", selection: Binding(
                get: { profile.difficulty },
                set: { var p = profile; p.difficulty = $0; model.save(p) }
            )) {
                ForEach(Difficulty.allCases) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 360)
        }
    }

    private func actions(profile: Profile, packs: [ContentPack], pack: ContentPack, reviewCount: Int) -> some View {
        HStack(spacing: 20) {
            Button {
                activeGame = GameConfig(
                    profileID: profile.id,
                    grade: profile.grade,
                    packIDs: [pack.id],
                    selection: selectedUnits.isEmpty ? .all : .units(selectedUnits),
                    difficulty: profile.difficulty)
            } label: {
                Label("开始闯关", systemImage: "play.fill")
                    .font(.title.weight(.heavy))
                    .frame(width: 280, height: 80)
                    .background(Capsule().fill(Theme.jade))
                    .foregroundStyle(.white)
            }
            .buttonStyle(PressableStyle())

            Button {
                activeGame = GameConfig(
                    profileID: profile.id,
                    grade: profile.grade,
                    packIDs: packs.map(\.id),
                    selection: .review(model.progress(for: profile.id).reviewKeys),
                    difficulty: profile.difficulty)
            } label: {
                Text("错题复习（\(reviewCount)）")
                    .font(.title2.weight(.bold))
                    .frame(width: 240, height: 80)
                    .background(Capsule().fill(reviewCount > 0 ? Theme.accent : Theme.muted.opacity(0.3)))
                    .foregroundStyle(.white)
            }
            .buttonStyle(PressableStyle())
            .disabled(reviewCount == 0)

            Button("错题本") { showWrongBook = true }
                .font(.title2.weight(.semibold))
        }
    }

    private func emptyHint(_ profile: Profile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(profile.grade.displayName)\(subject.displayName)还没有题库")
                .font(.title2.weight(.bold))
            Text("把 JSON 题库放到「文件」App →「我的 iPad」→「字灵守卫」→「Packs」文件夹，再点下面的按钮。")
                .foregroundStyle(Theme.muted)
            Button("重新加载题库") { model.reloadLibrary() }
                .font(.title3.weight(.semibold))
        }
        .padding(24)
        .background(RoundedRectangle(cornerRadius: 20).fill(Theme.card))
    }
}

struct Chip: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.title3.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(RoundedRectangle(cornerRadius: 16).fill(selected ? Theme.accent.opacity(0.22) : Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(selected ? Theme.accent : Theme.muted.opacity(0.3), lineWidth: 2))
                .foregroundStyle(Theme.ink)
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
