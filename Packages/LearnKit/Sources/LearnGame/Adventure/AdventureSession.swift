import Combine
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
    struct VoicePrompt: Identifiable, Equatable {
        let id = UUID()
        let display: String
        let hint: String?
        let speechText: String
        let expected: String
        let english: Bool
    }

    private(set) var battle: AdventureBattle
    let scene: AdventureScene
    let loadout: Loadout
    @Published private(set) var hud: AdventureHUD
    @Published private(set) var error: String?
    @Published private(set) var currentVoicePrompt: VoicePrompt?
    @Published private(set) var speechActive = false
    @Published var isVoiceListening = false
    private let model: AppModel
    private let growth: GrowthStore
    private var voicePrompts: [VoicePrompt] = []
    private var voicePromptIndex = 0
    private var speechCancellable: AnyCancellable?
    private var closed = false

    var isVoiceControlsLocked: Bool { speechActive || isVoiceListening }

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
        voicePrompts = Self.buildVoicePrompts(model: model, profileID: profileID)
        currentVoicePrompt = voicePrompts.first
        speechActive = model.speech.isSpeaking
        speechCancellable = model.speech.$isSpeaking.sink { [weak self] speaking in
            guard let self, self.speechActive != speaking else { return }
            self.speechActive = speaking
        }
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

    @discardableResult
    func resetPreparation() -> Bool {
        guard !closed, battle.resetPreparation() else { return false }
        changed()
        return true
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

    func speakCurrentVoicePrompt() {
        guard let prompt = currentVoicePrompt else { return }
        model.speech.speak(prompt.speechText, interrupt: true, channel: .preview)
    }

    func stopSpeech() {
        model.speech.stop()
    }

    /// 冒险模式大声读出复习口令：补阳光 + 充大招能量，并切到下一个词卡
    @discardableResult
    func claimVoiceBoost() -> Bool {
        guard !closed, error == nil, battle.grantVoiceBoost() else { return false }
        if let prompt = currentVoicePrompt {
            model.speech.speak(prompt.speechText, interrupt: true, channel: .preview)
        }
        advanceVoicePrompt()
        changed()
        return true
    }

    private func advanceVoicePrompt() {
        guard !voicePrompts.isEmpty else { currentVoicePrompt = nil; return }
        voicePromptIndex = (voicePromptIndex + 1) % voicePrompts.count
        currentVoicePrompt = voicePrompts[voicePromptIndex]
    }

    private static func buildVoicePrompts(model: AppModel, profileID: UUID) -> [VoicePrompt] {
        let grade = model.profiles.first(where: { $0.id == profileID })?.grade ?? .g3
        let reviewKeys = model.progress(for: profileID).reviewKeys
        let gradePacks = model.library.packs.filter { $0.grade == grade }
        let packs = gradePacks.isEmpty ? model.library.packs : gradePacks
        let allItems = ItemPool(packs: packs, selection: .all).items
        let reviewItems = allItems.filter { reviewKeys.contains($0.key) }
        let englishItems = allItems.filter {
            if case .englishWord = $0 { return true }
            if case .sentence = $0 { return true }
            return false
        }
        // 错题优先，其次英语单词/句子（帮小学英语弱项高频磨耳朵），其余随机补充
        let ordered = reviewItems.shuffled() + englishItems.shuffled() + allItems.shuffled()
        var seen: Set<String> = []
        var result: [VoicePrompt] = []
        for item in ordered where seen.insert(item.key).inserted {
            guard let prompt = makeVoicePrompt(from: item) else { continue }
            result.append(prompt)
            if result.count >= 24 { break }
        }
        return result
    }

    private static func makeVoicePrompt(from item: LearningItem) -> VoicePrompt? {
        switch item {
        case .englishWord(let w):
            return VoicePrompt(display: w.word, hint: w.meaning, speechText: "\(w.word)，\(w.meaning)", expected: w.word, english: true)
        case .sentence(let s):
            return VoicePrompt(display: s.sentence, hint: s.meaning, speechText: s.sentence, expected: s.sentence, english: true)
        case .character(let c):
            let word = (c.words ?? []).first(where: { $0.contains(c.char) && $0.count > 1 })
            let speech = word.map { "\(c.char)，\($0)的\(c.char)" } ?? c.char
            return VoicePrompt(display: word ?? c.char, hint: Pinyin.normalize(c.pinyin), speechText: speech, expected: word ?? c.char, english: false)
        case .picture(let p):
            return VoicePrompt(display: "\(p.emoji) \(p.text)", hint: p.pinyin.map(Pinyin.normalize), speechText: p.text, expected: p.text, english: false)
        case .word(let w):
            return VoicePrompt(display: w.text, hint: w.pinyin.map(Pinyin.normalize), speechText: w.text, expected: w.text, english: false)
        case .idiom(let i):
            return VoicePrompt(display: i.text, hint: i.meaning, speechText: i.text, expected: i.text, english: false)
        case .poemLine(let p, let index) where index + 1 < p.lines.count:
            let line = p.lines[index]
            return VoicePrompt(display: line, hint: p.title, speechText: line, expected: line, english: false)
        default:
            return nil
        }
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
