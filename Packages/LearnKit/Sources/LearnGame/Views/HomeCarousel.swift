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

/// 卡片顶部的角标，如「👑 上次是你」「🌱 新伙伴」
struct HomeRibbon: View {
    let text: String
    var fill: Color = Theme.accent
    var edge: Color = GrowthColors.orangeDeep

    var body: some View {
        Text(text)
            .font(.system(size: 18, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .frame(height: 36)
            .background(Capsule().fill(fill).shadow(color: edge, radius: 0, x: 0, y: 3))
            .overlay(Capsule().stroke(.white, lineWidth: 3))
    }
}

/// 一行状态小药丸
private struct StatPill: View {
    let text: String
    var tint: Color = GrowthColors.orangeDark

    var body: some View {
        Text(text)
            .font(.system(size: 18, weight: .heavy, design: .rounded))
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color(red: 1.0, green: 0.97, blue: 0.9)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(red: 0.98, green: 0.86, blue: 0.62), lineWidth: 1.5))
    }
}

/// 白底大卡片外框：focused 时金色粗描边 + 橙色厚底，侧卡用浅色描边
struct HomeCardFrame: ViewModifier {
    var focused: Bool
    var dashed = false

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 36)
        content
            .background(
                shape.fill(dashed ? Color(red: 1.0, green: 0.98, blue: 0.94) : .white)
                    .shadow(color: focused ? GrowthColors.orangeDark : GrowthColors.cardEdge, radius: 0, x: 0, y: focused ? 10 : 6)
                    .shadow(color: .black.opacity(0.08), radius: 16, y: 10))
            .overlay(
                shape.stroke(
                    focused ? GrowthColors.gold : GrowthColors.cardEdge,
                    style: StrokeStyle(lineWidth: focused ? 5 : 3, dash: dashed ? [12, 8] : [])))
    }
}

/// 轮播里的孩子卡。focused 为 false 时是两侧露出来的侧卡：不放「开始守护」，点整张卡换到中间
struct HomeProfileCard: View {
    let summary: HomeProfileSummary
    let focused: Bool
    let height: CGFloat
    let onEdit: () -> Void

    private var profile: Profile { summary.profile }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(AvatarTint.color(for: profile.avatar))
                    .overlay(Circle().stroke(.white, lineWidth: 5))
                    .shadow(color: .black.opacity(0.1), radius: 6, y: 3)
                    .frame(width: 124, height: 124)
                    .overlay(PictureView(emoji: profile.avatar, size: 88))
                LevelBadge(level: summary.level, size: 18)
                    .offset(x: 10, y: 2)
            }
            .padding(.top, 40)

            Text(profile.name)
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.top, 10)

            Text(profile.grade.displayName)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(GrowthColors.orangeDark)
                .padding(.horizontal, 16)
                .frame(height: 32)
                .background(Capsule().fill(Color(red: 1.0, green: 0.93, blue: 0.78)))

            Spacer(minLength: 12)

            HStack(spacing: 10) {
                StatPill(text: streakText, tint: summary.activity.streakDays > 0 ? Color(red: 0.85, green: 0.35, blue: 0.1) : Theme.muted)
                StatPill(text: "⭐ 闯关 \(summary.gamesPlayed) 次")
            }

            Spacer(minLength: 14)

            if focused {
                NavigationLink(value: profile.id) {
                    CandyButtonLabel(title: "开始守护！", icon: "▶",
                                     font: .system(size: 30, weight: .black, design: .rounded), height: 72, minWidth: 340)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("\(profile.name)开始守护")
            } else {
                Text("点我换成\(profile.name)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.muted)
                    .frame(height: 72)
            }
        }
        .padding(.horizontal, 26)
        .padding(.bottom, 26)
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .modifier(HomeCardFrame(focused: focused))
        .overlay(alignment: .top) {
            if summary.isLastPlayed {
                HomeRibbon(text: "👑 上次是你").offset(y: -18)
            } else if summary.isNew {
                HomeRibbon(text: "🌱 新伙伴", fill: Theme.jade, edge: GrowthColors.jadeDark).offset(y: -18)
            }
        }
        .overlay(alignment: .topTrailing) {
            if focused {
                Button(action: onEdit) {
                    PictureView(emoji: "✏️", size: 24)
                        .frame(width: 48, height: 48)
                        .background(Circle().fill(Color(red: 0.96, green: 0.95, blue: 0.93)))
                        .overlay(Circle().stroke(GrowthColors.cardEdge, lineWidth: 1.5))
                }
                .buttonStyle(PressableStyle())
                .padding(16)
                .accessibilityLabel("修改\(profile.name)的名字、年级和头像")
            }
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
