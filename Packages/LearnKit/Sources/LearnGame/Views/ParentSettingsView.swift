import LearnCore
import SwiftUI
import UniformTypeIdentifiers

enum ParentSection: String, CaseIterable, Identifiable {
    case voice = "朗读语音", packs = "课本与题库", profiles = "孩子档案"
    case game = "声音与游戏", data = "数据与备份", about = "关于"
    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .voice: "speaker.wave.2.fill"
        case .packs: "books.vertical.fill"
        case .profiles: "person.2.fill"
        case .game: "gamecontroller.fill"
        case .data: "externaldrive.fill"
        case .about: "info.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .voice: AppColor.parentAccent
        case .packs: AppColor.jade
        case .profiles: AppColor.accent
        case .game: AppColor.violet
        case .data: AppColor.adventure
        case .about: AppColor.muted
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

/// 家长端清雅设置卡片：同源暖米色 + 利落圆角 + 轻柔投影 + 统一 SF Symbols 徽章
struct SettingsCard<Content: View>: View {
    let title: String
    var systemImage: String? = nil
    var tint: Color = AppColor.parentAccent
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                if let systemImage {
                    AppIconBadge(systemImage: systemImage, tint: tint, size: 32)
                }
                Text(title).font(AppFont.heading).foregroundStyle(Theme.ink)
            }
            content
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .parentSurfaceCard(radius: AppRadius.md)
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
        CandyModalCard(bannerTitle: "家长验证", bannerIcon: "🔒", maxWidth: 620) {
            Text("请家长完成下面的计算，进入家长专区")
                .font(AppFont.body)
                .foregroundStyle(Theme.muted)
            Text("\(gate.left) × \(gate.right) = ?")
                .font(AppFont.digits(46, weight: .black))
                .foregroundStyle(Theme.ink)
            HStack(spacing: 14) {
                ForEach(gate.options, id: \.self) { option in
                    Button {
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
                    } label: {
                        Text("\(option)")
                            .font(AppFont.digits(28, weight: .heavy))
                            .frame(minWidth: 100, minHeight: 70)
                            .foregroundStyle(Theme.ink)
                            .background(CandyTileBackground(radius: AppRadius.md))
                    }
                    .buttonStyle(PressableStyle())
                    .disabled(!gate.canAnswer(now: now) || persistenceFailed)
                }
            }
            Text(message.isEmpty ? "连续答错 3 次后，需要稍后再试" : message)
                .font(AppFont.label)
                .foregroundStyle(Theme.muted)
            AppButton(title: "返回主页", systemImage: "chevron.left", role: .secondary, size: .medium, minWidth: 140, action: onCancel)
        }
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
        SettingsCard(title: "关于字灵守卫", systemImage: "info.circle.fill", tint: AppColor.muted) {
            Text("通过答题守护书本，在游戏中练习语文和英语。").font(AppFont.bodyStrong).foregroundStyle(Theme.ink)
            Text("版本 \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                .font(AppFont.body).foregroundStyle(Theme.ink)
            Text("学习记录存储在本机。导出备份后，请妥善保存文件。")
                .font(AppFont.body).foregroundStyle(Theme.muted)
            Text("图片：Microsoft Fluent Emoji（MIT）\n植物与僵尸素材说明见项目 Resources/Sprites。\n项目使用 GPL-3.0 许可。")
                .font(AppFont.caption).foregroundStyle(Theme.muted)
        }
    }
}

/// 家长专区主容器：移除重复的右侧“退出家长模式”按钮，采用清雅松石绿导航与圆润 SF Symbols 图标。
struct ParentSettingsContent: View {
    @State var section: ParentSection = .voice
    let onClose: () -> Void

    var body: some View {
        ZStack {
            GrowthPageBackground()
            VStack(spacing: 18) {
                GrowthPageHeader(
                    icon: "⚙️",
                    systemIcon: "gearshape.fill",
                    iconTint: AppColor.parentAccent,
                    title: "家长设置",
                    subtitle: "家长专区",
                    backTitle: "退出家长专区",
                    backSystemImage: "chevron.left",
                    parentStyle: true,
                    onClose: onClose
                ) {
                    EmptyView()
                }
                HStack(alignment: .top, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(ParentSection.allCases) { item in
                            let selected = item == section
                            Button { section = item } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: item.systemImage)
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(selected ? .white : item.tint)
                                        .frame(width: 32, height: 32)
                                        .background(
                                            RoundedRectangle(cornerRadius: AppRadius.xs)
                                                .fill(selected ? .white.opacity(0.22) : item.tint.opacity(0.14))
                                        )
                                    Text(item.rawValue)
                                        .font(AppFont.bodyStrong)
                                    Spacer(minLength: 0)
                                    if selected {
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 13, weight: .heavy))
                                            .foregroundStyle(.white.opacity(0.8))
                                    }
                                }
                                .foregroundStyle(selected ? .white : Theme.ink)
                                .padding(.horizontal, 12)
                                .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: AppRadius.sm)
                                        .fill(
                                            selected
                                                ? AnyShapeStyle(LinearGradient(colors: [AppColor.parentAccent, AppColor.adventureBottom],
                                                                               startPoint: .topLeading, endPoint: .bottomTrailing))
                                                : AnyShapeStyle(Color.clear)
                                        )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppRadius.sm)
                                        .strokeBorder(selected ? .clear : AppColor.parentStroke.opacity(0.5), lineWidth: 1)
                                )
                            }
                            .buttonStyle(PressableStyle())
                        }
                        Spacer()
                        Label("档案和学习记录仅保存在本台 iPad 上", systemImage: "lock.shield.fill")
                            .font(AppFont.caption)
                            .foregroundStyle(Theme.muted)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.paper, in: RoundedRectangle(cornerRadius: AppRadius.sm))
                    }
                    .padding(14)
                    .frame(width: 248)
                    .parentSurfaceCard(radius: AppRadius.md)

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
            .padding(22)
        }
    }
}
