import LearnCore
import SpriteKit

/// 游戏画面：负责怪物移动、瞄准、战斗结算和动画；答题规则在 GameSession 里。
/// 怪物和字灵的具体表现都交给各自的种类配置（外观、走法、攻击策略），这里不区分种类
final class GameScene: SKScene {
    static let designSize = CGSize(width: 1200, height: 600)
    /// 横屏高度不够时战场可以比 2:1 宽，多出的宽度只接在右边（怪物来的方向），最多这么宽（场景坐标）；
    /// 左边从地图原有的边缘开始，不拼接。草坪、怪物和所有玩法坐标仍在 designSize 里
    static let rightOverscan: CGFloat = 1200
    /// 战场最宽时画面覆盖的场景范围，全屏特效按它铺满
    static var visibleBounds: CGRect {
        CGRect(x: 0, y: 0, width: designSize.width + rightOverscan, height: designSize.height)
    }

    /// 战场在可用空间里的尺寸：比 2:1 窄（竖屏）时宽度占满、按 2:1 定高；
    /// 比 2:1 宽（横屏）时高度占满，宽度最多到带两侧延伸的比例，再宽才左右留边
    static func battlefieldSize(fitting available: CGSize) -> CGSize {
        guard available.width.isFinite || available.height.isFinite else { return designSize }
        let narrowest = designSize.width / designSize.height
        let widest = visibleBounds.width / visibleBounds.height
        let width = max(0, available.width), height = max(0, available.height)
        guard height.isFinite, width / max(height, 1) > narrowest else {
            return CGSize(width: width, height: width / narrowest)
        }
        return CGSize(width: min(width, height * widest), height: height)
    }

    weak var gameDelegate: GameSceneDelegate?

    let tuning: GameTuning
    private let theme: SceneTheme
    private(set) var map: BattleMap
    private var backgroundNodes: [SKNode] = []
    /// 孩子装备的外观：子弹和退场特效按它选，场景里不按皮肤写判断
    let loadout: Loadout
    var enemies: [Int: EnemyNode] = [:]
    var defenders: [DefenderCell: DefenderNode] = [:]
    var doomState = AdventureDoomState()
    var doomRemainder: Double = 0
    var nextDoomID = 0
    let doomArtwork = AdventureDoomArtwork()
    var displayedDoomCooldown = 0
    var doomCooldown: Int { max(0, Int(ceil(doomState.cooldown))) }
    /// 战斗中放下的路障（铁栅门），不占种植格
    var barricades: [DefenderNode] = []
    /// 每只怪物正在啃哪个防御道具
    var chewing: [Int: DefenderNode] = [:]
    var targetID: Int?
    private var lastUpdate: TimeInterval = 0
    private var spawnCountdown = 1.0
    private var spawningFinished = false
    /// 独立于出怪、掉落和题目的随机过程，每轮将已拥有外观打乱用完。
    private var appearanceBag: [String] = []
    private var lastAppearance: String?
    private var built = false
    private(set) var gamePaused = false
    /// 演出清理完成后再结算，避免最后一击被回合暂停冻结。
    var thunderEffect: ThunderStrikeEffect?
    /// 诊断日志：上次记录场景节点数量的时间
    private var lastDiagStats: TimeInterval = 0

    let baseX: CGFloat = 160
    /// 怪物和防御道具中心相距这么近就算碰上了（约半格）
    var contactGap: CGFloat { lawn.columnWidth * 0.45 }
    /// 被挡住时答错，怪物狠咬一口，扣掉的耐久秒数
    static let wrongAnswerBite = 2.0
    private var spawnX: CGFloat { size.width - 45 }
    let lawn: Lawn
    var laneHeight: CGFloat { lawn.rowHeight }
    /// 拖动植物卡时标出落点格
    var plantPreview: SKShapeNode?
    /// 视图比场景宽或高时拉远，整个 designSize 都在画面里；比场景宽时左边对齐场景左缘，多出的部分在右边
    private let viewCamera = SKCameraNode()
    /// 画面右缘在场景里的横坐标：视图正好 2:1 时是 1200，横屏加宽时更大
    private var visibleMaxX = GameScene.designSize.width
    /// 连续答对几题（答错清零）
    var answerStreak = 0

    init(tuning: GameTuning, theme: SceneTheme, loadout: Loadout = .standard, map: BattleMap = .courtyard) {
        self.tuning = tuning
        self.theme = theme
        self.map = map
        self.loadout = loadout
        lawn = Lawn(lanes: tuning.lanes)
        super.init(size: Self.designSize)
        // aspectFit 留出的边 SpriteKit 只画黑色，不画场景外的节点；改由相机拉远，让两侧延伸的背景露出来
        scaleMode = .aspectFill
        backgroundColor = theme.skyBottom.color
        viewCamera.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(viewCamera)
        camera = viewCamera
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        DiagLog.log("scene deinit")
    }

    override func willMove(from view: SKView) {
        DiagLog.log("scene willMove(from:) scene=\(DiagLog.id(self)) view=\(DiagLog.id(view))")
        super.willMove(from: view)
    }

    override func didMove(to view: SKView) {
        DiagLog.log("scene didMove(to:) scene=\(DiagLog.id(self)) view=\(DiagLog.id(view)) built=\(built)")
        guard !built else { return }
        built = true
        fitCamera(in: view)
        buildBackground()
        ThunderArtwork.preload()
    }

    func laneY(_ lane: Int) -> CGFloat {
        lawn.laneY(lane)
    }

    private func buildBackground() {
        backgroundNodes.forEach { $0.removeFromParent() }
        let existing = Set(children.map { ObjectIdentifier($0) })
        // 草坪上方是天空
        Backdrop(theme: theme, size: size, skyHeight: size.height - Lawn.frame.maxY, lawn: lawn, baseWidth: 64, map: map)
            .build(in: self)
        backgroundNodes = children.filter { !existing.contains(ObjectIdentifier($0)) }
        fitRightArt()
    }

    func setMap(_ map: BattleMap) {
        guard self.map != map else { return }
        self.map = map
        if built { buildBackground() }
    }

    /// 把 SwiftUI 里的拖动位置换成场景坐标。frame 是战场在同一坐标系里的位置，
    /// 场景按 aspectFit 等比缩放居中；落点不在战场里时返回 nil
    static func scenePoint(at location: CGPoint, in frame: CGRect) -> CGPoint? {
        guard frame.width > 0, frame.height > 0, frame.contains(location) else { return nil }
        let scale = min(frame.width / designSize.width, frame.height / designSize.height)
        // 战场比 2:1 宽时左边对齐、右边是延伸的背景；比 2:1 高时上下居中
        let offsetY = (frame.height - designSize.height * scale) / 2
        // SwiftUI 的 y 向下，SpriteKit 的 y 向上
        return CGPoint(
            x: (location.x - frame.minX) / scale,
            y: (frame.maxY - location.y - offsetY) / scale)
    }

    /// aspectFill 会裁掉比视图多出的那一边，相机按比例拉远补回来，完整显示 designSize（和 scenePoint 的换算一致）：
    /// 视图更宽时按高度缩放、左缘对齐，右边露出场景外的背景；视图更高时按宽度缩放、上下居中
    private func fitCamera(in view: SKView?) {
        guard let bounds = view?.bounds.size, bounds.width > 0, bounds.height > 0 else { return }
        let viewAspect = bounds.width / bounds.height
        let sceneAspect = size.width / size.height
        let scale = max(viewAspect / sceneAspect, sceneAspect / viewAspect)
        let center = CGPoint(x: viewAspect > sceneAspect ? size.width * scale / 2 : size.width / 2, y: size.height / 2)
        if viewCamera.xScale != scale { viewCamera.setScale(scale) }
        if viewCamera.position != center { viewCamera.position = center }
        let maxX = viewAspect > sceneAspect ? size.width * scale : size.width
        if visibleMaxX != maxX {
            visibleMaxX = maxX
            fitRightArt()
        }
    }

    /// 会拉伸的右侧延伸图（庭院）刚好铺到画面右缘；画面不比原画宽时保持原画比例
    private func fitRightArt() {
        guard let art = BattleMapArtwork.rightExtension(map, width: Self.rightOverscan), art.stretches,
              let node = childNode(withName: Backdrop.rightArtName(map)) as? SKSpriteNode else { return }
        node.size.width = max(art.naturalWidth, visibleMaxX - art.minX)
    }

    // MARK: - 主循环

    /// 战场时钟：对局进行了多少秒，暂停时不走
    private(set) var clock: TimeInterval = 0

    override func update(_ currentTime: TimeInterval) {
        fitCamera(in: view)
        let dt = lastUpdate == 0 ? 0 : min(currentTime - lastUpdate, 0.1)
        lastUpdate = currentTime
        if currentTime - lastDiagStats >= 5 {
            lastDiagStats = currentTime
            logDiagStats()
        }
        guard !gamePaused, dt > 0 else { return }
        if let effect = thunderEffect {
            if effect.advance(by: dt) {
                thunderEffect = nil
                gameDelegate?.ultimateAnimationFinished()
                for defeat in effect.defeats {
                    gameDelegate?.enemyDefeated(defeat.id, at: defeat.point)
                }
            }
            return
        }
        guard let delegate = gameDelegate else { return }
        clock += dt
        advanceDoom(by: dt)
        guard !gamePaused else { return }
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
        // 孩子在拼瞄准的这道字块题：这只怪物原地等着（也不啃、不踩雷）
        let held = delegate.holdsTarget ? targetID : nil
        for (id, enemy) in enemies where !enemy.doomed && id != held {
            let step = enemy.advance(dt: dt, speed: speed * enemy.kind.speed)
            move(enemy, by: step, chew: dt * factor * enemy.chewRate)
            triggerMines(under: enemy)
            guard !enemy.doomed, enemy.position.x <= baseX + 30 else { continue }
            chewing[id] = nil
            if delegate.enemyReachedBase(id) {
                enemies[id] = nil
                for (cell, defender) in defenders where cell.lane == enemy.lane {
                    defender.hurt()
                }
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
        spawn(spec, lane: chooseLane())
    }

    private func nextMonsterAppearance() -> String? {
        guard !loadout.enemyAppearances.isEmpty else { return loadout.enemyAppearance ?? EnemyKind.blob.id }
        if appearanceBag.isEmpty {
            appearanceBag = loadout.enemyAppearances.shuffled()
            if appearanceBag.count > 1, appearanceBag.last == lastAppearance {
                appearanceBag.swapAt(0, appearanceBag.count - 1)
            }
        }
        let chosen = appearanceBag.removeLast()
        lastAppearance = chosen
        return chosen
    }

    /// 让一只怪物从右边出场；测试里可以指定路和位置
    @discardableResult
    func spawn(_ spec: EnemySpawn, lane: Int, x: CGFloat? = nil) -> EnemyNode {
        let boss = tuning.waves.isBoss(spec.kind)
        let enemy = EnemyNode(id: spec.id, kind: spec.kind, sign: spec.sign, lane: lane,
                              scale: min(1.2, laneHeight / 104), skin: loadout.enemySkin, boss: boss, appearance: nextMonsterAppearance(),
                              defaultAppearance: loadout.enemyAppearances.isEmpty && loadout.enemyAppearance == nil)
        enemy.position = CGPoint(x: x ?? spawnX, y: laneY(lane))
        enemy.zPosition = 10 + CGFloat(tuning.lanes - lane)
        addChild(enemy)
        enemies[spec.id] = enemy
        enemy.appear()
        if boss {
            BossWarningEffect(name: enemy.displayName, laneY: laneY(lane), laneHeight: laneHeight).play(in: self)
            gameDelegate?.bossAppeared(name: enemy.displayName)
        }
        return enemy
    }

    /// 选右半边怪物最少的路，避免挤在一起
    private func chooseLane() -> Int {
        let crowd = { (lane: Int) in
            self.enemies.values.filter { $0.lane == lane && $0.position.x > self.size.width * 0.5 }.count
        }
        return (0..<tuning.lanes).shuffled().min { crowd($0) < crowd($1) } ?? 0
    }

    /// 瞄准最靠近书架的怪物；已瞄准的不会被后来者抢走，免得孩子答题时题目突然变了
    func updateTarget() {
        if let id = targetID, let current = enemies[id], !current.doomed { return }
        let next = enemies.values.filter { !$0.doomed }.min { $0.position.x < $1.position.x }
        let newID = next?.enemyID
        guard newID != targetID else { return }
        targetID = newID
        next?.setTargeted(true)
        gameDelegate?.targetChanged(to: newID)
    }

    /// 手动选题沿用自动瞄准的同一入口，场上已死亡目标不能再选。
    func selectTarget(_ id: Int) {
        guard !gamePaused, let enemy = enemies[id], !enemy.doomed else { return }
        if let targetID { enemies[targetID]?.setTargeted(false) }
        targetID = id
        enemy.setTargeted(true)
        gameDelegate?.targetChanged(to: id)
    }

    func selectTarget(at point: CGPoint) {
        guard let enemy = enemies.values.filter({ !$0.doomed && $0.calculateAccumulatedFrame().contains(point) })
            .min(by: { $0.enemyID < $1.enemyID }) else { return }
        selectTarget(enemy.enemyID)
    }

    func beginRound() {
        spawningFinished = false
        spawnCountdown = 0.5
        lastUpdate = 0
        targetID = nil
        setGamePaused(false)
    }

    /// 每 5 秒记一次场景里的节点数，闪退前最后一条能看出场面有多热闹
    private func logDiagStats() {
        #if DEBUG
        var total = 0, emitters = 0, sprites = 0, shapes = 0
        enumerateChildNodes(withName: ".//*") { node, _ in
            total += 1
            if node is SKEmitterNode { emitters += 1 } else if node is SKSpriteNode { sprites += 1 } else if node is SKShapeNode { shapes += 1 }
        }
        DiagLog.log("scene stats nodes=\(total) emitters=\(emitters) sprites=\(sprites) shapes=\(shapes) "
            + "enemies=\(enemies.count) defenders=\(defenders.count) paused=\(gamePaused) speed=\(speed)")
        #endif
    }

    func setGamePaused(_ paused: Bool, keepingAnimations: Bool = false) {
        DiagLog.log("scene setGamePaused(\(paused)) keepingAnimations=\(keepingAnimations)")
        gamePaused = paused
        // 回合休息只停玩法，让最后一次击杀的退场动作和命中特效自行清理。
        // 普通暂停、大招题和离场仍把动画一起停下。
        speed = paused && !keepingAnimations ? 0 : 1
        FXLibrary.setPaused(paused && !keepingAnimations, in: self)
    }

    /// 准备阶段冻结怪物和出怪，但保留植物种植动画
    func setPreparing(_ preparing: Bool) {
        gamePaused = preparing
        speed = 1
    }
}
