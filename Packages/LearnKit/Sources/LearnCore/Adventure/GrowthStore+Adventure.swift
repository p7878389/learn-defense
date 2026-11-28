import Foundation

extension GrowthStore {
    public func startAdventure(_ battle: AdventureBattle) throws {
        try updateAdventureState { state in
            if state.adventure.active?.id == battle.id { return }
            guard state.adventure.active == nil else { throw AdventureError.activeBattle }
            guard battle.deck.allSatisfy(state.canUseDefender) else { throw AdventureError.invalidBattle }
            guard battle.phase == .playing, battle.elapsed == 0,
                  battle.level == AdventureCatalog.level(battle.level.id),
                  !state.adventure.results.contains(where: { $0.id == battle.id }) else { throw AdventureError.invalidBattle }
            guard state.adventure.isUnlocked(battle.level.id) else { throw AdventureError.locked }
            guard state.coins >= AdventureCatalog.entryCost else {
                throw AdventureError.notEnough(short: AdventureCatalog.entryCost - state.coins)
            }
            state.coins -= AdventureCatalog.entryCost
            state.appendCoinRecord(
                kind: .adventureEntry,
                delta: -AdventureCatalog.entryCost,
                title: "冒险闯关 · \(battle.level.title)",
                detail: "\(battle.difficulty.displayName)难度入场"
            )
            state.adventure.active = battle
        }
    }

    public func saveAdventure(_ battle: AdventureBattle) throws {
        try updateAdventureState { state in
            guard state.adventure.active?.id == battle.id else { throw AdventureError.missingSave }
            state.adventure.active = battle
        }
    }

    public func finishAdventure(_ battle: AdventureBattle) throws {
        try updateAdventureState { state in
            if state.adventure.results.contains(where: { $0.id == battle.id }) { return }
            guard battle.isFinished, state.adventure.active?.id == battle.id else { throw AdventureError.missingSave }
            if battle.phase == .won {
                let key = String(battle.level.id)
                state.adventure.bestStars[key] = max(state.adventure.bestStars[key] ?? 0, battle.stars)
            }
            state.adventure.record(battle, abandoned: false)
        }
    }

    public func abandonAdventure(_ current: AdventureBattle? = nil) throws {
        try updateAdventureState { state in
            guard let active = state.adventure.active else { return }
            let battle = current ?? active
            guard battle.id == active.id else { throw AdventureError.missingSave }
            state.adventure.record(battle, abandoned: true)
        }
    }
}

private extension AdventureProgress {
    mutating func record(_ battle: AdventureBattle, abandoned: Bool) {
        results.insert(AdventureResult(id: battle.id, levelID: battle.level.id,
                                       stars: abandoned ? 0 : battle.stars, lives: battle.lives,
                                       seconds: Int(battle.elapsed), abandoned: abandoned, date: Date()), at: 0)
        if results.count > 30 { results.removeLast(results.count - 30) }
        active = nil
    }
}
