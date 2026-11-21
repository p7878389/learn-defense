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
}

extension GameSceneDelegate {
    /// 默认不定住目标（测试里的简单代理不用实现）
    var holdsTarget: Bool { false }
    /// 首领被打到只剩最后一段血、开始暴走
    func bossEnraged(_ id: Int) {}
    func ultimateAnimationStarted() {}
    func ultimateAnimationFinished() {}
}

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

    private let tuning: GameTuning
    private let theme: SceneTheme
    private(set) var map: BattleMap
    private var backgroundNodes: [SKNode] = []
    /// 孩子装备的外观：子弹和退场特效按它选，场景里不按皮肤写判断
    private let loadout: Loadout
    private var enemies: [Int: EnemyNode] = [:]
    private var defenders: [DefenderCell: DefenderNode] = [:]
    /// 战斗中放下的路障（铁栅门），不占种植格
    private var barricades: [DefenderNode] = []
    /// 每只怪物正在啃哪个防御道具
    private var chewing: [Int: DefenderNode] = [:]
    private var targetID: Int?
    private var lastUpdate: TimeInterval = 0
    private var spawnCountdown = 1.0
    private var spawningFinished = false
    private var built = false
    private(set) var gamePaused = false
    /// 演出清理完成后再结算，避免最后一击被回合暂停冻结。
    private var thunderEffect: ThunderStrikeEffect?
    /// 诊断日志：上次记录场景节点数量的时间
    private var lastDiagStats: TimeInterval = 0

    private let baseX: CGFloat = 160
    /// 怪物和防御道具中心相距这么近就算碰上了（约半格）
    private var contactGap: CGFloat { lawn.columnWidth * 0.45 }
    /// 被挡住时答错，怪物狠咬一口，扣掉的耐久秒数
    static let wrongAnswerBite = 2.0
    private var spawnX: CGFloat { size.width - 45 }
    private let lawn: Lawn
    private var laneHeight: CGFloat { lawn.rowHeight }
    /// 拖动植物卡时标出落点格
    private var plantPreview: SKShapeNode?
    /// 视图比场景宽或高时拉远，整个 designSize 都在画面里；比场景宽时左边对齐场景左缘，多出的部分在右边
    private let viewCamera = SKCameraNode()
    /// 画面右缘在场景里的横坐标：视图正好 2:1 时是 1200，横屏加宽时更大
    private var visibleMaxX = GameScene.designSize.width
    /// 连续答对几题（答错清零）
    private(set) var answerStreak = 0

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

    private func laneY(_ lane: Int) -> CGFloat {
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

    /// 让一只怪物从右边出场；测试里可以指定路和位置
    @discardableResult
    func spawn(_ spec: EnemySpawn, lane: Int, x: CGFloat? = nil) -> EnemyNode {
        let boss = tuning.waves.isBoss(spec.kind)
        let enemy = EnemyNode(id: spec.id, kind: spec.kind, sign: spec.sign, lane: lane,
                              scale: min(1.2, laneHeight / 104), skin: loadout.enemySkin, boss: boss)
        enemy.position = CGPoint(x: x ?? spawnX, y: laneY(lane))
        enemy.zPosition = 10 + CGFloat(tuning.lanes - lane)
        addChild(enemy)
        enemies[spec.id] = enemy
        enemy.appear()
        if boss { BossWarningEffect(name: spec.kind.name, laneY: laneY(lane), laneHeight: laneHeight).play(in: self) }
        return enemy
    }

    // MARK: - 防御道具

    /// 这一路上的防御道具（种下的坚果、土豆雷，和放下的铁栅门）
    private func guards(inLane lane: Int) -> [DefenderNode] {
        defenders.values.filter { $0.lane == lane && $0.guardian != nil } + barricades.filter { $0.lane == lane }
    }

    /// 怪物前方最近、会挡住它的防御道具
    private func blocker(for enemy: EnemyNode) -> DefenderNode? {
        guards(inLane: enemy.lane)
            .filter {
                $0.position.x < enemy.position.x
                    && $0.guardian?.blocks(enemy, vaulting: tuning.wallsCanBeVaulted) == true
            }
            .max { $0.position.x < $1.position.x }
    }

    /// 往前走一步；碰上防御道具就停在它面前啃，啃掉 seconds 秒耐久
    private func move(_ enemy: EnemyNode, by step: CGFloat, chew seconds: Double) {
        guard let blocker = blocker(for: enemy), enemy.position.x - step <= blocker.position.x + contactGap else {
            enemy.position.x -= step
            stopChewing(enemy)
            return
        }
        enemy.position.x = blocker.position.x + contactGap
        enemy.setChewing(true)
        chewing[enemy.enemyID] = blocker
        chew(blocker, seconds: seconds)
    }

    private func stopChewing(_ enemy: EnemyNode) {
        enemy.setChewing(false)
        chewing[enemy.enemyID] = nil
    }

    private func chew(_ blocker: DefenderNode, seconds: Double) {
        guard let guardian = blocker.guardian, seconds > 0 else { return }
        blocker.showDurability(guardian.chew(seconds))
        if guardian.isSpent { remove(blocker, exploded: false) }
    }

    /// 防御道具碎了或炸了：从场上拿掉，空出格子；正在啃它的怪物接着走
    private func remove(_ guardNode: DefenderNode, exploded: Bool) {
        if let cell = defenders.first(where: { $0.value === guardNode })?.key {
            defenders[cell] = nil
        }
        let wasBarricade = barricades.contains { $0 === guardNode }
        barricades.removeAll { $0 === guardNode }
        for (id, blocker) in chewing where blocker === guardNode {
            chewing[id] = nil
            enemies[id]?.setChewing(false)
        }
        if exploded { guardNode.explode() } else { guardNode.crumble() }
        if wasBarricade { gameDelegate?.barricadeRemoved() }
    }

    /// 出土的土豆雷被踩到就炸：普通怪物直接倒下，首领只扣血并被弹开
    private func triggerMines(under enemy: EnemyNode) {
        for mine in guards(inLane: enemy.lane) where abs(mine.position.x - enemy.position.x) <= contactGap {
            guard let damage = mine.guardian?.trigger(isBoss: tuning.waves.isBoss(enemy.kind),
                                                      health: enemy.health.current) else { continue }
            remove(mine, exploded: true)
            InkBurstEffect(color: UnitColor.coral.fill, scale: 1.3, count: 12).play(at: mine.position, in: self)
            blast(enemy, damage: damage)
            return
        }
    }

    /// 被打中但没倒下：更新血量；首领这一下开始暴走时，全屏红光一闪并通知对局配音
    private func wound(_ enemy: EnemyNode) {
        let wasEnraged = enemy.isEnraged
        enemy.showWound()
        guard enemy.isEnraged, !wasEnraged else { return }
        ScreenFlashEffect(color: Palette.hurt, alpha: 0.3, duration: 0.4)
            .play(at: CGPoint(x: size.width / 2, y: size.height / 2), in: self)
        FloatingTextEffect(text: "💢 首领暴走！", color: Palette.hurt, fontSize: 34)
            .play(at: CGPoint(x: enemy.center.x, y: enemy.center.y + 70), in: self)
        gameDelegate?.bossEnraged(enemy.enemyID)
    }

    /// 不经过答题直接受到伤害（土豆雷）
    private func blast(_ enemy: EnemyNode, damage: Int) {
        let id = enemy.enemyID
        enemy.flash()
        guard enemy.health.take(damage) else {
            wound(enemy)
            stopChewing(enemy)
            enemy.knockBack(70)
            return
        }
        enemy.doomed = true
        enemy.setTargeted(false)
        stopChewing(enemy)
        enemies[id] = nil
        if targetID == id { targetID = nil }
        enemy.defeat(with: loadout.defeat(for: enemy.kind), burnt: true)
        gameDelegate?.enemyDefeated(id, at: enemy.center)
    }

    private func updateStreak(_ streak: Int) {
        guard streak != answerStreak else { return }
        answerStreak = streak
    }

    /// 孩子答对一题：连对数加一；埋着的土豆雷往出土再近一步。返回有没有土豆雷刚出土
    @discardableResult
    func noteCorrectAnswer() -> Bool {
        updateStreak(answerStreak + 1)
        var armed = false
        for defender in defenders.values where defender.guardian?.correctAnswer() == true {
            defender.arm()
            armed = true
            play(FloatingTextEffect(text: "土豆雷出土了", color: Palette.jadeDark, fontSize: 26),
                 at: CGPoint(x: defender.position.x, y: defender.position.y + 54))
        }
        return armed
    }

    /// 在这只怪物面前落下一道路障（铁栅门）。怪物不在场上时不放
    @discardableResult
    func dropBarricade(_ kind: DefenderKind, before id: Int) -> Bool {
        guard !gamePaused, kind.guardStyle != nil, let enemy = enemies[id], !enemy.doomed else { return false }
        let x = max(baseX + 40, enemy.position.x - contactGap - 6)
        let gate = DefenderNode(kind: kind, radius: min(34, laneHeight * 0.32))
        gate.lane = enemy.lane
        gate.position = CGPoint(x: x, y: laneY(enemy.lane) + 120)
        gate.zPosition = 5
        gate.alpha = 0
        addChild(gate)
        barricades.append(gate)
        gate.run(.group([
            .moveTo(y: laneY(enemy.lane), duration: 0.22),
            .fadeIn(withDuration: 0.15),
        ]))
        // 怪物已经贴得很近时往后挪一点，正好停在门前
        if enemy.position.x < x + contactGap { enemy.position.x = x + contactGap }
        return true
    }

    /// 场上还有几道路障
    var barricadeCount: Int { barricades.count }

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

    // MARK: - 由 GameSession 调用

    /// 把植物种到具体草坪格；格子一旦占用就不能修改
    @discardableResult
    func plant(_ kind: DefenderKind, in cell: DefenderCell) -> Bool {
        guard cell.lane >= 0, cell.lane < tuning.lanes,
              cell.column >= 0, cell.column < Lawn.columns,
              defenders[cell] == nil else { return false }
        let defender = DefenderNode(kind: kind, radius: min(34, laneHeight * 0.32), skin: loadout.defenderSkins[kind.id])
        if kind.canShoot {
            IceCombatEffects.decorate(defender, projectile: loadout.projectile(for: kind), radius: min(34, laneHeight * 0.32))
        }
        defender.lane = cell.lane
        defender.position = CGPoint(x: lawn.columnX(cell.column), y: laneY(cell.lane))
        defender.zPosition = 5
        defender.setScale(0.2)
        defender.run(.sequence([
            .scale(to: 1, duration: 0.22),
            .run { [weak self, weak defender] in
                guard let self, let defender else { return }
                self.play(FloatingTextEffect(text: "种下了", color: Palette.jadeDark, fontSize: 26),
                          at: CGPoint(x: defender.position.x, y: defender.position.y + 54))
            },
        ]))
        addChild(defender)
        defenders[cell] = defender
        return true
    }

    /// 把拖到场景里的植物卡种到落点所在的草坪格；格子已有植物时不种，也不挪到别处
    @discardableResult
    func plant(_ kind: DefenderKind, at point: CGPoint) -> Bool {
        guard let cell = lawn.cell(at: point) else { return false }
        return plant(kind, in: cell)
    }

    /// 拖动植物卡时标出会种到哪一格：空格绿色，已有植物红色；不在可种草坪上或 point 为 nil 时隐藏
    func showPlantPreview(at point: CGPoint?) {
        guard let point, let cell = lawn.cell(at: point) else {
            plantPreview?.isHidden = true
            return
        }
        let preview = plantPreview ?? makePlantPreview()
        let color = defenders[cell] == nil ? Palette.jade : Palette.hurt
        preview.fillColor = color.withAlphaComponent(0.25)
        preview.strokeColor = color
        preview.position = CGPoint(x: lawn.columnX(cell.column), y: laneY(cell.lane))
        preview.isHidden = false
    }

    private func makePlantPreview() -> SKShapeNode {
        let inset: CGFloat = 4
        let node = SKShapeNode(
            rectOf: CGSize(width: lawn.columnWidth - inset * 2, height: lawn.rowHeight - inset * 2),
            cornerRadius: 8)
        node.name = "plantPreview"
        node.lineWidth = 3
        // 在植物下面一层
        node.zPosition = 4
        addChild(node)
        plantPreview = node
        return node
    }

    /// 当前瞄准的怪物所在路是否有字灵可以发射（防御道具不算）
    func canAttack(_ id: Int) -> Bool {
        guard let enemy = enemies[id], !enemy.doomed else { return false }
        return defenders.contains { $0.key.lane == enemy.lane && $0.value.canShoot }
    }

    /// 当前路上的字灵攻击这只怪物，返回它是否被打败（nil 表示怪物已不在场上）。
    /// overwhelming 为 true 时一下打败（大招）
    @discardableResult
    func fire(at id: Int, overwhelming: Bool = false) -> Bool? {
        guard let enemy = enemies[id], !enemy.doomed else {
            return nil
        }
        guard let defender = defenders
            .filter({ $0.key.lane == enemy.lane && $0.value.canShoot })
            .max(by: { $0.value.position.x < $1.value.position.x })?
            .value, let attack = defender.attack else { return nil }
        // 一次正确作答只推进一次攻击，怪物血量就是还要答对的题数。
        let damage = overwhelming ? enemy.health.current : 1
        let defeated = enemy.health.take(damage)
        if defeated {
            enemy.doomed = true
            enemy.setTargeted(false)
            updateTarget()
        }
        enemy.hold()
        defender.shoot()
        // 子弹从嘴里平着飞出去，打在僵尸身上同样的高度
        let target = CGPoint(x: enemy.position.x, y: defender.muzzle.y)
        attack.perform(from: defender.muzzle, to: target, projectile: loadout.projectile(for: defender.kind), in: self) {
            [weak self, weak enemy] isFinal in
            guard let self, let enemy, enemy.parent != nil else { return }
            enemy.flash()
            guard isFinal else { return }
            enemy.release()
            for effect in defender.hitEffects {
                effect.apply(to: enemy, defeated: defeated, field: self)
            }
            if defeated {
                enemy.defeat(with: self.loadout.defeat(for: enemy.kind), burnt: overwhelming)
                self.enemies[id] = nil
                self.gameDelegate?.enemyDefeated(id, at: enemy.center)
            } else {
                wound(enemy)
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

    /// 答错：怪物往前冲一段；被挡住时改为狠咬一口防御道具
    func penalize(_ id: Int) {
        updateStreak(0)
        guard let enemy = enemies[id] else { return }
        if enemy.isChewing, let blocker = chewing[id] {
            blocker.shake()
            chew(blocker, seconds: Self.wrongAnswerBite)
        }
        enemy.lunge()
    }

    /// 全场怪物一起消灭（大招）
    func unleash() {
        guard thunderEffect == nil else { return }
        // 大招从天空直接命中，不依赖这条路上是否有能射击的植物。
        // 先移出战斗集合，再通知对局，避免飞行中的普通子弹重复结算。
        let victims = enemies.values.filter { !$0.doomed }.sorted { $0.enemyID < $1.enemyID }
        guard !victims.isEmpty else { return }
        for enemy in victims {
            enemy.doomed = true
            _ = enemy.health.take(enemy.health.current)
            enemy.setTargeted(false)
            stopChewing(enemy)
            enemies[enemy.enemyID] = nil
            enemy.removeAllActions()
            enemy.alpha = 1
        }
        let effect = ThunderStrikeEffect(victims: victims, size: size)
        thunderEffect = effect
        addChild(effect)
        updateTarget()
        gameDelegate?.ultimateAnimationStarted()
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

    /// 已经布阵的路数（有射手的路）和格子数（含防御道具）
    var plantedLaneCount: Int { Set(defenders.filter { $0.value.canShoot }.keys.map(\.lane)).count }
    var plantedCellCount: Int { defenders.count }

    /// 落点是否在本局可种的草坪上（不管格子有没有被占）
    func isPlantable(_ point: CGPoint) -> Bool {
        lawn.cell(at: point) != nil
    }
}

extension GameScene: LaneField {
    func enemies(inLane lane: Int) -> [EnemyNode] {
        enemies.values.filter { $0.lane == lane }
    }
}
