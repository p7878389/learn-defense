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
        VStack(spacing: AppSpacing.md) {
            SettingsCard(title: "数据与备份", systemImage: "externaldrive.fill", tint: AppColor.adventure) {
                HStack {
                    Text("本地数据与导入课本").font(AppFont.bodyStrong).foregroundStyle(AppColor.ink)
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: storageBytes, countStyle: .file))
                        .font(AppFont.digits(20, weight: .heavy))
                        .foregroundStyle(AppColor.parentAccent)
                }
                .padding(AppSpacing.sm)
                .background(AppColor.paper, in: RoundedRectangle(cornerRadius: AppRadius.sm))
                Text("备份包含孩子档案、学习与成长记录、对局作答、设置和导入课本（含自带音频）。语音账号和缓存不包含在内。")
                    .font(AppFont.label).foregroundStyle(AppColor.muted)
                HStack(spacing: AppSpacing.sm) {
                    AppButton(title: "导出备份", systemImage: "square.and.arrow.up", role: .primary, size: .medium) { export() }
                    AppButton(title: "恢复备份", systemImage: "square.and.arrow.down", role: .secondary, size: .medium) { choosingBackup = true }
                }
                .disabled(model.database == nil)
                if let message { Text(message).font(AppFont.label).foregroundStyle(AppColor.jadeEdge) }
            }
            SettingsCard(title: "重置单个孩子的学习记录", systemImage: "arrow.counterclockwise", tint: AppColor.accent) {
                Text("清除学习统计、错题和对局记录；保留孩子档案、等级、积分、徽章和外观。")
                    .font(AppFont.label).foregroundStyle(AppColor.muted)
                ForEach(model.profiles) { profile in
                    HStack(spacing: AppSpacing.sm) {
                        PictureView(emoji: profile.avatar, size: 32)
                        Text(profile.name).font(AppFont.bodyStrong).foregroundStyle(AppColor.ink)
                        Spacer()
                        AppButton(title: "重置学习记录", role: .destructive, size: .small) { resetProfile = profile }
                    }
                    .padding(AppSpacing.sm)
                    .background(AppColor.paper, in: RoundedRectangle(cornerRadius: AppRadius.sm))
                }
            }
            SettingsCard(title: "危险区", systemImage: "exclamationmark.triangle.fill", tint: AppColor.dangerText) {
                Text("重置所有数据会删除全部孩子和学习成长记录、语音账号及设置。请先导出备份。")
                    .font(AppFont.label).foregroundStyle(AppColor.muted)
                AppButton(title: "重置所有数据", systemImage: "exclamationmark.triangle.fill", role: .destructive, size: .medium) {
                    showingReset = true
                }
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
            VStack(spacing: AppSpacing.md) {
                GrowthPageHeader(
                    icon: "💾", systemIcon: "externaldrive.badge.timemachine", iconTint: AppColor.adventure,
                    title: "恢复备份", backTitle: "关闭", backSystemImage: "xmark", parentStyle: true,
                    onClose: { restoreDraft = nil }
                ) {}
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text("备份时间：\(draft.archive.createdAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(AppFont.bodyStrong).foregroundStyle(AppColor.ink)
                    Text("\(draft.archive.children.count) 个孩子 · \(draft.archive.games.count) 局记录 · \(draft.archive.importedPacks.count) 份导入课本")
                        .font(AppFont.body).foregroundStyle(AppColor.ink)
                    Text("恢复会替换当前全部孩子、学习成长记录、游戏设置和导入课本。当前语音账号不变。请确认已经备份当前数据。")
                        .font(AppFont.body).foregroundStyle(AppColor.dangerText)
                    HStack(spacing: AppSpacing.sm) {
                        AppButton(title: "取消", role: .secondary, size: .large, expands: true) { restoreDraft = nil }
                        AppButton(title: "确认替换并恢复", systemImage: "checkmark", role: .destructiveSolid, size: .large, expands: true) {
                            do {
                                try model.restoreBackup(draft.archive)
                                restoreDraft = nil
                                message = "备份已恢复"
                                measure()
                            } catch { message = error.localizedDescription }
                        }
                    }
                    if let message { Text(message).font(AppFont.label).foregroundStyle(AppColor.muted) }
                }
                .padding(AppSpacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .parentSurfaceCard(radius: AppRadius.md)
                Spacer()
            }
            .padding(AppSpacing.md)
            .background(GrowthPageBackground())
        }
        .sheet(isPresented: $showingReset) { ResetAllPanel(onComplete: onReset) }
        .overlay {
            if let resetProfile {
                CandyConfirmModal(
                    title: "重置学习记录？",
                    icon: "⚠️",
                    message: "重置「\(resetProfile.name)」的学习统计、错题和对局记录后无法撤销。",
                    buttons: [
                        CandyConfirmButton(title: "重置学习记录", systemImage: "arrow.counterclockwise", role: .destructive) {
                            do { try model.resetLearning(resetProfile); message = "学习记录已重置" }
                            catch { message = error.localizedDescription }
                            self.resetProfile = nil
                        },
                        CandyConfirmButton(title: "取消", role: .cancel) { self.resetProfile = nil }
                    ],
                    onDismiss: { self.resetProfile = nil }
                )
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
        VStack(spacing: AppSpacing.md) {
            GrowthPageHeader(
                icon: "⚠️", systemIcon: "exclamationmark.triangle.fill", iconTint: AppColor.dangerText,
                title: "重置所有数据", backTitle: "关闭", backSystemImage: "xmark", parentStyle: true,
                onClose: { if !working { dismiss() } }
            ) {}
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("将删除所有孩子档案、学习/错题记录、对局明细、等级积分、徽章外观及语音账号和设置。")
                    .font(AppFont.bodyStrong).foregroundStyle(AppColor.ink)
                Text("建议先返回导出备份。重置后无法撤销。").font(AppFont.body).foregroundStyle(AppColor.muted)
                Toggle("保留我导入的课本", isOn: $keepingPacks).font(AppFont.body).tint(AppColor.parentAccent)
                TextField("输入“重置”两个字", text: $confirmation)
                    .font(AppFont.heading).padding(.horizontal, AppSpacing.md).frame(height: 52)
                    .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.sm))
                    .overlay(RoundedRectangle(cornerRadius: AppRadius.sm).strokeBorder(AppColor.parentStroke, lineWidth: 1.5))
                Text("输入后持续按住下面的按钮 3 秒；松开会取消。").font(AppFont.label).foregroundStyle(AppColor.muted)
                ZStack {
                    RoundedRectangle(cornerRadius: AppRadius.md).fill(AppColor.dangerText.opacity(0.14))
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: AppRadius.md).fill(AppColor.dangerText.opacity(0.45))
                            .frame(width: holding ? geo.size.width : 0)
                            .animation(holding ? .linear(duration: 3) : .default, value: holding)
                    }
                    Text(working ? "正在重置…" : "按住 3 秒，重置全部数据")
                        .font(AppFont.bodyStrong).foregroundStyle(AppColor.dangerText)
                }
                .frame(height: 58).contentShape(Rectangle())
                .opacity(canReset ? 1 : 0.45)
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
                if let error { Text(error).font(AppFont.label).foregroundStyle(AppColor.dangerText) }
            }
            .padding(AppSpacing.lg)
            .parentSurfaceCard(radius: AppRadius.md)
            Spacer()
        }
        .padding(AppSpacing.md)
        .background(GrowthPageBackground())
        .interactiveDismissDisabled(working)
        .onChange(of: confirmation) { _, _ in holding = false }
    }
}
