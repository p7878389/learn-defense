import AVFoundation
import LearnCore
import SwiftUI

/// 语音设置（家长用）：火山引擎账号、音色、语速，试听，缓存状态
struct VoiceSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var model: AppModel
    @ObservedObject var library: SpeechLibrary
    @State private var draft: TTSSettings
    @State private var previewing = false
    @State private var previewPlayer: AVAudioPlayer?
    @State private var message: String?
    @State private var confirmingClear = false

    init(library: SpeechLibrary) {
        self.library = library
        _draft = State(initialValue: library.settings ?? TTSSettings())
    }

    private static let resources: [(id: String, title: String)] = [
        ("seed-tts-2.0", "豆包语音合成 2.0"),
        ("seed-tts-1.0", "豆包语音合成 1.0"),
    ]

    var body: some View {
        NavigationStack {
            Form {
                systemVoiceSection
                accountSection
                voiceSection
                statusSection
            }
            .navigationTitle("语音设置")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(!draft.isUsable || draft == library.settings)
                }
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
    }

    private var systemVoiceSection: some View {
        Section {
            LabeledContent("系统语音", value: model.speech.systemVoiceDescription)
        } header: {
            Text("没有高质量语音时使用")
        } footer: {
            if model.speech.systemVoiceIsCompact {
                Text("有精简版语音，听起来比较生硬。可以在 iPad「设置 → 辅助功能 → 朗读内容 → 声音」的「中文」和「英语（英国）」里下载「增强」或「高品质」语音，重新打开 App 后生效。")
            }
        }
    }

    private var accountSection: some View {
        // 不用 SecureField：iOS 会把「APP ID + 密码框」当成登录表单，弹「存储密码」时键盘卡住出不来
        Section {
            TextField("API Key", text: $draft.apiKey)
                .credentialInput()
            DisclosureGroup("旧版控制台（APP ID + Access Token）") {
                TextField("APP ID", text: $draft.appID)
                    .credentialInput()
                TextField("Access Token", text: $draft.accessToken)
                    .credentialInput()
            }
        } header: {
            Text("豆包语音（火山引擎）")
        } footer: {
            Text("在火山引擎控制台开通「豆包语音合成」后获取。只保存在这台 iPad 的钥匙串里。填好后，题库和提示语会在后台生成高质量语音，生成之前先用系统语音朗读。")
        }
    }

    private var voiceSection: some View {
        Section {
            Picker("模型", selection: $draft.resourceID) {
                ForEach(Self.resources, id: \.id) { Text($0.title).tag($0.id) }
            }
            voicePicker("中文 / 中英混合", selection: $draft.speaker, voices: TTSSettings.chineseVoices)
            TextField("中文音色 ID", text: $draft.speaker)
                .credentialInput()
            voicePicker("纯英文", selection: $draft.englishSpeaker, voices: TTSSettings.englishVoices)
            TextField("英文音色 ID", text: $draft.englishSpeaker)
                .credentialInput()
            Stepper(value: $draft.speechRate, in: -50...50, step: 5) {
                LabeledContent("语速", value: String(format: "%.2f 倍", 1 + Double(draft.speechRate) / 100))
            }
            Button {
                preview(SpeechText.Line.sample)
            } label: {
                HStack {
                    Text("试听中文")
                    if previewing { Spacer(); ProgressView() }
                }
            }
            .disabled(!draft.isUsable || previewing)
            Button("试听英文") { preview(SpeechText.Line.englishSample) }
                .disabled(!draft.isUsable || previewing)
        } header: {
            Text("音色")
        } footer: {
            Text("纯英文的句子（英语题库的单词、句子）用英文音色，其余用中文音色。也可以在 ID 栏手动填写火山引擎「音色列表」里的其他音色，2.0 模型只能用 2.0 音色。换音色或语速后，已生成的语音会重新生成。")
        }
    }

    /// 官方推荐音色；手动填了列表外的 ID 时也显示出来
    private func voicePicker(_ title: String, selection: Binding<String>, voices: [TTSSettings.Voice]) -> some View {
        let custom = voices.contains { $0.id == selection.wrappedValue } ? [] : [selection.wrappedValue]
        return Picker(title, selection: selection) {
            ForEach(voices) { Text($0.name).tag($0.id) }
            ForEach(custom, id: \.self) { Text("自定义：\($0)").tag($0) }
        }
    }

    private var statusSection: some View {
        Section("状态") {
            if library.canGenerate {
                LabeledContent("已生成", value: "\(library.cachedCount()) 条")
                LabeledContent("排队中", value: "\(library.pendingCount) 条")
            } else {
                Text("未配置，全部使用系统语音（题库自带的语音仍会播放）")
                    .foregroundStyle(.secondary)
            }
            if let error = library.lastError {
                Text(error).foregroundStyle(.red)
            }
            if let message {
                Text(message).foregroundStyle(.secondary)
            }
            if library.settings != nil {
                Button("清除账号和已生成的语音", role: .destructive) { confirmingClear = true }
            }
        }
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
