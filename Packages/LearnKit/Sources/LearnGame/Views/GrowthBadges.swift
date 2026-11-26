import LearnCore
import SwiftUI

private enum LocalArt {
    /// 金色积分牌上的深褐金数字墨色，保证高对比度
    static let coinText = Color(red: 0.42, green: 0.26, blue: 0.0)
    /// 金色积分牌上的深褐金单位文字色
    static let coinSubtext = Color(red: 0.52, green: 0.36, blue: 0.04)
    /// 经验条暖羊皮纸凹槽底色
    static let xpTrackFill = Color(red: 0.90, green: 0.86, blue: 0.77)
    /// 未解锁奖章的银灰金属高光色
    static let lockedMedalTop = Color(white: 0.92)
    /// 未解锁奖章的银灰金属底色
    static let lockedMedalBottom = Color(white: 0.84)
    /// 未解锁奖章的银灰金属描边色
    static let lockedMedalEdge = Color(white: 0.74)
}

/// 橙金色等级牌「Lv.5」
struct LevelBadge: View {
    let level: Int
    var size: CGFloat = 20

    var body: some View {
        Text("Lv.\(level)")
            .font(AppFont.digits(size, weight: .black))
            .foregroundStyle(.white)
            .padding(.horizontal, size * 0.6)
            .padding(.vertical, size * 0.2)
            .background(
                Capsule()
                    .fill(LinearGradient(colors: [AppColor.accentTop, AppColor.accentEdge], startPoint: .top, endPoint: .bottom))
            )
            .overlay(Capsule().strokeBorder(.white, lineWidth: 2))
            .shadow(color: AppColor.accentEdge.opacity(0.28), radius: 4, y: 2)
    }
}

/// 紫色等级牌，放在收藏馆、徽章墙顶部
struct LevelPill: View {
    let level: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "rosette")
                .font(AppFont.rounded(18, weight: .black))
            Text("Lv.\(level)")
                .font(AppFont.digits(20, weight: .black))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, AppSpacing.md)
        .frame(height: 42.5)
        .padding(.bottom, 3.5)
        .background {
            ZStack(alignment: .top) {
                Capsule().fill(AppColor.violetEdge)
                Capsule()
                    .fill(LinearGradient(colors: [AppColor.violetTop, AppColor.violet], startPoint: .top, endPoint: .bottom))
                    .overlay(Capsule().strokeBorder(.white.opacity(0.45), lineWidth: 1.5))
                    .padding(.bottom, 3.5)
            }
        }
    }
}

/// 金色积分牌。没有「+」号：积分只能靠学习得到，没有充值入口
struct CoinPill: View {
    let coins: Int
    var size: CGFloat = 22

    private var pillHeight: CGFloat { max(44, size * 2) }

    var body: some View {
        HStack(spacing: 6) {
            CoinIcon(size: size * 1.1)
            Text("\(coins)")
                .font(AppFont.digits(size, weight: .black))
                .foregroundStyle(LocalArt.coinText)
            Text("积分")
                .font(AppFont.rounded(max(12, size * 0.54), weight: .heavy))
                .foregroundStyle(LocalArt.coinSubtext)
        }
        .padding(.horizontal, AppSpacing.md)
        .frame(height: pillHeight - 3.5)
        .padding(.bottom, 3.5)
        .background {
            ZStack(alignment: .top) {
                Capsule()
                    .fill(AppColor.goldEdge)
                    .shadow(color: AppColor.goldEdge.opacity(0.22), radius: 6, y: 3)
                Capsule()
                    .fill(LinearGradient(colors: [AppColor.goldLight, AppColor.gold], startPoint: .top, endPoint: .bottom))
                    .overlay(Capsule().strokeBorder(.white.opacity(0.6), lineWidth: 1.5))
                    .overlay(Capsule().strokeBorder(AppColor.goldEdge.opacity(0.75), lineWidth: 1.2))
                    .padding(.bottom, 3.5)
            }
        }
    }
}

/// 经验条（带内槽阴影与瓷釉顶部高光）。gained > 0 时把这一局得到的部分用亮绿色标出来
struct XPBar: View {
    let progress: LevelProgress
    var gained = 0
    var height: CGFloat = 30
    var showsText = true

    var body: some View {
        GeometryReader { geo in
            let total = max(1, CGFloat(progress.xpForNext))
            let now = CGFloat(progress.xpIntoLevel)
            let old = max(0, now - CGFloat(gained))
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(LocalArt.xpTrackFill)
                    .overlay(Capsule().strokeBorder(AppColor.cardStroke.opacity(0.8), lineWidth: 1.5))
                if now > 0 {
                    Capsule()
                        .fill(LinearGradient(colors: [AppColor.jadeLight, AppColor.jadeTop, AppColor.jade],
                                             startPoint: .top, endPoint: .bottom))
                        .overlay(alignment: .top) {
                            Capsule()
                                .fill(.white.opacity(0.45))
                                .frame(height: max(3, height * 0.24))
                                .padding(.horizontal, 6)
                                .padding(.top, 3)
                        }
                        .frame(width: min(geo.size.width, max(height, geo.size.width * now / total)))
                }
                if gained > 0, old > 0 {
                    Capsule()
                        .fill(AppColor.jadeBottom)
                        .frame(width: min(geo.size.width, max(height, geo.size.width * old / total)))
                }
                if showsText {
                    Text("\(progress.xpIntoLevel) / \(progress.xpForNext) 经验")
                        .font(AppFont.digits(max(13, height * 0.48), weight: .heavy))
                        .foregroundStyle(now > 0 ? .white : AppColor.ink.opacity(0.65))
                        .shadow(color: now > 0 ? .black.opacity(0.24) : .clear, radius: 1, y: 1)
                        .padding(.leading, 14)
                }
            }
        }
        .frame(height: height)
        .accessibilityLabel("经验 \(progress.xpIntoLevel)，升级需要 \(progress.xpForNext)")
    }
}

/// 圆形奖章 + 两条丝带。金属光泽双环，未得到为柔和灰阶加锁
struct MedalView: View {
    let icon: String
    let earned: Bool
    var size: CGFloat = 96

    var body: some View {
        ZStack(alignment: .bottom) {
            HStack(spacing: 3) {
                ribbon(earned ? AppColor.dangerSolidBottom : AppColor.disabledEdge)
                ribbon(earned ? AppColor.jade : AppColor.disabledFill)
            }
            .offset(y: size * 0.19)
            Circle()
                .fill(
                    earned
                        ? AnyShapeStyle(RadialGradient(
                            colors: [.white, AppColor.goldLight, AppColor.gold],
                            center: .topLeading, startRadius: 2, endRadius: size * 0.95
                        ))
                        : AnyShapeStyle(LinearGradient(
                            colors: [LocalArt.lockedMedalTop, LocalArt.lockedMedalBottom],
                            startPoint: .top, endPoint: .bottom
                        ))
                )
                .overlay(Circle().strokeBorder(earned ? AppColor.goldEdge : LocalArt.lockedMedalEdge, lineWidth: max(2.5, size * 0.055)))
                .overlay(Circle().inset(by: size * 0.09).strokeBorder(.white.opacity(earned ? 0.65 : 0.35), lineWidth: 1.5))
                .frame(width: size, height: size)
                .overlay(
                    PictureView(emoji: icon, size: size * 0.54)
                        .grayscale(earned ? 0 : 1)
                        .opacity(earned ? 1 : 0.42)
                )
                .overlay(alignment: .bottomTrailing) {
                    if !earned {
                        Image(systemName: "lock.fill")
                            .font(AppFont.rounded(size * 0.17, weight: .bold))
                            .foregroundStyle(AppColor.muted)
                            .padding(size * 0.06)
                            .background(Circle().fill(.white).overlay(Circle().strokeBorder(AppColor.cardStroke, lineWidth: 1)))
                    }
                }
                .shadow(color: (earned ? AppColor.goldEdge : .black).opacity(earned ? 0.25 : 0.08), radius: earned ? 8 : 3, y: 4)
        }
        .padding(.bottom, size * 0.19)
    }

    private func ribbon(_ color: Color) -> some View {
        Ribbon().fill(color).frame(width: size * 0.22, height: size * 0.3)
    }
}

/// 丝带尾巴：底部开一个三角口
private struct Ribbon: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - rect.height * 0.3))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// 一行小提示胶囊
struct HintCapsule: View {
    let icon: String
    let text: String
    var tint: Color = AppColor.accent

    var body: some View {
        HStack(spacing: 6) {
            Text(icon)
            Text(text).lineLimit(2).minimumScaleFactor(0.8)
        }
        .font(AppFont.body)
        .foregroundStyle(tint)
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.xs)
        .frame(maxWidth: .infinity)
        .background(Capsule().fill(tint.opacity(0.11)))
        .overlay(Capsule().strokeBorder(tint.opacity(0.32), lineWidth: 1.5))
    }
}
