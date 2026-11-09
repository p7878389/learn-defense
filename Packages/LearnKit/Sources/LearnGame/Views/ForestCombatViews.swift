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
    let enemy: ForestEnemy
    let width: CGFloat
    let height: CGFloat
    let time: Double
    var body: some View {
        let point = ForestPath.forest.point(at: enemy.distance)
        let size = width * (enemy.isBoss ? 0.13 : 0.085)
        let stride = sin(enemy.distance * 150)
        let moving = enemy.cast == nil && enemy.rooted <= 0
        let bob = moving ? abs(stride) * width * 0.003 : 0
        let charge = enemy.cast?.charging == true ? enemy.cast!.progress : 0
        let release = enemy.cast?.releasing == true
        ZStack {
            Ellipse().fill(.black.opacity(0.25))
                .frame(width: size * 0.55, height: width * 0.012)
                .offset(y: size * 0.42)
            ForestRosterArtwork.image(ForestRosterArtwork.pose(enemy.kind, cast: enemy.cast))
                .resizable().scaledToFit()
                .frame(width: size, height: size)
                .scaleEffect(x: enemy.facing, y: 1 - charge * 0.06, anchor: .bottom)
                .rotationEffect(.degrees(release ? -enemy.facing * 7 : (moving ? stride * 2 : charge * enemy.facing * 4)), anchor: .bottom)
                .offset(y: -bob - (enemy.kind.floating ? width * 0.007 : 0))
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
                let rect = CGRect(x: center.x - r, y: center.y - r * 0.38, width: r * 2, height: r * 0.76)
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
                    let r = width * (cast.skill ? 0.055 : 0.025)
                    let rect = CGRect(x: center.x - r, y: center.y - r * 0.4, width: r * 2, height: r * 0.8)
                    context.stroke(Path(ellipseIn: rect), with: .color(.orange.opacity(0.4 + cast.progress * 0.6)),
                                   style: StrokeStyle(lineWidth: 2 + cast.progress * 2, dash: [5, 4]))
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
                    let r = width * (shot.skill ? 0.055 : 0.025) * (0.3 + p)
                    let rect = CGRect(x: end.x - r, y: end.y - r * 0.55, width: r * 2, height: r * 1.1)
                    context.stroke(Path(ellipseIn: rect), with: .color(color.opacity(1 - p)), lineWidth: max(1, 5 * (1 - p)))
                    for n in 0..<8 {
                        let a = Double(n) * .pi / 4
                        var ray = Path()
                        ray.move(to: CGPoint(x: end.x + cos(a) * r * 0.4, y: end.y + sin(a) * r * 0.4))
                        ray.addLine(to: CGPoint(x: end.x + cos(a) * r, y: end.y + sin(a) * r))
                        context.stroke(ray, with: .color(color.opacity(1 - p)), lineWidth: 2)
                    }
                    if [.slash, .holy, .crossSlash, .fire].contains(shot.effect) {
                        var slash = Path()
                        slash.move(to: CGPoint(x: end.x - r, y: end.y + r * 0.4))
                        slash.addQuadCurve(to: CGPoint(x: end.x + r, y: end.y - r * 0.4), control: CGPoint(x: end.x + r, y: end.y + r))
                        context.stroke(slash, with: .color(color.opacity(1 - p)), lineWidth: 6 * (1 - p))
                    }
                }
            }
        }
        .frame(width: width, height: height)
        .allowsHitTesting(false)
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
