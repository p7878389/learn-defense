import LearnCore
import SwiftUI

extension View {
    /// 建卡 / 修改档案面板：iPad 上全屏盖一层半透明遮罩，中间是大面板；macOS（只用于编译检查）退化为 sheet。
    /// onDelete 不为 nil 时，修改已有档案的面板底部有「删除这个档案」
    func profileEditorCover(item: Binding<EditingProfile?>,
                            onSave: @escaping (Profile) -> Void,
                            onDelete: ((Profile) -> Void)? = nil) -> some View {
        #if os(iOS)
        fullScreenCover(item: item) { editing in
            ProfileEditor(profile: editing.profile, isNew: editing.isNew, onSave: onSave, onDelete: onDelete)
                .presentationBackground(.clear)
        }
        #else
        sheet(item: item) { editing in
            ProfileEditor(profile: editing.profile, isNew: editing.isNew, onSave: onSave, onDelete: onDelete)
        }
        #endif
    }
}

/// 建卡 / 修改档案：左边是实时预览的卡片，右边三步——选头像、名字、年级。设计稿见 docs/ui-home/06
struct ProfileEditor: View {
    static let maxNameLength = 6

    @Environment(\.dismiss) private var dismiss
    @State private var profile: Profile
    @State private var confirmingDelete = false
    let isNew: Bool
    let onSave: (Profile) -> Void
    var onDelete: ((Profile) -> Void)?

    init(profile: Profile, isNew: Bool, onSave: @escaping (Profile) -> Void, onDelete: ((Profile) -> Void)? = nil) {
        _profile = State(initialValue: profile)
        self.isNew = isNew
        self.onSave = onSave
        self.onDelete = onDelete
    }

    private var trimmedName: String {
        profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var nameTooLong: Bool { trimmedName.count > Self.maxNameLength }
    private var canSave: Bool { !trimmedName.isEmpty && !nameTooLong }

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            GeometryReader { geo in
                // 弹出键盘时可用高度变小，面板可以上下滚动
                ScrollView {
                    panel
                        .frame(maxWidth: 960)
                        .padding(24)
                        .frame(minWidth: geo.size.width, minHeight: geo.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .confirmationDialog(
            "删除「\(profile.name)」的档案？学习记录也会一起删除。",
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                onDelete?(profile)
                dismiss()
            }
            Button("取消", role: .cancel) {}
        }
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isNew ? "欢迎新的小守卫！🎉" : "修改小守卫")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.ink)
                    Text(isNew ? "选个喜欢的小动物，一起去守护书本吧！" : "改完点「保存」就好啦")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.muted)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(Theme.muted)
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(Color(red: 0.96, green: 0.95, blue: 0.93))
                            .shadow(color: GrowthColors.cardEdge, radius: 0, x: 0, y: 4))
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("关闭")
            }
            .padding(.bottom, 16)

            Divider()

            HStack(alignment: .top, spacing: 24) {
                preview
                VStack(alignment: .leading, spacing: 20) {
                    avatarStep
                    nameStep
                    gradeStep
                }
            }
            .padding(.vertical, 20)

            Divider()

            HStack(spacing: 16) {
                if !isNew, onDelete != nil {
                    Button("删除这个档案") { confirmingDelete = true }
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.wrong.opacity(0.85))
                        .frame(minHeight: 44)
                } else {
                    Text("💡 以后点卡片右上角的 ✏️ 可以修改")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.muted)
                }
                Spacer()
                Button { dismiss() } label: {
                    CandyButtonLabel(title: "再想想", fill: Color(red: 0.95, green: 0.94, blue: 0.92), edge: GrowthColors.cardEdge,
                                     foreground: Theme.ink, font: .system(size: 20, weight: .heavy, design: .rounded), height: 60)
                }
                .buttonStyle(PressableStyle())
                Button {
                    profile.name = trimmedName
                    onSave(profile)
                    dismiss()
                } label: {
                    CandyButtonLabel(title: isNew ? "建好啦！" : "保存", icon: "✨",
                                     font: .system(size: 26, weight: .black, design: .rounded), height: 68, minWidth: 200)
                }
                .buttonStyle(PressableStyle())
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.45)
            }
            .padding(.top, 16)
        }
        .padding(28)
        .background(RoundedRectangle(cornerRadius: 36).fill(.white)
            .shadow(color: GrowthColors.cardEdge, radius: 0, x: 0, y: 10)
            .shadow(color: .black.opacity(0.25), radius: 30, y: 16))
    }

    // MARK: - 左栏：实时预览

    private var preview: some View {
        VStack(spacing: 14) {
            Text("👀 实时卡片预览")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)
            VStack(spacing: 8) {
                Circle()
                    .fill(AvatarTint.color(for: profile.avatar))
                    .overlay(Circle().stroke(.white, lineWidth: 4))
                    .frame(width: 104, height: 104)
                    .overlay(PictureView(emoji: profile.avatar, size: 74))
                    .padding(.top, 26)
                Text(trimmedName.isEmpty ? "小守卫" : trimmedName)
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(trimmedName.isEmpty ? Theme.muted.opacity(0.6) : Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .fixedSize(horizontal: false, vertical: true)
                Text(profile.grade.displayName)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(GrowthColors.jadeDark)
                    .padding(.horizontal, 14)
                    .frame(height: 30)
                    .background(Capsule().fill(Color(red: 0.9, green: 0.97, blue: 0.94)))
                    .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .background(RoundedRectangle(cornerRadius: 26).fill(.white).shadow(color: GrowthColors.cardEdge, radius: 0, x: 0, y: 6))
            .overlay(alignment: .top) {
                if isNew {
                    HomeRibbon(text: "🌱 新伙伴", fill: Theme.jade, edge: GrowthColors.jadeDark).offset(y: -16)
                }
            }
            Text(isNew ? "✨ 建好后会出现在首页" : "✨ 首页的卡片会一起变")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.muted)
        }
        .padding(18)
        .frame(width: 290)
        .background(RoundedRectangle(cornerRadius: 30).fill(Theme.paper))
        .overlay(RoundedRectangle(cornerRadius: 30).stroke(GrowthColors.cardEdge, lineWidth: 2))
    }

    // MARK: - 右栏：三步

    private func stepTitle(_ number: Int, _ title: String, note: String? = nil) -> some View {
        HStack(spacing: 10) {
            Text("\(number)")
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Circle().fill(Theme.accent).shadow(color: GrowthColors.orangeDeep, radius: 0, x: 0, y: 2))
            Text(title)
                .font(.system(size: 21, weight: .black, design: .rounded))
                .foregroundStyle(Theme.ink)
            if let note {
                Spacer()
                Text(note)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(nameTooLong && number == 2 ? Theme.wrong : Theme.muted)
            }
        }
    }

    private var avatarStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            stepTitle(1, "选一个头像")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                ForEach(Profile.avatars, id: \.self) { avatar in
                    let selected = profile.avatar == avatar
                    Button { profile.avatar = avatar } label: {
                        PictureView(emoji: avatar, size: 44)
                            .frame(maxWidth: .infinity, minHeight: 64)
                            .background(CandyTileBackground(selected: selected, selectedFill: Color(red: 1.0, green: 0.95, blue: 0.85), radius: 18))
                            .overlay(alignment: .topTrailing) {
                                if selected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .black))
                                        .foregroundStyle(.white)
                                        .frame(width: 24, height: 24)
                                        .background(Circle().fill(Theme.jade))
                                        .overlay(Circle().stroke(.white, lineWidth: 2))
                                        .offset(x: 6, y: -6)
                                }
                            }
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("头像 \(avatar)")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
    }

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            stepTitle(2, "名字或小名", note: nameTooLong ? "最多 \(Self.maxNameLength) 个字哦" : "最多 \(Self.maxNameLength) 个字")
            TextField("例如：乐乐、朵朵", text: $profile.name)
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .padding(.horizontal, 20)
                .frame(height: 64)
                .background(RoundedRectangle(cornerRadius: 18).fill(Theme.paper))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(nameTooLong ? Theme.wrong : GrowthColors.gold, lineWidth: 3))
                .submitLabel(.done)
        }
    }

    private var gradeStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            stepTitle(3, "读几年级啦？", note: "会按年级出题")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                ForEach(Grade.allCases) { grade in
                    let selected = profile.grade == grade
                    Button { profile.grade = grade } label: {
                        Text(grade.displayName)
                            .font(.system(size: 19, weight: .heavy, design: .rounded))
                            .foregroundStyle(selected ? .white : Theme.ink)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(CandyTileBackground(selected: selected, radius: 18))
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
    }
}
