import AVFoundation
import LearnCore
import SwiftUI

/// 语音设置（家长用）：火山引擎账号、音色、语速，试听，缓存状态。
struct VoiceSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var model: AppModel
    @ObservedObject var library: SpeechLibrary
    @State private var draft: TTSSettings
    @State private var previewing = false
    @State private var previewPlayer: AVAudioPlayer?
    @State private var message: String?
    @State private var confirmingClear = false
    @State private var showsLegacy = false
    @State private var openMenu: String?

    init(library: SpeechLibrary) {
        self.library = library
        let settings = library.settings ?? TTSSettings()
        _draft = State(initialValue: settings)
        _showsLegacy = State(initialValue: !settings.appID.isEmpty || !settings.accessToken.isEmpty)
    }

    private static let resources: [(id: String, title: String)] = [
        ("seed-tts-2.0", "豆包语音合成 2.0"),
        ("seed-tts-1.0", "豆包语音合成 1.0"),
    ]

    private enum VoiceMenu {
        static let chinese = "chinese"
        static let english = "english"
    }

    private var hasChanges: Bool { draft != (library.settings ?? TTSSettings()) }

    var body: some View {
        ZStack {
            GrowthPageBackground()
            VStack(spacing: 18) {
                header
                HStack(alignment: .top, spacing: 20) {
                    ScrollView {
                        VStack(spacing: 20) {
                            systemVoiceCard
                            statusCard
                        }
                        .padding(.bottom, 12)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .frame(width: 340)
                    ScrollView {
                        VStack(spacing: 20) {
                            accountCard
                            voiceCard
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 12)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
            }
            .padding(22)
        }
        .tint(AppColor.parentAccent)
        .candyDropdownLayer(openID: $openMenu) { id in
            id == VoiceMenu.chinese
                ? menuItems(selection: $draft.speaker, voices: TTSSettings.chineseVoices)
                : menuItems(selection: $draft.englishSpeaker, voices: TTSSettings.englishVoices)
        }
        .overlay {
            if confirmingClear {
                CandyConfirmModal(
                    title: "清除语音配置？",
                    icon: "⚠️",
                    message: library.canDownload
                        ? "清除语音合成账号和已生成的语音？之后用云端语音朗读，没有时用系统语音。"
                        : "清除语音合成账号和已生成的语音？之后只用系统语音朗读。",
                    buttons: [
                        CandyConfirmButton(title: "确认清除", systemImage: "trash.fill", role: .destructive) {
                            library.clear(); draft = TTSSettings(); message = "已清除"; confirmingClear = false
                        },
                        CandyConfirmButton(title: "取消", role: .cancel) { confirmingClear = false }
                    ],
                    onDismiss: { confirmingClear = false }
                )
            }
        }
    }

    private var header: some View {
        GrowthPageHeader(
            icon: "☁️",
            systemIcon: "cloud.fill",
            iconTint: AppColor.parentAccent,
            title: "豆包语音设置",
            subtitle: "家长专区",
            backTitle: "返回",
            backSystemImage: "chevron.left",
            parentStyle: true,
            onClose: { dismiss() }
        ) {
            if hasChanges {
                Label("有修改未保存", systemImage: "pencil")
                    .font(AppFont.label)
                    .foregroundStyle(GrowthColors.orangeDark)
            }
            let canSave = draft.isUsable && hasChanges
            AppButton(title: "保存", systemImage: "checkmark", role: .primary, size: .medium, minWidth: 100) {
                save()
            }
            .disabled(!canSave)
        }
    }

    private var systemVoiceCard: some View {
        SettingsCard(title: "iPad 系统语音", systemImage: "ipad", tint: AppColor.muted) {
            Text("没有高质量语音时使用，不参与豆包语音生成。").font(AppFont.caption).foregroundStyle(Theme.muted)
            Text(model.speech.systemVoiceDescription)
                .font(AppFont.bodyStrong).foregroundStyle(Theme.ink)
                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.paper, in: RoundedRectangle(cornerRadius: AppRadius.sm))
            if model.speech.systemVoiceIsCompact {
                tip("有精简版语音，听起来比较生硬。可以在 iPad「设置 → 辅助功能 → 朗读内容 → 声音」里下载「增强」或「高品质」语音，重新打开 App 后生效。")
            }
        }
    }

    private var statusCard: some View {
        SettingsCard(title: "语音准备状态", systemImage: "chart.bar.fill", tint: AppColor.jade) {
            if library.preparingRemote {
                ProgressView("正在下载并准备语音包，完成后可离线播放…").font(AppFont.caption)
            }
            if library.canGenerate || library.canDownload {
                HStack(spacing: 10) {
                    if library.canDownload {
                        statTile(value: library.remoteDownloaded, title: "云端已下载", tint: Theme.jade, fill: Theme.jade.opacity(0.1))
                    }
                    if library.canGenerate {
                        statTile(value: library.cachedCount(), title: "已生成", tint: GrowthColors.orangeDark, fill: Theme.accent.opacity(0.1))
                    }
                    statTile(value: library.pendingCount, title: "排队中", tint: GrowthColors.calm, fill: GrowthColors.sky.opacity(0.55))
                }
                if library.canDownload, library.remoteTotal > 0 {
                    Text("云端共 \(library.remoteTotal) 句，下载后离线也能播放。配置了自己的账号和音色时，优先用自己的音色生成。")
                        .font(AppFont.caption).foregroundStyle(Theme.muted)
                }
            } else {
                Text("未配置，全部使用系统语音（题库自带的语音仍会播放）")
                    .font(AppFont.body).foregroundStyle(Theme.muted)
            }
            if let error = library.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill").font(AppFont.label).foregroundStyle(Theme.wrong)
                if library.canDownload {
                    AppButton(title: "重试下载语音包", systemImage: "arrow.clockwise", role: .secondary, size: .small) {
                        library.retryRemote()
                    }
                    .disabled(library.preparingRemote)
                }
            }
            if let message {
                Label(message, systemImage: "info.circle.fill").font(AppFont.label).foregroundStyle(Theme.muted)
            }
            if library.settings != nil {
                AppButton(title: "清除账号和已生成的语音", systemImage: "trash.fill", role: .destructive, size: .medium, expands: true) {
                    confirmingClear = true
                }
            }
        }
    }

    private func statTile(value: Int, title: String, tint: Color, fill: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)").font(AppFont.digits(28, weight: .heavy)).foregroundStyle(tint)
            Text("\(title)（条）").font(AppFont.caption).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(fill, in: RoundedRectangle(cornerRadius: AppRadius.sm))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.sm).strokeBorder(AppColor.parentStroke, lineWidth: 1.2))
    }

    private var accountCard: some View {
        SettingsCard(title: "账号密钥", systemImage: "key.fill", tint: AppColor.accent) {
            Text("在火山引擎控制台开通「豆包语音合成」后获取，只保存在这台 iPad 的钥匙串里。")
                .font(AppFont.caption).foregroundStyle(Theme.muted)
            field("API Key", text: $draft.apiKey)
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) { showsLegacy.toggle() }
            } label: {
                HStack {
                    Text("旧版控制台（APP ID + Access Token）").font(AppFont.bodyStrong)
                    Spacer()
                    Image(systemName: "chevron.down").font(AppFont.label).rotationEffect(.degrees(showsLegacy ? 180 : 0))
                }
                .foregroundStyle(Theme.ink).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if showsLegacy {
                HStack(spacing: 14) {
                    field("APP ID", text: $draft.appID)
                    field("Access Token", text: $draft.accessToken)
                }
            }
            tip("填好后，题库和提示语会在后台生成高质量语音，生成之前先用系统语音朗读。")
        }
    }

    private var voiceCard: some View {
        SettingsCard(title: "音色与试听", systemImage: "mic.fill", tint: AppColor.violet) {
            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("模型")
                GrowthSegmentedPicker(options: Self.resources.map(\.id),
                                      title: { id in Self.resources.first { $0.id == id }?.title ?? id },
                                      selection: $draft.resourceID)
            }
            HStack(alignment: .top, spacing: 14) {
                voiceColumn(id: VoiceMenu.chinese, caption: "中文 / 中英混合", idTitle: "中文音色 ID",
                            selection: $draft.speaker, voices: TTSSettings.chineseVoices)
                voiceColumn(id: VoiceMenu.english, caption: "纯英文", idTitle: "英文音色 ID",
                            selection: $draft.englishSpeaker, voices: TTSSettings.englishVoices)
            }
            HStack(spacing: 14) {
                rateRow
                previewButtons
            }
            tip("纯英文的句子用英文音色，其余用中文音色。2.0 模型只能用 2.0 音色。换音色或语速后，已生成的语音会重新生成。")
        }
    }

    private func voiceColumn(id: String, caption: String, idTitle: String,
                             selection: Binding<String>, voices: [TTSSettings.Voice]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            CandyDropdownButton(id: id, caption: caption, value: voiceName(selection.wrappedValue, voices: voices), openID: $openMenu)
            field(idTitle, text: selection)
        }
        .frame(maxWidth: .infinity)
    }

    private var rateRow: some View {
        HStack {
            Text("语速").font(AppFont.bodyStrong)
            Spacer()
            Text(String(format: "%.2f 倍", 1 + Double(draft.speechRate) / 100))
                .font(AppFont.digits(16, weight: .heavy))
                .foregroundStyle(AppColor.parentAccent)
            Stepper("语速", value: $draft.speechRate, in: -50...50, step: 5).labelsHidden()
        }
        .padding(14).frame(maxWidth: .infinity)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: AppRadius.sm))
    }

    private var previewButtons: some View {
        let ready = draft.isUsable && !previewing
        return HStack(spacing: 10) {
            AppButton(title: previewing ? "合成中…" : "试听中文", systemImage: "play.fill", role: .accent, size: .medium, minWidth: 112) {
                preview(SpeechText.Line.sample)
            }
            .disabled(!ready)
            AppButton(title: "试听英文", systemImage: "play.fill", role: .secondary, size: .medium, minWidth: 112) {
                preview(SpeechText.Line.englishSample)
            }
            .disabled(!ready)
        }
    }

    private func menuItems(selection: Binding<String>, voices: [TTSSettings.Voice]) -> [CandyMenuItem] {
        let current = selection.wrappedValue
        var items = voices.map { voice in
            CandyMenuItem(id: voice.id, title: voice.name, selected: voice.id == current) { selection.wrappedValue = voice.id }
        }
        if !voices.contains(where: { $0.id == current }) {
            items.append(CandyMenuItem(id: "custom:\(current)", title: "自定义：\(current)", selected: true) {})
        }
        return items
    }

    private func voiceName(_ id: String, voices: [TTSSettings.Voice]) -> String {
        voices.first { $0.id == id }?.name ?? (id.isEmpty ? "未选择" : "自定义：\(id)")
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title).font(AppFont.label).foregroundStyle(Theme.muted)
    }

    private func field(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel(title)
            TextField(title, text: text)
                .textFieldStyle(.plain)
                .credentialInput()
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 14).frame(minHeight: 46)
                .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.sm))
                .overlay(RoundedRectangle(cornerRadius: AppRadius.sm).strokeBorder(AppColor.parentStroke, lineWidth: 1.5))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func tip(_ text: String) -> some View {
        Label { Text(text) } icon: { Image(systemName: "lightbulb.fill").foregroundStyle(GrowthColors.gold) }
            .font(AppFont.caption).foregroundStyle(Theme.muted)
    }

    private func save() {
        guard library.update(draft) else {
            message = "保存到钥匙串失败"
            return
        }
        model.prepareSpeech()
        message = "已保存，正在后台生成语音"
    }

    private func preview(_ text: String) {
        previewing = true
        message = nil
        let settings = draft
        Task {
            defer { previewing = false }
            do {
                let audio = try await VolcengineTTS(settings: settings).synthesize(text)
                let player = try AVAudioPlayer(data: audio)
                previewPlayer = player
                player.play()
            } catch {
                message = "试听失败：\(error.localizedDescription)"
            }
        }
    }
}

private extension View {
    func credentialInput() -> some View {
        #if os(iOS)
        self
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .textContentType(.none)
            .privacySensitive()
        #else
        self
            .autocorrectionDisabled()
            .privacySensitive()
        #endif
    }
}
