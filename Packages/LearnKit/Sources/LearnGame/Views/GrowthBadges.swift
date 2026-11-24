import LearnCore
import SwiftUI

/// 橙金色等级牌「Lv.5」
struct LevelBadge: View {
    let level: Int
    var size: CGFloat = 22

    var body: some View {
        Text("Lv.\(level)")
            .font(.system(size: size, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, size * 0.6)
            .padding(.vertical, size * 0.18)
            .background(Capsule().fill(LinearGradient(colors: [Theme.accent, GrowthColors.orangeDark], startPoint: .top, endPoint: .bottom)))
            .overlay(Capsule().stroke(.white, lineWidth: 2))
    }
}

/// 紫色等级牌，放在收藏馆、徽章墙顶部
struct LevelPill: View {
    let level: Int

    var body: some View {
        HStack(spacing: 6) {
            Text("🎖️")
            Text("Lv.\(level)").font(.system(size: 24, weight: .black, design: .rounded))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .frame(height: 50)
        .background(Capsule().fill(GrowthColors.purple).shadow(color: GrowthColors.purpleDark, radius: 0, x: 0, y: 4))
    }
}

/// 金色积分牌。没有「+」号：积分只能靠学习得到，没有充值入口
struct CoinPill: View {
    let coins: Int
    var size: CGFloat = 26

    var body: some View {
        HStack(spacing: 6) {
            CoinIcon(size: size * 1.1)
            Text("\(coins)").font(.system(size: size, weight: .black, design: .rounded).monospacedDigit())
                .foregroundStyle(Color(red: 0.45, green: 0.3, blue: 0.0))
            Text("积分").font(.system(size: size * 0.5, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.55, green: 0.4, blue: 0.05))
        }
        .padding(.horizontal, 18)
        .frame(height: size * 2)
        .background(Capsule().fill(GrowthColors.gold).shadow(color: GrowthColors.goldDark, radius: 0, x: 0, y: 4))
    }
}

/// 经验条。gained > 0 时把这一局得到的部分用亮绿色标出来
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
                Capsule().fill(Color(red: 0.89, green: 0.85, blue: 0.77))
                Capsule()
                    .fill(LinearGradient(colors: [GrowthColors.jadeLight, Theme.jade], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(height, geo.size.width * now / total))
                    .opacity(now > 0 ? 1 : 0)
                if gained > 0 {
                    Capsule()
                        .fill(Theme.jade)
                        .frame(width: max(old > 0 ? height : 0, geo.size.width * old / total))
                        .opacity(old > 0 ? 1 : 0)
                }
                if showsText {
                    Text("\(progress.xpIntoLevel) / \(progress.xpForNext) 经验")
                        .font(.system(size: height * 0.5, weight: .heavy, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
                        .padding(.leading, 14)
                }
            }
        }
        .frame(height: height)
        .accessibilityLabel("经验 \(progress.xpIntoLevel)，升级需要 \(progress.xpForNext)")
    }
}

/// 圆形奖章 + 两条丝带。没得到的是灰色，右下角一把小锁
struct MedalView: View {
    let icon: String
    let earned: Bool
    var size: CGFloat = 96

    var body: some View {
        ZStack(alignment: .bottom) {
            HStack(spacing: 2) {
                ribbon(earned ? Theme.wrong : Color.gray.opacity(0.5))
                ribbon(earned ? Theme.jade : Color.gray.opacity(0.4))
            }
            .offset(y: size * 0.2)
            Circle()
                .fill(earned
                      ? AnyShapeStyle(RadialGradient(colors: [.white, GrowthColors.gold.opacity(0.6)], center: .topLeading, startRadius: 2, endRadius: size))
                      : AnyShapeStyle(Color(white: 0.88)))
                .overlay(Circle().stroke(earned ? GrowthColors.goldDark : Color(white: 0.78), lineWidth: size * 0.05))
                .frame(width: size, height: size)
                .overlay(
                    PictureView(emoji: icon, size: size * 0.55)
                        .grayscale(earned ? 0 : 1)
                        .opacity(earned ? 1 : 0.45))
                .overlay(alignment: .bottomTrailing) {
                    if !earned {
                        Text("🔒").font(.system(size: size * 0.2))
                            .padding(4)
                            .background(Circle().fill(.white))
                    }
                }
                .shadow(color: .black.opacity(earned ? 0.15 : 0.05), radius: 0, x: 0, y: 4)
        }
        .padding(.bottom, size * 0.2)
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
    var tint: Color = Theme.accent

    var body: some View {
        HStack(spacing: 6) {
            Text(icon)
            Text(text).lineLimit(2).minimumScaleFactor(0.8)
        }
        .font(.system(size: 17, weight: .bold, design: .rounded))
        .foregroundStyle(tint)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Capsule().fill(tint.opacity(0.12)))
        .overlay(Capsule().stroke(tint.opacity(0.35), lineWidth: 1.5))
    }
}
