import LearnCore
import SpriteKit

/// 独立冒险只渲染引擎状态和事件；复用现有场景部件、动画与 .sks 特效。
@MainActor
final class AdventureScene: SKScene {
    var onAdvance: ((Double) -> Void)?
    private let loadout: Loadout
    private let lawn = Lawn(lanes: 5)
    private var towerNodes: [Int: DefenderNode] = [:]
    private var enemyNodes: [Int: EnemyNode] = [:]
    private var displayedHealth: [Int: Int] = [:]
    private var previousTime: TimeInterval?
    private var pausedGameplay = true
    private var freezesAnimations = false
    private var built = false

    init(loadout: Loadout) {
        self.loadout = loadout
        super.init(size: GameScene.designSize)
        scaleMode = .aspectFit
        backgroundColor = Palette.paper
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func didMove(to view: SKView) {
        guard !built else { return }
        built = true
        Backdrop(theme: .meadow, size: size, skyHeight: 80, lawn: lawn, baseWidth: 64, map: .woodland).build(in: self)
    }

    override func update(_ currentTime: TimeInterval) {
        let delta = previousTime.map { max(0, min(0.1, currentTime - $0)) } ?? 0
        previousTime = currentTime
        guard !pausedGameplay, delta > 0 else { return }
        onAdvance?(delta)
    }

    func setPaused(_ paused: Bool) {
        pausedGameplay = paused
        guard freezesAnimations != paused else { return }
        freezesAnimations = paused
        previousTime = nil
        speed = paused ? 0 : 1
        FXLibrary.setPaused(paused, in: self)
    }

    func render(_ battle: AdventureBattle, events: [AdventureEvent]) {
        // 先建立事件里刚出现的怪物，允许一次推进跨过出生与死亡（恢复或测试）。
        for event in events {
            if case .spawned(let enemy) = event { addEnemy(enemy) }
        }
        for tower in battle.towers where towerNodes[tower.id] == nil {
            guard let kind = AdventureCatalog.defender(tower.kindID) else { continue }
            let node = DefenderNode(kind: kind, radius: 32, skin: loadout.defenderSkins[kind.id])
            node.lane = tower.lane
            node.position = CGPoint(x: tower.x, y: lawn.laneY(tower.lane))
            node.zPosition = 5
            addChild(node)
            towerNodes[tower.id] = node
        }
        for enemy in battle.enemies { addEnemy(enemy) }

        for event in events {
            switch event {
            case .shot(let tower, let target):
                guard let node = towerNodes[tower.id], let enemy = enemyNodes[target.id], let attack = node.attack else { continue }
                node.shoot()
                let point = CGPoint(x: target.x, y: node.muzzle.y)
                attack.perform(from: node.muzzle, to: point, projectile: loadout.projectile(for: node.kind), in: self) {
                    [weak enemy] _ in enemy?.flash()
                }
            case .defeated(let enemy):
                guard let node = enemyNodes.removeValue(forKey: enemy.id) else { continue }
                displayedHealth[enemy.id] = nil
                node.doomed = true
                let effect = loadout.defeat(for: node.kind)
                node.run(.sequence([.wait(forDuration: 0.45), .run { [weak node] in
                    guard let node else { return }
                    node.defeat(with: effect, burnt: false)
                }]))
            case .leaked(let enemy):
                displayedHealth[enemy.id] = nil
                enemyNodes.removeValue(forKey: enemy.id)?.breakThrough()
            case .towerBroken(let tower):
                towerNodes.removeValue(forKey: tower.id)?.crumble()
            case .ultimate:
                for node in enemyNodes.values {
                    FXLibrary.playResource("AstralImpact", at: node.position, in: self)?.setScale(2)
                }
            case .spawned, .wave:
                break
            }
        }

        let livingTowers = Set(battle.towers.map(\.id))
        for id in Array(towerNodes.keys) where !livingTowers.contains(id) {
            towerNodes.removeValue(forKey: id)?.removeFromParent()
        }
        for tower in battle.towers { towerNodes[tower.id]?.showDurability(tower.durability / tower.maxDurability) }
        for enemy in battle.enemies {
            guard let node = enemyNodes[enemy.id] else { continue }
            node.position.x = enemy.x
            if displayedHealth[enemy.id] != enemy.health {
                displayedHealth[enemy.id] = enemy.health
                let segments = max(1, enemy.kind.artwork.hp)
                node.health = Health(max: segments)
                node.health.take(segments - max(1, Int(ceil(Double(enemy.health) / Double(enemy.maxHealth) * Double(segments)))))
                node.setSign("\(enemy.health) / \(enemy.maxHealth)")
                node.showHealth()
            }
            let chewing = battle.towers.contains { $0.lane == enemy.lane && abs($0.x + 36 - enemy.x) < 2 }
            node.setChewing(chewing)
        }
        setPaused(battle.phase == .paused)
        pausedGameplay = battle.phase != .playing
        // 准备和结算阶段保留角色待机、子弹及退场动画。
        if battle.phase != .paused { speed = 1 }
    }

    private func addEnemy(_ enemy: AdventureEnemy) {
        guard enemyNodes[enemy.id] == nil else { return }
        let appearance: String?
        if enemy.kind == .boss { appearance = nil }
        else if loadout.enemyAppearances.isEmpty { appearance = loadout.enemyAppearance }
        else { appearance = loadout.enemyAppearances[enemy.id % loadout.enemyAppearances.count] }
        let node = EnemyNode(id: enemy.id, kind: enemy.kind.artwork, sign: "\(enemy.health)", lane: enemy.lane,
                             scale: 0.9, skin: loadout.enemySkin, boss: enemy.kind == .boss, appearance: appearance,
                             defaultAppearance: appearance == nil)
        node.position = CGPoint(x: enemy.x, y: lawn.laneY(enemy.lane))
        node.zPosition = CGFloat(15 - enemy.lane)
        addChild(node)
        enemyNodes[enemy.id] = node
        node.appear()
    }
}
