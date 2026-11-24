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
    let height: CGFloat
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            PlusBubble().padding(.top, 48)
            Text("添加小朋友")
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundStyle(Theme.ink)
                .padding(.top, 24)
            Text("给新来的小守卫建一张卡")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.muted)
                .padding(.top, 6)
            Spacer(minLength: 12)
            if focused {
                Button(action: onAdd) {
                    CandyButtonLabel(title: "添加", icon: "＋", fill: Theme.accent, edge: GrowthColors.orangeDeep,
                                     font: .system(size: 30, weight: .black, design: .rounded), height: 72, minWidth: 340)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("添加小朋友")
            } else {
                Color.clear.frame(height: 72)
            }
            Text("请爸爸妈妈帮忙填写")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.muted.opacity(0.85))
                .padding(.top, 12)
        }
        .padding(.horizontal, 26)
        .padding(.bottom, 22)
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .modifier(HomeCardFrame(focused: false, dashed: true))
        .overlay(alignment: .topTrailing) {
            HomeRibbon(text: "✨ 欢迎新队员", fill: GrowthColors.gold, edge: GrowthColors.goldDark)
                .offset(x: 14, y: -18)
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

/// 轮播两侧的「‹ ›」按钮，给还不会滑动的小朋友点
struct CarouselArrow: View {
    let left: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: left ? "chevron.left" : "chevron.right")
                .font(.system(size: 26, weight: .black))
                .foregroundStyle(GrowthColors.orangeDark)
                .frame(width: 64, height: 64)
                .background(Circle().fill(.white.opacity(0.95)).shadow(color: GrowthColors.cardEdge, radius: 0, x: 0, y: 5))
                .overlay(Circle().stroke(GrowthColors.cardEdge, lineWidth: 2))
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(left ? "上一个小朋友" : "下一个小朋友")
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
                                .font(.system(size: 10, weight: .black))
                                .foregroundStyle(selected ? .white : Theme.muted)
                                .frame(width: selected ? 30 : 18, height: 18)
                                .background(Capsule().fill(selected ? Theme.accent : .clear))
                                .overlay(Capsule().stroke(selected ? .clear : Theme.muted.opacity(0.6),
                                                          style: StrokeStyle(lineWidth: 1.5, dash: [3, 2])))
                        } else {
                            Capsule()
                                .fill(selected ? Theme.accent : Theme.muted.opacity(0.35))
                                .frame(width: selected ? 30 : 11, height: 11)
                        }
                    }
                    .frame(minWidth: 24, minHeight: 32)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 14)
        .background(Capsule().fill(.white.opacity(0.7)))
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: current)
    }
}
