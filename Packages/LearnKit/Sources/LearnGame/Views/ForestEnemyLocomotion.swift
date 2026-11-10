import Foundation
import LearnCore

/// 仅采样显示姿态，不推进时间或修改路径。步频由实际路程决定，减速和定身自然同步。
struct ForestEnemyLocomotion {
    let moving: Bool
    let progress: Double
    var lift = 0.0
    var lean = 0.0
    var scaleX = 1.0
    var scaleY = 1.0
    var shadowScale = 1.0
    var dustOpacity = 0.0

    init(enemy: ForestEnemy, time: Double, reduceMotion: Bool = false) {
        moving = enemy.health > 0 && enemy.cast == nil && enemy.rooted <= 0
        let heavy = [.knight, .ogre, .infernal].contains(enemy.kind)
        let frequency = enemy.fast ? 22.0 : (heavy ? 18.0 : 26.0)
        // 固定相位错开同种怪物的脚步；不使用逐帧随机数。
        let seed = Double(abs(enemy.id % 17)) * 0.0618033988
        let cycle = max(0, enemy.distance) * frequency + seed
        progress = cycle - floor(cycle)
        if enemy.kind.floating { lift = 0.007; shadowScale = 0.8 }
        guard moving, !reduceMotion else { return }

        let phase = progress * 2 * Double.pi
        let turn = min(1, max(0, enemy.turnTimer / ForestEnemy.turnTime))
        let pivot = turn > 0 ? sin((1 - turn) * .pi) : 0
        if enemy.kind.floating {
            let hover = sin(time * 2.5 + seed * 2 * .pi)
            lift += hover * 0.0015
            lean = hover * 0.7
            shadowScale -= hover * 0.06
        } else if enemy.kind == .slime {
            let stretch = sin(phase)
            scaleY = 1 + stretch * 0.045
            scaleX = 1 / scaleY
            lift = max(0, stretch) * 0.0015
            lean = cos(phase) * 0.5
            shadowScale = 1 - max(0, stretch) * 0.08
        } else if ![ForestEnemyKind.skeleton, .boar, .ogre].contains(enemy.kind),
                  !ForestRosterArtwork.hasActionSheet(enemy.kind) {
            // 巨魔已有真实跨步帧，重心变化由素材承担，避免再次整图摇摆造成滑行感。
            // 一个循环两次重心抬升，使用连续曲线，避免 abs(sin) 的尖锐落地。
            let step = (1 - cos(phase * 2)) / 2
            lift = step * (heavy ? 0.0015 : 0.0025)
            lean = sin(phase) * (heavy ? 0.9 : 1.6)
            scaleY = 1 - (1 - step) * (heavy ? 0.014 : 0.008)
            scaleX = 1 / scaleY
            shadowScale = 1 - step * 0.08
        }
        // 转身压低重心后回弹；保持宽度，避免翻面时缩成薄片。
        lift *= 1 - pivot
        lean *= 1 - pivot
        scaleX *= 1 + pivot * 0.035
        scaleY *= 1 - pivot * 0.055
        if enemy.kind == .boar {
            let landing = pow(max(0, cos(phase * 2)), 4)
            dustOpacity = min(0.85, landing * 0.55 + pivot * 0.4)
        }
    }

    func frameIndex(count: Int) -> Int {
        guard count > 0 else { return 0 }
        return min(count - 1, Int(progress * Double(count)))
    }
}
