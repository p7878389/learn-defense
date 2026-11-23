import LearnCore
import SpriteKit

/// 要出场的怪物：编号、牌子上的字、种类
struct EnemySpawn {
    let id: Int
    let sign: String
    let kind: EnemyKind
}

/// 草坪上的一个种植格
struct DefenderCell: Hashable {
    let lane: Int
    let column: Int
}

@MainActor
protocol GameSceneDelegate: AnyObject {
    /// 要生成新怪物时调用，返回 nil 表示这一局的怪物出完了
    func nextEnemy() -> EnemySpawn?
    /// 已确定实际外观后再播报，避免先报战斗类型再随机换皮。
    func bossAppeared(name: String)
    /// 当前瞄准的怪物变了（答题针对它）
    func targetChanged(to id: Int?)
    /// 怪物走到书架。返回 true 移除怪物（扣血），false 让它退回起点（不设失败）
    func enemyReachedBase(_ id: Int) -> Bool
    /// 怪物被打败，point 是它倒下的位置
    func enemyDefeated(_ id: Int, at point: CGPoint)
    /// 战斗中放下的路障（铁栅门）被啃碎了
    func barricadeRemoved()
    var speedFactor: Double { get }
    /// 孩子正在拼瞄准的这道字块题：这只怪物原地等着
    var holdsTarget: Bool { get }
    /// 首领被打到只剩最后一段血、开始暴走
    func bossEnraged(_ id: Int)
    func ultimateAnimationStarted()
    func ultimateAnimationFinished()
    func doomCooldownChanged(_ seconds: Int)
}

extension GameSceneDelegate {
    func bossAppeared(name: String) {}
    /// 默认不定住目标（测试里的简单代理不用实现）
    var holdsTarget: Bool { false }
    /// 首领被打到只剩最后一段血、开始暴走
    func bossEnraged(_ id: Int) {}
    func ultimateAnimationStarted() {}
    func ultimateAnimationFinished() {}
    func doomCooldownChanged(_ seconds: Int) {}
}
