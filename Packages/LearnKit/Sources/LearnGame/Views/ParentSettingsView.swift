import LearnCore
import SwiftUI
import UniformTypeIdentifiers

enum ParentSection: String, CaseIterable, Identifiable {
    case voice = "朗读语音", packs = "课本与题库", profiles = "孩子档案"
    case game = "声音与游戏", data = "数据与备份", about = "关于"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .voice: "🔊"
        case .packs: "📚"
        case .profiles: "👧"
        case .game: "🎮"
        case .data: "💾"
        case .about: "ℹ️"
        }
    }
}

struct ParentSettingsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var unlocked = false

    var body: some View {
        ZStack {
            GrowthPageBackground()
            if unlocked {
                ParentSettingsContent(onClose: { unlocked = false; dismiss() })
            } else {
                ParentGateView(onSuccess: { unlocked = true }, onCancel: { dismiss() })
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { unlocked = false }
        }
    }
}

struct SettingsCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(title).font(.title2.bold()).foregroundStyle(Theme.ink)
            content
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .candyCard(fill: .white)
    }
}

private struct ParentGateView: View {
    @EnvironmentObject private var model: AppModel
    @State private var gate = ParentGate()
    @State private var now = Date()
    @State private var message = ""
    @State private var persistenceFailed = false
    let onSuccess: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Spacer()
                Button("关闭", action: onCancel).buttonStyle(.bordered)
            }
            Text("🔒").font(.system(size: 64))
            Text("家长验证").font(.largeTitle.bold())
            Text("请家长完成下面的计算，进入家长专区").foregroundStyle(Theme.muted)
            Text("\(gate.left) × \(gate.right) = ?").font(.system(size: 48, weight: .heavy, design: .rounded))
            HStack(spacing: 16) {
                ForEach(gate.options, id: \.self) { option in
                    Button("\(option)") {
                        let success = gate.submit(option)
                        do {
                            guard let database = model.database else { throw SettingsError.invalid("数据库不可用") }
                            try database.saveSetting(gate, named: "parent-gate")
                            if success { onSuccess() }
                            else { message = gate.canAnswer() ? "再想一想，请家长来帮忙" : "请稍后再试，或请家长来帮忙" }
                        } catch {
                            persistenceFailed = true
                            message = "无法保存验证状态，请重新打开应用"
                        }
                    }
                    .font(.title.bold())
                    .frame(minWidth: 100, minHeight: 72)
                    .foregroundStyle(Theme.ink)
                    .background(Theme.paper, in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(GrowthColors.cardEdge, lineWidth: 2))
                    .disabled(!gate.canAnswer(now: now) || persistenceFailed)
                }
            }
            Text(message.isEmpty ? "连续答错 3 次后，需要稍后再试" : message).foregroundStyle(Theme.muted)
        }
        .padding(30).frame(maxWidth: 680).candyCard(fill: .white)
        .padding(30)
        .onAppear {
            do {
                guard let db = model.database else { throw SettingsError.invalid("数据库不可用") }
                gate = try db.setting(named: "parent-gate", fallback: ParentGate())
                gate.renewChallenge()
            } catch { persistenceFailed = true; message = "无法读取验证状态，请重新打开应用" }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { now = $0 }
    }
}

private struct ParentAboutPane: View {
    var body: some View {
        SettingsCard(title: "ℹ️ 关于字灵守卫") {
            Text("通过答题守护书本，在游戏中练习语文和英语。").font(.title3)
            Text("版本 \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
            Text("学习记录存储在本机。导出备份后，请妥善保存文件。")
            Text("图片：Microsoft Fluent Emoji（MIT）\n植物与僵尸素材说明见项目 Resources/Sprites。\n项目使用 GPL-3.0 许可。")
                .font(.footnote).foregroundStyle(Theme.muted)
        }
    }
}

/// 由家长验证后的容器呈现；可指定初始分区，保留独立的页面布局。
struct ParentSettingsContent: View {
    @State var section: ParentSection = .voice
    let onClose: () -> Void
    var body: some View {
        ZStack {
            GrowthPageBackground()
                VStack(spacing: 20) {
                    HStack {
                        Button(action: onClose) { Label("返回主页", systemImage: "arrow.left.circle.fill") }
                        Spacer()
                        Text("⚙️ 设置").font(.largeTitle.bold())
                        Text("🔒 家长专区").font(.headline).padding(10).background(.white, in: Capsule())
                        Spacer()
                        Button("退出家长模式", action: onClose).buttonStyle(.bordered)
                    }
                    .foregroundStyle(Theme.ink)
                    .font(.title3.bold())
                    HStack(alignment: .top, spacing: 24) {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(ParentSection.allCases) { item in
                                Button { section = item } label: {
                                    HStack(spacing: 14) {
                                        Text(item.icon)
                                        Text(item.rawValue)
                                        Spacer(minLength: 0)
                                        if item == section { Circle().fill(.white.opacity(0.7)).frame(width: 8, height: 8) }
                                    }
                                    .font(.title3.bold())
                                    .foregroundStyle(item == section ? .white : Theme.ink)
                                    .padding(18)
                                    .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
                                    .background(item == section ? Theme.accent : .clear, in: RoundedRectangle(cornerRadius: 18))
                                }
                                .buttonStyle(.plain)
                            }
                            Spacer()
                            Text("档案和学习记录只保存在这台 iPad 上")
                                .font(.footnote).foregroundStyle(Theme.muted)
                                .padding(14).background(Theme.paper, in: RoundedRectangle(cornerRadius: 16))
                        }
                        .padding(18).frame(width: 250).candyCard(fill: .white)
                        ScrollView {
                            Group {
                                switch section {
                                case .voice: ParentVoicePane()
                                case .packs: ParentPacksPane()
                                case .profiles: ParentProfilesPane()
                                case .game: ParentGamePane()
                                case .data: ParentDataPane(onReset: onClose)
                                case .about: ParentAboutPane()
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.bottom, 12)
                        }
                        .scrollBounceBehavior(.basedOnSize)
                    }
                }
                .padding(24)

        }
    }
}
