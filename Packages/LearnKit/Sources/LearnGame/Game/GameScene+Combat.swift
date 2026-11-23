import LearnCore
import SpriteKit

extension GameScene {
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
}

extension GameScene: LaneField {
    func enemies(inLane lane: Int) -> [EnemyNode] {
        enemies.values.filter { $0.lane == lane }
    }
}
