import LearnCore
import SwiftUI

/// App 入口
public struct RootView: View {
    @StateObject private var model = AppModel()

    public init() {}

    public var body: some View {
        NavigationStack {
            ProfilesView()
        }
        .environmentObject(model)
        .tint(AppColor.accent)
    }
}

/// 首页：左右滑动的孩子卡片轮播，最后一张是「添加小朋友」；一个孩子都没有时只显示欢迎卡。
/// 上次玩的孩子排第一个并停在中间。设计稿见 docs/ui-home（05~07）
struct ProfilesView: View {
    @EnvironmentObject private var model: AppModel
    @State private var editing: EditingProfile?
    @State private var showingVoiceSettings = false
    /// 各孩子的游玩概况，进入首页、从主页返回、改完档案时刷新
    @State private var activity: [UUID: PlayActivity] = [:]
    /// 轮播当前停在哪张卡
    @State private var current: HomeCardID?
    /// 下次刷新后要停在哪张卡（刚建好或刚改完的孩子）；为 nil 时回到第一张
    @State private var focusAfterRefresh: HomeCardID?
    /// 手指实时拖动偏移，让卡片位置、倾角与内部焦点细节 1:1 实时跟手
    @State private var dragOffset: CGFloat = 0
    @State private var stageGlow = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let cardWidth: CGFloat = 400
    private static let dragStep: CGFloat = 340

    private var ordered: [Profile] { PlayActivity.homeOrder(model.profiles, activity: activity) }

    private var cards: [HomeCardID] { ordered.map { .profile($0.id) } + [.add] }

    var body: some View {
        VStack(spacing: 0) {
            header
            if model.profiles.isEmpty {
                GeometryReader { geo in
                    HomeEmptyCard(height: min(500, geo.size.height - 40), onAdd: addProfile)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                carousel
                CarouselPager(cards: cards, current: current) { card in
                    select(card)
                }
                .padding(.vertical, AppSpacing.xs)
            }
            HomeLawn()
        }
        .background(homeBackground)
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .navigationDestination(for: UUID.self) { id in
            ProfileHomeView(profileID: id)
        }
        .onAppear(perform: refresh)
        .profileEditorCover(item: $editing, onSave: save, onDelete: delete)
        .growthCover(isPresented: $showingVoiceSettings) {
            ParentSettingsView()
        }
    }

    // MARK: - 顶部

    private var header: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 6) {
                GameLogo(size: 52)
                Text("今天谁来守护书本？")
                    .font(AppFont.heading)
                    .foregroundStyle(AppColor.ink)
            }
            .frame(maxWidth: .infinity)

            // 家长专区入口，使用统一的 .subtle 轻柔按钮，不抢孩子的注意力；进入前要家长验证
            AppButton(title: "家长专区", systemImage: "lock.fill", role: .subtle, size: .medium) {
                showingVoiceSettings = true
            }
        }
        .padding(.horizontal, AppSpacing.xl)
        .padding(.top, AppSpacing.xs)
    }

    private var spotlightColor: Color {
        if case let .profile(id) = current,
           let profile = model.profiles.first(where: { $0.id == id }) {
            return AvatarTint.color(for: profile.avatar)
        }
        return AppColor.gold
    }

    private var homeBackground: some View {
        ZStack {
            GrowthPageBackground()
            // 顶部柔和天空微蓝渐变
            LinearGradient(
                colors: [AppColor.sky.opacity(0.65), AppColor.sky.opacity(0.2), .clear],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
            // 舞台中央聚光灯随当前聚焦孩子平滑切换主题色并轻微呼吸
            RadialGradient(
                colors: [spotlightColor.opacity(stageGlow ? 0.46 : 0.34), AppColor.gold.opacity(0.14), .clear],
                center: UnitPoint(x: 0.5, y: 0.42),
                startRadius: 30,
                endRadius: 500
            )
            .scaleEffect(stageGlow ? 1.04 : 0.98)
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.45), value: current)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                stageGlow = true
            }
        }
    }

    // MARK: - 轮播舞台

    private var carousel: some View {
        GeometryReader { geo in
            let cardHeight = min(500, geo.size.height - 48)
            let index = current.flatMap { cards.firstIndex(of: $0) } ?? 0
            let progress = Double(dragOffset / Self.dragStep)

            ZStack {
                // C 位卡片正下方的椭圆发光舞台底座
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [spotlightColor.opacity(0.42), AppColor.gold.opacity(0.18), .clear],
                            center: .center,
                            startRadius: 12,
                            endRadius: 260
                        )
                    )
                    .frame(width: 520, height: 42)
                    .offset(y: cardHeight / 2 + 12)
                    .animation(.easeInOut(duration: 0.4), value: current)
                    .allowsHitTesting(false)

                if geo.size.width > 900 {
                    stageDecorations
                }

                // 卡片扇面舞台：每张卡由连续 phase 实时驱动位置、缩放、微倾角与内部聚焦度
                ZStack {
                    ForEach(Array(ordered.enumerated()), id: \.element.id) { offset, profile in
                        let id = HomeCardID.profile(profile.id)
                        let phase = Double(offset - index) + progress
                        if abs(phase) <= 2.2 {
                            let g = CarouselGeometry(phase: phase)
                            HomeProfileCard(
                                summary: summary(profile, isFirst: offset == 0),
                                focused: id == current,
                                focus: g.focus,
                                height: cardHeight
                            ) {
                                editing = EditingProfile(profile: profile, isNew: false)
                            }
                            .frame(width: Self.cardWidth)
                            .contentShape(RoundedRectangle(cornerRadius: 36))
                            .onTapGesture {
                                if id != current { select(id) }
                            }
                            .modifier(CarouselTransform(phase: phase))
                            .zIndex(g.zIndex)
                        }
                    }

                    let addPhase = Double(ordered.count - index) + progress
                    if abs(addPhase) <= 2.2 {
                        let g = CarouselGeometry(phase: addPhase)
                        HomeAddCard(
                            focused: current == .add,
                            focus: g.focus,
                            height: cardHeight,
                            onAdd: addProfile
                        )
                        .frame(width: Self.cardWidth)
                        .contentShape(RoundedRectangle(cornerRadius: 36))
                        .onTapGesture {
                            if current != .add { select(.add) }
                        }
                        .modifier(CarouselTransform(phase: addPhase))
                        .zIndex(g.zIndex)
                    }
                }
                .padding(.vertical, AppSpacing.lg)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        let dx = value.translation.width
                        let atStart = index == 0 && dx > 0
                        let atEnd = index == cards.count - 1 && dx < 0
                        dragOffset = (atStart || atEnd) ? dx * 0.32 : dx
                    }
                    .onEnded { value in
                        let actual = value.translation.width
                        let predicted = value.predictedEndTranslation.width
                        var target = index
                        if (actual < -52 || predicted < -135), index < cards.count - 1 {
                            target = index + 1
                        } else if (actual > 52 || predicted > 135), index > 0 {
                            target = index - 1
                        }
                        withAnimation(.spring(response: 0.44, dampingFraction: 0.84)) {
                            current = cards[target]
                            dragOffset = 0
                        }
                    }
            )
        }
    }

    private var stageDecorations: some View {
        ZStack {
            PictureView(emoji: "🦋", size: 28)
                .offset(x: -440, y: -150 + (stageGlow ? -6 : 6))
                .rotationEffect(.degrees(stageGlow ? -8 : 4))
            PictureView(emoji: "✨", size: 22)
                .offset(x: -380, y: 110)
                .opacity(stageGlow ? 0.85 : 0.4)
            PictureView(emoji: "🦋", size: 28)
                .offset(x: 440, y: -130 + (stageGlow ? 6 : -6))
                .rotationEffect(.degrees(stageGlow ? 8 : -4))
            PictureView(emoji: "⭐", size: 22)
                .offset(x: 390, y: 120)
                .opacity(stageGlow ? 0.85 : 0.4)
        }
        .allowsHitTesting(false)
    }

    private func summary(_ profile: Profile, isFirst: Bool) -> HomeProfileSummary {
        let growth = model.growth(for: profile.id)
        let activity = activity[profile.id] ?? .none
        return HomeProfileSummary(
            profile: profile,
            level: growth.level.level,
            gamesPlayed: growth.state.stats.gamesPlayed,
            activity: activity,
            isLastPlayed: isFirst && activity.lastPlayedAt != nil)
    }

    private func select(_ card: HomeCardID) {
        guard card != current else { return }
        withAnimation(.spring(response: 0.44, dampingFraction: 0.84)) {
            current = card
            dragOffset = 0
        }
    }

    // MARK: - 数据

    /// 重新读游玩概况，排好顺序后停在指定的卡（默认第一张，也就是上次玩的孩子）
    private func refresh() {
        var latest: [UUID: PlayActivity] = [:]
        for profile in model.profiles {
            latest[profile.id] = model.playActivity(for: profile.id)
        }
        activity = latest
        let first = PlayActivity.homeOrder(model.profiles, activity: latest).first.map { HomeCardID.profile($0.id) }
        if let focus = focusAfterRefresh, focus == .add || cards.contains(focus) {
            current = focus
        } else {
            current = first
        }
        focusAfterRefresh = nil
    }

    private func addProfile() {
        editing = EditingProfile(
            profile: Profile(name: "", grade: .g3, avatar: Profile.avatars.randomElement() ?? "🐯"),
            isNew: true)
    }

    private func save(_ profile: Profile) {
        model.save(profile)
        // 新建或改完后停在这个孩子上；关掉面板时首页会重新出现并刷新
        focusAfterRefresh = .profile(profile.id)
        refresh()
    }

    private func delete(_ profile: Profile) {
        model.delete(profile)
        focusAfterRefresh = nil
        refresh()
    }
}

/// 扇面圆弧舞台几何：中心主角卡端正高浮，两侧候补卡沿圆弧自然下沉、微倾并柔和缩放，保持 2D 矢量锐利度。
/// phase 是卡片相对舞台中心的连续步数（左边为负），手指拖动与弹簧回弹时全程连续插值。
struct CarouselGeometry {
    let phase: Double

    private var clamped: Double { min(max(phase, -2.0), 2.0) }
    var distance: Double { abs(clamped) }
    /// Smoothstep 连续聚焦度（0 ~ 1）：中心点与邻卡点导数均为 0，过渡温润无折角
    var focus: Double {
        let t = max(0, min(1, 1 - distance))
        return t * t * (3 - 2 * t)
    }
    var angle: Angle { .degrees(clamped * -8) }
    var tilt: Angle { .degrees(clamped * 3.2) }
    var scale: Double { 0.85 + 0.15 * focus }
    var opacity: Double { max(0, 1 - distance * 0.34) }
    var offsetX: Double { clamped * 336 }
    var offsetY: Double { min(distance * distance * 20, 32) - focus * 4 }
    var zIndex: Double { 100 - distance * 20 }
    static let perspective: CGFloat = 0.25
}

/// 舞台卡片连续空间变换
struct CarouselTransform: ViewModifier {
    let phase: Double

    func body(content: Content) -> some View {
        let g = CarouselGeometry(phase: phase)
        content
            .scaleEffect(g.scale)
            .rotationEffect(g.tilt)
            .rotation3DEffect(g.angle, axis: (x: 0, y: 1, z: 0), perspective: CarouselGeometry.perspective)
            .opacity(g.opacity)
            .offset(x: g.offsetX, y: g.offsetY)
    }
}

struct EditingProfile: Identifiable {
    var id: UUID { profile.id }
    var profile: Profile
    var isNew: Bool
}
