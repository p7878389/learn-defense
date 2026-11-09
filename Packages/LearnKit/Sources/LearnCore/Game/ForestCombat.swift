import Foundation

extension ForestBattle {
    public static let repairCost = 15
    public static let heroSkillCooldown = 12.0

    @discardableResult public mutating func deploy(_ hero: ForestHero, at slot: Int) -> Bool {
        guard phase == .preparing, Self.slots.indices.contains(slot), defenses[slot] == nil, coins >= 50,
              !defenses.values.contains(where: { $0.hero == hero }) else { return false }
        coins -= 50
        defenses[slot] = ForestDefenseUnit(hero: hero)
        return true
    }

    @discardableResult public mutating func repair(at slot: Int) -> Bool {
        guard phase == .preparing || phase == .fighting, var unit = defenses[slot],
              unit.health < unit.maxHealth, coins >= Self.repairCost else { return false }
        coins -= Self.repairCost
        unit.health = min(unit.maxHealth, unit.health + 20)
        defenses[slot] = unit
        addZone(at: Self.slots[slot], effect: .repair, radius: 0.045, seconds: 0.6)
        return true
    }

    @discardableResult public mutating func useSkill(at slot: Int) -> Bool {
        guard phase == .fighting, var unit = defenses[slot], unit.alive, let hero = unit.hero,
              unit.skillCooldown <= 0, unit.cast == nil else { return false }
        let point = Self.slots[slot]
        let target = enemies.filter { $0.health > 0 && point.distance(to: ForestPath.forest.point(at: $0.distance)) <= 0.30 }
            .max { $0.distance < $1.distance }
        guard hero == .paladin || target != nil else { return false }
        unit.cast = ForestCast(target: target?.id ?? -1,
                               point: target.map { ForestPath.forest.point(at: $0.distance) } ?? point,
                               windup: hero == .paladin ? 0.8 : 1, recovery: 0.5,
                               effect: hero == .paladin ? .shield : .vines, skill: true, count: 1)
        unit.skillCooldown = Self.heroSkillCooldown
        defenses[slot] = unit
        return true
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
                while cast.emitted < cast.count && cast.age + 1e-9 >= cast.windup + Double(cast.emitted) * 0.12 {
                    let source = ForestPath.forest.point(at: enemies[index].distance)
                    let area = cast.skill && kind != .reaper ? 0.12 : 0
                    emit(side: .enemy, source: enemies[index].id, target: cast.target,
                         origin: source, point: cast.point, effect: cast.effect,
                         damage: kind.isBoss ? (cast.skill ? 5 : 3) : (kind.ranged ? 3 : 1),
                         flight: kind.ranged ? 0.35 : 0.08, radius: area, skill: cast.skill)
                    cast.emitted += 1
                }
                if cast.age >= cast.duration {
                    enemies[index].cast = nil
                    enemies[index].attackCooldown = kind.isBoss ? 3.2 : 4
                } else { enemies[index].cast = cast }
            } else if enemies[index].attackCooldown <= 0 {
                let kind = enemies[index].kind
                let source = ForestPath.forest.point(at: enemies[index].distance)
                let range = kind.ranged ? 0.24 : 0.13
                let candidates = defenses.keys.sorted().filter {
                    defenses[$0]!.alive && source.distance(to: Self.slots[$0]) <= range
                }
                guard let target = candidates.min(by: { source.distance(to: Self.slots[$0]) < source.distance(to: Self.slots[$1]) }) else { continue }
                enemies[index].attacks += 1
                let skill = kind.isBoss && enemies[index].attacks.isMultiple(of: 3)
                let count = skill && (kind == .reaper || kind == .gargoyle) ? 3 : 1
                enemies[index].cast = ForestCast(target: target, point: Self.slots[target],
                                                windup: kind.windup + (skill && !kind.ranged ? 0.25 : 0),
                                                recovery: kind.recovery,
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
            unit.cooldown = max(0, unit.cooldown - dt * (unit.chilled > 0 ? 0.5 : 1))
            if var cast = unit.cast {
                let targetAlive = enemies.contains { $0.id == cast.target && $0.health > 0 }
                guard cast.effect == .shield || targetAlive else {
                    unit.cast = nil
                    unit.cooldown = 0.4
                    defenses[slot] = unit
                    continue
                }
                cast.age += dt
                if cast.emitted == 0 && cast.age + 1e-9 >= cast.windup {
                    if cast.effect == .shield {
                        for target in defenses.keys.sorted() where Self.slots[target].distance(to: Self.slots[slot]) <= 0.30 {
                            defenses[target]!.shield = 6
                        }
                        unit.shield = 6
                        addZone(at: Self.slots[slot], effect: .shield, radius: 0.30, seconds: 0.7)
                    } else {
                        emit(side: .hero, source: slot, target: cast.target, origin: Self.slots[slot],
                             point: cast.point, effect: cast.effect, damage: cast.skill ? 2 : 1.2,
                             flight: hero == .paladin ? 0.12 : 0.35,
                             radius: cast.skill ? 0.14 : 0, skill: cast.skill)
                    }
                    cast.emitted = 1
                }
                if cast.age >= cast.duration { unit.cast = nil; unit.cooldown = 0.85 }
                else { unit.cast = cast }
            } else if unit.cooldown <= 0 {
                let source = Self.slots[slot]
                if let target = enemies.filter({ $0.health > 0 && source.distance(to: ForestPath.forest.point(at: $0.distance)) <= 0.24 })
                    .max(by: { $0.distance < $1.distance }) {
                    unit.cast = ForestCast(target: target.id, point: ForestPath.forest.point(at: target.distance),
                                           windup: hero.windup, recovery: hero == .paladin ? 0.35 : 0.45,
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
                if shot.effect == .frost { defenses[slot]!.chilled = 3 }
            }
            if shot.skill && [.acid, .flask, .sandstorm, .fire].contains(shot.effect) {
                addZone(at: shot.point, effect: shot.effect, radius: max(shot.radius, 0.1), seconds: 3)
            }
        } else {
            for index in enemies.indices where enemies[index].health > 0 {
                let inArea = shot.radius > 0 && ForestPath.forest.point(at: enemies[index].distance).distance(to: shot.point) <= shot.radius
                guard inArea || (shot.radius == 0 && enemies[index].id == shot.target) else { continue }
                enemies[index].health -= shot.damage
                enemies[index].hitTimer = ForestEnemy.hitFlash
                if shot.effect == .vines { enemies[index].rooted = 3 }
            }
            if shot.effect == .vines { addZone(at: shot.point, effect: .vines, radius: shot.radius, seconds: 3) }
        }
    }

    private mutating func damageDefense(_ slot: Int, amount: Double) {
        guard var unit = defenses[slot], unit.alive else { return }
        unit.health = max(0, unit.health - amount * (unit.shield > 0 ? 0.35 : 1))
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
            guard [.acid, .flask, .sandstorm, .fire].contains(zone.effect), zone.pulse >= 0.5 else { continue }
            zones[index].pulse -= 0.5
            for slot in defenses.keys.sorted() where Self.slots[slot].distance(to: zone.point) <= zone.radius {
                damageDefense(slot, amount: 1)
            }
        }
        zones.removeAll { $0.remaining <= 0 }
    }
}
