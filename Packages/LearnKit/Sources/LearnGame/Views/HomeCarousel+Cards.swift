import LearnCore
import SwiftUI

/// 白色圆形大「＋」
private struct PlusBubble: View {
    var size: CGFloat = 112

    var body: some View {
        Circle()
            .fill(.white)
            .overlay(Circle().stroke(Color(red: 1.0, green: 0.88, blue: 0.55), lineWidth: 4))
            .shadow(color: GrowthColors.gold, radius: 0, x: 0, y: 7)
            .shadow(color: GrowthColors.gold.opacity(0.5), radius: 14)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: "plus")
                    .font(.system(size: size * 0.42, weight: .black))
                    .foregroundStyle(Theme.accent))
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
                .padding(.top, 46)
            Text("添加小朋友")
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundStyle(Theme.ink)
                .scaleEffect(0.94 + 0.06 * f)
                .padding(.top, 22)
            Text("给新来的小守卫建一张卡")
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.muted)
                .padding(.top, 6)
            Spacer(minLength: 12)
            Button(action: onAdd) {
                CandyButtonLabel(title: "添加", icon: "＋", fill: Theme.accent, edge: GrowthColors.orangeDeep,
                                 font: .system(size: 30, weight: .black, design: .rounded), height: 70, minWidth: 340)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("添加小朋友")
            .scaleEffect(0.84 + 0.16 * f)
            .opacity(f)
            .allowsHitTesting(focused)
            .frame(height: 72)
            Text("请爸爸妈妈帮忙填写")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.muted.opacity(0.85))
                .padding(.top, 10)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 22)
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .modifier(HomeCardFrame(focused: focused, focus: f, tint: GrowthColors.gold, dashed: true))
        .overlay(alignment: .topTrailing) {
            HomeRibbon(text: "✨ 欢迎新队员", fill: GrowthColors.gold, edge: GrowthColors.goldDark)
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
            HStack(alignment: .bottom, spacing: 14) {
                placeholder(72)
                placeholder(92).overlay(alignment: .top) {
                    PictureView(emoji: "🌿", size: 30).offset(y: -18)
                }
                placeholder(72)
            }
            .padding(.top, 48)
            Text("还没有小守卫")
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundStyle(Theme.ink)
                .padding(.top, 28)
            Text("先给孩子建一张卡，\n就可以开始守护书本啦")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.top, 10)
            Spacer(minLength: 12)
            Button(action: onAdd) {
                CandyButtonLabel(title: "添加第一个小朋友", icon: "＋", fill: Theme.accent, edge: GrowthColors.orangeDeep,
                                 font: .system(size: 26, weight: .black, design: .rounded), height: 72, minWidth: 360)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PressableStyle())
            Text("💡 请爸爸妈妈帮忙填写名字和年级")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.muted.opacity(0.85))
                .padding(.top, 12)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 22)
        .frame(width: 420, height: height)
        .modifier(HomeCardFrame(focused: true))
        .overlay(alignment: .top) {
            HomeRibbon(text: "🌱 新守卫报到处", fill: GrowthColors.gold, edge: GrowthColors.goldDark).offset(y: -18)
        }
    }

    private func placeholder(_ size: CGFloat) -> some View {
        Circle()
            .fill(Color(red: 1.0, green: 0.96, blue: 0.86))
            .overlay(Circle().stroke(GrowthColors.gold, style: StrokeStyle(lineWidth: 3, dash: [7, 6])))
            .frame(width: size, height: size)
            .overlay(Text("?").font(.system(size: size * 0.4, weight: .black, design: .rounded)).foregroundStyle(GrowthColors.gold))
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
                                .font(.system(size: 11, weight: .black))
                                .foregroundStyle(selected ? .white : GrowthColors.orangeDark)
                                .frame(width: selected ? 34 : 20, height: 20)
                                .background(
                                    Capsule()
                                        .fill(selected ? Theme.accent : GrowthColors.gold.opacity(0.18))
                                        .shadow(color: selected ? GrowthColors.orangeDeep.opacity(0.45) : .clear, radius: 4, y: 2)
                                )
                                .overlay(
                                    Capsule().stroke(
                                        selected ? .white.opacity(0.8) : GrowthColors.gold.opacity(0.8),
                                        style: StrokeStyle(lineWidth: 1.5, dash: selected ? [] : [3, 2])
                                    )
                                )
                        } else {
                            Capsule()
                                .fill(
                                    selected
                                        ? LinearGradient(colors: [GrowthColors.gold, Theme.accent], startPoint: .leading, endPoint: .trailing)
                                        : LinearGradient(colors: [GrowthColors.cardEdge, GrowthColors.cardEdge], startPoint: .leading, endPoint: .trailing)
                                )
                                .frame(width: selected ? 34 : 11, height: 11)
                                .shadow(color: selected ? Theme.accent.opacity(0.45) : .clear, radius: 4, y: 2)
                        }
                    }
                    .frame(minWidth: 24, minHeight: 32)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(.white.opacity(0.82))
                .shadow(color: GrowthColors.cardEdge.opacity(0.7), radius: 0, x: 0, y: 2)
        )
        .overlay(Capsule().stroke(GrowthColors.cardEdge.opacity(0.8), lineWidth: 1.5))
        .animation(.spring(response: 0.36, dampingFraction: 0.78), value: current)
    }
}
