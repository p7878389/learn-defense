import LearnCore
import SwiftUI

/// 结算页：左边这一局（星星、成绩、经验和积分），右边成长（升级 / 经验条、解锁、新徽章）和「记一记」。
/// 设计稿：docs/ui-growth/02（升级）、02b（没升级）、02c（失败）、02d（当天第 6 局起减半）
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
            ScrollView {
                VStack(spacing: 18) {
                    banner
                    HStack(alignment: .top, spacing: 20) {
                        roundColumn
                        if hasRightColumn { growthColumn }
                    }
                    buttons
                }
                .padding(.horizontal, 28)
                .padding(.top, 52)
                .padding(.bottom, 28)
                .frame(maxWidth: hasRightColumn ? 1040 : 620)
                .background(RoundedRectangle(cornerRadius: 32).fill(Theme.paper).padding(.top, 24))
                .padding(28)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    // MARK: - 横幅

    private var banner: some View {
        HStack(spacing: 12) {
            PictureView(emoji: won ? "🎉" : "💪", size: 44)
            Text(won ? "闯关成功！" : "差一点就守住了！")
                .font(.system(size: 40, weight: .heavy, design: .rounded))
            PictureView(emoji: won ? "🌟" : "📚", size: 44)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 40)
        .frame(height: 76)
        .background(
            Capsule()
                .fill(LinearGradient(colors: won ? [GrowthColors.gold, Theme.accent] : [GrowthColors.calm.opacity(0.8), GrowthColors.calm],
                                     startPoint: .top, endPoint: .bottom))
                .shadow(color: won ? GrowthColors.orangeDark : Color(red: 0.18, green: 0.31, blue: 0.54), radius: 0, x: 0, y: 6))
        .padding(.top, -64)
    }

    // MARK: - 左栏：这一局

    private var roundColumn: some View {
        VStack(spacing: 18) {
            HStack(alignment: .bottom, spacing: 14) {
                star(0, label: "通关", size: 64)
                star(1, label: "答对 7 成", size: 84)
                star(2, label: "9 成 · 满心", size: 64)
            }
            HStack(spacing: 12) {
                stat("🎯", "第一次就答对", session.attempted == 0 ? "-" : "\(session.firstTryCorrect)/\(session.attempted)")
                stat("⚡", "首答正确率", session.attempted == 0 ? "-" : "\(Int((session.accuracy * 100).rounded()))%", tint: Theme.jade)
                stat("⏱️", "用时", String(format: "%02d:%02d", session.playSeconds / 60, session.playSeconds % 60))
            }
            if let growth { rewards(growth) }
        }
        .padding(20)
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
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(earned ? GrowthColors.orangeDark : Theme.muted)
                .padding(.horizontal, 10).padding(.vertical, 3)
                .background(Capsule().fill(earned ? GrowthColors.gold.opacity(0.3) : Theme.muted.opacity(0.15)))
        }
    }

    private func stat(_ icon: String, _ title: String, _ value: String, tint: Color = Theme.ink) -> some View {
        VStack(spacing: 2) {
            Text(icon).font(.system(size: 24))
            Text(title).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(Theme.muted)
            Text(value).font(.system(size: 30, weight: .heavy, design: .rounded).monospacedDigit()).foregroundStyle(tint)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 22).fill(Theme.paper))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.muted.opacity(0.2), lineWidth: 2))
    }

    private func rewards(_ g: GrowthResult) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                rewardTile(icon: "⭐", title: "经验", value: g.xp, full: g.reduced ? g.fullXP : nil,
                           fill: Theme.jade, edge: GrowthColors.jadeDark, text: .white)
                rewardTile(icon: nil, title: "积分", value: g.coins, full: g.reduced ? g.fullCoins : nil,
                           fill: GrowthColors.gold, edge: GrowthColors.goldDark, text: Color(red: 0.36, green: 0.25, blue: 0))
            }
            if g.reduced {
                HintCapsule(icon: "😴", text: "今天玩了 \(g.gamesToday) 局，奖励减半啦。休息一下眼睛，明天再来！", tint: GrowthColors.calm)
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
            if let icon { PictureView(emoji: icon, size: 40) } else { CoinIcon(size: 40) }
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.system(size: 14, weight: .bold, design: .rounded)).opacity(0.85)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("+\(value)").font(.system(size: 32, weight: .black, design: .rounded).monospacedDigit())
                    if let full {
                        Text("\(full)").strikethrough().font(.system(size: 16, weight: .bold, design: .rounded)).opacity(0.6)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(text)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 72)
        .background(RoundedRectangle(cornerRadius: 20).fill(fill).shadow(color: edge, radius: 0, x: 0, y: 5))
    }

    // MARK: - 右栏：成长 + 记一记

    private var growthColumn: some View {
        VStack(spacing: 14) {
            if let growth {
                levelCard(growth)
                ForEach(growth.gifts + growth.unlocked, id: \.id) { unlockCard($0) }
                ForEach(growth.newBadges, id: \.id) { badgeCard($0) }
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
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
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
            XPBar(progress: g.after, gained: g.leveledUp ? 0 : g.xp, height: 28)
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
        .padding(18)
        .candyCard()
    }

    private func unlockCard(_ item: CosmeticKind) -> some View {
        HStack(spacing: 14) {
            PictureView(emoji: item.icon, size: 56)
                .frame(width: 76, height: 76)
                .background(RoundedRectangle(cornerRadius: 18).fill(GrowthColors.gold.opacity(0.2)))
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(item.name).font(.system(size: 24, weight: .heavy, design: .rounded))
                    Text("Lv.\(item.unlockLevel) 解锁").font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(GrowthColors.jadeDark)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Capsule().fill(Theme.jade.opacity(0.15)))
                }
                Text("\(item.slot.displayName) · " + (item.price == 0 ? "升级送的，可以直接装备" : "现在可以用 \(item.price) 积分买了"))
                    .font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 0)
            Text("新！").font(.system(size: 14, weight: .black, design: .rounded)).foregroundStyle(.white)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Capsule().fill(Theme.wrong))
        }
        .foregroundStyle(Theme.ink)
        .padding(14)
        .candyCard()
    }

    private func badgeCard(_ badge: BadgeKind) -> some View {
        HStack(spacing: 14) {
            MedalView(icon: badge.icon, earned: true, size: 60)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(badge.name).font(.system(size: 24, weight: .heavy, design: .rounded))
                    Text("新徽章！").font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(GrowthColors.orangeDark)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Capsule().fill(GrowthColors.gold.opacity(0.3)))
                }
                Text("\(badge.summary) · 奖励 \(badge.coins) 积分")
                    .font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(Theme.ink)
        .padding(14)
        .candyCard()
    }

    /// 记一记：答错和没来得及答的题，结算后再看一遍
    private var notebook: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("✏️ 记一记").font(.system(size: 22, weight: .heavy, design: .rounded)).foregroundStyle(Theme.ink)
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(session.mistakes) { m in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            PictureView(emoji: m.missed ? "⏰" : "✏️", size: 26)
                            Text(m.explanation ?? "\(m.prompt) → \(m.answer)")
                                .foregroundStyle(Theme.ink)
                        }
                        .font(.title3)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.paper))
                    }
                }
            }
            .frame(maxHeight: 220)
        }
        .padding(18)
        .candyCard()
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
