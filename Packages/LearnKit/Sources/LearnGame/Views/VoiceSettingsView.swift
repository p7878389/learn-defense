import AVFoundation
import LearnCore
import SwiftUI

/// 语音设置（家长用）：火山引擎账号、音色、语速，试听，缓存状态。
/// 和家长专区其他页面一样用纸张底色 + 糖果卡片，左栏放系统语音和生成状态，右栏放账号与音色
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

    /// 没配置过时和默认值比，避免一打开就提示「有修改未保存」
    private var hasChanges: Bool { draft != (library.settings ?? TTSSettings()) }

    var body: some View {
        ZStack {
            GrowthPageBackground()
            VStack(spacing: 20) {
                header
                HStack(alignment: .top, spacing: 24) {
                    ScrollView {
                        VStack(spacing: 24) {
                            systemVoiceCard
                            statusCard
                        }
                        .padding(.bottom, 12)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .frame(width: 340)
                    ScrollView {
                        VStack(spacing: 24) {
                            accountCard
                            voiceCard
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 12)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
            }
            .padding(24)
        }
        .tint(Theme.accent)
        // 下拉菜单画在滚动区域外面，不会被裁掉
        .candyDropdownLayer(openID: $openMenu) { id in
            id == VoiceMenu.chinese
                ? menuItems(selection: $draft.speaker, voices: TTSSettings.chineseVoices)
                : menuItems(selection: $draft.englishSpeaker, voices: TTSSettings.englishVoices)
        }
        .confirmationDialog(
            "清除语音合成账号和已生成的语音？之后只用系统语音朗读。",
            isPresented: $confirmingClear,
            titleVisibility: .visible
        ) {
            Button("清除", role: .destructive) {
                library.clear()
                draft = TTSSettings()
                message = "已清除"
            }
            Button("取消", role: .cancel) {}
        }
    }

    // MARK: - 顶栏：和设置页一样的返回、标题、家长专区标识

    private var header: some View {
        HStack(spacing: 16) {
            Button { dismiss() } label: { Label("返回", systemImage: "arrow.left.circle.fill") }
            Spacer()
            Text("☁️ 豆包语音设置").font(.largeTitle.bold())
            Text("🔒 家长专区").font(.headline).padding(10).background(.white, in: Capsule())
            Spacer()
            if hasChanges {
                Label("有修改未保存", systemImage: "pencil").font(.headline).foregroundStyle(GrowthColors.orangeDark)
            }
            Button { save() } label: { Label("保存", systemImage: "checkmark.circle.fill") }
                .buttonStyle(.borderedProminent).tint(Theme.jade)
                .disabled(!draft.isUsable || !hasChanges)
        }
        .foregroundStyle(Theme.ink)
        .font(.title3.bold())
    }

    // MARK: - 左栏

    private var systemVoiceCard: some View {
        SettingsCard(title: "🤖 iPad 系统语音") {
            Text("没有高质量语音时使用，不参与豆包语音生成。").font(.footnote).foregroundStyle(Theme.muted)
            Text(model.speech.systemVoiceDescription)
                .font(.headline).foregroundStyle(Theme.ink)
                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.paper, in: RoundedRectangle(cornerRadius: 16))
            if model.speech.systemVoiceIsCompact {
                tip("有精简版语音，听起来比较生硬。可以在 iPad「设置 → 辅助功能 → 朗读内容 → 声音」的「中文」和「英语（英国）」里下载「增强」或「高品质」语音，重新打开 App 后生效。")
            }
        }
    }

    private var statusCard: some View {
        SettingsCard(title: "📊 生成状态") {
            if library.canGenerate {
                HStack(spacing: 12) {
                    statTile(value: library.cachedCount(), title: "已生成", tint: GrowthColors.orangeDark, fill: Theme.accent.opacity(0.1))
                    statTile(value: library.pendingCount, title: "排队中", tint: GrowthColors.calm, fill: GrowthColors.sky.opacity(0.6))
                }
            } else {
                Text("未配置，全部使用系统语音（题库自带的语音仍会播放）")
                    .font(.callout).foregroundStyle(Theme.muted)
            }
            if let error = library.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill").font(.callout).foregroundStyle(Theme.wrong)
            }
            if let message {
                Label(message, systemImage: "info.circle.fill").font(.callout).foregroundStyle(Theme.muted)
            }
            if library.settings != nil {
                Button(role: .destructive) { confirmingClear = true } label: {
                    Label("清除账号和已生成的语音", systemImage: "trash").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered).tint(Theme.wrong)
            }
        }
    }

    private func statTile(value: Int, title: String, tint: Color, fill: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)").font(.system(size: 30, weight: .heavy, design: .rounded)).monospacedDigit().foregroundStyle(tint)
            Text("\(title)（条）").font(.footnote.bold()).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
        .background(fill, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(GrowthColors.cardEdge, lineWidth: 1.5))
    }

    // MARK: - 右栏

    private var accountCard: some View {
        // 不用 SecureField：iOS 会把「APP ID + 密码框」当成登录表单，弹「存储密码」时键盘卡住出不来
        SettingsCard(title: "🔑 账号密钥") {
            Text("在火山引擎控制台开通「豆包语音合成」后获取，只保存在这台 iPad 的钥匙串里。")
                .font(.footnote).foregroundStyle(Theme.muted)
            field("API Key", text: $draft.apiKey)
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) { showsLegacy.toggle() }
            } label: {
                HStack {
                    Text("旧版控制台（APP ID + Access Token）").font(.headline)
                    Spacer()
                    Image(systemName: "chevron.down").font(.headline).rotationEffect(.degrees(showsLegacy ? 180 : 0))
                }
                .foregroundStyle(Theme.ink).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if showsLegacy {
                HStack(spacing: 16) {
                    field("APP ID", text: $draft.appID)
                    field("Access Token", text: $draft.accessToken)
                }
            }
            tip("填好后，题库和提示语会在后台生成高质量语音，生成之前先用系统语音朗读。")
        }
    }

    private var voiceCard: some View {
        SettingsCard(title: "🎙️ 音色") {
            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("模型")
                GrowthSegmentedPicker(options: Self.resources.map(\.id),
                                      title: { id in Self.resources.first { $0.id == id }?.title ?? id },
                                      selection: $draft.resourceID)
            }
            HStack(alignment: .top, spacing: 16) {
                voiceColumn(id: VoiceMenu.chinese, caption: "中文 / 中英混合", idTitle: "中文音色 ID",
                            selection: $draft.speaker, voices: TTSSettings.chineseVoices)
                voiceColumn(id: VoiceMenu.english, caption: "纯英文", idTitle: "英文音色 ID",
                            selection: $draft.englishSpeaker, voices: TTSSettings.englishVoices)
            }
            HStack(spacing: 16) {
                rateRow
                previewButtons
            }
            tip("纯英文的句子（英语题库的单词、句子）用英文音色，其余用中文音色。也可以在 ID 栏手动填写火山引擎「音色列表」里的其他音色，2.0 模型只能用 2.0 音色。换音色或语速后，已生成的语音会重新生成。")
        }
    }

    private func voiceColumn(id: String, caption: String, idTitle: String,
                             selection: Binding<String>, voices: [TTSSettings.Voice]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            CandyDropdownButton(id: id, caption: caption, value: voiceName(selection.wrappedValue, voices: voices), openID: $openMenu)
            field(idTitle, text: selection)
        }
        .frame(maxWidth: .infinity)
    }

    private var rateRow: some View {
        HStack {
            Text("语速").bold()
            Spacer()
            Text(String(format: "%.2f 倍", 1 + Double(draft.speechRate) / 100)).monospacedDigit().foregroundStyle(Theme.accent).bold()
            Stepper("语速", value: $draft.speechRate, in: -50...50, step: 5).labelsHidden()
        }
        .padding(14).frame(maxWidth: .infinity)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 16))
    }

    private var previewButtons: some View {
        HStack(spacing: 12) {
            Button { preview(SpeechText.Line.sample) } label: {
                HStack(spacing: 6) {
                    if previewing { ProgressView() } else { Image(systemName: "play.circle.fill") }
                    Text("试听中文")
                }
            }
            .buttonStyle(.borderedProminent)
            Button { preview(SpeechText.Line.englishSample) } label: { Label("试听英文", systemImage: "play.circle") }
                .buttonStyle(.bordered)
        }
        .font(.headline)
        .disabled(!draft.isUsable || previewing)
    }

    // MARK: - 小部件

    /// 官方推荐音色；手动填了列表外的 ID 时也显示出来
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
        Text(title).font(.subheadline.bold()).foregroundStyle(Theme.muted)
    }

    private func field(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel(title)
            TextField(title, text: text)
                .textFieldStyle(.plain)
                .credentialInput()
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 14).frame(minHeight: 50)
                .background(GrowthColors.surface, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(GrowthColors.cardEdge, lineWidth: 2))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func tip(_ text: String) -> some View {
        Label { Text(text) } icon: { Image(systemName: "lightbulb.fill").foregroundStyle(GrowthColors.gold) }
            .font(.footnote).foregroundStyle(Theme.muted)
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
    /// 账号、音色这类英文标识：不自动大写、不纠错、不参与密码自动填充，截屏和多任务预览里打码
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
