import SwiftUI
import LearnCore

struct ForestVitalBar: View {
    let ratio: Double
    var color: Color = .green
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.black.opacity(0.65))
                Capsule().fill(color).frame(width: geo.size.width * max(0, min(1, ratio)))
            }
        }
        .frame(height: 5)
    }
}

struct ForestRosterEnemyView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let enemy: ForestEnemy
    let width: CGFloat
    let height: CGFloat
    let time: Double
    var body: some View {
        let point = ForestPath.forest.point(at: enemy.distance)
        let size = width * (enemy.isBoss ? 0.13 : 0.085)
        let motion = ForestEnemyLocomotion(enemy: enemy, time: time, reduceMotion: reduceMotion)
        // 巨魔行走帧脚底 448/512；通用动作帧脚底 280/320；均对齐原视图 0.92 高度的阴影。
        let footOffset: CGFloat = ForestRosterArtwork.hasActionSheet(enemy.kind)
            ? size * (0.92 - 280.0 / 320)
            : (enemy.kind == .ogre && enemy.cast == nil ? size * (0.92 - 448.0 / 512) : 0)
        let pathPoint = ForestPath.forest.point(at: enemy.distance)
        let displayFacing = enemy.cast.map {
            abs($0.point.x - pathPoint.x) > 0.001 ? ($0.point.x > pathPoint.x ? 1.0 : -1.0) : enemy.facing
        } ?? enemy.facing
        let charge = enemy.cast?.charging == true ? enemy.cast!.progress : 0
        let release = enemy.cast?.releasing == true
        ZStack {
            Ellipse().fill(.black.opacity(0.25))
                .frame(width: size * 0.55, height: width * 0.012)
                .scaleEffect(motion.shadowScale)
                .offset(y: size * 0.42)
            ForestRosterArtwork.image(ForestRosterArtwork.locomotionPose(enemy, progress: motion.progress))
                .resizable().scaledToFit()
                .frame(width: size, height: size)
                .scaleEffect(x: displayFacing * ForestRosterArtwork.nativeFacing(enemy.kind) * motion.scaleX,
                             y: motion.scaleY * (1 - charge * 0.06), anchor: .bottom)
                .rotationEffect(.degrees(release ? -displayFacing * 7 : (motion.moving ? motion.lean * displayFacing : charge * displayFacing * 4)), anchor: .bottom)
                .offset(y: footOffset - motion.lift * width)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: motion.moving)
                .brightness(enemy.hitTimer > 0 ? 0.5 : 0)
                .colorMultiply(enemy.slowed > 0 ? Color(red: 0.65, green: 0.9, blue: 1) : .white)
            if enemy.rooted > 0 {
                Image(systemName: "leaf.fill").font(.system(size: size * 0.25))
                    .foregroundStyle(.green).offset(y: size * 0.33)
            }
            VStack(spacing: 3) {
                if enemy.isBoss { Text(enemy.kind.name).font(.system(size: max(10, width * 0.011), weight: .bold)).foregroundStyle(.white).shadow(color: .black, radius: 2) }
                ForestVitalBar(ratio: enemy.health / enemy.maxHealth, color: enemy.isBoss ? .red : .green)
                if let cast = enemy.cast, cast.charging {
                    ForestVitalBar(ratio: cast.progress, color: .orange)
                    if cast.skill { Text(enemy.kind.skillName).font(.system(size: 10, weight: .bold)).foregroundStyle(.yellow).shadow(color: .black, radius: 2) }
                }
            }
            .frame(width: size * 0.8)
            .offset(y: -size * 0.48)
        }
        .position(x: point.x * width, y: point.y * height - size * 0.4)
        .task(id: enemy.kind) { await ForestRosterArtwork.preload(enemy.kind) }
        .allowsHitTesting(false)
    }
}

struct ForestHeroView: View {
    let unit: ForestDefenseUnit
    let slot: Int
    let width: CGFloat
    let height: CGFloat
    var body: some View {
        let point = ForestBattle.slots[slot]
        let size = width * 0.105
        let cast = unit.cast
        let facing = (cast?.point.x ?? (point.x + 1)) >= point.x ? 1.0 : -1.0
        let charge = cast?.charging == true ? cast!.progress : 0
        ForestRosterArtwork.image(unit.hero!.rawValue).resizable().scaledToFit()
            .frame(width: size, height: size)
            .scaleEffect(x: facing, y: 1, anchor: .bottom)
            .rotationEffect(.degrees((cast?.releasing == true ? -8 : charge * 6) * facing), anchor: .bottom)
            .brightness(unit.hitTimer > 0 ? 0.5 : 0)
            .opacity(unit.alive ? 1 : 0.25)
            .saturation(unit.alive ? 1 : 0)
            .position(x: point.x * width, y: point.y * height - size * 0.38)
            .allowsHitTesting(false)
    }
}

/// 游戏状态驱动的独立弹道与地面效果；不把技能爆炸烘焙进行走帧。
struct ForestCombatOverlay: View {
    let battle: ForestBattle
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        Canvas { context, _ in
            for zone in battle.zones {
                let center = pixel(zone.point)
                let r = zone.radius * width
                let rect = Self.footprint(at: zone.point, radius: zone.radius, width: width, height: height)
                let opacity = min(0.28, zone.remaining * 0.28)
                context.fill(Path(ellipseIn: rect), with: .color(tint(zone.effect).opacity(opacity)))
                context.stroke(Path(ellipseIn: rect), with: .color(tint(zone.effect).opacity(0.7)), lineWidth: 2)
                if zone.effect == .vines {
                    for i in 0..<5 {
                        let x = center.x + CGFloat(i - 2) * r * 0.3
                        var stem = Path()
                        stem.move(to: CGPoint(x: x, y: center.y))
                        stem.addQuadCurve(to: CGPoint(x: x + 12, y: center.y - 24), control: CGPoint(x: x - 12, y: center.y - 16))
                        context.stroke(stem, with: .color(.green), lineWidth: 3)
                    }
                }
            }
            for enemy in battle.enemies {
                if let cast = enemy.cast, cast.charging {
                    let center = pixel(cast.point)
                    // 范围技按真实波及范围预警；单体攻击只在被锁定的塔位脚下画小圈。
                    let area = Self.warningRadius(of: enemy, rules: battle.rules)
                    let r = width * 0.025
                    let rect = area > 0
                        ? Self.footprint(at: cast.point, radius: area, width: width, height: height)
                        : CGRect(x: center.x - r, y: center.y - r * 0.4, width: r * 2, height: r * 0.8)
                    context.stroke(Path(ellipseIn: rect), with: .color(.orange.opacity(0.4 + cast.progress * 0.6)),
                                   style: StrokeStyle(lineWidth: 2 + cast.progress * 2, dash: [5, 4]))
                    drawCharge(context: &context, enemy: enemy, cast: cast)
                }
            }
            for shot in battle.combatShots {
                let start = bodyPoint(shot.origin)
                let end = bodyPoint(shot.point)
                let color = tint(shot.effect)
                if shot.age < shot.flight {
                    let p = min(1, shot.age / shot.flight)
                    let here = trajectory(start, end, p, shot.effect.arc * width)
                    var trail = Path()
                    for n in 0...8 {
                        let progress = max(0, p - Double(8 - n) * 0.025)
                        let point = trajectory(start, end, progress, shot.effect.arc * width)
                        if n == 0 { trail.move(to: point) } else { trail.addLine(to: point) }
                    }
                    context.stroke(trail, with: .color(color.opacity(0.5)), lineWidth: 4)
                    let radius: CGFloat = shot.skill ? 7 : 5
                    context.fill(Path(ellipseIn: CGRect(x: here.x - radius, y: here.y - radius, width: radius * 2, height: radius * 2)), with: .color(color))
                    if [.soul, .scarab, .meteor, .flask].contains(shot.effect) {
                        let symbol = shot.effect == .soul ? "☠" : (shot.effect == .scarab ? "◆" : (shot.effect == .meteor ? "✦" : "◈"))
                        context.draw(Text(symbol).font(.system(size: 17, weight: .black)).foregroundColor(color), at: here)
                    }
                } else {
                    let p = min(1, (shot.age - shot.flight) / 0.45)
                    drawImpact(context: &context, effect: shot.effect, at: end,
                               radius: shot.radius, progress: p)
                }
            }
        }
        .frame(width: width, height: height)
        .allowsHitTesting(false)
    }

    /// 敌人蓄力时预警的范围半径（归一化坐标）；0 表示单体攻击，只标出被锁定的塔位。
    static func warningRadius(of enemy: ForestEnemy, rules: ForestRules) -> Double {
        enemy.cast?.skill == true ? rules.enemy(enemy.kind).skillRadius : 0
    }
    /// 范围效果在画面上的落地椭圆。判定用的是归一化坐标里的圆，换算到画面横向乘宽、纵向乘高，
    /// 这样圈内的塔位正好是会被波及的塔位。
    static func footprint(at point: ForestPoint, radius: Double, width: CGFloat, height: CGFloat) -> CGRect {
        CGRect(x: (point.x - radius) * width, y: (point.y - radius) * height,
               width: radius * 2 * width, height: radius * 2 * height)
    }

    /// 0.45 秒命中特效分六阶段：出现、展开、峰值、碎散、衰减、收尾。
    static func impactStage(_ progress: Double) -> Int {
        min(5, max(0, Int(min(0.999_999, max(0, progress)) * 6)))
    }

    static func impactParticleCount(stage: Int) -> Int {
        [4, 8, 12, 10, 6, 2][min(5, max(0, stage))]
    }

    private func drawCharge(context: inout GraphicsContext, enemy: ForestEnemy, cast: ForestCast) {
        let origin = bodyPoint(ForestPath.forest.point(at: enemy.distance))
        let color = tint(cast.effect)
        let pulse = 0.75 + 0.25 * sin(cast.progress * .pi * 4)
        let radius = width * (0.006 + 0.006 * pulse)
        context.fill(Path(ellipseIn: CGRect(x: origin.x - radius, y: origin.y - radius,
                                            width: radius * 2, height: radius * 2)),
                     with: .color(color.opacity(0.45 + 0.45 * cast.progress)))
        for index in 0..<4 {
            let angle = cast.progress * 5 + Double(index) * .pi / 2
            let orbit = width * (0.018 + 0.006 * pulse)
            let point = CGPoint(x: origin.x + cos(angle) * orbit, y: origin.y + sin(angle) * orbit * 0.65)
            context.fill(Path(ellipseIn: CGRect(x: point.x - 2, y: point.y - 2, width: 4, height: 4)),
                         with: .color(color.opacity(0.9)))
        }
    }

    private func drawImpact(context: inout GraphicsContext, effect: ForestCombatEffect,
                            at end: CGPoint, radius: Double, progress: Double) {
        let stage = Self.impactStage(progress)
        let color = tint(effect)
        let fade = pow(1 - progress, 1.25)
        let peak = sin(min(1, progress * 1.7) * .pi * 0.5)
        let impactRadius = width * (radius > 0
            ? radius * min(1, 0.22 + 0.78 * peak)
            : 0.018 + 0.026 * peak)
        let rect = CGRect(x: end.x - impactRadius, y: end.y - impactRadius * 0.58,
                          width: impactRadius * 2, height: impactRadius * 1.16)
        context.stroke(Path(ellipseIn: rect), with: .color(color.opacity(0.9 * fade)),
                       lineWidth: max(1, 5 * fade))

        var slash = Path()
        slash.move(to: CGPoint(x: end.x - impactRadius, y: end.y + impactRadius * 0.35))
        slash.addQuadCurve(to: CGPoint(x: end.x + impactRadius, y: end.y - impactRadius * 0.35),
                           control: CGPoint(x: end.x + impactRadius * 0.2, y: end.y + impactRadius))
        context.stroke(slash, with: .color(.white.opacity(0.65 * fade)),
                       lineWidth: max(1, 4 * fade))

        let count = Self.impactParticleCount(stage: stage)
        for index in 0..<count {
            let angle = Double(index) * 2.399_963 + progress * 2.2
            let distance = impactRadius * (0.35 + 0.65 * progress) * (0.72 + 0.28 * sin(Double(index) * 1.7))
            let point = CGPoint(x: end.x + cos(angle) * distance,
                                y: end.y + sin(angle) * distance * 0.65)
            let particleSize = max(1.5, (5 - Double(stage) * 0.55) * fade)
            let particle = CGRect(x: point.x - particleSize, y: point.y - particleSize,
                                  width: particleSize * 2, height: particleSize * 2)
            context.fill(Path(ellipseIn: particle), with: .color(color.opacity(0.9 * fade)))
        }

        // 属性轮廓只在峰值阶段出现，不把大面积闪光拖到恢复阶段。
        if stage == 2 || stage == 3 {
            let symbol: String
            switch effect {
            case .frost: symbol = "❄"
            case .fire, .meteor: symbol = "✦"
            case .acid, .flask: symbol = "●"
            case .soul, .shadow: symbol = "☠"
            case .scarab, .sandstorm: symbol = "◆"
            case .stone, .smash: symbol = "✹"
            default: symbol = "⚡"
            }
            context.draw(Text(symbol).font(.system(size: max(12, width * 0.018), weight: .black))
                .foregroundColor(color.opacity(0.85 * fade)), at: end)
        }
    }

    private func pixel(_ point: ForestPoint) -> CGPoint { CGPoint(x: point.x * width, y: point.y * height) }
    private func bodyPoint(_ point: ForestPoint) -> CGPoint { CGPoint(x: point.x * width, y: point.y * height - width * 0.035) }
    private func trajectory(_ a: CGPoint, _ b: CGPoint, _ p: Double, _ arc: CGFloat) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * p, y: a.y + (b.y - a.y) * p - sin(p * .pi) * arc)
    }
    private func tint(_ effect: ForestCombatEffect) -> Color {
        switch effect {
        case .slash, .frost: .cyan
        case .soul, .shadow: .purple
        case .scarab, .sandstorm, .holy, .shield, .repair: .yellow
        case .acid, .seed, .vines: .green
        case .flask: .mint
        case .fire, .meteor, .smash: .orange
        case .crossSlash: .red
        case .stone: .gray
        }
    }
}

struct ForestDefenseStatusView: View {
    let unit: ForestDefenseUnit
    let slot: Int
    let width: CGFloat
    let height: CGFloat
    var selected = false
    var body: some View {
        let point = ForestBattle.slots[slot]
        VStack(spacing: 2) {
            Text(unit.alive ? (unit.hero?.name ?? "炮塔") : "已损毁 · 可修复")
                .font(.system(size: max(9, width * 0.01), weight: .bold))
                .foregroundStyle(unit.alive ? .white : .orange)
                .shadow(color: .black, radius: 2)
            ForestVitalBar(ratio: unit.health / unit.maxHealth, color: unit.shield > 0 ? .yellow : .green)
            if let cast = unit.cast, cast.charging { ForestVitalBar(ratio: cast.progress, color: .cyan) }
        }
        .frame(width: width * 0.075)
        .position(x: point.x * width, y: point.y * height - width * 0.105)
        .overlay {
            if selected || unit.shield > 0 {
                Ellipse().stroke(unit.shield > 0 ? Color.yellow : .white, lineWidth: 3)
                    .frame(width: width * 0.095, height: width * 0.045)
                    .position(x: point.x * width, y: point.y * height)
            }
        }
        .allowsHitTesting(false)
    }
}
