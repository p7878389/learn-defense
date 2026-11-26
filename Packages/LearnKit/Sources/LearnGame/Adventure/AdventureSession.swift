import Foundation
import LearnCore

struct AdventureHUD: Equatable {
    let phase: AdventureBattle.Phase
    let sun: Int
    let lives: Int
    let wave: Int
    let energy: Int
    let seconds: Int
    let rest: Int
    let defeated: Int
    let towers: Int
    let ultimateReady: Bool
    let doomCooldown: Int

    init(_ battle: AdventureBattle) {
        phase = battle.phase
        sun = battle.sun
        lives = battle.lives
        wave = battle.wave
        energy = battle.energy
        seconds = Int(battle.elapsed)
        rest = Int(ceil(battle.restRemaining))
        defeated = battle.defeated
        towers = battle.towers.count
        ultimateReady = battle.ultimateReady
        doomCooldown = max(0, Int(ceil(battle.doomCooldown)))
    }
}

@MainActor
final class AdventureSession: ObservableObject {
    private(set) var battle: AdventureBattle
    let scene: AdventureScene
    let loadout: Loadout
    @Published private(set) var hud: AdventureHUD
    @Published private(set) var error: String?
    private let model: AppModel
    private let growth: GrowthStore
    private var closed = false

    var plantable: [DefenderKind] {
        battle.deck.filter(growth.state.canUseDefender).compactMap(AdventureCatalog.defender)
    }

    init(levelID: Int, model: AppModel, profileID: UUID, difficulty: Difficulty,
         deck: [String] = AdventureCatalog.defaultDeck) {
        self.model = model
        growth = model.growth(for: profileID)
        let allowedDeck = deck.allSatisfy(growth.state.canUseDefender) ? deck : AdventureCatalog.defaultDeck
        let state = AdventureBattle(level: AdventureCatalog.level(levelID) ?? AdventureCatalog.levels[0], difficulty: difficulty, deck: allowedDeck)
        battle = state
        hud = AdventureHUD(state)
        loadout = growth.loadout
        scene = AdventureScene(loadout: loadout)
        let enemies = Array(Set(state.level.waves.flatMap { $0.enemies.map(\.kind.artwork) }))
        UnitSprites.preloadCombat(defenders: plantable, enemies: enemies, loadout: loadout)
        scene.onAdvance = { [weak self] dt in self?.advance(by: dt) }
        scene.render(state, events: [])
    }

    @discardableResult
    func plant(_ id: String, lane: Int, column: Int) -> Bool {
        guard !closed, error == nil, growth.state.canUseDefender(id), battle.plant(id, lane: lane, column: column) else { return false }
        changed()
        return true
    }

    func shovel(lane: Int, column: Int) {
        guard !closed, battle.shovel(lane: lane, column: column) else { return }
        changed()
    }

    func start() {
        guard !closed else { return }
        var next = battle
        guard next.start() else { return }
        do {
            try growth.startAdventure(next)
            battle = next
            error = nil
            changed()
            model.objectWillChange.send()
        } catch { self.error = error.localizedDescription }
    }

    func advance(by seconds: Double) {
        guard !closed, error == nil, battle.phase == .playing else { return }
        let events = battle.advance(by: seconds)
        scene.render(battle, events: events)
        publishHUD()
        if battle.isFinished { persist() }
    }

    func unleash() {
        guard !closed, error == nil else { return }
        let events = battle.unleash()
        guard !events.isEmpty else { return }
        scene.render(battle, events: events)
        changed()
    }

    func suspend() {
        guard !closed else { return }
        battle.pause()
        scene.setPaused(true)
        publishHUD()
    }

    func resume() {
        guard !closed, battle.phase == .paused else { return }
        error = nil
        battle.resume()
        changed()
    }

    func retrySave() {
        error = nil
        if battle.isFinished { persist() }
    }

    @discardableResult
    func abandon() -> Bool {
        guard !closed else { return true }
        do {
            if battle.phase != .preparing && !battle.isFinished { try growth.abandonAdventure(battle) }
            else if battle.isFinished { try growth.finishAdventure(battle) }
            closed = true
            scene.setPaused(true)
            model.objectWillChange.send()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    private func changed() {
        scene.render(battle, events: [])
        publishHUD()
    }

    private func publishHUD() {
        let next = AdventureHUD(battle)
        if next != hud { hud = next }
    }

    private func persist() {
        do {
            if battle.isFinished { try growth.finishAdventure(battle) }
            model.objectWillChange.send()
        } catch {
            battle.pause()
            scene.setPaused(true)
            publishHUD()
            self.error = "对局保存失败，已暂停：\(error.localizedDescription)"
        }
    }
}
