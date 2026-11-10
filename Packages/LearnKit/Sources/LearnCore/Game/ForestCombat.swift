import Foundation

extension ForestBattle {
    @discardableResult public mutating func deploy(_ hero: ForestHero, at slot: Int) -> Bool {
        let stats = rules.hero(hero)
        guard phase == .preparing, Self.slots.indices.contains(slot), defenses[slot] == nil, coins >= stats.cost,
              !defenses.values.contains(where: { $0.hero == hero }) else { return false }
        coins -= stats.cost
        defenses[slot] = ForestDefenseUnit(hero: hero, maxHealth: stats.maxHealth)
        return true
    }

    @discardableResult public mutating func repair(at slot: Int) -> Bool {
        guard phase == .preparing || phase == .fighting, var unit = defenses[slot],
              unit.health < unit.maxHealth, coins >= rules.economy.repairCost else { return false }
        coins -= rules.economy.repairCost
        unit.health = min(unit.maxHealth, unit.health + rules.economy.repairAmount)
        defenses[slot] = unit
        addZone(at: Self.slots[slot], effect: .repair, radius: 0.045, seconds: 0.6)
        return true
    }

    /// 技能就绪：英雄存活、冷却完毕，且没有正在施放的技能。普攻进行中也可以放，技能会打断这次普攻。
    public func canUseSkill(at slot: Int) -> Bool {
        guard phase == .fighting, let unit = defenses[slot], unit.alive, unit.hero != nil else { return false }
        return unit.skillCooldown <= 0 && unit.cast?.skill != true
    }

    @discardableResult public mutating func useSkill(at slot: Int) -> Bool {
        guard phase == .fighting, var unit = defenses[slot], unit.alive, let hero = unit.hero,
              canUseSkill(at: slot) else { return false }
        let point = Self.slots[slot]
        let stats = rules.hero(hero)
        let target = enemies.filter { $0.health > 0 && point.distance(to: ForestPath.forest.point(at: $0.distance)) <= stats.skillRange }
            .max { $0.distance < $1.distance }
        guard hero == .paladin || target != nil else { return false }
        unit.cast = ForestCast(target: target?.id ?? -1,
                               point: target.map { ForestPath.forest.point(at: $0.distance) } ?? point,
                               windup: stats.skillWindup, recovery: stats.skillRecovery,
                               effect: hero == .paladin ? .shield : .vines, skill: true, count: 1)
        unit.skillCooldown = stats.skillCooldown
        defenses[slot] = unit
        return true
    }

    /// 一波结束时清掉只在战斗中有意义的状态：这些计时只在战斗中递减，不清会原样带进下一波。
    mutating func endCombat() {
        combatShots.removeAll()
        zones.removeAll()
        for slot in defenses.keys {
            defenses[slot]!.hitTimer = 0
            defenses[slot]!.shield = 0
            defenses[slot]!.chilled = 0
            defenses[slot]!.cast = nil
        }
    }

    /// 先结算已有弹道，再推进施法；死亡的施法者不能在同一帧继续出手。
    mutating func tickCombat(_ dt: Double) {
        for slot in defenses.keys.sorted() {
            defenses[slot]!.hitTimer = max(0, defenses[slot]!.hitTimer - dt)
            defenses[slot]!.shield = max(0, defenses[slot]!.shield - dt)
            defenses[slot]!.chilled = max(0, defenses[slot]!.chilled - dt)
            defenses[slot]!.skillCooldown = max(0, defenses[slot]!.skillCooldown - dt)
        }
        advanceShots(dt)
        advanceZones(dt)
        for index in enemies.indices {
            guard enemies[index].health > 0 else { enemies[index].cast = nil; continue }
            enemies[index].attackCooldown = max(0, enemies[index].attackCooldown - dt)
            if var cast = enemies[index].cast {
                guard defenses[cast.target]?.alive == true else {
                    enemies[index].cast = nil
                    enemies[index].attackCooldown = 1
                    continue
                }
                // 定身阻止移动，不冻结施法时间。
                cast.age += dt
                let kind = enemies[index].kind
                let stats = rules.enemy(kind)
                while cast.emitted < cast.count && cast.age + 1e-9 >= cast.windup + Double(cast.emitted) * 0.12 {
                    let source = ForestPath.forest.point(at: enemies[index].distance)
                    emit(side: .enemy, source: enemies[index].id, target: cast.target,
                         origin: source, point: cast.point, effect: cast.effect,
                         damage: cast.skill ? stats.skillDamage : stats.attackDamage,
                         flight: kind.ranged ? 0.35 : 0.08,
                         radius: cast.skill ? stats.skillRadius : 0, skill: cast.skill)
                    cast.emitted += 1
                }
                if cast.age >= cast.duration {
                    enemies[index].cast = nil
                    enemies[index].attackCooldown = stats.attackCooldown
                } else { enemies[index].cast = cast }
            } else if enemies[index].attackCooldown <= 0 {
                let kind = enemies[index].kind
                let source = ForestPath.forest.point(at: enemies[index].distance)
                let stats = rules.enemy(kind)
                let candidates = defenses.keys.sorted().filter {
                    defenses[$0]!.alive && source.distance(to: Self.slots[$0]) <= stats.attackRange
                }
                guard let target = candidates.min(by: { source.distance(to: Self.slots[$0]) < source.distance(to: Self.slots[$1]) }) else { continue }
                enemies[index].attacks += 1
                let every = rules.combat.skillEvery
                let skill = stats.skillDamage > 0 && every > 0 && enemies[index].attacks.isMultiple(of: every)
                let count = skill ? stats.skillCount : 1
                enemies[index].cast = ForestCast(target: target, point: Self.slots[target],
                                                windup: stats.windup + (skill && !kind.ranged ? rules.combat.meleeSkillExtraWindup : 0),
                                                recovery: stats.recovery,
                                                effect: skill ? kind.skillEffect : kind.effect,
                                                skill: skill, count: count)
                let dx = Self.slots[target].x - source.x
                if abs(dx) > 0.01 { enemies[index].facing = dx < 0 ? -1 : 1 }
            }
        }
        advanceHeroes(dt)
    }

    private mutating func advanceHeroes(_ dt: Double) {
        for slot in defenses.keys.sorted() {
            guard var unit = defenses[slot], unit.alive, let hero = unit.hero else { continue }
            let stats = rules.hero(hero)
            unit.cooldown = max(0, unit.cooldown - dt * (unit.chilled > 0 ? rules.combat.chillFactor : 1))
            if var cast = unit.cast {
                let targetAlive = enemies.contains { $0.id == cast.target && $0.health > 0 }
                // 技能锁定的是落点（或自身），目标中途倒下也照常释放；普攻失去目标才取消。
                guard cast.skill || targetAlive else {
                    unit.cast = nil
                    unit.cooldown = 0.4
                    defenses[slot] = unit
                    continue
                }
                cast.age += dt
                if cast.emitted == 0 && cast.age + 1e-9 >= cast.windup {
                    if cast.effect == .shield {
                        for target in defenses.keys.sorted() where Self.slots[target].distance(to: Self.slots[slot]) <= stats.skillRadius {
                            defenses[target]!.shield = stats.skillSeconds
                        }
                        unit.shield = stats.skillSeconds
                        addZone(at: Self.slots[slot], effect: .shield, radius: stats.skillRadius, seconds: 0.7)
                    } else {
                        emit(side: .hero, source: slot, target: cast.target, origin: Self.slots[slot],
                             point: cast.point, effect: cast.effect,
                             damage: cast.skill ? stats.skillDamage : stats.attackDamage,
                             flight: hero == .paladin ? 0.12 : 0.35,
                             radius: cast.skill ? stats.skillRadius : 0, skill: cast.skill)
                    }
                    cast.emitted = 1
                }
                if cast.age >= cast.duration { unit.cast = nil; unit.cooldown = stats.attackCooldown }
                else { unit.cast = cast }
            } else if unit.cooldown <= 0 {
                let source = Self.slots[slot]
                if let target = enemies.filter({ $0.health > 0 && source.distance(to: ForestPath.forest.point(at: $0.distance)) <= stats.attackRange })
                    .max(by: { $0.distance < $1.distance }) {
                    unit.cast = ForestCast(target: target.id, point: ForestPath.forest.point(at: target.distance),
                                           windup: stats.attackWindup, recovery: stats.attackRecovery,
                                           effect: hero == .paladin ? .holy : .seed, skill: false, count: 1)
                }
            }
            defenses[slot] = unit
        }
    }

    private mutating func emit(side: ForestCombatShot.Side, source: Int, target: Int, origin: ForestPoint,
                               point: ForestPoint, effect: ForestCombatEffect, damage: Double,
                               flight: Double, radius: Double, skill: Bool) {
        nextCombatID += 1
        combatShots.append(ForestCombatShot(id: nextCombatID, side: side, source: source, target: target,
                                            origin: origin, point: point, effect: effect, damage: damage,
                                            flight: flight, radius: radius, skill: skill))
    }

    private mutating func advanceShots(_ dt: Double) {
        for index in combatShots.indices {
            var shot = combatShots[index]
            shot.age += dt
            if !shot.impacted {
                // 英雄普通攻击追踪怪物；范围技能锁定落点。敌方结构固定，不改变预警落点。
                if shot.side == .hero && !shot.skill,
                   let enemy = enemies.first(where: { $0.id == shot.target && $0.health > 0 }) {
                    shot.point = ForestPath.forest.point(at: enemy.distance)
                }
                if shot.age >= shot.flight {
                    shot.impacted = true
                    impact(shot)
                }
            }
            combatShots[index] = shot
        }
        combatShots.removeAll { $0.age >= $0.duration }
    }

    private mutating func impact(_ shot: ForestCombatShot) {
        if shot.side == .enemy {
            for slot in defenses.keys.sorted() where defenses[slot]!.alive {
                let inArea = shot.radius > 0 && Self.slots[slot].distance(to: shot.point) <= shot.radius
                guard inArea || (shot.radius == 0 && slot == shot.target) else { continue }
                damageDefense(slot, amount: shot.damage)
                if shot.effect == .frost { defenses[slot]!.chilled = rules.combat.chillSeconds }
            }
            if shot.skill && [.acid, .flask, .sandstorm, .fire].contains(shot.effect) {
                addZone(at: shot.point, effect: shot.effect, radius: max(shot.radius, rules.combat.zoneMinRadius), seconds: rules.combat.zoneSeconds)
            }
        } else {
            let rootSeconds = rules.hero(.botanist).skillSeconds
            for index in enemies.indices where enemies[index].health > 0 {
                let inArea = shot.radius > 0 && ForestPath.forest.point(at: enemies[index].distance).distance(to: shot.point) <= shot.radius
                guard inArea || (shot.radius == 0 && enemies[index].id == shot.target) else { continue }
                enemies[index].health -= shot.damage
                enemies[index].hitTimer = ForestEnemy.hitFlash
                if shot.effect == .vines { enemies[index].rooted = rootSeconds }
            }
            if shot.effect == .vines { addZone(at: shot.point, effect: .vines, radius: shot.radius, seconds: rootSeconds) }
        }
    }

    private mutating func damageDefense(_ slot: Int, amount: Double) {
        guard var unit = defenses[slot], unit.alive else { return }
        unit.health = max(0, unit.health - amount * (unit.shield > 0 ? rules.combat.shieldDamageFactor : 1))
        unit.hitTimer = 0.18
        if !unit.alive { unit.cast = nil; unit.shield = 0 }
        defenses[slot] = unit
    }

    private mutating func addZone(at point: ForestPoint, effect: ForestCombatEffect, radius: Double, seconds: Double) {
        nextCombatID += 1
        zones.append(ForestZone(id: nextCombatID, point: point, effect: effect, radius: radius, remaining: seconds))
    }

    private mutating func advanceZones(_ dt: Double) {
        for index in zones.indices {
            zones[index].remaining -= dt
            zones[index].pulse += dt
            let zone = zones[index]
            guard [.acid, .flask, .sandstorm, .fire].contains(zone.effect), zone.pulse >= rules.combat.zoneTickSeconds else { continue }
            zones[index].pulse -= rules.combat.zoneTickSeconds
            for slot in defenses.keys.sorted() where Self.slots[slot].distance(to: zone.point) <= zone.radius {
                damageDefense(slot, amount: rules.combat.zoneTickDamage)
            }
        }
        zones.removeAll { $0.remaining <= 0 }
    }
}
