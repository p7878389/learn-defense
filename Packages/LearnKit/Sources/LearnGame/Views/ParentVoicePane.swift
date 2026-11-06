import LearnCore
import SwiftUI

struct ParentVoicePane: View {
    @EnvironmentObject private var model: AppModel
    @State private var draft = ReaderPreferences()
    @State private var advanced = false
    @State private var message: String?

    var body: some View {
        VStack(spacing: 24) {
            SettingsCard(title: "🔊 当前朗读方式") {
                HStack(spacing: 16) {
                    source(.system, title: "🤖 iPad 系统语音", detail: "离线可用")
                    source(.doubao, title: "☁️ 豆包语音", detail: model.speechLibrary.settings?.isUsable == true ? "已配置 · 不可用时回退系统语音" : "配置账号后可生成语音")
                }
                HStack {
                    Text("高级设置可配置豆包账号与中英文音色。").foregroundStyle(Theme.muted)
                    Spacer()
                    Button("高级设置（账号 · 音色） ›") { advanced = true }.buttonStyle(.borderedProminent)
                }
            }
            SettingsCard(title: "🎛️ 朗读参数") {
                slider("语速", value: $draft.rate, range: 0.25...0.65, format: "%.2f")
                slider("音调（系统语音）", value: $draft.pitch, range: 0.7...1.5, format: "%.2f")
                slider("音量", value: $draft.volume, range: 0...1, format: "%.2f")
                Toggle("自动朗读题目", isOn: $draft.readQuestions)
                Toggle("朗读游戏提示语", isOn: $draft.readGuidance)
                Toggle("静音模式下也朗读", isOn: $draft.readsWhenSilent)
                HStack {
                    Button("保存设置") { save() }.buttonStyle(.borderedProminent)
                    Button("🔊 试读") {
                        if save() { model.speech.speak("春眠不觉晓，处处闻啼鸟。Hello, welcome!", interrupt: true, channel: .preview) }
                    }.buttonStyle(.bordered)
                    if let message { Text(message).font(.footnote).foregroundStyle(Theme.muted) }
                }
            }
        }
        .onAppear { draft = model.readerPreferences }
        .sheet(isPresented: $advanced) { VoiceSettingsView(library: model.speechLibrary) }
    }

    private func source(_ source: ReaderPreferences.Source, title: String, detail: String) -> some View {
        Button { draft.source = source } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack { Text(title).font(.title3.bold()); Spacer(); Image(systemName: draft.source == source ? "checkmark.circle.fill" : "circle") }
                Text(detail).font(.footnote).multilineTextAlignment(.leading)
            }
            .padding(18).frame(maxWidth: .infinity, minHeight: 110)
            .background(source == draft.source ? Theme.accent.opacity(0.1) : Theme.paper, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(source == draft.source ? Theme.accent : GrowthColors.cardEdge, lineWidth: 2))
        }.buttonStyle(.plain).foregroundStyle(Theme.ink)
    }

    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, format: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text(title).bold(); Spacer(); Text(String(format: format, value.wrappedValue)).monospacedDigit().foregroundStyle(Theme.accent) }
            Slider(value: value, in: range)
        }.padding(14).background(Theme.paper, in: RoundedRectangle(cornerRadius: 16))
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
        VStack(spacing: 24) {
            SettingsCard(title: "🎮 声音与游戏") {
                Text("保存后，从下一局游戏开始使用新规则。").foregroundStyle(Theme.muted)
                HStack { Text("答题提示音音量"); Slider(value: $effects, in: 0...1).frame(maxWidth: 320) }
                Stepper("开始 \(rules.initialRestRounds) 回合使用固定休息", value: $rules.initialRestRounds, in: 1...20)
                Stepper("初始休息 \(rules.initialRestSeconds) 秒", value: $rules.initialRestSeconds, in: 1...90)
                Stepper("后续每回合增加 \(rules.restIncrementSeconds) 秒", value: $rules.restIncrementSeconds, in: 1...30)
                Stepper("最长休息 \(rules.maxRestSeconds) 秒", value: $rules.maxRestSeconds, in: rules.initialRestSeconds...600)
                Stepper("每 \(rules.reviewEvery) 题穿插一次错题", value: $rules.reviewEvery, in: 2...20)
                Stepper("简单：每回合增加 \(rules.questionIncrement.easy) 题", value: $rules.questionIncrement.easy, in: 1...20)
                Stepper("标准：每回合增加 \(rules.questionIncrement.normal) 题", value: $rules.questionIncrement.normal, in: 1...20)
                Stepper("挑战：每回合增加 \(rules.questionIncrement.hard) 题", value: $rules.questionIncrement.hard, in: 1...20)
            }
            SettingsCard(title: "🪙 每日积分上限") {
                ForEach(CoinSource.allCases, id: \.rawValue) { source in
                    Stepper("\(title(source))：\(rules.coinLimits[source.rawValue] ?? 0) 分",
                            value: Binding(get: { rules.coinLimits[source.rawValue] ?? 0 },
                                           set: { rules.coinLimits[source.rawValue] = $0 }), in: 0...10000, step: 10)
                }
                Text("上限设为 0 可关闭该来源。调高上限不会重置今天已领取的积分。").font(.footnote).foregroundStyle(Theme.muted)
                Button("保存游戏设置") {
                    do {
                        try model.updateRules(rules)
                        var reader = model.readerPreferences; reader.effectsVolume = effects
                        try model.updateReader(reader)
                        message = "已保存"
                    } catch { message = error.localizedDescription }
                }.buttonStyle(.borderedProminent)
                if let message { Text(message).foregroundStyle(Theme.muted) }
            }
        }
        .onAppear { rules = model.gameRules; effects = model.readerPreferences.effectsVolume }
        .onChange(of: rules.initialRestSeconds) { _, value in rules.maxRestSeconds = max(rules.maxRestSeconds, value) }
    }

    private func title(_ s: CoinSource) -> String {
        switch s { case .answers: "答题"; case .completion: "过关评分"; case .firstWin: "每日首胜"; case .level: "升级"; case .badge: "徽章" }
    }
}
