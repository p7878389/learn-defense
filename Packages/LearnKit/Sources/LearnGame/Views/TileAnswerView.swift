import LearnCore
import SwiftUI

/// 字块题的作答区：上面一排空格，下面一排大字块。点字块放进下一个空位，点空格把字块退回；
/// 拼满自动交卷，答错清空重来。答错两次显示提示，三次把正确的字块按顺序高亮，照着点就能出击
struct TileAnswerView: View {
    let spec: InputSpec
    /// 这道题已经答错几次
    let wrongCount: Int
    let onStart: () -> Void
    let onSubmit: ([String]) -> Void

    /// 每个空放的是哪一块（组号、块号）
    @State private var placed: [TileRef?]
    @State private var shakes = 0

    struct TileRef: Hashable {
        let group: Int
        let index: Int
    }

    init(spec: InputSpec, wrongCount: Int, onStart: @escaping () -> Void, onSubmit: @escaping ([String]) -> Void) {
        self.spec = spec
        self.wrongCount = wrongCount
        self.onStart = onStart
        self.onSubmit = onSubmit
        _placed = State(initialValue: Array(repeating: nil, count: spec.blanks.count))
    }

    var body: some View {
        VStack(spacing: 12) {
            slots
            feedback
            tiles
        }
        .offset(x: shakes % 2 == 0 ? 0 : 10)
        .animation(.spring(response: 0.12, dampingFraction: 0.25), value: shakes)
        .onChange(of: wrongCount) { _, _ in
            shakes += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { shakes += 1 }
            // 答错：清空重来
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
                        Text(parts[i]).font(.system(size: 32, weight: .bold, design: .rounded)).foregroundStyle(Theme.ink)
                    }
                    if i < parts.count - 1, i < spec.blanks.count { slot(i) }
                }
            } else {
                ForEach(spec.blanks.indices, id: \.self) { i in
                    // 拼音的声母、韵母、声调之间加个「+」，孩子知道是拼起来的
                    if spec.style == .pinyin, i > 0 {
                        Text("+").font(.system(size: 26, weight: .bold, design: .rounded)).foregroundStyle(Theme.muted)
                    }
                    slot(i)
                }
                if spec.style == .pinyin, filled {
                    Text("= \(spec.compose(texts))")
                        .font(.system(size: 32, weight: .heavy, design: .rounded)).foregroundStyle(Theme.jade)
                }
            }
        }
        .lineLimit(1).minimumScaleFactor(0.5)
    }

    private func slot(_ i: Int) -> some View {
        let text = placed[i].map(tileText)
        let isNext = placed.firstIndex(where: { $0 == nil }) == i
        return Button { placed[i] = nil } label: {
            Text(text ?? (spec.style == .pinyin ? spec.groups[spec.blanks[i].group].title ?? "?" : " "))
                .font(.system(size: text == nil && spec.style == .pinyin ? 16 : 30, weight: .bold, design: .rounded))
                .foregroundStyle(text == nil ? Theme.muted.opacity(0.6) : Theme.ink)
                .frame(minWidth: slotWidth, minHeight: 58)
                .padding(.horizontal, 4)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(isNext ? Theme.accent : Theme.muted.opacity(0.4),
                                                                   style: StrokeStyle(lineWidth: isNext ? 3 : 2, dash: text == nil ? [6, 4] : [])))
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

    // MARK: 字块

    private var tiles: some View {
        HStack(spacing: 10) {
            ForEach(spec.groups.indices, id: \.self) { g in
                if g > 0 { Rectangle().fill(Theme.muted.opacity(0.35)).frame(width: 2, height: 46) }
                ForEach(spec.groups[g].tiles.indices, id: \.self) { i in
                    tile(TileRef(group: g, index: i))
                }
            }
        }
        .lineLimit(1).minimumScaleFactor(0.6)
    }

    private func tile(_ ref: TileRef) -> some View {
        let used = placed.contains(ref)
        let glow = revealNext == ref
        return Button { place(ref) } label: {
            Text(tileText(ref))
                .font(.system(size: spec.style == .words ? 24 : 30, weight: .bold, design: .rounded))
                .foregroundStyle(used ? Theme.muted.opacity(0.4) : Theme.ink)
                .frame(minWidth: 58, minHeight: 58)
                .padding(.horizontal, spec.style == .words ? 10 : 2)
                .background(RoundedRectangle(cornerRadius: 14).fill(used ? Color(white: 0.9) : Color(red: 1, green: 0.97, blue: 0.86))
                    .shadow(color: .black.opacity(used ? 0 : 0.18), radius: 0, y: 4))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(glow ? Theme.wrong : Theme.accent.opacity(0.5), lineWidth: glow ? 4 : 2))
                .scaleEffect(glow ? 1.08 : 1)
        }
        .buttonStyle(PressableStyle())
        .disabled(used)
    }

    // MARK: 提示

    @ViewBuilder
    private var feedback: some View {
        if wrongCount >= 3 {
            Text("答案是「\(spec.answerText)」，照着亮起来的字块点一遍！")
                .font(.system(size: 18, weight: .heavy, design: .rounded)).foregroundStyle(Theme.wrong)
        } else if wrongCount == 2 {
            Text("💡 提示：\(spec.hint)")
                .font(.system(size: 18, weight: .heavy, design: .rounded)).foregroundStyle(Theme.accent)
        } else if wrongCount == 1 {
            Text("不对哦，再拼一次")
                .font(.system(size: 18, weight: .bold, design: .rounded)).foregroundStyle(Theme.wrong)
        }
    }

    // MARK: 操作

    private var texts: [String] { placed.map { $0.map(tileText) ?? "" } }
    private var filled: Bool { !placed.contains(nil) }

    private func tileText(_ ref: TileRef) -> String { spec.groups[ref.group].tiles[ref.index] }

    /// 揭晓答案后，下一块该点哪一块
    private var revealNext: TileRef? {
        guard wrongCount >= 3, let k = placed.firstIndex(where: { $0 == nil }) else { return nil }
        let blank = spec.blanks[k]
        return spec.groups[blank.group].tiles.indices
            .map { TileRef(group: blank.group, index: $0) }
            .first { tileText($0) == blank.answer && !placed.contains($0) }
    }

    private func place(_ ref: TileRef) {
        // 放进这一组的下一个空位；这组只有一个空（拼音）时直接替换
        let slotsOfGroup = spec.blanks.indices.filter { spec.blanks[$0].group == ref.group }
        guard let k = slotsOfGroup.first(where: { placed[$0] == nil }) ?? (slotsOfGroup.count == 1 ? slotsOfGroup.first : nil) else { return }
        if placed.allSatisfy({ $0 == nil }) { onStart() }
        placed[k] = ref
        if filled { onSubmit(texts) }
    }
}
