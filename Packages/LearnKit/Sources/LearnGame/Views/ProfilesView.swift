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
        .tint(Theme.accent)
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

    private static let cardWidth: CGFloat = 400

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
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { current = card }
                }
                .padding(.top, 6)
                Text("← 左右滑动换人 →")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.muted.opacity(0.8))
                    .padding(.top, 4)
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
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)
            }
            .frame(maxWidth: .infinity)

            // 家长专区入口，灰白色，不抢孩子的注意力；进入前要家长验证
            Button { showingVoiceSettings = true } label: {
                Label("家长专区", systemImage: "lock.fill")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.muted)
                    .padding(.horizontal, 16)
                    .frame(height: 44)
                    .background(Capsule().fill(.white.opacity(0.75)))
                    .overlay(Capsule().stroke(Theme.muted.opacity(0.25), lineWidth: 1))
            }
            .buttonStyle(PressableStyle())
        }
        .padding(.horizontal, 32)
        .padding(.top, 8)
    }

    private var homeBackground: some View {
        ZStack {
            GrowthPageBackground()
            // 中间的聚光灯
            RadialGradient(colors: [GrowthColors.gold.opacity(0.3), .clear], center: .center, startRadius: 40, endRadius: 460)
                .ignoresSafeArea()
        }
    }

    // MARK: - 轮播

    private var carousel: some View {
        GeometryReader { geo in
            let cardHeight = min(500, geo.size.height - 48)
            let sideMargin = max(0, (geo.size.width - Self.cardWidth) / 2)
            let index = current.flatMap { cards.firstIndex(of: $0) } ?? 0

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 28) {
                    ForEach(Array(ordered.enumerated()), id: \.element.id) { offset, profile in
                        let id = HomeCardID.profile(profile.id)
                        HomeProfileCard(summary: summary(profile, isFirst: offset == 0),
                                        focused: id == current, height: cardHeight) {
                            editing = EditingProfile(profile: profile, isNew: false)
                        }
                        .frame(width: Self.cardWidth)
                        .contentShape(Rectangle())
                        .onTapGesture { select(id) }
                        .modifier(CarouselTransition())
                        .id(id)
                    }
                    HomeAddCard(focused: current == .add, height: cardHeight, onAdd: addProfile)
                        .frame(width: Self.cardWidth)
                        .contentShape(Rectangle())
                        .onTapGesture { select(.add) }
                        .modifier(CarouselTransition())
                        .id(HomeCardID.add)
                }
                .scrollTargetLayout()
                // 角标在卡片上沿外面，留出位置不被裁掉
                .padding(.vertical, 24)
            }
            .contentMargins(.horizontal, sideMargin, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $current)
            .overlay {
                HStack {
                    if index > 0 {
                        CarouselArrow(left: true) { select(cards[index - 1]) }
                    }
                    Spacer()
                    if index < cards.count - 1 {
                        CarouselArrow(left: false) { select(cards[index + 1]) }
                    }
                }
                .frame(width: Self.cardWidth + 150)
            }
        }
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
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { current = card }
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

/// 3D 旋转木马：卡片像排在一个圆筒外侧，离中间越远转得越多、越小越淡。
/// phase 是卡片离中间几张卡的距离（左边为负），拖动时连续变化
struct CarouselGeometry {
    let phase: Double

    private var clamped: Double { min(max(phase, -1.6), 1.6) }
    /// 绕竖轴转的角度：左边的卡外缘往后退，朝向中间
    var angle: Angle { .degrees(clamped * 42) }
    var scale: Double { 1 - abs(clamped) * 0.14 }
    var opacity: Double { 1 - abs(clamped) * 0.38 }
    /// 转过去以后看起来变窄了，往中间收一点，让几张卡连成一圈
    var offsetX: Double { -clamped * 46 }
    static let perspective: CGFloat = 0.55
}

private struct CarouselTransition: ViewModifier {
    func body(content: Content) -> some View {
        content.scrollTransition(.interactive, axis: .horizontal) { view, phase in
            let g = CarouselGeometry(phase: phase.value)
            return view
                .rotation3DEffect(g.angle, axis: (x: 0, y: 1, z: 0), perspective: CarouselGeometry.perspective)
                .scaleEffect(g.scale)
                .opacity(g.opacity)
                .offset(x: g.offsetX)
        }
    }
}

/// 和 CarouselTransition 相同的变换，用于不在 ScrollView 里的场合（如渲染截图）
struct CarouselTransform: ViewModifier {
    let phase: Double

    func body(content: Content) -> some View {
        let g = CarouselGeometry(phase: phase)
        content
            .rotation3DEffect(g.angle, axis: (x: 0, y: 1, z: 0), perspective: CarouselGeometry.perspective)
            .scaleEffect(g.scale)
            .opacity(g.opacity)
            .offset(x: g.offsetX)
    }
}

struct EditingProfile: Identifiable {
    var id: UUID { profile.id }
    var profile: Profile
    var isNew: Bool
}
