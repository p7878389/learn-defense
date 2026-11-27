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
    private var pendingFlight: [Int: TimeInterval] = [:]
    private var previousTime: TimeInterval?
    private var pausedGameplay = true
    private var freezesAnimations = false
    private var built = false
    private let doomArtwork = AdventureDoomArtwork()

    init(loadout: Loadout) {
        self.loadout = loadout
        super.init(size: GameScene.designSize)
        scaleMode = .fill
        backgroundColor = Palette.paper
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 冒险战场铺满视口，横纵方向分别换算，保持拖放、预览和渲染一致。
    static func scenePoint(at location: CGPoint, in frame: CGRect) -> CGPoint? {
        guard frame.width > 0, frame.height > 0, frame.contains(location) else { return nil }
        return CGPoint(x: (location.x - frame.minX) * GameScene.designSize.width / frame.width,
                       y: (frame.maxY - location.y) * GameScene.designSize.height / frame.height)
    }

    override func didMove(to view: SKView) {
        guard !built else { return }
        built = true
        Backdrop(theme: .meadow, size: size, skyHeight: 80, lawn: lawn, baseWidth: 64, map: .woodland).build(in: self)
        fitCharactersToViewport()
    }

    override func update(_ currentTime: TimeInterval) {
        fitCharactersToViewport()
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
            if kind.canShoot {
                IceCombatEffects.decorate(node, projectile: loadout.projectile(for: kind), radius: 32)
            }
            node.lane = tower.lane
            node.position = CGPoint(x: tower.x, y: lawn.laneY(tower.lane))
            node.zPosition = 5
            addChild(node)
            towerNodes[tower.id] = node
        }
        for enemy in battle.enemies {
            addEnemy(enemy)
        }

        enum DamageCause {
            case shot(lane: Int, targetID: Int, isBeam: Bool)
            case blast
        }
        var lastCause: DamageCause?

        for event in events {
            switch event {
            case .shot(let tower, let target):
                let isBeam = tower.kindID == "stroke"
                lastCause = .shot(lane: tower.lane, targetID: target.id, isBeam: isBeam)
                guard let node = towerNodes[tower.id], let enemy = enemyNodes[target.id], let attack = node.attack else { continue }
                enemy.position.x = target.x
                enemy.hold()
                node.shoot()
                let point = CGPoint(x: target.x, y: node.muzzle.y)
                let effect = loadout.defeat(for: enemy.kind)
                let flight = attack.totalDuration(from: node.muzzle, to: point)
                pendingFlight[target.id] = max(pendingFlight[target.id] ?? 0, flight)
                attack.perform(
                    from: node.muzzle,
                    to: point,
                    projectile: loadout.projectile(for: node.kind),
                    in: self,
                    destination: { [weak enemy] in CGPoint(x: enemy?.position.x ?? point.x, y: point.y) }
                ) { [weak self, weak enemy] isFinal in
                    guard let self, let enemy, enemy.parent != nil else { return }
                    if enemy.doomed, enemy.action(forKey: "adventureDefeat") == nil {
                        if isFinal { enemy.release() }
                        return
                    }
                    enemy.flash()
                    if isFinal {
                        enemy.release()
                        if !enemy.isHeld { self.pendingFlight[target.id] = nil }
                    }
                    if enemy.doomed, !enemy.isHeld, enemy.action(forKey: "adventureDefeat") != nil {
                        enemy.removeAction(forKey: "adventureDefeat")
                        enemy.defeat(with: effect, burnt: false)
                    }
                }
            case .defeated(let enemy):
                guard let node = enemyNodes.removeValue(forKey: enemy.id) else { continue }
                node.position.x = enemy.x
                node.doomed = true
                node.setChewing(false)
                let effect = loadout.defeat(for: node.kind)
                if case .blast = lastCause {
                    pendingFlight[enemy.id] = nil
                    node.defeat(with: effect, burnt: true)
                } else {
                    let isSplashBeam: Bool
                    if case .shot(_, let targetID, let isBeam) = lastCause {
                        isSplashBeam = isBeam && enemy.id != targetID
                    } else {
                        isSplashBeam = false
                    }
                    let flight = node.isHeld
                        ? max(pendingFlight[enemy.id] ?? 0.85, isSplashBeam ? BeamAttack.impactDelay : 0)
                        : (isSplashBeam ? BeamAttack.impactDelay : 0.08)
                    let wait = node.isHeld ? flight + 0.15 : flight
                    let slow = enemy.slowRemaining > 0 ? 0.5 : 1.0
                    let walkSpeed = Self.enemySpeed(enemy.kind) * (battle.difficulty == .hard ? 1.1 : 1.0) * slow
                    let blockerX = battle.towers
                        .filter { $0.lane == enemy.lane && $0.x <= enemy.x }
                        .map { $0.x + 36 }
                        .max()
                    let minX = max(165, blockerX ?? 165)
                    if enemy.x > minX, walkSpeed > 0 {
                        let available = enemy.x - minX
                        let walkDuration = min(flight, available / walkSpeed)
                        let targetX = max(minX, enemy.x - walkSpeed * walkDuration)
                        node.run(.moveTo(x: targetX, duration: walkDuration), withKey: "adventureAdvance")
                    }
                    node.run(.sequence([.wait(forDuration: wait), .run { [weak self, weak node] in
                        guard let node else { return }
                        self?.pendingFlight[enemy.id] = nil
                        node.defeat(with: effect, burnt: false)
                    }]), withKey: "adventureDefeat")
                }
            case .leaked(let enemy):
                pendingFlight[enemy.id] = nil
                enemyNodes.removeValue(forKey: enemy.id)?.breakThrough()
            case .towerBroken(let tower):
                towerNodes.removeValue(forKey: tower.id)?.crumble()
            case .ultimate:
                lastCause = .blast
                for node in enemyNodes.values {
                    FXLibrary.playResource("AstralImpact", at: node.position, in: self)?.setScale(2)
                }
            case .doomExploded(let site):
                lastCause = .blast
                doomArtwork.explode(site, in: self)
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
            let chewing = battle.towers.contains { $0.lane == enemy.lane && abs($0.x + 36 - enemy.x) < 2 }
            node.setChewing(chewing)
        }
        doomArtwork.render(battle, in: self)
        fitCharactersToViewport()
        setPaused(battle.phase == .paused)
        pausedGameplay = battle.phase != .playing
        // 准备和结算阶段保留角色待机、子弹及退场动画。
        if battle.phase != .paused { speed = 1 }
    }

    private func fitCharactersToViewport() {
        guard let viewport = view?.bounds.size, viewport.width > 0, viewport.height > 0 else { return }
        let ratio = (viewport.width / size.width) / (viewport.height / size.height)
        for node in children where node is DefenderNode || node is EnemyNode
            || node.name?.hasPrefix("doom-") == true || node.zPosition >= 20 {
            node.yScale = abs(node.xScale) * ratio
        }
    }

    private static func enemySpeed(_ kind: AdventureEnemyKind) -> Double {
        switch kind {
        case .grunt: 24
        case .runner: 42
        case .armored: 19
        case .boss: 16
        }
    }

    private func addEnemy(_ enemy: AdventureEnemy) {
        guard enemyNodes[enemy.id] == nil else { return }
        let appearance: String?
        if enemy.kind == .boss { appearance = nil }
        else if loadout.enemyAppearances.isEmpty { appearance = loadout.enemyAppearance }
        else { appearance = loadout.enemyAppearances[enemy.id % loadout.enemyAppearances.count] }
        let node = EnemyNode(id: enemy.id, kind: enemy.kind.artwork, sign: "",
                             lane: enemy.lane, scale: 0.9, skin: loadout.enemySkin, boss: enemy.kind == .boss,
                             appearance: appearance, defaultAppearance: appearance == nil)
        node.sign.isHidden = true
        node.pips.isHidden = true
        node.healthBar?.isHidden = true
        node.position = CGPoint(x: enemy.x, y: lawn.laneY(enemy.lane))
        node.zPosition = CGFloat(15 - enemy.lane)
        addChild(node)
        enemyNodes[enemy.id] = node
        node.appear()
    }
}
