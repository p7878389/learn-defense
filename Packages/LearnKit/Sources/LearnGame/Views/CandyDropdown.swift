import SwiftUI

/// 糖果风格的下拉菜单：按钮放在页面里，展开的菜单画在页面最上层（见 `candyDropdownLayer`），
/// 不会被滚动区域裁掉，也不会被下面的内容盖住；下面放不下时往上展开
struct CandyMenuItem: Identifiable {
    enum Style {
        /// 普通选项
        case option
        /// 分组标题（比如一册书），也能点
        case header
        /// 分组里的子项（比如单元），缩进显示
        case child
    }

    let id: String
    let title: String
    var detail: String?
    var selected = false
    var style: Style = .option
    /// 点完收起菜单；多选的单元点完不收，方便连着选
    var closesMenu = true
    var enabled = true
    let action: () -> Void

    var rowHeight: CGFloat { style == .header ? 42 : 50 }
}

/// 下拉按钮：上面一行小字说明是什么，下面一行是当前选中的值
struct CandyDropdownButton: View {
    let id: String
    let caption: String
    let value: String
    var enabled = true
    @Binding var openID: String?

    private var open: Bool { openID == id }

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) { openID = open ? nil : id }
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(caption)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(open ? .white.opacity(0.85) : Theme.muted)
                    Text(value)
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(open ? .white : (enabled ? Theme.ink : Theme.muted))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.down")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(open ? .white : Theme.accent)
                    .rotationEffect(.degrees(open ? 180 : 0))
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(CandyTileBackground(selected: open, radius: 18))
            .contentShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(PressableStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.6)
        .anchorPreference(key: CandyDropdownAnchors.self, value: .bounds) { [id: $0] }
        .accessibilityLabel("\(caption)：\(value)")
        .accessibilityHint("点一下展开选项")
    }
}

struct CandyDropdownAnchors: PreferenceKey {
    static let defaultValue: [String: Anchor<CGRect>] = [:]

    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

/// 展开的菜单
struct CandyMenuList: View {
    let items: [CandyMenuItem]
    let onClose: () -> Void

    static let spacing: CGFloat = 4
    static let padding: CGFloat = 8

    /// 菜单全部展开时的高度；超过可用高度时在菜单里滚动
    static func height(of items: [CandyMenuItem]) -> CGFloat {
        items.reduce(0) { $0 + $1.rowHeight } + CGFloat(max(0, items.count - 1)) * spacing + padding * 2
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Self.spacing) {
                ForEach(items) { row($0) }
            }
            .padding(Self.padding)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(GrowthColors.surface)
                .shadow(color: GrowthColors.cardEdge, radius: 0, x: 0, y: 5))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(GrowthColors.cardEdge, lineWidth: 2))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.12), radius: 14, x: 0, y: 8)
    }

    private func row(_ item: CandyMenuItem) -> some View {
        Button {
            item.action()
            if item.closesMenu { onClose() }
        } label: {
            HStack(spacing: 10) {
                if item.style != .header {
                    Image(systemName: item.selected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(item.selected ? Theme.jade : Theme.muted.opacity(0.4))
                }
                Text(item.title)
                    .font(.system(size: item.style == .header ? 16 : 19,
                                  weight: item.style == .header ? .heavy : .bold, design: .rounded))
                    .foregroundStyle(item.style == .header ? GrowthColors.orangeDark : (item.enabled ? Theme.ink : Theme.muted))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 8)
                if let detail = item.detail {
                    Text(detail)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
            }
            .padding(.leading, item.style == .child ? 34 : 14)
            .padding(.trailing, 14)
            .frame(maxWidth: .infinity, minHeight: item.rowHeight, maxHeight: item.rowHeight)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(item.style == .header ? GrowthColors.gold.opacity(0.15)
                          : (item.selected ? Theme.jade.opacity(0.14) : .clear)))
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(PressableStyle())
        .disabled(!item.enabled)
        .accessibilityAddTraits(item.selected ? .isSelected : [])
    }
}

extension View {
    /// 在这一层画出当前展开的下拉菜单。放在滚动区域外面，菜单就不会被裁掉；点菜单外面收起
    func candyDropdownLayer(openID: Binding<String?>, items: @escaping (String) -> [CandyMenuItem]) -> some View {
        overlayPreferenceValue(CandyDropdownAnchors.self) { anchors in
            GeometryReader { proxy in
                if let id = openID.wrappedValue, let anchor = anchors[id] {
                    let button = proxy[anchor]
                    let menu = items(id)
                    let width = max(button.width, 280)
                    let x = min(max(button.minX, 12), proxy.size.width - width - 12)
                    let below = proxy.size.height - button.maxY - 20
                    let above = button.minY - 20
                    let full = CandyMenuList.height(of: menu)
                    // 下面放得下、或者下面比上面宽敞时往下展开，否则往上
                    let down = full <= below || below >= above
                    let height = min(full, max(down ? below : above, 120))
                    ZStack(alignment: .topLeading) {
                        Color.black.opacity(0.001)
                            .onTapGesture { openID.wrappedValue = nil }
                        CandyMenuList(items: menu) { openID.wrappedValue = nil }
                            .frame(width: width, height: height)
                            .offset(x: x, y: down ? button.maxY + 10 : button.minY - 10 - height)
                            .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: down ? .top : .bottom)))
                    }
                }
            }
        }
    }
}
