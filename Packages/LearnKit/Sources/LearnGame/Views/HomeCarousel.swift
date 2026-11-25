import LearnCore
import SwiftUI

// 首页（选择孩子）的组件：标题、孩子卡、添加卡、空状态卡、分页点、底部草坪。设计稿见 docs/ui-home（05~07）

/// 轮播里的一张卡：一个孩子，或者最后的「添加小朋友」
enum HomeCardID: Hashable {
    case profile(UUID)
    case add
}

/// 卡片上要显示的孩子信息：档案 + 等级、闯关次数、游玩概况
struct HomeProfileSummary {
    var profile: Profile
    var level: Int
    var gamesPlayed: Int
    var activity: PlayActivity
    /// 轮播第一张且玩过：显示「上次是你」
    var isLastPlayed: Bool

    /// 从没玩过（老档案只有成长统计、没有对局记录时也算玩过）
    var isNew: Bool { activity.lastPlayedAt == nil && gamesPlayed == 0 }
}

/// 头像底座的颜色，按头像区分，让每个孩子的卡一眼能认出来
enum AvatarTint {
    static func color(for avatar: String) -> Color {
        switch avatar {
        case "🐯": Color(red: 1.0, green: 0.86, blue: 0.55)
        case "🐼": Color(red: 0.78, green: 0.93, blue: 0.85)
        case "🦊": Color(red: 1.0, green: 0.82, blue: 0.66)
        case "🐰": Color(red: 0.99, green: 0.84, blue: 0.9)
        case "🐨": Color(red: 0.84, green: 0.87, blue: 0.93)
        case "🦁": Color(red: 1.0, green: 0.9, blue: 0.6)
        case "🐸": Color(red: 0.8, green: 0.93, blue: 0.7)
        case "🐧": Color(red: 0.8, green: 0.9, blue: 1.0)
        case "🦄": Color(red: 0.9, green: 0.84, blue: 1.0)
        case "🐳": Color(red: 0.76, green: 0.88, blue: 1.0)
        default: GrowthColors.surface
        }
    }
}

/// 橙色描边大字「字灵守卫」
struct GameLogo: View {
    var size: CGFloat = 52

    var body: some View {
        let text = Text("字灵守卫").font(.system(size: size, weight: .black, design: .rounded))
        let outline = size * 0.06
        ZStack {
            // 白色描边：在八个方向各垫一层
            ForEach(0..<8, id: \.self) { i in
                let angle = Double(i) * .pi / 4
                text.foregroundStyle(.white)
                    .offset(x: cos(angle) * outline, y: sin(angle) * outline)
            }
            text.foregroundStyle(Theme.accent)
        }
        .shadow(color: GrowthColors.orangeDeep, radius: 0, x: 0, y: size * 0.1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("字灵守卫")
        .accessibilityAddTraits(.isHeader)
    }
}

/// 卡片顶部的立体渐变角标，如「👑 上次是你」「🌱 新伙伴」
struct HomeRibbon: View {
    let text: String
    var fill: Color = Theme.accent
    var edge: Color = GrowthColors.orangeDeep

    var body: some View {
        Text(text)
            .font(.system(size: 17, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .frame(height: 36)
            .background(
                Capsule()
                    .fill(LinearGradient(colors: [fill.opacity(0.9), fill, edge], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: edge, radius: 0, x: 0, y: 3)
                    .shadow(color: edge.opacity(0.35), radius: 6, y: 4)
            )
            .overlay(Capsule().stroke(.white, lineWidth: 3))
    }
}

/// 一行状态糖果小药丸
private struct StatPill: View {
    let text: String
    var tint: Color = GrowthColors.orangeDark
    var fill: Color = Color(red: 1.0, green: 0.97, blue: 0.90)
    var border: Color = Color(red: 0.98, green: 0.85, blue: 0.58)

    var body: some View {
        Text(text)
            .font(.system(size: 17, weight: .black, design: .rounded))
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, minHeight: 42)
            .background(RoundedRectangle(cornerRadius: 15).fill(fill).shadow(color: border.opacity(0.75), radius: 0, x: 0, y: 2))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(border, lineWidth: 1.5))
    }
}

/// 角色卡片立体糖果外框：顶部主题色柔和穹顶渐变 + 晶莹内高光 + 连续 focus 驱动的金色描边与厚底
struct HomeCardFrame: ViewModifier {
    var focused: Bool
    var focus: Double? = nil
    var tint: Color = GrowthColors.gold
    var dashed = false

    private var f: Double { focus ?? (focused ? 1.0 : 0.0) }

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 36)
        content
            .background(
                ZStack(alignment: .top) {
                    shape.fill(dashed ? Color(red: 1.0, green: 0.985, blue: 0.95) : .white)
                        .shadow(color: f > 0.5 ? GrowthColors.orangeDark : GrowthColors.cardEdge, radius: 0, x: 0, y: 6 + 6 * f)
                        .shadow(color: GrowthColors.orangeDark.opacity(0.08 + 0.22 * f), radius: 14 + 14 * f, y: 10 + 10 * f)
                    // 卡片顶部柔和角色主题色穹顶内渐变（还原设计稿 05）
                    LinearGradient(colors: [tint.opacity(0.14 + 0.24 * f), tint.opacity(0.05 * f), .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: 165)
                        .clipShape(RoundedRectangle(cornerRadius: 33))
                        .padding(3)
                }
            )
            .overlay(RoundedRectangle(cornerRadius: 33).inset(by: 3).stroke(.white.opacity(0.9), lineWidth: 1.5))
            .overlay(shape.stroke(f > 0.45 ? GrowthColors.gold : GrowthColors.cardEdge,
                                  style: StrokeStyle(lineWidth: 3 + 2 * f, dash: dashed ? [12, 8] : [])))
    }
}

/// 轮播里的孩子卡：所有视觉层次由连续 focus（0~1）实时插值驱动，聚焦时头像轻柔呼吸浮动
struct HomeProfileCard: View {
    let summary: HomeProfileSummary
    let focused: Bool
    var focus: Double? = nil
    let height: CGFloat
    let onEdit: () -> Void

    @State private var floating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var profile: Profile { summary.profile }
    private var f: Double { focus ?? (focused ? 1.0 : 0.0) }
    private var tint: Color { AvatarTint.color(for: profile.avatar) }

    var body: some View {
        VStack(spacing: 0) {
            avatarStage
                .padding(.top, 28)

            Text(profile.name)
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .scaleEffect(0.94 + 0.06 * f)
                .padding(.top, 4)

            Text(profile.grade.displayName)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(GrowthColors.orangeDark)
                .padding(.horizontal, 18)
                .frame(height: 30)
                .background(
                    Capsule()
                        .fill(Color(red: 1.0, green: 0.94, blue: 0.80))
                        .shadow(color: GrowthColors.gold.opacity(0.45), radius: 0, x: 0, y: 2)
                )
                .overlay(Capsule().stroke(GrowthColors.gold.opacity(0.85), lineWidth: 1.5))
                .scaleEffect(0.94 + 0.06 * f)
                .padding(.top, 2)

            Spacer(minLength: 10)

            HStack(spacing: 10) {
                StatPill(
                    text: streakText,
                    tint: summary.activity.streakDays > 0 ? Color(red: 0.82, green: 0.32, blue: 0.08) : Theme.muted,
                    fill: Color(red: 1.0, green: 0.96, blue: 0.91),
                    border: Color(red: 0.98, green: 0.83, blue: 0.65)
                )
                StatPill(
                    text: "⭐ 闯关 \(summary.gamesPlayed) 次",
                    tint: Color(red: 0.58, green: 0.34, blue: 0.04),
                    fill: Color(red: 1.0, green: 0.97, blue: 0.88),
                    border: Color(red: 0.96, green: 0.84, blue: 0.52)
                )
            }

            Spacer(minLength: 12)

            actionArea
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .modifier(HomeCardFrame(focused: focused, focus: f, tint: tint))
        .overlay(alignment: .top) {
            if summary.isLastPlayed {
                HomeRibbon(text: "👑 上次是你")
                    .scaleEffect(0.88 + 0.12 * f)
                    .rotationEffect(.degrees(-2.0 * f))
                    .offset(y: -13 - 6 * f)
            } else if summary.isNew {
                HomeRibbon(text: "🌱 新伙伴", fill: Theme.jade, edge: GrowthColors.jadeDark)
                    .scaleEffect(0.88 + 0.12 * f)
                    .rotationEffect(.degrees(-2.0 * f))
                    .offset(y: -13 - 6 * f)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button(action: onEdit) {
                PictureView(emoji: "✏️", size: 22)
                    .frame(width: 46, height: 46)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.92))
                            .shadow(color: GrowthColors.cardEdge, radius: 0, x: 0, y: 3)
                    )
                    .overlay(Circle().stroke(GrowthColors.cardEdge, lineWidth: 1.5))
            }
            .buttonStyle(PressableStyle())
            .padding(16)
            .scaleEffect(0.5 + 0.5 * f)
            .opacity(f)
            .allowsHitTesting(focused)
            .accessibilityLabel("修改\(profile.name)的名字、年级和头像")
        }
        .onAppear { updateFloat() }
        .onChange(of: focused) { _, _ in updateFloat() }
    }

    private var avatarStage: some View {
        ZStack(alignment: .bottomTrailing) {
            // 柔和主题色外发光晕
            Circle()
                .fill(
                    RadialGradient(
                        colors: [tint.opacity(0.55 * f), tint.opacity(0.15 * f), .clear],
                        center: .center,
                        startRadius: 32,
                        endRadius: 80
                    )
                )
                .frame(width: 152, height: 152)
                .scaleEffect(0.85 + 0.22 * f)

            // 立体渐变头像圆盘
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.55), tint, tint],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .background(Circle().fill(tint))
                .overlay(Circle().stroke(.white, lineWidth: 5))
                .shadow(color: tint.opacity(0.55), radius: 10, y: 5)
                .shadow(color: .black.opacity(0.10), radius: 5, y: 3)
                .frame(width: 126, height: 126)
                .overlay(
                    PictureView(emoji: profile.avatar, size: 90)
                        .scaleEffect(0.95 + 0.08 * f)
                )
                .frame(width: 152, height: 152)

            // 主角两侧闪烁的小星光
            if f > 0.2 {
                Text("✨")
                    .font(.system(size: 18))
                    .offset(x: -116, y: -96)
                    .scaleEffect(floating ? 1.15 : 0.85)
                    .opacity(f * 0.9)
                Text("✨")
                    .font(.system(size: 15))
                    .offset(x: -6, y: -112)
                    .scaleEffect(floating ? 0.85 : 1.15)
                    .opacity(f * 0.85)
            }

            LevelBadge(level: summary.level, size: 18)
                .scaleEffect(0.88 + 0.18 * f)
                .offset(x: 0, y: -4)
        }
        .scaleEffect(0.90 + 0.14 * f)
        .offset(y: (focused && floating ? -5 : 0) - 3 * f)
    }

    private var actionArea: some View {
        NavigationLink(value: profile.id) {
            HStack(spacing: 10) {
                Text("▶").font(.system(size: 24, weight: .black, design: .rounded))
                Text("开始守护！").font(.system(size: 30, weight: .black, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .background(
                RoundedRectangle(cornerRadius: 26)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.24, green: 0.84, blue: 0.62),
                                Theme.jade,
                                Color(red: 0.09, green: 0.58, blue: 0.43)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: GrowthColors.jadeDark, radius: 0, x: 0, y: 7)
                    .shadow(color: Theme.jade.opacity(0.38), radius: 14, y: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26)
                    .stroke(Color(red: 0.55, green: 0.95, blue: 0.78).opacity(0.85), lineWidth: 2.5)
            )
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("\(profile.name)开始守护")
        .scaleEffect(0.84 + 0.16 * f)
        .opacity(f)
        .allowsHitTesting(focused)
        .frame(height: 72)
    }

    private func updateFloat() {
        guard focused, !reduceMotion else {
            withAnimation(.easeOut(duration: 0.25)) { floating = false }
            return
        }
        withAnimation(.easeInOut(duration: 2.1).repeatForever(autoreverses: true)) {
            floating = true
        }
    }

    private var streakText: String {
        let activity = summary.activity
        if activity.streakDays > 0 { return "🔥 连续 \(activity.streakDays) 天" }
        if let days = activity.daysSinceLastPlay(), days >= 2 { return "💤 \(days) 天没来" }
        if summary.isNew { return "🌱 还没玩过" }
        return "🔥 连续 0 天"
    }
}
