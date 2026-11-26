import SwiftUI

/// 糖果风格的下拉菜单：按钮放在页面里，展开的菜单画在页面最上层（见 `candyDropdownLayer`）
struct CandyMenuItem: Identifiable {
    enum Style {
        case option
        case header
        case child
    }

    let id: String
    let title: String
    var detail: String?
    var selected = false
    var style: Style = .option
    var closesMenu = true
    var enabled = true
    let action: () -> Void

    var rowHeight: CGFloat { style == .header ? 42 : 50 }
}

/// 下拉按钮：统一 AppFont 与多行自适应，防止教材名被生硬截断
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
            HStack(spacing: AppSpacing.xs) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(caption)
                        .font(AppFont.caption)
                        .foregroundStyle(open ? .white.opacity(0.88) : AppColor.muted)
                    Text(value)
                        .font(AppFont.rounded(18, weight: .heavy))
                        .foregroundStyle(open ? .white : (enabled ? AppColor.ink : AppColor.muted))
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: AppSpacing.xxs)
                Image(systemName: "chevron.down")
                    .font(AppFont.rounded(15, weight: .heavy))
                    .foregroundStyle(open ? .white : AppColor.jade)
                    .rotationEffect(.degrees(open ? 180 : 0))
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(CandyTileBackground(selected: open, selectedFill: AppColor.jade, selectedEdge: AppColor.jadeEdge, radius: AppRadius.md))
            .contentShape(RoundedRectangle(cornerRadius: AppRadius.md))
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
        .appPanel(radius: AppRadius.md)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .appShadow(.floating)
    }

    private func row(_ item: CandyMenuItem) -> some View {
        Button {
            item.action()
            if item.closesMenu { onClose() }
        } label: {
            HStack(spacing: 10) {
                if item.style != .header {
                    Image(systemName: item.selected ? "checkmark.circle.fill" : "circle")
                        .font(AppFont.rounded(19, weight: .bold))
                        .foregroundStyle(item.selected ? AppColor.jade : AppColor.muted.opacity(0.4))
                }
                Text(item.title)
                    .font(item.style == .header ? AppFont.body : AppFont.bodyStrong)
                    .foregroundStyle(item.style == .header ? AppColor.accentEdge : (item.enabled ? AppColor.ink : AppColor.muted))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: AppSpacing.xs)
                if let detail = item.detail {
                    Text(detail)
                        .font(AppFont.label)
                        .foregroundStyle(AppColor.muted)
                        .lineLimit(1)
                }
            }
            .padding(.leading, item.style == .child ? 34 : AppSpacing.sm)
            .padding(.trailing, AppSpacing.sm)
            .frame(maxWidth: .infinity, minHeight: item.rowHeight, maxHeight: item.rowHeight)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.sm)
                    .fill(item.style == .header ? AppColor.gold.opacity(0.16)
                          : (item.selected ? AppColor.jade.opacity(0.14) : .clear)))
            .contentShape(RoundedRectangle(cornerRadius: AppRadius.sm))
        }
        .buttonStyle(PressableStyle())
        .disabled(!item.enabled)
        .accessibilityAddTraits(item.selected ? .isSelected : [])
    }
}

extension View {
    func candyDropdownLayer(openID: Binding<String?>, items: @escaping (String) -> [CandyMenuItem]) -> some View {
        overlayPreferenceValue(CandyDropdownAnchors.self) { anchors in
            GeometryReader { proxy in
                if let id = openID.wrappedValue, let anchor = anchors[id] {
                    let button = proxy[anchor]
                    let menu = items(id)
                    let width = max(button.width, 300)
                    let x = min(max(button.minX, 12), proxy.size.width - width - 12)
                    let below = proxy.size.height - button.maxY - 20
                    let above = button.minY - 20
                    let full = CandyMenuList.height(of: menu)
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
