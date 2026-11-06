import LearnCore
import SwiftUI

/// App 入口
public struct RootView: View {
    @StateObject private var model = AppModel()

    public init() {}

    public var body: some View {
        NavigationStack {
            ProfilesView()
        }
        .environmentObject(model)
        .tint(Theme.accent)
    }
}

/// 选择孩子
struct ProfilesView: View {
    @EnvironmentObject private var model: AppModel
    @State private var editing: EditingProfile?
    @State private var deleting: Profile?
    @State private var showingVoiceSettings = false

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Text("字灵守卫")
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Text("今天谁来守护书本？")
                    .font(.title2)
                    .foregroundStyle(Theme.muted)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 24)], spacing: 24) {
                    ForEach(model.profiles) { profile in
                        NavigationLink(value: profile.id) {
                            ProfileCard(avatar: profile.avatar, title: profile.name, subtitle: profile.grade.displayName)
                        }
                        .buttonStyle(PressableStyle())
                        .contextMenu {
                            Button("编辑") { editing = EditingProfile(profile: profile, isNew: false) }
                            Button("删除", role: .destructive) { deleting = profile }
                        }
                    }
                    Button {
                        editing = EditingProfile(
                            profile: Profile(name: "", grade: .g3, avatar: Profile.avatars.randomElement()!),
                            isNew: true)
                    } label: {
                        ProfileCard(avatar: "➕", title: "添加孩子", subtitle: "长按卡片可编辑")
                    }
                    .buttonStyle(PressableStyle())
                }
                .frame(maxWidth: 1000)

                Text("图片来自 Microsoft Fluent Emoji（MIT 许可）")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted.opacity(0.8))
            }
            .padding(40)
            .frame(maxWidth: .infinity)
        }
        .background(GrowthPageBackground())
        .navigationDestination(for: UUID.self) { id in
            ProfileHomeView(profileID: id)
        }
        .sheet(item: $editing) { item in
            ProfileEditor(profile: item.profile, isNew: item.isNew) { model.save($0) }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingVoiceSettings = true
                } label: {
                    Label("语音设置", systemImage: "speaker.wave.2.fill")
                }
            }
        }
        .sheet(isPresented: $showingVoiceSettings) {
            VoiceSettingsView(library: model.speechLibrary)
        }
        .confirmationDialog(
            "删除「\(deleting?.name ?? "")」的档案？学习记录也会一起删除。",
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                if let deleting { model.delete(deleting) }
                deleting = nil
            }
            Button("取消", role: .cancel) { deleting = nil }
        }
    }
}

struct EditingProfile: Identifiable {
    var id: UUID { profile.id }
    var profile: Profile
    var isNew: Bool
}

struct ProfileCard: View {
    let avatar: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 10) {
            PictureView(emoji: avatar, size: 96)
            Text(title.isEmpty ? " " : title)
                .font(.title.weight(.bold))
                .foregroundStyle(Theme.ink)
            Text(subtitle).font(.headline).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .background(RoundedRectangle(cornerRadius: 28).fill(GrowthColors.surface))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
    }
}

struct ProfileEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var profile: Profile
    let isNew: Bool
    let onSave: (Profile) -> Void

    init(profile: Profile, isNew: Bool, onSave: @escaping (Profile) -> Void) {
        _profile = State(initialValue: profile)
        self.isNew = isNew
        self.onSave = onSave
    }

    private var trimmedName: String {
        profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("名字") {
                    TextField("孩子的名字或小名", text: $profile.name)
                }
                Section("年级") {
                    Picker("年级", selection: $profile.grade) {
                        ForEach(Grade.allCases) { Text($0.displayName).tag($0) }
                    }
                }
                Section("头像") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))], spacing: 12) {
                        ForEach(Profile.avatars, id: \.self) { avatar in
                            Button { profile.avatar = avatar } label: {
                                PictureView(emoji: avatar, size: 54)
                                    .padding(6)
                                    .background(Circle().fill(profile.avatar == avatar ? Theme.accent.opacity(0.3) : .clear))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "添加孩子" : "编辑档案")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        profile.name = trimmedName
                        onSave(profile)
                        dismiss()
                    }
                    .disabled(trimmedName.isEmpty)
                }
            }
        }
    }
}
