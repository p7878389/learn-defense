import LearnCore
import SwiftUI
import UniformTypeIdentifiers

enum SettingsFileReader {
    static func read(_ url: URL, limit: Int) throws -> Data {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= limit else { throw SettingsError.invalid("文件过大，无法导入") }
        return try Data(contentsOf: url, options: .mappedIfSafe)
    }
}

struct ParentPacksPane: View {
    @EnvironmentObject private var model: AppModel
    @State private var choosing = false
    @State private var pending: PackImport?
    @State private var deleting: String?
    @State private var error: String?
    @State private var help = false
    @State private var revision = 0
    private var manager: PackManager { PackManager(directory: AppPaths.userPacksDirectory) }
    private var importedIDs: Set<String> { Set(manager.imported().map(\.id)) }

    var body: some View {
        VStack(spacing: 24) {
            SettingsCard(title: "📚 导入课本") {
                Text("添加自制或分享的 JSON 题库。导入前会先检查内容。").foregroundStyle(Theme.muted)
                HStack(spacing: 16) {
                    Button { choosing = true } label: {
                        CandyButtonLabel(title: "从文件 App 选择", icon: "＋", fill: Theme.jade, edge: GrowthColors.jadeDark,
                                         font: .system(size: 16, weight: .heavy, design: .rounded), height: 44)
                    }
                    .buttonStyle(PressableStyle())
                    Button { help = true } label: {
                        CandyButtonLabel(title: "怎么做题库？", icon: "💡", fill: GrowthColors.surface, edge: GrowthColors.cardEdge,
                                         foreground: Theme.ink, font: .system(size: 16, weight: .heavy, design: .rounded), height: 44)
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            SettingsCard(title: "📖 已安装课本（\(model.library.packs.count)）") {
                ForEach(model.library.packs) { pack in
                    HStack(spacing: 16) {
                        Text(pack.subject == .english ? "📘" : "📕").font(.system(size: 42))
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(pack.title).font(.title3.bold())
                                Text(importedIDs.contains(pack.id) ? "已导入" : "内置")
                                    .font(.caption.bold()).padding(6).background(Theme.paper, in: Capsule())
                            }
                            Text("\(pack.grade.displayName) · \(pack.units.count) 个单元 · \(ItemPool(packs: [pack], selection: .all).items.count) 个知识点")
                                .font(.footnote).foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        if importedIDs.contains(pack.id) {
                            Button { deleting = pack.id } label: {
                                CandyButtonLabel(title: "删除", icon: "🗑", fill: Theme.wrong.opacity(0.14),
                                                 edge: Theme.wrong.opacity(0.45), foreground: Theme.wrong,
                                                 font: .system(size: 15, weight: .heavy, design: .rounded), height: 40, minWidth: 86)
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                    .padding(16).background(Theme.paper, in: RoundedRectangle(cornerRadius: 18))
                }
            }.id(revision)
        }
        .fileImporter(isPresented: $choosing, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get()
                pending = try manager.preview(SettingsFileReader.read(url, limit: 20_000_000))
            } catch { self.error = error.localizedDescription }
        }
        .sheet(item: $pending) { draft in
            VStack(spacing: 18) {
                GrowthPageHeader(icon: "📗", title: "确认导入课本", onClose: { pending = nil }) {}
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(draft.pack.title).font(.largeTitle.bold())
                        Text("\(draft.pack.grade.displayName) · \(draft.pack.edition ?? "通用版")").foregroundStyle(Theme.muted)
                        HStack(spacing: 24) {
                            Label("\(draft.pack.units.count) 个单元", systemImage: "books.vertical")
                            Label("\(draft.itemCount) 个知识点", systemImage: "checkmark.circle")
                        }.font(.title3)
                        if model.library.pack(id: draft.pack.id) != nil {
                            Label("同 id 课本将被替换，已有学习记录会保留。", systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(Theme.accent)
                        }
                        Text("✓ 文件格式检查通过").foregroundStyle(Theme.jade)
                        Text("导入后立即可选，无需重启。").foregroundStyle(Theme.muted)
                        HStack(spacing: 14) {
                            Button { pending = nil } label: {
                                CandyButtonLabel(title: "再想想", fill: GrowthColors.surface, edge: GrowthColors.cardEdge,
                                                 foreground: Theme.ink, font: .headline, height: 50, expands: true)
                            }
                            Button {
                                do {
                                    try manager.install(draft)
                                    model.reloadLibrary()
                                    revision += 1
                                    pending = nil
                                } catch { self.error = error.localizedDescription }
                            } label: {
                                CandyButtonLabel(title: model.library.pack(id: draft.pack.id) == nil ? "确认导入" : "导入并替换",
                                                 icon: "✓", font: .headline, height: 50, expands: true)
                            }
                        }
                        .buttonStyle(PressableStyle())
                    }.padding(24).candyCard()
                }
            }
            .padding(20)
            .background(GrowthPageBackground())
        }
        .sheet(isPresented: $help) {
            VStack(spacing: 18) {
                GrowthPageHeader(icon: "💡", title: "怎么做题库", onClose: { help = false }) {}
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("准备一份 UTF-8 编码的 JSON 文件，包含课本 id、书名、学科、年级、单元及课文内容。").font(.title3)
                        Text("支持生字、词语、古诗、成语、图片、英语词句和自定义选择题；每个知识点要提供对应的读音或答案。")
                        Text("同 id 的课本会覆盖导入版本；删除导入版本后，内置课本会重新出现。")
                        Text("生字拼音使用带声调的拼音（例如 chén）；选择题答案必须存在于选项中。")
                        Text("""
                        {
                          "schemaVersion": 1,
                          "id": "my-pack",
                          "title": "我的课本",
                          "subject": "chinese",
                          "grade": "g3",
                          "units": [{
                            "id": "unit1",
                            "title": "第一单元",
                            "lessons": [{
                              "id": "lesson1",
                              "title": "第一课",
                              "characters": [
                                {"char": "晨", "pinyin": "chén"}
                              ]
                            }]
                          }]
                        }
                        """).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                    }.padding(24).candyCard()
                }
            }
            .padding(20)
            .background(GrowthPageBackground())
        }
        .overlay {
            if let deleting {
                CandyConfirmModal(
                    title: "删除导入的课本？",
                    icon: "⚠️",
                    message: "若覆盖了内置课本，将恢复内置版本，已有学习记录保留。",
                    buttons: [
                        CandyConfirmButton(title: "确认删除", icon: "🗑", role: .destructive) {
                            do {
                                try manager.remove(id: deleting)
                                model.reloadLibrary(); revision += 1; self.deleting = nil
                            } catch { self.error = error.localizedDescription; self.deleting = nil }
                        },
                        CandyConfirmButton(title: "取消", role: .cancel) { self.deleting = nil }
                    ],
                    onDismiss: { self.deleting = nil }
                )
            } else if let message = error {
                CandyConfirmModal(
                    title: "操作未完成",
                    icon: "⚠️",
                    message: message,
                    buttons: [CandyConfirmButton(title: "知道了", role: .primary) { error = nil }],
                    onDismiss: { error = nil }
                )
            }
        }
    }
}

struct ParentProfilesPane: View {
    @EnvironmentObject private var model: AppModel
    @State private var editing: EditingProfile?
    @State private var deleting: Profile?

    var body: some View {
        SettingsCard(title: "👧 孩子档案") {
            ForEach(model.profiles) { profile in
                HStack(spacing: 16) {
                    Text(profile.avatar).font(.largeTitle)
                    VStack(alignment: .leading) {
                        Text(profile.name).font(.title3.bold())
                        Text(profile.grade.displayName).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Button { editing = EditingProfile(profile: profile, isNew: false) } label: {
                        CandyButtonLabel(title: "编辑", fill: GrowthColors.surface, edge: GrowthColors.cardEdge,
                                         foreground: Theme.ink, font: .system(size: 15, weight: .heavy, design: .rounded),
                                         height: 40, minWidth: 80)
                    }
                    Button { deleting = profile } label: {
                        CandyButtonLabel(title: "删除", fill: Theme.wrong.opacity(0.14), edge: Theme.wrong.opacity(0.45),
                                         foreground: Theme.wrong, font: .system(size: 15, weight: .heavy, design: .rounded),
                                         height: 40, minWidth: 80)
                    }
                }.buttonStyle(PressableStyle()).padding(14).background(Theme.paper, in: RoundedRectangle(cornerRadius: 18))
            }
            Button {
                editing = EditingProfile(profile: Profile(name: "", grade: .g3, avatar: "🐯"), isNew: true)
            } label: {
                CandyButtonLabel(title: "添加孩子", icon: "＋", fill: Theme.jade, edge: GrowthColors.jadeDark,
                                 font: .system(size: 16, weight: .heavy, design: .rounded), height: 44)
            }
            .buttonStyle(PressableStyle())
        }
        .profileEditorCover(item: $editing) { model.save($0) }
        .overlay {
            if let deleting {
                CandyConfirmModal(
                    title: "删除孩子档案？",
                    icon: "⚠️",
                    message: "删除「\(deleting.name)」及其全部学习、成长和对局记录后无法恢复。",
                    buttons: [
                        CandyConfirmButton(title: "确认删除", icon: "🗑", role: .destructive) {
                            model.delete(deleting); self.deleting = nil
                        },
                        CandyConfirmButton(title: "取消", role: .cancel) { self.deleting = nil }
                    ],
                    onDismiss: { self.deleting = nil }
                )
            }
        }
    }
}
