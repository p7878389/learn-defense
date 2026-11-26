import LearnCore
import SwiftUI

extension View {
    /// 建卡 / 修改档案面板：iPad 上全屏盖一层半透明遮罩，中间是大面板；macOS（只用于编译检查）退化为 sheet。
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

/// 建卡 / 修改档案：左边是实时预览的卡片，右边三步——选头像、名字、年级。底部按钮同档齐平。
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
                ScrollView {
                    panel
                        .frame(maxWidth: 960)
                        .padding(AppSpacing.lg)
                        .frame(minWidth: geo.size.width, minHeight: geo.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .overlay {
            if confirmingDelete {
                CandyConfirmModal(
                    title: "删除档案？",
                    icon: "⚠️",
                    message: "删除「\(profile.name)」的档案后，所有学习、成长和对局记录都会一起删除。",
                    buttons: [
                        CandyConfirmButton(title: "确认删除", systemImage: "trash.fill", role: .destructive) {
                            confirmingDelete = false
                            onDelete?(profile)
                            dismiss()
                        },
                        CandyConfirmButton(title: "取消", role: .cancel) { confirmingDelete = false }
                    ],
                    onDismiss: { confirmingDelete = false }
                )
            }
        }
    }

    private var panel: some View {
        let shape = RoundedRectangle(cornerRadius: AppRadius.xl)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: AppSpacing.sm) {
                AppIconBadge(systemImage: isNew ? "sparkles" : "person.crop.circle.badge.checkmark", tint: AppColor.accent, size: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text(isNew ? "欢迎新的小守卫！" : "修改小守卫")
                        .font(AppFont.title)
                        .foregroundStyle(AppColor.ink)
                    Text(isNew ? "选个喜欢的小动物，一起去守护书本吧！" : "修改完成后点击底部「保存」即可生效")
                        .font(AppFont.body)
                        .foregroundStyle(AppColor.muted)
                }
                Spacer()
            }
            .padding(.bottom, AppSpacing.md)

            Divider()

            HStack(alignment: .top, spacing: AppSpacing.lg) {
                preview
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    avatarStep
                    nameStep
                    gradeStep
                }
            }
            .padding(.vertical, AppSpacing.md)

            Divider()

            // 底部同行按钮全部统一 .large（54pt），不再参差不齐
            HStack(spacing: AppSpacing.sm) {
                if !isNew, onDelete != nil {
                    AppButton(title: "删除档案", systemImage: "trash.fill", role: .destructive, size: .large, minWidth: 136) {
                        confirmingDelete = true
                    }
                } else {
                    Label("以后点卡片右上角的编辑按钮可以随时修改", systemImage: "lightbulb.fill")
                        .font(AppFont.label)
                        .foregroundStyle(AppColor.muted)
                }
                Spacer()
                AppButton(title: "取消", role: .secondary, size: .large, minWidth: 120) {
                    dismiss()
                }
                AppButton(title: isNew ? "建好啦！" : "保存修改", systemImage: "checkmark", role: .primary, size: .large, minWidth: 180) {
                    profile.name = trimmedName
                    onSave(profile)
                    dismiss()
                }
                .disabled(!canSave)
            }
            .padding(.top, AppSpacing.md)
        }
        .padding(AppSpacing.lg)
        .background(
            ZStack {
                shape.fill(AppColor.cardEdge)
                    .appShadow(.floating)
                shape.fill(LinearGradient(colors: [AppColor.paperTop, AppColor.paper], startPoint: .top, endPoint: .bottom))
                    .overlay(shape.strokeBorder(AppColor.gold.opacity(0.75), lineWidth: 2.5))
                    .padding(.bottom, 5)
            }
        )
    }

    // MARK: - 左栏：实时预览

    private var preview: some View {
        let tint = AvatarTint.color(for: profile.avatar)
        return VStack(spacing: AppSpacing.sm) {
            Label("实时卡片预览", systemImage: "eye.fill")
                .font(AppFont.bodyStrong)
                .foregroundStyle(AppColor.ink)
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [tint.opacity(0.45), .clear], center: .center, startRadius: 20, endRadius: 62))
                        .frame(width: 120, height: 120)
                    Circle()
                        .fill(LinearGradient(colors: [.white.opacity(0.55), tint], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .overlay(Circle().strokeBorder(.white, lineWidth: 4))
                        .frame(width: 100, height: 100)
                        .overlay(PictureView(emoji: profile.avatar, size: 70))
                }
                .padding(.top, AppSpacing.md)
                Text(trimmedName.isEmpty ? "小守卫" : trimmedName)
                    .font(AppFont.title)
                    .foregroundStyle(trimmedName.isEmpty ? AppColor.muted.opacity(0.6) : AppColor.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .fixedSize(horizontal: false, vertical: true)
                Text(profile.grade.displayName)
                    .font(AppFont.label)
                    .foregroundStyle(AppColor.jadeEdge)
                    .padding(.horizontal, AppSpacing.md)
                    .frame(height: 30)
                    .background(Capsule().fill(AppColor.jade.opacity(0.14)))
                    .padding(.bottom, AppSpacing.md)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, AppSpacing.md)
            .appInset(radius: AppRadius.lg)
            .overlay(alignment: .top) {
                if isNew {
                    HomeRibbon(text: "🌱 新伙伴", fill: AppColor.jade, edge: AppColor.jadeEdge).offset(y: -16)
                }
            }
            Text(isNew ? "建好后会出现在首页舞台" : "首页的卡片会同步更新")
                .font(AppFont.label)
                .foregroundStyle(AppColor.muted)
        }
        .padding(AppSpacing.md)
        .frame(width: 288)
        .appPanel(radius: AppRadius.lg)
    }

    // MARK: - 右栏：三步

    private func stepTitle(_ number: Int, _ title: String, note: String? = nil) -> some View {
        HStack(spacing: 10) {
            Text("\(number)")
                .font(AppFont.digits(15, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(AppColor.accent))
            Text(title)
                .font(AppFont.heading)
                .foregroundStyle(AppColor.ink)
            if let note {
                Spacer()
                Text(note)
                    .font(AppFont.label)
                    .foregroundStyle(nameTooLong && number == 2 ? AppColor.dangerText : AppColor.muted)
            }
        }
    }

    private var avatarStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            stepTitle(1, "选一个头像")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                ForEach(Profile.avatars, id: \.self) { avatar in
                    let selected = profile.avatar == avatar
                    Button { profile.avatar = avatar } label: {
                        PictureView(emoji: avatar, size: 42)
                            .frame(maxWidth: .infinity, minHeight: 62)
                            .background(CandyTileBackground(selected: selected, selectedFill: AppColor.jade.opacity(0.14), selectedEdge: AppColor.jade, radius: AppRadius.md))
                            .overlay(alignment: .topTrailing) {
                                if selected {
                                    Image(systemName: "checkmark")
                                        .font(AppFont.rounded(11, weight: .black))
                                        .foregroundStyle(.white)
                                        .frame(width: 22, height: 22)
                                        .background(Circle().fill(AppColor.jade))
                                        .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                                        .offset(x: 5, y: -5)
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
                .font(AppFont.heading)
                .padding(.horizontal, AppSpacing.md)
                .frame(height: 58)
                .background(RoundedRectangle(cornerRadius: AppRadius.md).fill(AppColor.surface))
                .overlay(RoundedRectangle(cornerRadius: AppRadius.md).strokeBorder(nameTooLong ? AppColor.dangerText : AppColor.gold, lineWidth: 2.5))
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
                            .font(AppFont.bodyStrong)
                            .foregroundStyle(selected ? .white : AppColor.ink)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(CandyTileBackground(selected: selected, selectedFill: AppColor.jade, selectedEdge: AppColor.jadeEdge, radius: AppRadius.md))
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
    }
}
