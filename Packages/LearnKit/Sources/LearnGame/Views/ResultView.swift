import LearnCore
import SwiftUI

private enum ResultLocalArt {
    /// 未通关时的结算横幅深蓝底座边色，衬托沉稳鼓励气氛
    static let defeatBannerEdge = Color(red: 0.18, green: 0.31, blue: 0.54)
    /// 结算积分卡中的深褐金数值文字色
    static let coinRewardText = Color(red: 0.36, green: 0.25, blue: 0.0)
}

/// 结算页：左边这一局（星星、成绩、经验和积分），右边成长（升级 / 经验条、解锁、新徽章）和「记一记」。
/// 设计稿：docs/ui-growth/02（升级）、02b（没升级）、02c（失败）、02d（当天第 6 局起减半）
/// 弹窗和按钮始终位于屏幕内；右侧收获较多时局部滚动，少量内容保持自然高度。
struct ResultView: View {
    @ObservedObject var session: GameSession
    let onReplay: () -> Void
    let onExit: () -> Void
    var onOpenCollection: () -> Void = {}

    private var won: Bool { session.phase == .won }
    private var growth: GrowthResult? { session.growthResult }
    private var hasRightColumn: Bool { growth != nil || !session.mistakes.isEmpty }

    var body: some View {
        GeometryReader { geometry in
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            ViewThatFits(in: .vertical) {
                dialog(bounded: false).fixedSize(horizontal: false, vertical: true)
                dialog(bounded: true)
            }
            .frame(maxHeight: max(0, geometry.size.height - 40))
            .padding(.horizontal, 28)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        }
    }

    private func dialog(bounded: Bool) -> some View {
            VStack(spacing: 14) {
                banner
                HStack(alignment: .top, spacing: AppSpacing.md) {
                    roundColumn
                    if hasRightColumn { growthColumn(bounded: bounded) }
                }
                .frame(maxHeight: bounded ? .infinity : nil, alignment: .top)
                if let error = session.settlementError {
                    Text(error).font(AppFont.label).foregroundStyle(AppColor.dangerText)
                    AppButton(title: "重试保存本局", systemImage: "arrow.clockwise", role: .destructiveSolid, size: .medium, minWidth: 180, action: session.retrySettlement)
                }
                buttons
                    .disabled(session.settlementError != nil)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, 40)
            .padding(.bottom, 20)
            .frame(maxWidth: hasRightColumn ? 1040 : 620)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.xl)
                    .fill(AppColor.paper)
                    .shadow(color: AppColor.cardEdge, radius: 0, x: 0, y: 6)
                    .overlay(RoundedRectangle(cornerRadius: AppRadius.xl).stroke(AppColor.cardStroke, lineWidth: 2))
                    .padding(.top, 22))
    }

    // MARK: - 横幅

    private var banner: some View {
        HStack(spacing: AppSpacing.sm) {
            PictureView(emoji: won ? "🎉" : "💪", size: 36)
            Text("本局结束 · 完成 \(session.completedRounds) 回合")
                .font(AppFont.rounded(30, weight: .black))
            PictureView(emoji: won ? "🌟" : "📚", size: 36)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 34)
        .frame(height: 54)
        .padding(.bottom, 5)
        .background {
            ZStack(alignment: .top) {
                Capsule()
                    .fill(won ? AppColor.violetEdge : ResultLocalArt.defeatBannerEdge)
                    .shadow(color: (won ? AppColor.violetEdge : AppColor.calm).opacity(0.28), radius: 8, y: 4)
                Capsule()
                    .fill(LinearGradient(colors: won ? [AppColor.violetTop, AppColor.violet] : [AppColor.calm.opacity(0.85), AppColor.calm],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(Capsule().strokeBorder(.white.opacity(0.75), lineWidth: 2))
                    .padding(.bottom, 5)
            }
        }
        .padding(.top, -48)
    }

    // MARK: - 左栏：这一局

    private var roundColumn: some View {
        VStack(spacing: AppSpacing.sm) {
            HStack(alignment: .bottom, spacing: 14) {
                star(0, label: "通关", size: 50)
                star(1, label: "答对 7 成", size: 66)
                star(2, label: "9 成 · 满心", size: 50)
            }
            HStack(spacing: AppSpacing.sm) {
                stat("🎯", "第一次就答对", session.attempted == 0 ? "-" : "\(session.firstTryCorrect)/\(session.attempted)")
                stat("⚡", "首答正确率", session.attempted == 0 ? "-" : "\(Int((session.accuracy * 100).rounded()))%", tint: AppColor.jadeEdge)
                stat("⏱️", "用时", String(format: "%02d:%02d", session.playSeconds / 60, session.playSeconds % 60))
            }
            if let growth { rewards(growth) }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity)
        .appPanel(radius: AppRadius.lg)
    }

    private func star(_ index: Int, label: String, size: CGFloat) -> some View {
        let earned = index < session.stars
        return VStack(spacing: AppSpacing.xxs) {
            Text("⭐").font(AppFont.rounded(size))
                .grayscale(earned ? 0 : 1)
                .opacity(earned ? 1 : 0.3)
            Text(earned ? label : (won && index > 0 ? "差一点" : label))
                .font(AppFont.label)
                .foregroundStyle(earned ? AppColor.goldEdge : AppColor.muted)
                .padding(.horizontal, 10).padding(.vertical, 3)
                .background(Capsule().fill(earned ? AppColor.gold.opacity(0.25) : AppColor.disabledFill))
        }
    }

    private func stat(_ icon: String, _ title: String, _ value: String, tint: Color = AppColor.ink) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: AppSpacing.xxs) {
                Text(icon).font(AppFont.rounded(18))
                Text(title).font(AppFont.label).foregroundStyle(AppColor.muted)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            Text(value).font(AppFont.digits(28, weight: .heavy)).foregroundStyle(tint)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xs)
        .appInset(radius: AppRadius.md)
    }

    private func rewards(_ g: GrowthResult) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: AppSpacing.sm) {
                rewardTile(icon: "⭐", title: "经验", value: g.xp, full: g.reduced ? g.fullXP : nil,
                           tint: AppColor.jade, text: AppColor.jadeEdge)
                rewardTile(icon: nil, title: "总积分", value: g.totalCoins, full: nil,
                           tint: AppColor.gold, text: ResultLocalArt.coinRewardText)
            }
            Text("每日上限：答题 \(session.rules.coinLimit(.answers)) · 过关 \(session.rules.coinLimit(.completion)) · 首胜 \(session.rules.coinLimit(.firstWin)) · 升级 \(session.rules.coinLimit(.level)) · 徽章 \(session.rules.coinLimit(.badge))")
                .font(AppFont.caption)
                .foregroundStyle(AppColor.muted)
            if g.reduced {
                HintCapsule(icon: "😴", text: "今天玩了 \(g.gamesToday) 局，基础奖励减半，积分按每日剩余额度发放", tint: AppColor.calm)
            } else if g.dailyFirstWin {
                let p = GrowthCatalog.bundled.pacing.daily
                HintCapsule(icon: "🔥", text: "今天第一次通关：+\(p.firstWinXP) 经验 · +\(p.firstWinCoins) 积分（已计入）", tint: AppColor.jadeEdge)
            } else if !won {
                HintCapsule(icon: "🌱", text: "答对的题也有奖励！通关还能拿星星和通关奖励", tint: AppColor.jadeEdge)
            } else if session.stars < 3 {
                HintCapsule(icon: "💡", text: "3 星：第一次就答对九成，而且一颗心都不丢", tint: AppColor.adventure)
            }
        }
    }

    private func rewardTile(icon: String?, title: String, value: Int, full: Int?, tint: Color, text: Color) -> some View {
        HStack(spacing: 10) {
            if let icon { PictureView(emoji: icon, size: 34) } else { CoinIcon(size: 34) }
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(AppFont.label).opacity(0.85)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("+\(value)").font(AppFont.digits(28, weight: .black))
                    if let full {
                        Text("\(full)").strikethrough().font(AppFont.body).opacity(0.6)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(text)
        .padding(.horizontal, AppSpacing.md)
        .frame(maxWidth: .infinity, minHeight: 60)
        .appInset(radius: AppRadius.md, tint: tint)
    }

    // MARK: - 右栏：成长 + 记一记

    private func growthColumn(bounded: Bool) -> some View {
        VStack(spacing: AppSpacing.sm) {
            if let growth { levelCard(growth) }
            if bounded {
                Text("上下滑动查看全部收获与错题")
                    .font(AppFont.caption).foregroundStyle(AppColor.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ScrollView {
                    gainsAndNotebook.padding(4)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollIndicators(.visible)
                .scrollIndicatorsFlash(onAppear: true)
            } else {
                gainsAndNotebook
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var gainsAndNotebook: some View {
        VStack(spacing: AppSpacing.sm) {
            if let growth, !(growth.gifts + growth.unlocked).isEmpty || !growth.newBadges.isEmpty { gainsCard(growth) }
            if !session.mistakes.isEmpty { notebook }
        }
    }

    private func levelCard(_ g: GrowthResult) -> some View {
        let catalog = GrowthCatalog.bundled
        let next = catalog.cosmetics.first { $0.unlockLevel == g.after.level + 1 && !$0.isOriginal }
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                LevelBadge(level: g.after.level, size: 24)
                VStack(alignment: .leading, spacing: 0) {
                    if g.leveledUp {
                        Text("Lv.\(g.before.level) → Lv.\(g.after.level)").font(AppFont.rounded(15, weight: .heavy))
                            .foregroundStyle(AppColor.violetEdge)
                    }
                    Text(g.leveledUp ? "升级啦！" : (won ? "经验在长大！" : "答对就有经验！"))
                        .font(AppFont.rounded(26, weight: .heavy))
                        .foregroundStyle(g.leveledUp ? AppColor.violetEdge : AppColor.jadeEdge)
                }
                Spacer()
                if g.levelCoins > 0 {
                    HStack(spacing: AppSpacing.xxs) {
                        CoinIcon(size: 20)
                        Text("升级奖励 +\(g.levelCoins)")
                    }
                    .font(AppFont.rounded(15, weight: .heavy))
                    .foregroundStyle(ResultLocalArt.coinRewardText)
                    .padding(.horizontal, AppSpacing.sm).padding(.vertical, 6)
                    .background(Capsule().fill(AppColor.gold.opacity(0.24)))
                }
            }
            XPBar(progress: g.after, gained: g.leveledUp ? 0 : g.xp, height: 24)
            HStack {
                Text("Lv.\(g.after.level)　\(g.after.xpIntoLevel) / \(g.after.xpForNext) 经验")
                    .foregroundStyle(AppColor.jadeEdge)
                Spacer()
                Text("再得 \(g.after.xpToGo) 经验升级" + (next.map { "，解锁 \($0.icon) \($0.name)" } ?? ""))
                    .foregroundStyle(AppColor.muted)
            }
            .font(AppFont.label)
            .lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(AppSpacing.md)
        .appPanel(radius: AppRadius.lg)
    }

    /// 这一局新得到的外观和徽章，排在一张卡片里，每样一行
    private func gainsCard(_ g: GrowthResult) -> some View {
        VStack(spacing: AppSpacing.xs) {
            Text("新收获（\(g.gifts.count + g.unlocked.count + g.newBadges.count)）")
                .font(AppFont.bodyStrong).foregroundStyle(AppColor.ink).frame(maxWidth: .infinity, alignment: .leading)
            ForEach(g.gifts + g.unlocked, id: \.id) { unlockRow($0) }
            ForEach(g.newBadges, id: \.id) { badgeRow($0) }
        }
        .padding(AppSpacing.sm)
        .frame(maxWidth: .infinity)
        .appPanel(radius: AppRadius.lg)
    }

    private func unlockRow(_ item: CosmeticKind) -> some View {
        gainRow(title: item.name,
                tag: "Lv.\(item.unlockLevel) 解锁", tagText: AppColor.jadeEdge, tagFill: AppColor.jade.opacity(0.15),
                detail: "\(item.slot.displayName) · " + (item.price == 0 ? "升级送的，可以直接装备" : "现在可以用 \(item.price) 积分买了"),
                isNew: true) {
            PictureView(emoji: item.icon, size: 36)
                .frame(width: 52, height: 52)
                .appInset(radius: AppRadius.sm, tint: AppColor.jade)
        }
    }

    private func badgeRow(_ badge: BadgeKind) -> some View {
        gainRow(title: badge.name,
                tag: "新徽章！", tagText: AppColor.violetEdge, tagFill: AppColor.violet.opacity(0.16),
                detail: "\(badge.summary) · 积分已按每日额度计入总额", isNew: false) {
            MedalView(icon: badge.icon, earned: true, size: 40)
                .frame(width: 52, height: 52)
        }
    }

    private func gainRow<Icon: View>(title: String, tag: String, tagText: Color, tagFill: Color, detail: String, isNew: Bool,
                                     @ViewBuilder icon: () -> Icon) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            icon()
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(AppFont.rounded(20, weight: .heavy))
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: AppSpacing.xs) {
                    Text(tag).font(AppFont.caption)
                        .foregroundStyle(tagText)
                        .padding(.horizontal, AppSpacing.xs).padding(.vertical, 2)
                        .background(Capsule().fill(tagFill))
                    if isNew {
                        Text("新！").font(AppFont.caption).foregroundStyle(.white)
                            .padding(.horizontal, AppSpacing.xs).padding(.vertical, 2)
                            .background(Capsule().fill(AppColor.dangerSolidBottom))
                    }
                }
                Text(detail)
                    .font(AppFont.label).foregroundStyle(AppColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(AppColor.ink)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .appInset(radius: AppRadius.md)
    }

    private var notebook: some View {
        MistakeNotebook(mistakes: session.mistakes)
    }
    // MARK: - 按钮

    private var buttons: some View {
        HStack(spacing: AppSpacing.md) {
            AppButton(title: "返回主页", systemImage: "house.fill", role: .secondary, size: .large, action: onExit)
            Spacer()
            if won, growth != nil {
                AppButton(title: "去收藏馆看看", systemImage: "gift.fill", role: .adventure, size: .large, action: onOpenCollection)
            }
            AppButton(title: won ? "再来一局" : "再试一次", systemImage: "play.fill", role: .primary, size: .large, minWidth: 180, action: onReplay)
        }
    }
}

/// 记一记：答错和没来得及答的题，结算后再看一遍。
/// 放得下就全部列出来；错题多、弹窗放不下时只在这个框里滚动，弹窗高度不跟着错题数变，按钮始终在一屏里
struct MistakeNotebook: View {
    let mistakes: [GameSession.Mistake]

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("✏️ 记一记（\(mistakes.count)）").font(AppFont.rounded(20, weight: .heavy)).foregroundStyle(AppColor.ink)
            ViewThatFits(in: .vertical) {
                list
                ScrollView { list }
                    .scrollBounceBehavior(.basedOnSize)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appPanel(radius: AppRadius.lg)
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(mistakes) { m in
                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                    PictureView(emoji: m.missed ? "⏰" : "✏️", size: 22)
                    Text("\(m.prompt) · " + (m.missed ? "未作答" : "需要再练习"))
                        .foregroundStyle(AppColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(AppFont.rounded(17, weight: .semibold))
                .padding(.horizontal, AppSpacing.sm).padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .appInset(radius: AppRadius.sm)
            }
        }
    }
}
