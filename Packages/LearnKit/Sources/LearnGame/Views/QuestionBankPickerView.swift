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
            VStack(alignment: .leading, spacing: 12) {
                header
                if wide {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(spacing: 8) {
                            dropdown("subject", caption: "学科", value: draft.subject.displayName)
                            dropdown("grade", caption: "年级", value: draft.grade.displayName)
                            dropdown("difficulty", caption: "难度", value: draft.difficulty.displayName)
                            bookSelectors
                        }
                        .padding(10).candyCard(radius: 20)
                        .frame(width: geometry.size.width < 800 ? 220 : 250)
                        unitsArea(compact: compact).frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    Grid(horizontalSpacing: 10, verticalSpacing: 8) {
                        GridRow {
                            dropdown("subject", caption: "学科", value: draft.subject.displayName)
                            dropdown("grade", caption: "年级", value: draft.grade.displayName)
                            dropdown("difficulty", caption: "难度", value: draft.difficulty.displayName)
                        }
                        if !draft.isReview {
                            GridRow {
                                dropdown("edition", caption: "教材版本", value: draft.selectedEdition ?? "暂无", enabled: !draft.editions.isEmpty)
                                dropdown("book", caption: "课本", value: draft.selectedPack.map(QuestionBankChoice.volumeTitle) ?? "暂无", enabled: !draft.packs.isEmpty)
                                    .gridCellColumns(2)
                            }
                        }
                    }
                    unitsArea(compact: compact).frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                if let errorMessage { Text(errorMessage).foregroundStyle(Theme.wrong).font(.callout).lineLimit(2) }
                footer
            }
            .padding(16)
        }
        .background(GrowthPageBackground())
        .candyDropdownLayer(openID: $openMenu, items: menuItems)
        .interactiveDismissDisabled()
        #if os(macOS)
        .frame(minWidth: 640, idealWidth: 900, minHeight: 480, idealHeight: 700)
        #endif
    }

    private var header: some View {
            HStack {
                Label(draft.isReview ? "选择复习题库" : "选择本局题库", systemImage: "books.vertical.fill")
                    .font(.system(size: 24, weight: .heavy, design: .rounded)).foregroundStyle(Theme.ink)
                Spacer()
                Button(action: onCancel) {
                    CandyButtonLabel(title: "返回", icon: "←", fill: GrowthColors.surface, edge: GrowthColors.cardEdge,
                                     foreground: Theme.ink, font: .headline, height: 44)
                }.buttonStyle(PressableStyle())
            }
    }

    @ViewBuilder private func unitsArea(compact: Bool) -> some View {
            if draft.isReview {
                VStack(alignment: .leading, spacing: 14) {
                    Label("复习本年级、本学科所有题库中的错题", systemImage: "arrow.clockwise.book.fill").font(.headline)
                    Text(draft.confirmedConfig() == nil ? "这个范围还没有需要复习的错题，请换一个学科或年级。" : "只出已进入错题本的知识点，不重复学习已掌握的内容。")
                        .foregroundStyle(Theme.muted)
                }.padding(20).frame(maxWidth: .infinity, alignment: .leading).candyCard()
            } else if let pack = draft.selectedPack {
                VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("单元 \(draft.units.count)/\(pack.units.count)").font(.headline)
                    Spacer()
                    let allSelected = draft.units == draft.allUnitKeys
                    Button { draft.selectAllUnits() } label: {
                        CandyButtonLabel(title: "全选",
                                         fill: allSelected ? GrowthColors.disabledFill : GrowthColors.surface,
                                         edge: allSelected ? GrowthColors.disabledEdge : GrowthColors.cardEdge,
                                         foreground: allSelected ? Theme.muted : GrowthColors.jadeDark,
                                         font: .system(size: 14, weight: .heavy, design: .rounded),
                                         height: 32, minWidth: 64)
                    }
                    .disabled(allSelected)
                    Button { draft.clearUnits() } label: {
                        CandyButtonLabel(title: "清空",
                                         fill: draft.units.isEmpty ? GrowthColors.disabledFill : GrowthColors.surface,
                                         edge: draft.units.isEmpty ? GrowthColors.disabledEdge : GrowthColors.cardEdge,
                                         foreground: draft.units.isEmpty ? Theme.muted : Theme.ink,
                                         font: .system(size: 14, weight: .heavy, design: .rounded),
                                         height: 32, minWidth: 64)
                    }
                    .disabled(draft.units.isEmpty)
                }.buttonStyle(PressableStyle())
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

    private var footer: some View {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(draft.grade.displayName) · \(draft.subject.displayName) · \(draft.difficulty.displayName)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Text(draft.isReview ? "错题复习" : draft.units.isEmpty ? "请至少选择一个单元" : draft.selectedPack.map { QuestionBankChoice.courseSummary(pack: $0, selectedUnits: draft.units) } ?? "暂无可用题库")
                        .font(.caption).foregroundStyle(draft.units.isEmpty && !draft.isReview ? Theme.wrong : Theme.muted).lineLimit(1)
                }
                Spacer()
                Button { if let config = draft.confirmedConfig() { onConfirm(config) } } label: {
                    let ready = draft.confirmedConfig() != nil
                    CandyButtonLabel(title: "确认题库", icon: "✓",
                                     fill: ready ? Theme.jade : GrowthColors.disabledFill,
                                     edge: ready ? GrowthColors.jadeDark : GrowthColors.disabledEdge,
                                     foreground: ready ? .white : Theme.muted,
                                     font: .headline, height: 48)
                }
                .buttonStyle(PressableStyle()).disabled(draft.confirmedConfig() == nil)
            }
    }

    private func dropdown(_ id: String, caption: String, value: String, enabled: Bool = true) -> some View {
        CandyDropdownButton(id: id, caption: caption, value: value, enabled: enabled, openID: $openMenu)
    }

    @ViewBuilder private var bookSelectors: some View {
        if !draft.isReview {
            dropdown("edition", caption: "教材版本", value: draft.selectedEdition ?? "暂无", enabled: !draft.editions.isEmpty)
            dropdown("book", caption: "课本", value: draft.selectedPack.map(QuestionBankChoice.volumeTitle) ?? "暂无", enabled: !draft.packs.isEmpty)
        }
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

/// 复选卡片按内容增长，完整显示长标题；紧凑弹窗减少装饰占位，不裁切文字。
struct QuestionUnitTile: View {
    let title: String
    let lessonCount: Int
    let selected: Bool
    var compact = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: compact ? 8 : 12) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: compact ? 20 : 24, weight: .semibold)).foregroundStyle(selected ? Theme.jade : Theme.muted)
                    .frame(width: compact ? 24 : 28)
                VStack(alignment: .leading, spacing: compact ? 3 : 6) {
                    Text(title).font(.system(size: compact ? 15 : 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true).multilineTextAlignment(.leading)
                    Text("\(lessonCount) 课").font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, compact ? 12 : 16).padding(.vertical, compact ? 8 : 12)
            .frame(maxWidth: .infinity).frame(minHeight: compact ? 68 : 88, alignment: .leading)
            .background(CandyTileBackground(selected: selected, selectedFill: GrowthColors.jadeLight.opacity(0.25), selectedEdge: Theme.jade, radius: 18))
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("\(title)，\(lessonCount)课，\(selected ? "已选择" : "未选择")")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
