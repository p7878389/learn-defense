import LearnCore
import SwiftUI

struct ParentVoicePane: View {
    @EnvironmentObject private var model: AppModel
    @State private var draft = ReaderPreferences()
    @State private var advanced = false
    @State private var message: String?

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            SettingsCard(title: "当前朗读方式", systemImage: "speaker.wave.2.fill", tint: AppColor.parentAccent) {
                HStack(spacing: AppSpacing.sm) {
                    source(.system, systemImage: "ipad", title: "iPad 系统语音", detail: "离线可用，零配置")
                    source(.doubao, systemImage: "cloud.fill", title: "豆包语音", detail: doubaoDetail)
                }
                HStack {
                    Text("高级设置可配置豆包账号与中英文音色。")
                        .font(AppFont.label)
                        .foregroundStyle(AppColor.muted)
                    Spacer()
                    AppButton(title: "高级设置（账号 · 音色）", systemImage: "slider.horizontal.3", role: .accent, size: .medium) {
                        advanced = true
                    }
                }
            }
            SettingsCard(title: "朗读参数", systemImage: "dial.medium.fill", tint: AppColor.adventure) {
                slider("语速", value: $draft.rate, range: 0.25...0.65, format: "%.2f")
                slider("音调（系统语音）", value: $draft.pitch, range: 0.7...1.5, format: "%.2f")
                slider("音量", value: $draft.volume, range: 0...1, format: "%.2f")
                VStack(spacing: AppSpacing.xs) {
                    Toggle("自动朗读题目", isOn: $draft.readQuestions)
                    Toggle("朗读游戏提示语", isOn: $draft.readGuidance)
                    Toggle("静音模式下也朗读", isOn: $draft.readsWhenSilent)
                }
                .font(AppFont.body)
                .foregroundStyle(AppColor.ink)
                .tint(AppColor.parentAccent)

                HStack(spacing: AppSpacing.sm) {
                    AppButton(title: "保存设置", systemImage: "checkmark", role: .primary, size: .medium) { save() }
                    AppButton(title: "试读", systemImage: "speaker.wave.2.fill", role: .secondary, size: .medium) {
                        if save() { model.speech.speak("春眠不觉晓，处处闻啼鸟。Hello, welcome!", interrupt: true, channel: .preview) }
                    }
                    if let message { Text(message).font(AppFont.label).foregroundStyle(AppColor.jadeEdge) }
                }
            }
        }
        .onAppear { draft = model.readerPreferences }
        .growthCover(isPresented: $advanced) { VoiceSettingsView(library: model.speechLibrary) }
    }

    private var doubaoDetail: String {
        if model.speechLibrary.settings?.isUsable == true { return "已配置 · 不可用时回退系统语音" }
        return model.speechLibrary.hasRemote ? "使用云端语音 · 没有时回退系统语音" : "配置账号后可生成高质量语音"
    }

    private func source(_ source: ReaderPreferences.Source, systemImage: String, title: String, detail: String) -> some View {
        let selected = draft.source == source
        return Button { draft.source = source } label: {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack(spacing: AppSpacing.xs) {
                    AppIconBadge(systemImage: systemImage, tint: selected ? AppColor.parentAccent : AppColor.muted, size: 30)
                    Text(title).font(AppFont.bodyStrong)
                    Spacer()
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(AppFont.rounded(20, weight: .bold))
                        .foregroundStyle(selected ? AppColor.parentAccent : AppColor.cardStroke)
                }
                Text(detail).font(AppFont.label).foregroundStyle(AppColor.muted).multilineTextAlignment(.leading)
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity, minHeight: 102, alignment: .topLeading)
            .background(selected ? AppColor.parentAccent.opacity(0.09) : AppColor.paper, in: RoundedRectangle(cornerRadius: AppRadius.sm))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.sm).strokeBorder(selected ? AppColor.parentAccent : AppColor.parentStroke, lineWidth: selected ? 2 : 1.2))
        }
        .buttonStyle(PressableStyle())
        .foregroundStyle(AppColor.ink)
    }

    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, format: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(AppFont.body).foregroundStyle(AppColor.ink)
                Spacer()
                Text(String(format: format, value.wrappedValue))
                    .font(AppFont.digits(16, weight: .heavy))
                    .foregroundStyle(AppColor.parentAccent)
            }
            Slider(value: value, in: range).tint(AppColor.parentAccent)
        }
        .padding(AppSpacing.sm)
        .background(AppColor.paper, in: RoundedRectangle(cornerRadius: AppRadius.sm))
    }

    @discardableResult private func save() -> Bool {
        do { try model.updateReader(draft); message = "已保存"; return true }
        catch { message = error.localizedDescription; return false }
    }
}

struct ParentGamePane: View {
    @EnvironmentObject private var model: AppModel
    @State private var rules = GameRules()
    @State private var effects = 0.45
    @State private var message: String?

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            SettingsCard(title: "声音与游戏规则", systemImage: "gamecontroller.fill", tint: AppColor.violet) {
                Text("保存后，从下一局游戏开始使用新规则。").font(AppFont.label).foregroundStyle(AppColor.muted)
                HStack {
                    Text("答题提示音音量").font(AppFont.body)
                    Spacer()
                    Slider(value: $effects, in: 0...1).tint(AppColor.parentAccent).frame(maxWidth: 320)
                }
                .padding(AppSpacing.sm)
                .background(AppColor.paper, in: RoundedRectangle(cornerRadius: AppRadius.sm))

                VStack(spacing: AppSpacing.xs) {
                    Stepper("开始 \(rules.initialRestRounds) 回合使用固定休息", value: $rules.initialRestRounds, in: 1...20)
                    Stepper("初始休息 \(rules.initialRestSeconds) 秒", value: $rules.initialRestSeconds, in: 1...90)
                    Stepper("后续每回合增加 \(rules.restIncrementSeconds) 秒", value: $rules.restIncrementSeconds, in: 1...30)
                    Stepper("最长休息 \(rules.maxRestSeconds) 秒", value: $rules.maxRestSeconds, in: rules.initialRestSeconds...600)
                    Stepper("每 \(rules.reviewEvery) 题穿插一次错题", value: $rules.reviewEvery, in: 2...20)
                    Stepper(rules.newItemGraceSeconds == 0 ? "新知识点不额外等待"
                            : "新知识点先等 \(rules.newItemGraceSeconds) 秒再逼近",
                            value: $rules.newItemGraceSeconds, in: 0...60, step: 2)
                    Stepper("入门：每回合增加 \(rules.questionIncrement.easy) 题", value: $rules.questionIncrement.easy, in: 1...20)
                    Stepper("标准：每回合增加 \(rules.questionIncrement.normal) 题", value: $rules.questionIncrement.normal, in: 1...20)
                    Stepper("挑战：每回合增加 \(rules.questionIncrement.hard) 题", value: $rules.questionIncrement.hard, in: 1...20)
                }
                .font(AppFont.body)
                .foregroundStyle(AppColor.ink)
            }
            SettingsCard(title: "每日积分上限", systemImage: "star.circle.fill", tint: AppColor.goldEdge) {
                VStack(spacing: AppSpacing.xs) {
                    ForEach(CoinSource.allCases, id: \.rawValue) { source in
                        Stepper("\(title(source))：\(rules.coinLimits[source.rawValue] ?? 0) 分",
                                value: Binding(get: { rules.coinLimits[source.rawValue] ?? 0 },
                                               set: { rules.coinLimits[source.rawValue] = $0 }), in: 0...10000, step: 10)
                    }
                }
                .font(AppFont.body)
                .foregroundStyle(AppColor.ink)
                Text("上限设为 0 可关闭该来源。调高上限不会重置今天已领取的积分。")
                    .font(AppFont.caption).foregroundStyle(AppColor.muted)
                HStack(spacing: AppSpacing.sm) {
                    AppButton(title: "保存游戏设置", systemImage: "checkmark", role: .primary, size: .medium) {
                        do {
                            try model.updateRules(rules)
                            var reader = model.readerPreferences; reader.effectsVolume = effects
                            try model.updateReader(reader)
                            message = "已保存"
                        } catch { message = error.localizedDescription }
                    }
                    if let message { Text(message).font(AppFont.label).foregroundStyle(AppColor.jadeEdge) }
                }
            }
        }
        .onAppear { rules = model.gameRules; effects = model.readerPreferences.effectsVolume }
        .onChange(of: rules.initialRestSeconds) { _, value in rules.maxRestSeconds = max(rules.maxRestSeconds, value) }
    }

    private func title(_ s: CoinSource) -> String {
        switch s { case .answers: "答题"; case .completion: "过关评分"; case .firstWin: "每日首胜"; case .level: "升级"; case .badge: "徽章" }
    }
}
