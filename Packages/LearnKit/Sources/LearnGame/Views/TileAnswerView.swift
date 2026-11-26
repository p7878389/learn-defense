import LearnCore
import SwiftUI

/// 字块题的作答区：象牙拼字麻将块手感 + 内凹暖木填空槽。
struct TileAnswerView: View {
    let spec: InputSpec
    let wrongCount: Int
    let compact: Bool
    let onStart: () -> Void
    let onSubmit: ([String]) -> Void

    @State private var placed: [TileRef?]
    @State private var shakes = 0

    struct TileRef: Hashable {
        let group: Int
        let index: Int
    }

    init(spec: InputSpec, wrongCount: Int, compact: Bool = false,
         onStart: @escaping () -> Void, onSubmit: @escaping ([String]) -> Void) {
        self.spec = spec
        self.wrongCount = wrongCount
        self.compact = compact
        self.onStart = onStart
        self.onSubmit = onSubmit
        _placed = State(initialValue: Array(repeating: nil, count: spec.blanks.count))
    }

    var body: some View {
        VStack(spacing: compact ? 6 : 12) {
            slots
            feedback
            tiles
        }
        .offset(x: shakes % 2 == 0 ? 0 : 10)
        .animation(.spring(response: 0.12, dampingFraction: 0.25), value: shakes)
        .onChange(of: wrongCount) { _, _ in
            shakes += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { shakes += 1 }
            placed = Array(repeating: nil, count: spec.blanks.count)
        }
    }

    // MARK: 空格

    private var slots: some View {
        HStack(spacing: spec.style == .letters ? 4 : 8) {
            if let template = spec.template {
                let parts = template.components(separatedBy: "□")
                ForEach(parts.indices, id: \.self) { i in
                    if !parts[i].isEmpty {
                        Text(parts[i]).font(AppFont.rounded(32, weight: .heavy)).foregroundStyle(Theme.ink)
                    }
                    if i < parts.count - 1, i < spec.blanks.count { slot(i) }
                }
            } else {
                ForEach(spec.blanks.indices, id: \.self) { i in
                    if spec.style == .pinyin, i > 0 {
                        Text("+").font(AppFont.rounded(26, weight: .heavy)).foregroundStyle(Theme.muted)
                    }
                    slot(i)
                }
                if spec.style == .pinyin, filled {
                    Text("= \(spec.compose(texts))")
                        .font(AppFont.rounded(32, weight: .black)).foregroundStyle(Theme.jade)
                }
            }
        }
        .lineLimit(1).minimumScaleFactor(0.5)
    }

    private func slot(_ i: Int) -> some View {
        let text = placed[i].map(tileText)
        let isNext = placed.firstIndex(where: { $0 == nil }) == i
        let shape = RoundedRectangle(cornerRadius: AppRadius.sm)
        return Button { placed[i] = nil } label: {
            Text(text ?? (spec.style == .pinyin ? spec.groups[spec.blanks[i].group].title ?? "?" : " "))
                .font(AppFont.rounded(text == nil && spec.style == .pinyin ? 16 : 30, weight: .heavy))
                .foregroundStyle(text == nil ? (isNext ? AppColor.accentEdge : Theme.muted.opacity(0.6)) : Theme.ink)
                .frame(minWidth: slotWidth, minHeight: 56)
                .padding(.horizontal, 4)
                .padding(.bottom, text != nil ? 3 : 0)
                .background {
                    if text != nil {
                        ZStack {
                            shape.fill(AppColor.jadeEdge)
                            shape.fill(LinearGradient(colors: [AppColor.surface, AppColor.surfaceBottom], startPoint: .top, endPoint: .bottom))
                                .overlay(shape.strokeBorder(AppColor.jade, lineWidth: 2))
                                .padding(.bottom, 3)
                        }
                    } else {
                        shape.fill(isNext ? AppColor.gold.opacity(0.18) : Color.white.opacity(0.65))
                            .overlay(
                                shape.strokeBorder(
                                    isNext ? AppColor.accent : AppColor.cardStroke,
                                    style: StrokeStyle(lineWidth: isNext ? 2.5 : 1.8, dash: [6, 4])
                                )
                            )
                    }
                }
        }
        .buttonStyle(.plain)
        .disabled(text == nil)
        .accessibilityLabel(text.map { "第 \(i + 1) 个空：\($0)，点一下退回" } ?? "第 \(i + 1) 个空")
    }

    private var slotWidth: CGFloat {
        switch spec.style {
        case .letters: 46
        case .words: 110
        case .hanzi, .pinyin: 58
        }
    }

    // MARK: 象牙麻将字块

    private var tiles: some View {
        HStack(spacing: 10) {
            ForEach(spec.groups.indices, id: \.self) { g in
                if g > 0 {
                    RoundedRectangle(cornerRadius: 1).fill(AppColor.cardEdge).frame(width: 2, height: 44)
                }
                ForEach(spec.groups[g].tiles.indices, id: \.self) { i in
                    tile(TileRef(group: g, index: i))
                }
            }
        }
        .lineLimit(1).minimumScaleFactor(0.6)
    }

    private func tile(_ ref: TileRef) -> some View {
        let used = placed.contains(ref)
        let shape = RoundedRectangle(cornerRadius: AppRadius.sm)
        return Button { place(ref) } label: {
            Text(tileText(ref))
                .font(AppFont.rounded(spec.style == .words ? 24 : 30, weight: .heavy))
                .foregroundStyle(used ? AppColor.disabledText.opacity(0.6) : Theme.ink)
                .frame(minWidth: 58, minHeight: used ? 58 : 54)
                .padding(.horizontal, spec.style == .words ? 10 : 2)
                .padding(.bottom, used ? 0 : 4)
                .background {
                    ZStack {
                        if !used {
                            shape.fill(AppColor.accent.opacity(0.75))
                                .shadow(color: AppColor.warmShadow.opacity(0.12), radius: 5, y: 3)
                        }
                        shape
                            .fill(
                                used
                                    ? LinearGradient(colors: [AppColor.disabledFill, AppColor.disabledFill], startPoint: .top, endPoint: .bottom)
                                    : LinearGradient(colors: [.white, GrowthColors.tileFill], startPoint: .top, endPoint: .bottom)
                            )
                            .overlay(shape.strokeBorder(.white.opacity(used ? 0.2 : 0.85), lineWidth: 1.4))
                            .overlay(shape.strokeBorder(used ? AppColor.disabledEdge : AppColor.accent.opacity(0.68), lineWidth: 1.8))
                            .padding(.bottom, used ? 0 : 4)
                    }
                }
        }
        .buttonStyle(PressableStyle())
        .disabled(used)
    }

    // MARK: 提示

    @ViewBuilder
    private var feedback: some View {
        if wrongCount > 0 {
            Text("不对哦，再拼一次")
                .font(AppFont.bodyStrong).foregroundStyle(Theme.wrong)
        }
    }

    // MARK: 操作

    private var texts: [String] { placed.map { $0.map(tileText) ?? "" } }
    private var filled: Bool { !placed.contains(nil) }

    private func tileText(_ ref: TileRef) -> String { spec.groups[ref.group].tiles[ref.index] }

    private func place(_ ref: TileRef) {
        let slotsOfGroup = spec.blanks.indices.filter { spec.blanks[$0].group == ref.group }
        guard let k = slotsOfGroup.first(where: { placed[$0] == nil }) ?? (slotsOfGroup.count == 1 ? slotsOfGroup.first : nil) else { return }
        if placed.allSatisfy({ $0 == nil }) { onStart() }
        placed[k] = ref
        if filled { onSubmit(texts) }
    }
}
