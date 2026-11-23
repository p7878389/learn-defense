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
    private var lastSave: Double = 0
    private var closed = false

    init(levelID: Int, model: AppModel, profileID: UUID, difficulty: Difficulty,
         deck: [String] = AdventureCatalog.defaultDeck) {
        self.model = model
        growth = model.growth(for: profileID)
        var state = growth.state.adventure.active
            ?? AdventureBattle(level: AdventureCatalog.level(levelID) ?? AdventureCatalog.levels[0], difficulty: difficulty, deck: deck)
        state.pause()
        battle = state
        hud = AdventureHUD(state)
        loadout = growth.loadout
        scene = AdventureScene(loadout: loadout)
        scene.onAdvance = { [weak self] dt in self?.advance(by: dt) }
        scene.render(state, events: [])
        if state.isFinished { persist() }
    }

    @discardableResult
    func plant(_ id: String, lane: Int, column: Int) -> Bool {
        guard !closed, error == nil, battle.plant(id, lane: lane, column: column) else { return false }
        changed(save: battle.phase != .preparing)
        return true
    }

    func shovel(lane: Int, column: Int) {
        guard !closed, battle.shovel(lane: lane, column: column) else { return }
        changed(save: battle.phase != .preparing)
    }

    func start() {
        guard !closed else { return }
        var next = battle
        guard next.start() else { return }
        do {
            try growth.startAdventure(next)
            battle = next
            error = nil
            changed(save: false)
            model.objectWillChange.send()
        } catch { self.error = error.localizedDescription }
    }

    func advance(by seconds: Double) {
        guard !closed, error == nil, battle.phase == .playing else { return }
        let events = battle.advance(by: seconds)
        scene.render(battle, events: events)
        publishHUD()
        if battle.isFinished || battle.elapsed - lastSave >= 2 { persist() }
    }

    func unleash() {
        guard !closed, error == nil else { return }
        let events = battle.unleash()
        guard !events.isEmpty else { return }
        scene.render(battle, events: events)
        changed(save: true)
    }

    func suspend() {
        guard !closed else { return }
        battle.pause()
        scene.setPaused(true)
        publishHUD()
        if battle.phase != .preparing { persist() }
    }

    func resume() {
        guard !closed, battle.phase == .paused else { return }
        error = nil
        battle.resume()
        persist()
        changed(save: false)
    }

    func retrySave() {
        error = nil
        if battle.phase != .preparing { persist() }
    }

    @discardableResult
    func abandon() -> Bool {
        guard !closed else { return true }
        do {
            if battle.phase != .preparing && !battle.isFinished { try growth.abandonAdventure() }
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

    private func changed(save: Bool) {
        scene.render(battle, events: [])
        publishHUD()
        if save { persist() }
    }

    private func publishHUD() {
        let next = AdventureHUD(battle)
        if next != hud { hud = next }
    }

    private func persist() {
        do {
            if battle.isFinished { try growth.finishAdventure(battle) }
            else { try growth.saveAdventure(battle) }
            lastSave = battle.elapsed
            model.objectWillChange.send()
        } catch {
            battle.pause()
            scene.setPaused(true)
            publishHUD()
            self.error = "对局保存失败，已暂停：\(error.localizedDescription)"
        }
    }
}
