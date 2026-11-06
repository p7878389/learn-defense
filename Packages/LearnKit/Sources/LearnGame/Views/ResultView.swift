import LearnCore
import SwiftUI

/// 结算页：左边这一局（星星、成绩、经验和积分），右边成长（升级 / 经验条、解锁、新徽章）和「记一记」。
/// 设计稿：docs/ui-growth/02（升级）、02b（没升级）、02c（失败）、02d（当天第 6 局起减半）
/// iPad 11 寸横屏要一屏放下整个弹窗和按钮，不整页滚动：内容排得紧凑，「记一记」放不下时只在自己的框里滚动
struct ResultView: View {
    @ObservedObject var session: GameSession
    let onReplay: () -> Void
    let onExit: () -> Void
    var onOpenCollection: () -> Void = {}

    private var won: Bool { session.phase == .won }
    private var growth: GrowthResult? { session.growthResult }
    private var hasRightColumn: Bool { growth != nil || !session.mistakes.isEmpty }

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 14) {
                banner
                HStack(alignment: .top, spacing: 16) {
                    roundColumn
                    if hasRightColumn { growthColumn }
                }
                buttons
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)
            .padding(.bottom, 20)
            .frame(maxWidth: hasRightColumn ? 1040 : 620)
            .background(
                RoundedRectangle(cornerRadius: 32)
                    .fill(Theme.paper)
                    .shadow(color: GrowthColors.cardEdge, radius: 0, x: 0, y: 6)
                    .overlay(RoundedRectangle(cornerRadius: 32).stroke(GrowthColors.surface, lineWidth: 4))
                    .padding(.top, 22))
            .padding(.horizontal, 28)
            .padding(.vertical, 12)
        }
    }

    // MARK: - 横幅

    private var banner: some View {
        HStack(spacing: 12) {
            PictureView(emoji: won ? "🎉" : "💪", size: 38)
            Text("本局结束 · 完成 \(session.completedRounds) 回合")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
            PictureView(emoji: won ? "🌟" : "📚", size: 38)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 36)
        .frame(height: 60)
        .background(
            Capsule()
                .fill(LinearGradient(colors: won ? [GrowthColors.gold, Theme.accent] : [GrowthColors.calm.opacity(0.8), GrowthColors.calm],
                                     startPoint: .top, endPoint: .bottom))
                .shadow(color: won ? GrowthColors.orangeDark : Color(red: 0.18, green: 0.31, blue: 0.54), radius: 0, x: 0, y: 6))
        // 横幅一半压在弹窗上沿
        .padding(.top, -48)
    }

    // MARK: - 左栏：这一局

    private var roundColumn: some View {
        VStack(spacing: 12) {
            HStack(alignment: .bottom, spacing: 14) {
                star(0, label: "通关", size: 50)
                star(1, label: "答对 7 成", size: 66)
                star(2, label: "9 成 · 满心", size: 50)
            }
            HStack(spacing: 12) {
                stat("🎯", "第一次就答对", session.attempted == 0 ? "-" : "\(session.firstTryCorrect)/\(session.attempted)")
                stat("⚡", "首答正确率", session.attempted == 0 ? "-" : "\(Int((session.accuracy * 100).rounded()))%", tint: Theme.jade)
                stat("⏱️", "用时", String(format: "%02d:%02d", session.playSeconds / 60, session.playSeconds % 60))
            }
            if let growth { rewards(growth) }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .candyCard()
    }

    private func star(_ index: Int, label: String, size: CGFloat) -> some View {
        let earned = index < session.stars
        return VStack(spacing: 4) {
            Text("⭐").font(.system(size: size))
                .grayscale(earned ? 0 : 1)
                .opacity(earned ? 1 : 0.3)
            Text(earned ? label : (won && index > 0 ? "差一点" : label))
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(earned ? GrowthColors.orangeDark : Theme.muted)
                .padding(.horizontal, 10).padding(.vertical, 3)
                .background(Capsule().fill(earned ? GrowthColors.gold.opacity(0.3) : Theme.muted.opacity(0.15)))
        }
    }

    private func stat(_ icon: String, _ title: String, _ value: String, tint: Color = Theme.ink) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Text(icon).font(.system(size: 18))
                Text(title).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(Theme.muted)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            Text(value).font(.system(size: 28, weight: .heavy, design: .rounded).monospacedDigit()).foregroundStyle(tint)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        // 和主页单元按钮同一套：米白底、浅金描边、厚底
        .background(RoundedRectangle(cornerRadius: 20).fill(GrowthColors.surface)
            .shadow(color: GrowthColors.cardEdge, radius: 0, x: 0, y: 4))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(GrowthColors.cardEdge, lineWidth: 2))
    }

    private func rewards(_ g: GrowthResult) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                rewardTile(icon: "⭐", title: "经验", value: g.xp, full: g.reduced ? g.fullXP : nil,
                           fill: Theme.jade, edge: GrowthColors.jadeDark, text: .white)
                rewardTile(icon: nil, title: "总积分", value: g.totalCoins, full: nil,
                           fill: GrowthColors.gold, edge: GrowthColors.goldDark, text: Color(red: 0.36, green: 0.25, blue: 0))
            }
            Text("每日上限：答题 \(session.rules.coinLimit(.answers)) · 过关 \(session.rules.coinLimit(.completion)) · 首胜 \(session.rules.coinLimit(.firstWin)) · 升级 \(session.rules.coinLimit(.level)) · 徽章 \(session.rules.coinLimit(.badge))")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.muted)
            if g.reduced {
                HintCapsule(icon: "😴", text: "今天玩了 \(g.gamesToday) 局，基础奖励减半，积分按每日剩余额度发放", tint: GrowthColors.calm)
            } else if g.dailyFirstWin {
                let p = GrowthCatalog.bundled.pacing.daily
                HintCapsule(icon: "🔥", text: "今天第一次通关：+\(p.firstWinXP) 经验 · +\(p.firstWinCoins) 积分（已计入）")
            } else if !won {
                HintCapsule(icon: "🌱", text: "答对的题也有奖励！通关还能拿星星和通关奖励", tint: GrowthColors.jadeDark)
            } else if session.stars < 3 {
                HintCapsule(icon: "💡", text: "3 星：第一次就答对九成，而且一颗心都不丢")
            }
        }
    }

    private func rewardTile(icon: String?, title: String, value: Int, full: Int?, fill: Color, edge: Color, text: Color) -> some View {
        HStack(spacing: 10) {
            if let icon { PictureView(emoji: icon, size: 34) } else { CoinIcon(size: 34) }
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.system(size: 14, weight: .bold, design: .rounded)).opacity(0.85)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("+\(value)").font(.system(size: 28, weight: .black, design: .rounded).monospacedDigit())
                    if let full {
                        Text("\(full)").strikethrough().font(.system(size: 16, weight: .bold, design: .rounded)).opacity(0.6)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(text)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 60)
        .background(RoundedRectangle(cornerRadius: 20).fill(fill).shadow(color: edge, radius: 0, x: 0, y: 5))
    }

    // MARK: - 右栏：成长 + 记一记

    private var growthColumn: some View {
        VStack(spacing: 12) {
            if let growth {
                levelCard(growth)
                if !(growth.gifts + growth.unlocked).isEmpty || !growth.newBadges.isEmpty { gainsCard(growth) }
            }
            if !session.mistakes.isEmpty { notebook }
        }
        .frame(maxWidth: .infinity)
    }

    private func levelCard(_ g: GrowthResult) -> some View {
        let catalog = GrowthCatalog.bundled
        let next = catalog.cosmetics.first { $0.unlockLevel == g.after.level + 1 && !$0.isOriginal }
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                LevelBadge(level: g.after.level, size: 24)
                VStack(alignment: .leading, spacing: 0) {
                    if g.leveledUp {
                        Text("Lv.\(g.before.level) → Lv.\(g.after.level)").font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.accent)
                    }
                    Text(g.leveledUp ? "升级啦！" : (won ? "经验在长大！" : "答对就有经验！"))
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundStyle(g.leveledUp ? Theme.accent : GrowthColors.jadeDark)
                }
                Spacer()
                if g.levelCoins > 0 {
                    HStack(spacing: 4) {
                        CoinIcon(size: 20)
                        Text("升级奖励 +\(g.levelCoins)")
                    }
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(GrowthColors.jadeDark)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Capsule().fill(Theme.jade.opacity(0.15)))
                }
            }
            XPBar(progress: g.after, gained: g.leveledUp ? 0 : g.xp, height: 24)
            HStack {
                Text("Lv.\(g.after.level)　\(g.after.xpIntoLevel) / \(g.after.xpForNext) 经验")
                    .foregroundStyle(GrowthColors.jadeDark)
                Spacer()
                Text("再得 \(g.after.xpToGo) 经验升级" + (next.map { "，解锁 \($0.icon) \($0.name)" } ?? ""))
                    .foregroundStyle(GrowthColors.orangeDark)
            }
            .font(.system(size: 14, weight: .heavy, design: .rounded))
            .lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(16)
        .candyCard()
    }

    /// 这一局新得到的外观和徽章，排在一张卡片里，每样一行
    private func gainsCard(_ g: GrowthResult) -> some View {
        VStack(spacing: 8) {
            ForEach(g.gifts + g.unlocked, id: \.id) { unlockRow($0) }
            ForEach(g.newBadges, id: \.id) { badgeRow($0) }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .candyCard()
    }

    private func unlockRow(_ item: CosmeticKind) -> some View {
        gainRow(title: item.name,
                tag: "Lv.\(item.unlockLevel) 解锁", tagText: GrowthColors.jadeDark, tagFill: Theme.jade.opacity(0.15),
                detail: "\(item.slot.displayName) · " + (item.price == 0 ? "升级送的，可以直接装备" : "现在可以用 \(item.price) 积分买了"),
                isNew: true) {
            PictureView(emoji: item.icon, size: 36)
                .frame(width: 52, height: 52)
                .background(RoundedRectangle(cornerRadius: 14).fill(GrowthColors.gold.opacity(0.2)))
        }
    }

    private func badgeRow(_ badge: BadgeKind) -> some View {
        gainRow(title: badge.name,
                tag: "新徽章！", tagText: GrowthColors.orangeDark, tagFill: GrowthColors.gold.opacity(0.3),
                detail: "\(badge.summary) · 积分已按每日额度计入总额", isNew: false) {
            MedalView(icon: badge.icon, earned: true, size: 40)
                .frame(width: 52, height: 52)
        }
    }

    private func gainRow<Icon: View>(title: String, tag: String, tagText: Color, tagFill: Color, detail: String, isNew: Bool,
                                     @ViewBuilder icon: () -> Icon) -> some View {
        HStack(spacing: 12) {
            icon()
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(title).font(.system(size: 20, weight: .heavy, design: .rounded))
                    Text(tag).font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(tagText)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Capsule().fill(tagFill))
                }
                Text(detail)
                    .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(Theme.muted)
                    .lineLimit(1).minimumScaleFactor(0.75)
            }
            Spacer(minLength: 0)
            if isNew {
                Text("新！").font(.system(size: 13, weight: .black, design: .rounded)).foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(Theme.wrong))
            }
        }
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.paper))
    }

    private var notebook: some View {
        MistakeNotebook(mistakes: session.mistakes)
    }
    // MARK: - 按钮

    private var buttons: some View {
        HStack(spacing: 18) {
            Button(action: onExit) {
                CandyButtonLabel(title: "回主页", icon: "🏡", fill: GrowthColors.surface, edge: GrowthColors.cardEdge, foreground: Theme.ink)
            }
            Spacer()
            if won, growth != nil {
                Button(action: onOpenCollection) {
                    CandyButtonLabel(title: "去收藏馆看看", icon: "🎁", fill: Theme.accent, edge: GrowthColors.orangeDark)
                }
            }
            Button(action: onReplay) {
                CandyButtonLabel(title: won ? "再来一局" : "再试一次", icon: "▶", fill: Theme.jade, edge: GrowthColors.jadeDark,
                                 font: .system(size: 28, weight: .heavy, design: .rounded))
            }
        }
        .buttonStyle(PressableStyle())
    }
}

/// 记一记：答错和没来得及答的题，结算后再看一遍。
/// 放得下就全部列出来；错题多、弹窗放不下时只在这个框里滚动，弹窗高度不跟着错题数变，按钮始终在一屏里
struct MistakeNotebook: View {
    let mistakes: [GameSession.Mistake]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("✏️ 记一记（\(mistakes.count)）").font(.system(size: 20, weight: .heavy, design: .rounded)).foregroundStyle(Theme.ink)
            ViewThatFits(in: .vertical) {
                list
                ScrollView { list }
                    .scrollBounceBehavior(.basedOnSize)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .candyCard()
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(mistakes) { m in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    PictureView(emoji: m.missed ? "⏰" : "✏️", size: 22)
                    Text("\(m.prompt) · " + (m.missed ? "未作答" : "需要再练习"))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 14).fill(Theme.paper))
            }
        }
    }
}
