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
                    Button("＋ 从文件 App 选择") { choosing = true }.buttonStyle(.borderedProminent)
                    Button("怎么做题库？") { help = true }.buttonStyle(.bordered)
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
                            Button("删除", role: .destructive) { deleting = pack.id }.buttonStyle(.bordered)
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
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        Text("📗 \(draft.pack.title)").font(.largeTitle.bold())
                        Text("\(draft.pack.grade.displayName) · \(draft.pack.edition ?? "通用版")")
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
                        Button(model.library.pack(id: draft.pack.id) == nil ? "确认导入" : "导入并替换") {
                            do {
                                try manager.install(draft)
                                model.reloadLibrary()
                                revision += 1
                                pending = nil
                            } catch { self.error = error.localizedDescription }
                        }
                        .buttonStyle(.borderedProminent).font(.title2.bold())
                    }.padding(30)
                }.background(Theme.paper)
                .navigationTitle("确认导入课本")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("再想想") { pending = nil } } }
            }
        }
        .sheet(isPresented: $help) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
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
                    }.padding(28)
                }.navigationTitle("怎么做题库")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { help = false } } }
            }
        }
        .confirmationDialog("删除导入的课本？若覆盖了内置课本，将恢复内置版本。学习记录保留。",
                            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                do {
                    if let deleting { try manager.remove(id: deleting) }
                    model.reloadLibrary(); revision += 1; deleting = nil
                } catch { self.error = error.localizedDescription }
            }
        }
        .alert("操作未完成", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("知道了") { error = nil }
        } message: { Text(error ?? "") }
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
                    Button("编辑") { editing = EditingProfile(profile: profile, isNew: false) }.buttonStyle(.bordered)
                    Button("删除", role: .destructive) { deleting = profile }.buttonStyle(.bordered)
                }.padding(14).background(Theme.paper, in: RoundedRectangle(cornerRadius: 18))
            }
            Button("＋ 添加孩子") {
                editing = EditingProfile(profile: Profile(name: "", grade: .g3, avatar: "🐯"), isNew: true)
            }.buttonStyle(.borderedProminent)
        }
        .sheet(item: $editing) { item in ProfileEditor(profile: item.profile, isNew: item.isNew) { model.save($0) } }
        .confirmationDialog("删除这个孩子及其全部学习、成长和对局记录？", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
            Button("删除", role: .destructive) { if let deleting { model.delete(deleting) }; deleting = nil }
        }
    }
}
