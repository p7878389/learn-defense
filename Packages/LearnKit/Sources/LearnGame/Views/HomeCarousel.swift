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

/// 轮播舞台与头像圆盘的专属绘本装饰色（`AppColor` 主语义之外的美术色）
private enum LocalArt {
    static let tiger = Color(red: 1.0, green: 0.86, blue: 0.55)
    static let panda = Color(red: 0.78, green: 0.93, blue: 0.85)
    static let fox = Color(red: 1.0, green: 0.82, blue: 0.66)
    static let rabbit = Color(red: 0.99, green: 0.84, blue: 0.9)
    static let koala = Color(red: 0.84, green: 0.87, blue: 0.93)
    static let lion = Color(red: 1.0, green: 0.9, blue: 0.6)
    static let frog = Color(red: 0.8, green: 0.93, blue: 0.7)
    static let penguin = Color(red: 0.8, green: 0.9, blue: 1.0)
    static let unicorn = Color(red: 0.9, green: 0.84, blue: 1.0)
    static let whale = Color(red: 0.76, green: 0.88, blue: 1.0)
}

/// 头像底座的颜色，按头像区分，让每个孩子的卡一眼能认出来
enum AvatarTint {
    static func color(for avatar: String) -> Color {
        switch avatar {
        case "🐯": LocalArt.tiger
        case "🐼": LocalArt.panda
        case "🦊": LocalArt.fox
        case "🐰": LocalArt.rabbit
        case "🐨": LocalArt.koala
        case "🦁": LocalArt.lion
        case "🐸": LocalArt.frog
        case "🐧": LocalArt.penguin
        case "🦄": LocalArt.unicorn
        case "🐳": LocalArt.whale
        default: AppColor.surface
        }
    }
}

/// 橙色描边大字「字灵守卫」
struct GameLogo: View {
    var size: CGFloat = 52

    var body: some View {
        let text = Text("字灵守卫").font(AppFont.rounded(size, weight: .black))
        let outline = size * 0.06
        ZStack {
            // 白色描边：在八个方向各垫一层
            ForEach(0..<8, id: \.self) { i in
                let angle = Double(i) * .pi / 4
                text.foregroundStyle(.white)
                    .offset(x: cos(angle) * outline, y: sin(angle) * outline)
            }
            text.foregroundStyle(AppColor.accent)
        }
        .shadow(color: AppColor.accentEdge, radius: 0, x: 0, y: size * 0.1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("字灵守卫")
        .accessibilityAddTraits(.isHeader)
    }
}

/// 卡片顶部的立体渐变角标，如「👑 上次是你」「🌱 新伙伴」
struct HomeRibbon: View {
    let text: String
    var fill: Color = AppColor.accent
    var edge: Color = AppColor.accentEdge

    var body: some View {
        Text(text)
            .font(AppFont.rounded(17, weight: .black))
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

/// 一行状态信息小药丸（静态展示，用浅色内嵌描边，无按压厚底）
private struct StatPill: View {
    let text: String
    var tint: Color = AppColor.accentEdge
    var fill: Color = AppColor.surface
    var border: Color = AppColor.accentSoftEdge

    var body: some View {
        Text(text)
            .font(AppFont.rounded(17, weight: .black))
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, minHeight: 42)
            .background(RoundedRectangle(cornerRadius: AppRadius.sm).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.sm).strokeBorder(border, lineWidth: 1.5))
    }
}

/// 角色卡片立体糖果外框：顶部主题色柔和穹顶渐变 + 晶莹内高光 + 连续 focus 驱动的金色描边与厚底
struct HomeCardFrame: ViewModifier {
    var focused: Bool
    var focus: Double? = nil
    var tint: Color = AppColor.gold
    var dashed = false

    private var f: Double { focus ?? (focused ? 1.0 : 0.0) }

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 36)
        content
            .background(
                ZStack(alignment: .top) {
                    shape.fill(dashed ? AppColor.surface : .white)
                        .shadow(color: f > 0.5 ? AppColor.accentEdge : AppColor.cardEdge, radius: 0, x: 0, y: 6 + 6 * f)
                        .shadow(color: AppColor.accentEdge.opacity(0.08 + 0.22 * f), radius: 14 + 14 * f, y: 10 + 10 * f)
                    // 卡片顶部柔和角色主题色穹顶内渐变（还原设计稿 05）
                    LinearGradient(colors: [tint.opacity(0.14 + 0.24 * f), tint.opacity(0.05 * f), .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: 165)
                        .clipShape(RoundedRectangle(cornerRadius: 33))
                        .padding(3)
                }
            )
            .overlay(RoundedRectangle(cornerRadius: 33).inset(by: 3).stroke(.white.opacity(0.9), lineWidth: 1.5))
            .overlay(shape.stroke(f > 0.45 ? AppColor.gold : AppColor.cardEdge,
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
                .font(AppFont.rounded(40, weight: .black))
                .foregroundStyle(AppColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .scaleEffect(0.94 + 0.06 * f)
                .padding(.top, AppSpacing.xxs)

            Text(profile.grade.displayName)
                .font(AppFont.rounded(16, weight: .black))
                .foregroundStyle(AppColor.accentEdge)
                .padding(.horizontal, AppSpacing.md)
                .frame(height: 30)
                .background(
                    Capsule()
                        .fill(AppColor.answerTray)
                        .shadow(color: AppColor.gold.opacity(0.45), radius: 0, x: 0, y: 2)
                )
                .overlay(Capsule().stroke(AppColor.gold.opacity(0.85), lineWidth: 1.5))
                .scaleEffect(0.94 + 0.06 * f)
                .padding(.top, 2)

            Spacer(minLength: 10)

            HStack(spacing: 10) {
                StatPill(
                    text: streakText,
                    tint: summary.activity.streakDays > 0 ? AppColor.accentEdge : AppColor.muted,
                    fill: AppColor.surface,
                    border: AppColor.accentSoftEdge
                )
                StatPill(
                    text: "⭐ 闯关 \(summary.gamesPlayed) 次",
                    tint: AppColor.goldEdge,
                    fill: AppColor.answerTray,
                    border: AppColor.gold.opacity(0.75)
                )
            }

            Spacer(minLength: AppSpacing.sm)

            actionArea
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.bottom, AppSpacing.lg)
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
                HomeRibbon(text: "🌱 新伙伴", fill: AppColor.jade, edge: AppColor.jadeEdge)
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
                            .shadow(color: AppColor.cardEdge, radius: 0, x: 0, y: 3)
                    )
                    .overlay(Circle().stroke(AppColor.cardEdge, lineWidth: 1.5))
            }
            .buttonStyle(PressableStyle())
            .padding(AppSpacing.md)
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
                    .font(AppFont.rounded(18))
                    .offset(x: -116, y: -96)
                    .scaleEffect(floating ? 1.15 : 0.85)
                    .opacity(f * 0.9)
                Text("✨")
                    .font(AppFont.rounded(15))
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
                Text("▶").font(AppFont.rounded(24, weight: .black))
                Text("开始守护！").font(AppFont.rounded(30, weight: .black))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .background(
                RoundedRectangle(cornerRadius: 26)
                    .fill(
                        LinearGradient(
                            colors: [
                                AppColor.jadeTop,
                                AppColor.jade,
                                AppColor.jadeBottom
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: AppColor.jadeEdge, radius: 0, x: 0, y: 7)
                    .shadow(color: AppColor.jade.opacity(0.38), radius: 14, y: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26)
                    .stroke(AppColor.jadeLight.opacity(0.85), lineWidth: 2.5)
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
