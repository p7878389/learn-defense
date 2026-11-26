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
        VStack(spacing: 20) {
            SettingsCard(title: "导入课本", systemImage: "square.and.arrow.down.fill", tint: AppColor.jade) {
                Text("添加自制或分享的 JSON 题库。导入前会先检查内容。")
                    .font(AppFont.body).foregroundStyle(Theme.muted)
                HStack(spacing: 14) {
                    AppButton(title: "从文件 App 选择", systemImage: "plus", role: .primary, size: .medium) { choosing = true }
                    AppButton(title: "怎么做题库？", systemImage: "questionmark.circle", role: .secondary, size: .medium) { help = true }
                }
            }
            SettingsCard(title: "已安装课本（\(model.library.packs.count)）", systemImage: "books.vertical.fill", tint: AppColor.parentAccent) {
                ForEach(model.library.packs) { pack in
                    HStack(spacing: 14) {
                        AppIconBadge(
                            systemImage: pack.subject == .english ? "character.book.closed.fill" : "book.closed.fill",
                            tint: pack.subject == .english ? AppColor.adventure : AppColor.accent,
                            size: 42
                        )
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(pack.title).font(AppFont.bodyStrong).foregroundStyle(Theme.ink)
                                Text(importedIDs.contains(pack.id) ? "已导入" : "内置")
                                    .font(AppFont.caption)
                                    .foregroundStyle(importedIDs.contains(pack.id) ? AppColor.jadeEdge : Theme.muted)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(Capsule().fill(importedIDs.contains(pack.id) ? AppColor.jade.opacity(0.14) : AppColor.surface))
                            }
                            Text("\(pack.grade.displayName) · \(pack.units.count) 个单元 · \(ItemPool(packs: [pack], selection: .all).items.count) 个知识点")
                                .font(AppFont.caption).foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        if importedIDs.contains(pack.id) {
                            AppButton(title: "删除", systemImage: "trash.fill", role: .destructive, size: .small, minWidth: 88) {
                                deleting = pack.id
                            }
                        }
                    }
                    .padding(14)
                    .background(Theme.paper, in: RoundedRectangle(cornerRadius: AppRadius.sm))
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
                GrowthPageHeader(
                    icon: "📗", systemIcon: "book.badge.plus", iconTint: AppColor.jade,
                    title: "确认导入课本", backTitle: "关闭", backSystemImage: "xmark", parentStyle: true,
                    onClose: { pending = nil }
                ) {}
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(draft.pack.title).font(AppFont.title).foregroundStyle(Theme.ink)
                        Text("\(draft.pack.grade.displayName) · \(draft.pack.edition ?? "通用版")")
                            .font(AppFont.body).foregroundStyle(Theme.muted)
                        HStack(spacing: 24) {
                            Label("\(draft.pack.units.count) 个单元", systemImage: "books.vertical")
                            Label("\(draft.itemCount) 个知识点", systemImage: "checkmark.circle")
                        }.font(AppFont.bodyStrong).foregroundStyle(Theme.ink)
                        if model.library.pack(id: draft.pack.id) != nil {
                            Label("同 id 课本将被替换，已有学习记录会保留。", systemImage: "exclamationmark.triangle.fill")
                                .font(AppFont.body).foregroundStyle(Theme.accent)
                        }
                        Label("文件格式检查通过", systemImage: "checkmark.seal.fill")
                            .font(AppFont.bodyStrong).foregroundStyle(Theme.jade)
                        Text("导入后立即可选，无需重启。").font(AppFont.label).foregroundStyle(Theme.muted)
                        HStack(spacing: 14) {
                            AppButton(title: "取消", role: .secondary, size: .large, expands: true) { pending = nil }
                            AppButton(
                                title: model.library.pack(id: draft.pack.id) == nil ? "确认导入" : "导入并替换",
                                systemImage: "checkmark", role: .primary, size: .large, expands: true
                            ) {
                                do {
                                    try manager.install(draft)
                                    model.reloadLibrary()
                                    revision += 1
                                    pending = nil
                                } catch { self.error = error.localizedDescription }
                            }
                        }
                    }
                    .padding(24)
                    .parentSurfaceCard(radius: AppRadius.md)
                }
            }
            .padding(20)
            .background(GrowthPageBackground())
        }
        .sheet(isPresented: $help) {
            VStack(spacing: 18) {
                GrowthPageHeader(
                    icon: "💡", systemIcon: "lightbulb.fill", iconTint: AppColor.accent,
                    title: "怎么做题库", backTitle: "关闭", backSystemImage: "xmark", parentStyle: true,
                    onClose: { help = false }
                ) {}
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("准备一份 UTF-8 编码的 JSON 文件，包含课本 id、书名、学科、年级、单元及课文内容。").font(AppFont.bodyStrong)
                        Text("支持生字、词语、古诗、成语、图片、英语词句和自定义选择题；每个知识点要提供对应的读音或答案。").font(AppFont.body)
                        Text("同 id 的课本会覆盖导入版本；删除导入版本后，内置课本会重新出现。").font(AppFont.body)
                        Text("生字拼音使用带声调的拼音（例如 chén）；选择题答案必须存在于选项中。").font(AppFont.body)
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
                            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.paper, in: RoundedRectangle(cornerRadius: AppRadius.sm))
                    }
                    .foregroundStyle(Theme.ink)
                    .padding(24)
                    .parentSurfaceCard(radius: AppRadius.md)
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
                        CandyConfirmButton(title: "确认删除", systemImage: "trash.fill", role: .destructive) {
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
        SettingsCard(title: "孩子档案", systemImage: "person.2.fill", tint: AppColor.accent) {
            ForEach(model.profiles) { profile in
                HStack(spacing: 14) {
                    PictureView(emoji: profile.avatar, size: 42)
                        .frame(width: 52, height: 52)
                        .background(Circle().fill(AvatarTint.color(for: profile.avatar).opacity(0.65)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(profile.name).font(AppFont.bodyStrong).foregroundStyle(Theme.ink)
                        Text(profile.grade.displayName).font(AppFont.label).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    AppButton(title: "编辑", systemImage: "pencil", role: .secondary, size: .small, minWidth: 88) {
                        editing = EditingProfile(profile: profile, isNew: false)
                    }
                    AppButton(title: "删除", systemImage: "trash.fill", role: .destructive, size: .small, minWidth: 88) {
                        deleting = profile
                    }
                }
                .padding(12)
                .background(Theme.paper, in: RoundedRectangle(cornerRadius: AppRadius.sm))
            }
            AppButton(title: "添加孩子", systemImage: "plus", role: .primary, size: .medium) {
                editing = EditingProfile(profile: Profile(name: "", grade: .g3, avatar: "🐯"), isNew: true)
            }
        }
        .profileEditorCover(item: $editing) { model.save($0) }
        .overlay {
            if let deleting {
                CandyConfirmModal(
                    title: "删除孩子档案？",
                    icon: "⚠️",
                    message: "删除「\(deleting.name)」及其全部学习、成长和对局记录后无法恢复。",
                    buttons: [
                        CandyConfirmButton(title: "确认删除", systemImage: "trash.fill", role: .destructive) {
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
