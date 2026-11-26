import LearnCore
import SwiftUI

/// 白色圆形大「＋」
private struct PlusBubble: View {
    var size: CGFloat = 112

    var body: some View {
        Circle()
            .fill(.white)
            .overlay(Circle().stroke(AppColor.goldLight, lineWidth: 4))
            .shadow(color: AppColor.gold, radius: 0, x: 0, y: 7)
            .shadow(color: AppColor.gold.opacity(0.5), radius: 14)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: "plus")
                    .font(AppFont.rounded(size * 0.42, weight: .black))
                    .foregroundStyle(AppColor.accent))
            .accessibilityHidden(true)
    }
}

/// 轮播最后一张：添加小朋友
struct HomeAddCard: View {
    let focused: Bool
    var focus: Double? = nil
    let height: CGFloat
    let onAdd: () -> Void

    private var f: Double { focus ?? (focused ? 1.0 : 0.0) }

    var body: some View {
        VStack(spacing: 0) {
            PlusBubble()
                .scaleEffect(0.90 + 0.16 * f)
                .offset(y: 3 - 6 * f)
                .padding(.top, AppSpacing.xxl)
            Text("添加小朋友")
                .font(AppFont.display)
                .foregroundStyle(AppColor.ink)
                .scaleEffect(0.94 + 0.06 * f)
                .padding(.top, AppSpacing.lg)
            Text("给新来的小守卫建一张卡")
                .font(AppFont.rounded(19, weight: .bold))
                .foregroundStyle(AppColor.muted)
                .padding(.top, 6)
            Spacer(minLength: AppSpacing.sm)
            Button(action: onAdd) {
                CandyButtonLabel(title: "添加", icon: "＋", fill: AppColor.accent, edge: AppColor.accentEdge,
                                 font: AppFont.rounded(30, weight: .black), height: 70, minWidth: 340)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("添加小朋友")
            .scaleEffect(0.84 + 0.16 * f)
            .opacity(f)
            .allowsHitTesting(focused)
            .frame(height: 72)
            Text("请爸爸妈妈帮忙填写")
                .font(AppFont.rounded(15, weight: .semibold))
                .foregroundStyle(AppColor.muted.opacity(0.85))
                .padding(.top, 10)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.bottom, AppSpacing.lg)
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .modifier(HomeCardFrame(focused: focused, focus: f, tint: AppColor.gold, dashed: true))
        .overlay(alignment: .topTrailing) {
            HomeRibbon(text: "✨ 欢迎新队员", fill: AppColor.gold, edge: AppColor.goldEdge)
                .scaleEffect(0.88 + 0.12 * f)
                .rotationEffect(.degrees(2.0 * f))
                .offset(x: 14, y: -13 - 6 * f)
        }
    }
}

/// 一个孩子都没有时的欢迎卡（第一次打开）
struct HomeEmptyCard: View {
    let height: CGFloat
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: AppSpacing.sm) {
                placeholder(72)
                placeholder(92).overlay(alignment: .top) {
                    PictureView(emoji: "🌿", size: 30).offset(y: -18)
                }
                placeholder(72)
            }
            .padding(.top, AppSpacing.xxl)
            Text("还没有小守卫")
                .font(AppFont.display)
                .foregroundStyle(AppColor.ink)
                .padding(.top, AppSpacing.lg)
            Text("先给孩子建一张卡，\n就可以开始守护书本啦")
                .font(AppFont.rounded(20, weight: .bold))
                .foregroundStyle(AppColor.muted)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.top, 10)
            Spacer(minLength: AppSpacing.sm)
            Button(action: onAdd) {
                CandyButtonLabel(title: "添加第一个小朋友", icon: "＋", fill: AppColor.accent, edge: AppColor.accentEdge,
                                 font: AppFont.rounded(26, weight: .black), height: 72, minWidth: 360)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PressableStyle())
            Text("💡 请爸爸妈妈帮忙填写名字和年级")
                .font(AppFont.body)
                .foregroundStyle(AppColor.muted.opacity(0.85))
                .padding(.top, AppSpacing.sm)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.bottom, AppSpacing.lg)
        .frame(width: 420, height: height)
        .modifier(HomeCardFrame(focused: true))
        .overlay(alignment: .top) {
            HomeRibbon(text: "🌱 新守卫报到处", fill: AppColor.gold, edge: AppColor.goldEdge).offset(y: -18)
        }
    }

    private func placeholder(_ size: CGFloat) -> some View {
        Circle()
            .fill(AppColor.answerTray)
            .overlay(Circle().stroke(AppColor.gold, style: StrokeStyle(lineWidth: 3, dash: [7, 6])))
            .frame(width: size, height: size)
            .overlay(Text("?").font(AppFont.rounded(size * 0.4, weight: .black)).foregroundStyle(AppColor.gold))
            .accessibilityHidden(true)
    }
}

/// 分页点：一个孩子一个点，最后一个是「＋」；当前那个拉长成橙色胶囊。点圆点也能跳过去
struct CarouselPager: View {
    let cards: [HomeCardID]
    let current: HomeCardID?
    let onSelect: (HomeCardID) -> Void

    var body: some View {
        HStack(spacing: 10) {
            ForEach(cards, id: \.self) { card in
                let selected = card == current
                Button { onSelect(card) } label: {
                    Group {
                        if card == .add {
                            Image(systemName: "plus")
                                .font(AppFont.rounded(11, weight: .black))
                                .foregroundStyle(selected ? .white : AppColor.accentEdge)
                                .frame(width: selected ? 34 : 20, height: 20)
                                .background(
                                    Capsule()
                                        .fill(selected ? AppColor.accent : AppColor.gold.opacity(0.18))
                                        .shadow(color: selected ? AppColor.accentEdge.opacity(0.45) : .clear, radius: 4, y: 2)
                                )
                                .overlay(
                                    Capsule().stroke(
                                        selected ? .white.opacity(0.8) : AppColor.gold.opacity(0.8),
                                        style: StrokeStyle(lineWidth: 1.5, dash: selected ? [] : [3, 2])
                                    )
                                )
                        } else {
                            Capsule()
                                .fill(
                                    selected
                                        ? LinearGradient(colors: [AppColor.gold, AppColor.accent], startPoint: .leading, endPoint: .trailing)
                                        : LinearGradient(colors: [AppColor.cardEdge, AppColor.cardEdge], startPoint: .leading, endPoint: .trailing)
                                )
                                .frame(width: selected ? 34 : 11, height: 11)
                                .shadow(color: selected ? AppColor.accent.opacity(0.45) : .clear, radius: 4, y: 2)
                        }
                    }
                    .frame(minWidth: 24, minHeight: 32)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(.white.opacity(0.82))
                .shadow(color: AppColor.cardEdge.opacity(0.7), radius: 0, x: 0, y: 2)
        )
        .overlay(Capsule().stroke(AppColor.cardEdge.opacity(0.8), lineWidth: 1.5))
        .animation(.spring(response: 0.36, dampingFraction: 0.78), value: current)
    }
}
