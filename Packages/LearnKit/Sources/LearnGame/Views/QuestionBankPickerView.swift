import LearnCore
import SwiftUI

struct QuestionBankPickerView: View {
    @State private var draft: QuestionBankDraft
    @State private var openMenu: String?
    let onConfirm: (GameConfig) -> Void
    let onCancel: () -> Void
    let errorMessage: String?

    init(config: GameConfig, library: ContentLibrary, onConfirm: @escaping (GameConfig) -> Void, onCancel: @escaping () -> Void,
         errorMessage: String? = nil) {
        _draft = State(initialValue: QuestionBankDraft(config: config, library: library))
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        self.errorMessage = errorMessage
    }

    var body: some View {
        GeometryReader { geometry in
            let wide = geometry.size.width > geometry.size.height && geometry.size.width >= 680
            let compact = geometry.size.height < 700
            VStack(alignment: .leading, spacing: compact ? 8 : 12) {
                header
                if wide {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(spacing: compact ? 6 : 10) {
                            dropdown("subject", caption: "学科", value: draft.subject.displayName)
                            dropdown("grade", caption: "年级", value: draft.grade.displayName)
                            dropdown("difficulty", caption: "难度", value: draft.difficulty.displayName)
                            bookSelectors
                        }
                        .padding(compact ? 8 : 12)
                        .candyCard(radius: AppRadius.lg)
                        .frame(width: geometry.size.width < 820 ? 226 : 264)
                        unitsArea(compact: compact).frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    Grid(horizontalSpacing: 10, verticalSpacing: 6) {
                        GridRow {
                            dropdown("subject", caption: "学科", value: draft.subject.displayName)
                            dropdown("grade", caption: "年级", value: draft.grade.displayName)
                            dropdown("difficulty", caption: "难度", value: draft.difficulty.displayName)
                        }
                        if !draft.isReview {
                            GridRow {
                                dropdown("edition", caption: "教材版本", value: shortEdition(draft.selectedEdition), enabled: !draft.editions.isEmpty)
                                dropdown("book", caption: "课本", value: shortBook(draft.selectedPack.map(QuestionBankChoice.volumeTitle)), enabled: !draft.packs.isEmpty)
                                    .gridCellColumns(2)
                            }
                        }
                    }
                    unitsArea(compact: compact).frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                if let errorMessage {
                    Text(errorMessage).font(AppFont.label).foregroundStyle(Theme.wrong).lineLimit(2)
                }
                footer(compact: compact)
            }
            .padding(compact ? 12 : 18)
        }
        .background(GrowthPageBackground())
        .candyDropdownLayer(openID: $openMenu, items: menuItems)
        .interactiveDismissDisabled()
        #if os(macOS)
        .frame(minWidth: 640, idealWidth: 900, minHeight: 480, idealHeight: 700)
        #endif
    }

    private var header: some View {
        HStack(spacing: 12) {
            AppIconBadge(systemImage: "books.vertical.fill", tint: AppColor.jade, size: 38)
            Text(draft.isReview ? "选择复习题库" : "选择本局题库")
                .font(AppFont.title)
                .foregroundStyle(Theme.ink)
            Spacer()
            AppButton(title: "返回", systemImage: "chevron.left", role: .secondary, size: .medium, action: onCancel)
        }
    }

    @ViewBuilder private func unitsArea(compact: Bool) -> some View {
        if draft.isReview {
            VStack(alignment: .leading, spacing: 14) {
                Label("复习本年级、本学科所有题库中的错题", systemImage: "arrow.clockwise.circle.fill")
                    .font(AppFont.bodyStrong)
                    .foregroundStyle(Theme.ink)
                Text(draft.confirmedConfig() == nil ? "这个范围还没有需要复习的错题，请换一个学科或年级。" : "只出已进入错题本的知识点，不重复学习已掌握的内容。")
                    .font(AppFont.body)
                    .foregroundStyle(Theme.muted)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .candyCard()
        } else if let pack = draft.selectedPack {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Text("已选单元 \(draft.units.count) / \(pack.units.count)")
                        .font(AppFont.bodyStrong)
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    let allSelected = draft.units == draft.allUnitKeys
                    AppButton(title: "全选", role: .secondary, size: .small, minWidth: 72) {
                        draft.selectAllUnits()
                    }
                    .disabled(allSelected)
                    AppButton(title: "清空", role: .secondary, size: .small, minWidth: 72) {
                        draft.clearUnits()
                    }
                    .disabled(draft.units.isEmpty)
                }
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: compact ? 180 : 220), alignment: .top)], spacing: compact ? 8 : 12) {
                        ForEach(pack.units) { unit in
                            let key = QuestionBankChoice.unitKey(pack: pack, unit: unit)
                            QuestionUnitTile(title: unit.title, lessonCount: unit.lessons.count, selected: draft.units.contains(key), compact: compact) {
                                draft.toggleUnit(key)
                            }
                        }
                    }.padding(4)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollIndicators(.visible)
                .scrollIndicatorsFlash(onAppear: true)
            }
        } else {
            ContentUnavailableView("这个年级还没有题库", systemImage: "book.closed",
                                   description: Text("换一个年级或学科，或在家长设置中导入题库。"))
        }
    }

    private func footer(compact: Bool) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(draft.grade.displayName) · \(draft.subject.displayName) · \(draft.difficulty.displayName)")
                    .font(AppFont.bodyStrong)
                    .foregroundStyle(Theme.ink)
                Text(draft.isReview ? "错题复习" : draft.units.isEmpty ? "请至少选择一个单元" : draft.selectedPack.map { QuestionBankChoice.courseSummary(pack: $0, selectedUnits: draft.units) } ?? "暂无可用题库")
                    .font(AppFont.label)
                    .foregroundStyle(draft.units.isEmpty && !draft.isReview ? Theme.wrong : Theme.muted)
                    .lineLimit(1)
            }
            Spacer()
            AppButton(title: "确认题库", systemImage: "checkmark", role: .primary, size: compact ? .medium : .large, minWidth: 148) {
                if let config = draft.confirmedConfig() { onConfirm(config) }
            }
            .disabled(draft.confirmedConfig() == nil)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, compact ? 6 : 10)
        .candyCard(radius: AppRadius.md)
    }

    private func dropdown(_ id: String, caption: String, value: String, enabled: Bool = true) -> some View {
        CandyDropdownButton(id: id, caption: caption, value: value, enabled: enabled, openID: $openMenu)
    }

    @ViewBuilder private var bookSelectors: some View {
        if !draft.isReview {
            dropdown("edition", caption: "教材版本", value: shortEdition(draft.selectedEdition), enabled: !draft.editions.isEmpty)
            dropdown("book", caption: "课本", value: shortBook(draft.selectedPack.map(QuestionBankChoice.volumeTitle)), enabled: !draft.packs.isEmpty)
        }
    }

    /// 精简冗长教材前缀，避免窄栏截断
    private func shortEdition(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "暂无" }
        return raw
            .replacingOccurrences(of: "人民教育出版社（教育部审定）", with: "人教版（部编）")
            .replacingOccurrences(of: "人民教育出版社", with: "人教版")
    }

    private func shortBook(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "暂无" }
        return raw.replacingOccurrences(of: "义务教育教科书 ", with: "")
    }

    private func menuItems(_ id: String) -> [CandyMenuItem] {
        switch id {
        case "subject":
            return Subject.allCases.map { subject in
                CandyMenuItem(id: subject.rawValue, title: subject.displayName, selected: draft.subject == subject) { draft.selectSubject(subject) }
            }
        case "grade":
            return Grade.allCases.map { grade in
                CandyMenuItem(id: grade.rawValue, title: grade.displayName, selected: draft.grade == grade) { draft.selectGrade(grade) }
            }
        case "difficulty":
            return Difficulty.allCases.map { difficulty in
                CandyMenuItem(id: difficulty.rawValue, title: difficulty.displayName, selected: draft.difficulty == difficulty) { draft.selectDifficulty(difficulty) }
            }
        case "edition":
            return draft.editions.map { edition in
                CandyMenuItem(id: edition, title: edition, selected: draft.selectedEdition == edition) { draft.selectEdition(edition) }
            }
        case "book":
            return draft.packs.map { pack in
                CandyMenuItem(id: pack.id, title: QuestionBankChoice.volumeTitle(pack), selected: draft.selectedPack?.id == pack.id) { draft.selectPack(pack.id) }
            }
        default: return []
        }
    }
}

/// 轻盈清透的单元复选卡：暖白底 + 左侧 4pt 翡翠高亮条 + 打勾徽章（全选时不再压抑），选中/未选中尺寸恒定。
struct QuestionUnitTile: View {
    let title: String
    let lessonCount: Int
    let selected: Bool
    var compact = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: compact ? 8 : 12) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(selected ? AppColor.jade : AppColor.cardEdge.opacity(0.6))
                    .frame(width: 4)
                    .padding(.vertical, 6)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: compact ? 20 : 22, weight: .bold))
                    .foregroundStyle(selected ? AppColor.jade : AppColor.cardStroke)
                    .frame(width: compact ? 24 : 26)
                VStack(alignment: .leading, spacing: compact ? 2 : 4) {
                    Text(title)
                        .font(AppFont.rounded(compact ? 15 : 17, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                    Text("\(lessonCount) 课")
                        .font(AppFont.caption)
                        .foregroundStyle(selected ? AppColor.jadeEdge : Theme.muted)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, compact ? 10 : 14)
            .padding(.vertical, compact ? 6 : 12)
            .frame(maxWidth: .infinity)
            .frame(minHeight: compact ? 58 : 84, alignment: .leading)
            .background(
                CandyTileBackground(
                    selected: selected,
                    selectedFill: Color(red: 0.93, green: 0.985, blue: 0.955),
                    selectedEdge: AppColor.jade,
                    radius: AppRadius.md
                )
            )
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("\(title)，\(lessonCount)课，\(selected ? "已选择" : "未选择")")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
