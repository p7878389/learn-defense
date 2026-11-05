import LearnCore
import SpriteKit

/// 要出场的怪物：编号、牌子上的字、种类
struct EnemySpawn {
    let id: Int
    let sign: String
    let kind: EnemyKind
}

@MainActor
protocol GameSceneDelegate: AnyObject {
    /// 要生成新怪物时调用，返回 nil 表示这一局的怪物出完了
    func nextEnemy() -> EnemySpawn?
    /// 当前瞄准的怪物变了（答题针对它）
    func targetChanged(to id: Int?)
    /// 怪物走到书架。返回 true 移除怪物（扣血），false 让它退回起点（不设失败）
    func enemyReachedBase(_ id: Int) -> Bool
    /// 怪物被打败，point 是它倒下的位置
    func enemyDefeated(_ id: Int, at point: CGPoint)
    var speedFactor: Double { get }
}

/// 游戏画面：负责怪物移动、瞄准、战斗结算和动画；答题规则在 GameSession 里。
/// 怪物和字灵的具体表现都交给各自的种类配置（外观、走法、攻击策略），这里不区分种类
final class GameScene: SKScene {
    static let designSize = CGSize(width: 1200, height: 520)

    weak var gameDelegate: GameSceneDelegate?

    private let tuning: GameTuning
    private let theme: SceneTheme
    private var enemies: [Int: EnemyNode] = [:]
    private var defenders: [DefenderNode] = []
    private var targetID: Int?
    private var lastUpdate: TimeInterval = 0
    private var spawnCountdown = 1.0
    private var spawningFinished = false
    private var built = false
    private(set) var gamePaused = false

    private let baseX: CGFloat = 130
    /// 顶部天空的高度，路在天空下面
    private let skyHeight: CGFloat = 64
    private var spawnX: CGFloat { size.width + 70 }
    private var laneHeight: CGFloat { (size.height - skyHeight) / CGFloat(tuning.lanes) }

    init(tuning: GameTuning, theme: SceneTheme) {
        self.tuning = tuning
        self.theme = theme
        super.init(size: Self.designSize)
        scaleMode = .aspectFit
        backgroundColor = theme.skyBottom.color
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func didMove(to view: SKView) {
        guard !built else { return }
        built = true
        buildBackground()
        buildDefenders()
    }

    private func laneY(_ lane: Int) -> CGFloat {
        laneHeight * (CGFloat(lane) + 0.5)
    }

    private func buildBackground() {
        Backdrop(theme: theme, size: size, skyHeight: skyHeight, lanes: tuning.lanes, baseWidth: 64).build(in: self)
    }

    private func buildDefenders() {
        for lane in 0..<tuning.lanes {
            let kind = tuning.lineup.isEmpty ? DefenderKind.inkling : tuning.lineup[lane % tuning.lineup.count]
            let defender = DefenderNode(kind: kind, radius: min(34, laneHeight * 0.32))
            defender.position = CGPoint(x: 100, y: laneY(lane))
            defender.zPosition = 5
            addChild(defender)
            defenders.append(defender)
        }
    }

    // MARK: - 主循环

    override func update(_ currentTime: TimeInterval) {
        let dt = lastUpdate == 0 ? 0 : min(currentTime - lastUpdate, 0.1)
        lastUpdate = currentTime
        guard !gamePaused, dt > 0, let delegate = gameDelegate else { return }
        let factor = delegate.speedFactor

        if !spawningFinished {
            spawnCountdown -= dt * factor
            // 场上没有怪物时不让孩子干等
            if !enemies.values.contains(where: { !$0.doomed }) {
                spawnCountdown = min(spawnCountdown, 0.5)
            }
            if spawnCountdown <= 0 {
                spawnEnemy()
                spawnCountdown = tuning.spawnInterval
            }
        }

        let speed = Double(spawnX - baseX) / tuning.crossSeconds * factor
        for (id, enemy) in enemies where !enemy.doomed {
            enemy.position.x -= enemy.advance(dt: dt, speed: speed * enemy.kind.speed)
            guard enemy.position.x <= baseX + 30 else { continue }
            if delegate.enemyReachedBase(id) {
                enemies[id] = nil
                defenders[enemy.lane].hurt()
                enemy.breakThrough()
            } else {
                enemy.bounceBack(toX: spawnX - 40)
            }
            if targetID == id {
                enemy.setTargeted(false)
                targetID = nil
            }
            if gamePaused { return }
        }
        updateTarget()
    }

    private func spawnEnemy() {
        guard let spec = gameDelegate?.nextEnemy() else {
            spawningFinished = true
            return
        }
        let lane = chooseLane()
        let enemy = EnemyNode(id: spec.id, kind: spec.kind, sign: spec.sign, lane: lane, scale: min(1.2, laneHeight / 104))
        enemy.position = CGPoint(x: spawnX, y: laneY(lane))
        enemy.zPosition = 10 + CGFloat(tuning.lanes - lane)
        addChild(enemy)
        enemies[spec.id] = enemy
        enemy.appear()
    }

    /// 选右半边怪物最少的路，避免挤在一起
    private func chooseLane() -> Int {
        let crowd = { (lane: Int) in
            self.enemies.values.filter { $0.lane == lane && $0.position.x > self.size.width * 0.5 }.count
        }
        return (0..<tuning.lanes).shuffled().min { crowd($0) < crowd($1) } ?? 0
    }

    /// 瞄准最靠近书架的怪物；已瞄准的不会被后来者抢走，免得孩子答题时题目突然变了
    private func updateTarget() {
        if let id = targetID, let current = enemies[id], !current.doomed { return }
        let next = enemies.values.filter { !$0.doomed }.min { $0.position.x < $1.position.x }
        let newID = next?.enemyID
        guard newID != targetID else { return }
        targetID = newID
        next?.setTargeted(true)
        gameDelegate?.targetChanged(to: newID)
    }

    // MARK: - 由 GameSession 调用

    /// 当前路上的字灵攻击这只怪物，返回它是否被打败（nil 表示怪物已不在场上）。
    /// overwhelming 为 true 时一下打败（大招）
    @discardableResult
    func fire(at id: Int, overwhelming: Bool = false) -> Bool? {
        guard let enemy = enemies[id], !enemy.doomed else { return nil }
        let defender = defenders[enemy.lane]
        let damage = overwhelming ? enemy.health.current : defender.kind.attack.totalDamage
        let defeated = enemy.health.take(damage)
        if defeated {
            enemy.doomed = true
            enemy.setTargeted(false)
            updateTarget()
        }
        enemy.hold()
        defender.shoot()
        let target = CGPoint(x: enemy.position.x, y: enemy.position.y + 10)
        defender.attack.perform(from: defender.muzzle, to: target, projectile: defender.kind.projectile, in: self) {
            [weak self, weak enemy] isFinal in
            guard let self, let enemy, enemy.parent != nil else { return }
            enemy.flash()
            guard isFinal else { return }
            enemy.release()
            for effect in defender.hitEffects {
                effect.apply(to: enemy, defeated: defeated, field: self)
            }
            if defeated {
                enemy.defeat()
                self.enemies[id] = nil
                self.gameDelegate?.enemyDefeated(id, at: enemy.center)
            } else {
                enemy.showHealth()
            }
        }
        return defeated
    }

    func setSign(_ id: Int, _ text: String) {
        enemies[id]?.setSign(text)
    }

    /// 答对后在怪物上方弹出单词卡；id 为 nil 或怪物已不在场上时放在画面中间
    func showCard(_ card: WordCard, near id: Int?) {
        let point = id.flatMap { enemies[$0]?.center }
        WordCardEffect(card: card).play(at: point ?? CGPoint(x: size.width / 2, y: size.height / 2), in: self)
    }

    func penalize(_ id: Int) {
        enemies[id]?.lunge()
    }

    /// 全场怪物一起消灭（大招）
    func unleash() {
        ScreenFlashEffect().play(at: .zero, in: self)
        for id in enemies.keys.sorted() {
            fire(at: id, overwhelming: true)
        }
    }

    /// 全场怪物停住
    func freeze(seconds: Double) {
        SnowfallEffect().play(at: .zero, in: self)
        for enemy in enemies.values where !enemy.doomed {
            enemy.slow(factor: 0, seconds: seconds)
        }
    }

    /// 在场景里播放一个特效；point 为 nil 时放在画面中间
    func play(_ effect: any VisualEffect, at point: CGPoint? = nil) {
        effect.play(at: point ?? CGPoint(x: size.width / 2, y: size.height / 2), in: self)
    }

    func setGamePaused(_ paused: Bool) {
        gamePaused = paused
        // speed 为 0 时动画也停下
        speed = paused ? 0 : 1
    }
}

extension GameScene: LaneField {
    func enemies(inLane lane: Int) -> [EnemyNode] {
        enemies.values.filter { $0.lane == lane }
    }
}
