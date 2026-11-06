import LearnCore
import SwiftUI
import UniformTypeIdentifiers

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

private struct RestoreDraft: Identifiable {
    let id = UUID()
    let archive: SettingsBackup
}

struct ParentDataPane: View {
    @EnvironmentObject private var model: AppModel
    let onReset: () -> Void
    @State private var exporting = false
    @State private var choosingBackup = false
    @State private var document: BackupDocument?
    @State private var restoreDraft: RestoreDraft?
    @State private var resetProfile: Profile?
    @State private var showingReset = false
    @State private var message: String?
    @State private var storageBytes: Int64 = 0

    var body: some View {
        VStack(spacing: 24) {
            SettingsCard(title: "💾 数据与备份") {
                HStack {
                    Text("本地数据与导入课本").font(.title3)
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: storageBytes, countStyle: .file)).font(.title2.bold())
                }
                Text("备份包含孩子档案、学习与成长记录、对局作答、设置和导入课本（含自带音频）。语音账号和缓存不包含在内。")
                    .foregroundStyle(Theme.muted)
                HStack(spacing: 18) {
                    Button("⬆️ 导出备份") { export() }.buttonStyle(.borderedProminent)
                    Button("⬇️ 恢复备份") { choosingBackup = true }.buttonStyle(.bordered)
                }
                .disabled(model.database == nil)
                if let message { Text(message).font(.footnote).foregroundStyle(Theme.muted) }
            }
            SettingsCard(title: "👧 重置单个孩子的学习记录") {
                Text("清除学习统计、错题和对局记录；保留孩子档案、等级、积分、徽章和外观。").foregroundStyle(Theme.muted)
                ForEach(model.profiles) { profile in
                    HStack {
                        Text("\(profile.avatar) \(profile.name)").font(.title3.bold())
                        Spacer()
                        Button("重置学习记录", role: .destructive) { resetProfile = profile }.buttonStyle(.bordered)
                    }
                }
            }
            SettingsCard(title: "⚠️ 危险区") {
                Text("重置所有数据会删除全部孩子和学习成长记录、语音账号及设置。请先导出备份。")
                    .foregroundStyle(Theme.muted)
                Button("重置所有数据", role: .destructive) { showingReset = true }.buttonStyle(.bordered)
            }
        }
        .onAppear { measure() }
        .fileExporter(isPresented: $exporting, document: document, contentType: .json, defaultFilename: "字灵守卫备份") { result in
            switch result {
            case .success: message = "备份已保存"
            case .failure(let error): message = error.localizedDescription
            }
        }
        .fileImporter(isPresented: $choosingBackup, allowedContentTypes: [.json]) { result in
            do {
                let data = try SettingsFileReader.read(result.get(), limit: 100_000_000)
                restoreDraft = RestoreDraft(archive: try SettingsBackup.decode(data))
            } catch { message = error.localizedDescription }
        }
        .sheet(item: $restoreDraft) { draft in
            NavigationStack {
                VStack(alignment: .leading, spacing: 24) {
                    Text("💾 恢复备份").font(.largeTitle.bold())
                    Text("备份时间：\(draft.archive.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    Text("\(draft.archive.children.count) 个孩子 · \(draft.archive.games.count) 局记录 · \(draft.archive.importedPacks.count) 份导入课本")
                    Text("恢复会替换当前全部孩子、学习成长记录、游戏设置和导入课本。当前语音账号不变。请确认已经备份当前数据。").foregroundStyle(.red)
                    Button("确认替换并恢复", role: .destructive) {
                        do {
                            try model.restoreBackup(draft.archive)
                            restoreDraft = nil
                            message = "备份已恢复"
                            measure()
                        } catch { message = error.localizedDescription }
                    }.buttonStyle(.borderedProminent)
                    if let message { Text(message).foregroundStyle(Theme.muted) }
                    Spacer()
                }.padding(30).frame(maxWidth: .infinity, alignment: .leading).background(Theme.paper)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { restoreDraft = nil } } }
            }
        }
        .sheet(isPresented: $showingReset) { ResetAllPanel(onComplete: onReset) }
        .confirmationDialog("重置「\(resetProfile?.name ?? "")」的学习记录？此操作无法撤销。",
                            isPresented: Binding(get: { resetProfile != nil }, set: { if !$0 { resetProfile = nil } }), titleVisibility: .visible) {
            Button("重置学习记录", role: .destructive) {
                do { if let resetProfile { try model.resetLearning(resetProfile) }; message = "学习记录已重置"; self.resetProfile = nil }
                catch { message = error.localizedDescription }
            }
        }
    }

    private func measure() {
        storageBytes = SettingsFiles.bytes(in: AppPaths.dataDirectory) + SettingsFiles.bytes(in: AppPaths.userPacksDirectory)
    }

    private func export() {
        do {
            guard let database = model.database else { throw SettingsError.invalid("数据库不可用") }
            let manager = PackManager(directory: AppPaths.userPacksDirectory)
            let packs = try manager.imported().compactMap(\.files.last).map { try Data(contentsOf: $0) }
            let audioDir = AppPaths.userPackAudioDirectory
            var audio: [String: Data] = [:]
            for file in (try? FileManager.default.contentsOfDirectory(at: audioDir, includingPropertiesForKeys: nil)) ?? []
                where file.pathExtension == "mp3" {
                audio[file.lastPathComponent] = try Data(contentsOf: file)
            }
            document = BackupDocument(data: try database.backupData(importedPacks: packs, packAudio: audio))
            exporting = true
        } catch { message = error.localizedDescription }
    }
}

private struct ResetAllPanel: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirmation = ""
    @State private var keepingPacks = true
    @State private var holding = false
    @State private var working = false
    @State private var error: String?
    let onComplete: () -> Void
    private var canReset: Bool { confirmation == "重置" && !working }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 22) {
                Text("⚠️ 确认重置所有数据").font(.largeTitle.bold()).foregroundStyle(.red)
                Text("将删除所有孩子档案、学习/错题记录、对局明细、等级积分、徽章外观及语音账号和设置。")
                Text("建议先返回导出备份。重置后无法撤销。").foregroundStyle(Theme.muted)
                Toggle("保留我导入的课本", isOn: $keepingPacks)
                TextField("输入“重置”两个字", text: $confirmation).textFieldStyle(.roundedBorder).font(.title2)
                Text("输入后持续按住下面的按钮 3 秒；松开会取消。").foregroundStyle(Theme.muted)
                ZStack {
                    RoundedRectangle(cornerRadius: 20).fill(.red.opacity(0.15))
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 20).fill(.red.opacity(0.5))
                            .frame(width: holding ? geo.size.width : 0)
                            .animation(holding ? .linear(duration: 3) : .default, value: holding)
                    }
                    Text(working ? "正在重置…" : "按住 3 秒，重置全部数据").font(.title3.bold()).foregroundStyle(.red)
                }
                .frame(height: 68).contentShape(Rectangle())
                .opacity(canReset ? 1 : 0.4)
                .onLongPressGesture(minimumDuration: 3, maximumDistance: 30, pressing: { isPressing in
                    holding = canReset && isPressing
                }, perform: {
                    guard canReset else { return }
                    working = true
                    do {
                        try model.resetAll(keepingPacks: keepingPacks)
                        dismiss(); onComplete()
                    } catch { self.error = error.localizedDescription; working = false }
                })
                .allowsHitTesting(canReset)
                if let error { Text(error).foregroundStyle(.red) }
                Spacer()
            }.padding(30).background(Theme.paper)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("再想想") { dismiss() }.disabled(working) } }
        }
        .interactiveDismissDisabled(working)
        .onChange(of: confirmation) { _, _ in holding = false }
    }
}
