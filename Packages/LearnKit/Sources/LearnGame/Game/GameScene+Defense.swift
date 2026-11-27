import LearnCore
import SpriteKit

extension GameScene {
    // MARK: - 防御道具

    /// 这一路上的防御道具（种下的坚果、土豆雷，和放下的铁栅门）
    private func guards(inLane lane: Int) -> [DefenderNode] {
        defenders.values.filter { $0.lane == lane && $0.guardian != nil } + barricades.filter { $0.lane == lane }
    }

    /// 怪物前方最近、会挡住它的防御道具
    func blocker(for enemy: EnemyNode) -> DefenderNode? {
        guards(inLane: enemy.lane)
            .filter {
                $0.position.x < enemy.position.x
                    && $0.guardian?.blocks(enemy, vaulting: tuning.wallsCanBeVaulted) == true
            }
            .max { $0.position.x < $1.position.x }
    }

    /// 往前走一步；碰上防御道具就停在它面前啃，啃掉 seconds 秒耐久
    func move(_ enemy: EnemyNode, by step: CGFloat, chew seconds: Double) {
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

    func stopChewing(_ enemy: EnemyNode) {
        enemy.setChewing(false)
        chewing[enemy.enemyID] = nil
    }

    func chew(_ blocker: DefenderNode, seconds: Double) {
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
    func triggerMines(under enemy: EnemyNode) {
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
    func wound(_ enemy: EnemyNode) {
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

    func updateStreak(_ streak: Int) {
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

    private func renderDoom() {
        doomArtwork.render(charges: doomState.charges, craters: doomState.craters, playing: !gamePaused,
                           in: self, laneOffset: (Lawn.rows - tuning.lanes) / 2)
        if displayedDoomCooldown != doomCooldown {
            displayedDoomCooldown = doomCooldown
            gameDelegate?.doomCooldownChanged(doomCooldown)
        }
    }

    func advanceDoom(by seconds: Double) {
        doomRemainder += seconds
        var exploded: [AdventureDoomSite] = []
        while doomRemainder + 0.0000001 >= 0.05 {
            doomRemainder = max(0, doomRemainder - 0.05)
            exploded += doomState.step()
        }
        renderDoom()
        for site in exploded {
            doomArtwork.explode(site, in: self, laneOffset: (Lawn.rows - tuning.lanes) / 2)
            let victims = enemies.values.filter {
                !$0.doomed && AdventureDoom.contains(lane: site.lane, column: site.column,
                                                     enemyLane: $0.lane, enemyX: Double($0.position.x))
            }.sorted { $0.enemyID < $1.enemyID }
            var defeats: [(Int, CGPoint)] = []
            for enemy in victims where enemy.health.take(AdventureDoom.damage) {
                enemy.doomed = true
                enemy.setTargeted(false)
                stopChewing(enemy)
                enemies[enemy.enemyID] = nil
                defeats.append((enemy.enemyID, enemy.center))
                enemy.defeat(with: loadout.defeat(for: enemy.kind), burnt: true)
            }
            updateTarget()
            for (id, point) in defeats { gameDelegate?.enemyDefeated(id, at: point) }
        }
    }

    func hasDoomCrater(at point: CGPoint) -> Bool {
        guard let cell = lawn.cell(at: point) else { return false }
        return doomState.craters.contains { $0.lane == cell.lane && $0.column == cell.column }
    }

    /// 把植物种到具体草坪格；格子一旦占用就不能修改
    @discardableResult
    func plant(_ kind: DefenderKind, in cell: DefenderCell) -> Bool {
        guard cell.lane >= 0, cell.lane < tuning.lanes,
              cell.column >= 0, cell.column < Lawn.columns,
              defenders[cell] == nil,
              !doomState.charges.contains(where: { $0.lane == cell.lane && $0.column == cell.column }),
              !doomState.craters.contains(where: { $0.lane == cell.lane && $0.column == cell.column }) else { return false }
        if kind.id == AdventureDoom.id {
            guard doomState.cooldown <= 0 else { return false }
            nextDoomID += 1
            doomState.plant(id: nextDoomID, lane: cell.lane, column: cell.column)
            renderDoom()
            return true
        }
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
        let occupied = defenders[cell] != nil || hasDoomCrater(at: point)
            || doomState.charges.contains { $0.lane == cell.lane && $0.column == cell.column }
        let color = occupied ? Palette.hurt : Palette.jade
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

    /// 已经布阵的路数（有射手的路）和格子数（含防御道具）
    var plantedLaneCount: Int { Set(defenders.filter { $0.value.canShoot }.keys.map(\.lane)).count }
    var plantedCellCount: Int { defenders.count }

    /// 准备阶段一键清空已种单位与预放毁灭菇
    func clearPreparedDefenders() {
        for node in defenders.values { node.removeFromParent() }
        defenders.removeAll()
        doomState = AdventureDoomState()
        doomRemainder = 0
        renderDoom()
        plantPreview?.isHidden = true
    }

    /// 落点是否在本局可种的草坪上（不管格子有没有被占）
    func isPlantable(_ point: CGPoint) -> Bool {
        lawn.cell(at: point) != nil
    }
}
