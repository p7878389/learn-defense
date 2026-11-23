import Foundation
import LearnCore

/// 进入准备界面不自动弹窗；沿用有效历史，首次手动选库，核对配置后才开战。
@MainActor
final class GamePreparation: ObservableObject {
    @Published private(set) var session: GameSession?
    @Published var choosingBank = false
    @Published var confirmingStart = false
    @Published private(set) var error: String?
    private(set) var config: GameConfig
    let model: AppModel
    private let preferences: UserDefaults
    private let preferenceKey: String

    init(config: GameConfig, model: AppModel, preferences: UserDefaults = .standard) {
        self.config = config
        self.model = model
        self.preferences = preferences
        let mode: String
        if case .review = config.selection { mode = "review" } else { mode = "classic" }
        preferenceKey = "question-bank.\(config.profileID.uuidString).\(mode)"
        let data = preferences.data(forKey: preferenceKey)
        let saved = data
            .flatMap { try? JSONDecoder().decode(QuestionBankPreference.self, from: $0) }
            .flatMap { $0.restore(for: config, library: model.library) }
        // 升级前已有对局时从最近记录恢复；已保存但失效的选择必须重选，不退回更旧的范围。
        let previous = saved ?? (data == nil ? Self.historicalConfig(for: config, model: model) : nil)
        self.config = previous ?? QuestionBankDraft(config: config, library: model.library).confirmedConfig() ?? config
        session = makeSession(self.config, confirmed: previous != nil)
    }

    @discardableResult
    func confirm(_ config: GameConfig) -> Bool {
        guard session == nil || session?.phase == .preparing,
              config.profileID == self.config.profileID,
              !ItemPool(packs: config.packIDs.compactMap(model.library.pack(id:)), selection: config.selection).isEmpty else { return false }
        do {
            let value = QuestionBankPreference(config: config)
            preferences.set(try JSONEncoder().encode(value), forKey: preferenceKey)
        } catch {
            self.error = "题库选择未保存，请重试。"
            return false
        }
        let unchanged = session?.bankConfirmed == true && self.config.grade == config.grade
            && self.config.packIDs == config.packIDs && self.config.selection == config.selection
            && self.config.difficulty == config.difficulty
        if !unchanged {
            session?.end()
            self.config = config
            session = makeSession(config, confirmed: true)
        }
        if var profile = model.profiles.first(where: { $0.id == config.profileID }), profile.difficulty != config.difficulty {
            profile.difficulty = config.difficulty
            model.save(profile)
        }
        choosingBank = false
        confirmingStart = false
        error = nil
        return true
    }

    @discardableResult
    func chooseBank() -> Bool {
        guard session == nil || session?.phase == .preparing else { return false }
        confirmingStart = false
        error = nil
        choosingBank = true
        return true
    }

    func cancelChoosing() {
        choosingBank = false
        error = nil
    }

    @discardableResult
    func requestStartConfirmation() -> Bool {
        guard !choosingBank, session?.canStartBattle == true else { return false }
        confirmingStart = true
        return true
    }

    func cancelStartConfirmation() { confirmingStart = false }

    func confirmStart() {
        guard confirmingStart, !choosingBank, session?.canStartBattle == true else { return }
        session?.startBattle()
        if session?.phase == .playing { confirmingStart = false }
    }

    private func makeSession(_ config: GameConfig, confirmed: Bool) -> GameSession {
        GameSession(config: config, library: model.library, progress: model.progress(for: config.profileID),
                    speech: model.speech, growth: model.growth(for: config.profileID), recorder: model.recorder(for: config),
                    map: preferences.string(forKey: BattleMap.preferenceKey).flatMap(BattleMap.init(rawValue:)) ?? .woodland,
                    bankConfirmed: confirmed)
    }

    private static func historicalConfig(for config: GameConfig, model: AppModel) -> GameConfig? {
        guard let games = try? model.database?.games(profileID: config.profileID) else { return nil }
        let reviewing: Bool
        if case .review = config.selection { reviewing = true } else { reviewing = false }
        guard let last = games.first(where: { ($0.selection == "review") == reviewing }),
              let grade = Grade(rawValue: last.grade) else { return nil }
        let selection: ItemPool.Selection
        if reviewing { selection = config.selection }
        else if last.selection == "units" { selection = .units(Set(last.unitKeys.split(separator: ",").map(String.init))) }
        else if last.selection == "all" { selection = .all }
        else { return nil }
        let choice = GameConfig(profileID: config.profileID, grade: grade,
                                packIDs: last.packIDs.split(separator: ",").map(String.init), selection: selection,
                                difficulty: config.difficulty)
        return QuestionBankPreference(config: choice).restore(for: config, library: model.library)
    }
}

/// 只记录选题范围；复习题目使用实时错题集合，避免恢复过期错题或串用孩子档案。
private struct QuestionBankPreference: Codable {
    let grade: Grade
    let packIDs: [String]
    let unitKeys: Set<String>?

    init(config: GameConfig) {
        grade = config.grade
        packIDs = config.packIDs
        if case .units(let keys) = config.selection { unitKeys = keys } else { unitKeys = nil }
    }

    func restore(for config: GameConfig, library: ContentLibrary) -> GameConfig? {
        let packs = packIDs.compactMap(library.pack(id:))
        guard !packs.isEmpty, packs.count == packIDs.count, packs.allSatisfy({ $0.grade == grade }) else { return nil }
        let selection: ItemPool.Selection
        if case .review(let keys) = config.selection { selection = .review(keys) }
        else if let unitKeys {
            let available = Set(packs.flatMap { pack in pack.units.map { QuestionBankChoice.unitKey(pack: pack, unit: $0) } })
            guard !unitKeys.isEmpty, unitKeys.isSubset(of: available) else { return nil }
            selection = .units(unitKeys)
        } else { selection = .all }
        guard !ItemPool(packs: packs, selection: selection).isEmpty else { return nil }
        return GameConfig(profileID: config.profileID, grade: grade, packIDs: packIDs, selection: selection, difficulty: config.difficulty)
    }
}

struct QuestionBankDraft {
    private let original: GameConfig
    private let library: ContentLibrary
    private let reviewKeys: Set<String>?
    private(set) var subject: Subject
    private(set) var grade: Grade
    private(set) var difficulty: Difficulty
    private(set) var edition: String?
    private(set) var packID: String?
    private(set) var units: Set<String> = []

    init(config: GameConfig, library: ContentLibrary) {
        original = config
        self.library = library
        grade = config.grade
        difficulty = config.difficulty
        let keys: Set<String>?
        if case .review(let value) = config.selection { keys = value } else { keys = nil }
        reviewKeys = keys
        let candidates = config.packIDs.compactMap(library.pack(id:))
        let initial = candidates.first(where: { pack in
            if let keys { return !ItemPool(packs: [pack], selection: .review(keys)).isEmpty }
            return true
        }) ?? candidates.first ?? library.packs.first { $0.grade == config.grade }
        subject = initial?.subject ?? .chinese
        edition = initial.map(QuestionBankChoice.edition)
        packID = initial?.id
        if case .units(let keys) = config.selection { units = keys }
        else { selectAllUnits() }
    }

    var isReview: Bool { reviewKeys != nil }
    var gradePacks: [ContentPack] { library.packs(grade: grade, subject: subject) }
    var editions: [String] { QuestionBankChoice.editions(in: gradePacks) }
    var selectedEdition: String? { edition.flatMap { editions.contains($0) ? $0 : nil } ?? editions.first }
    var packs: [ContentPack] { selectedEdition.map { QuestionBankChoice.packs(gradePacks, edition: $0) } ?? [] }
    var selectedPack: ContentPack? { packs.first { $0.id == packID } ?? packs.first }
    var allUnitKeys: Set<String> {
        guard let pack = selectedPack else { return [] }
        return Set(pack.units.map { QuestionBankChoice.unitKey(pack: pack, unit: $0) })
    }

    mutating func selectDifficulty(_ value: Difficulty) { difficulty = value }

    mutating func selectSubject(_ value: Subject) {
        guard subject != value else { return }
        subject = value
        resetBook()
    }

    mutating func selectGrade(_ value: Grade) {
        guard grade != value else { return }
        grade = value
        resetBook()
    }

    mutating func selectEdition(_ value: String) {
        guard editions.contains(value), value != selectedEdition else { return }
        edition = value
        packID = nil
        selectAllUnits()
    }

    mutating func selectPack(_ value: String) {
        guard packs.contains(where: { $0.id == value }), selectedPack?.id != value else { return }
        packID = value
        selectAllUnits()
    }

    mutating func toggleUnit(_ key: String) {
        guard let pack = selectedPack, pack.units.contains(where: { QuestionBankChoice.unitKey(pack: pack, unit: $0) == key }) else { return }
        if units.contains(key) { units.remove(key) } else { units.insert(key) }
    }

    mutating func selectAllUnits() { units = allUnitKeys }
    mutating func clearUnits() { units = [] }

    func confirmedConfig() -> GameConfig? {
        let ids: [String]
        let selection: ItemPool.Selection
        if let reviewKeys {
            ids = gradePacks.map(\.id)
            selection = .review(reviewKeys)
        } else {
            guard let pack = selectedPack else { return nil }
            ids = [pack.id]
            let valid = Set(pack.units.map { QuestionBankChoice.unitKey(pack: pack, unit: $0) })
            let selected = units.intersection(valid)
            guard !selected.isEmpty else { return nil }
            selection = selected == valid ? .all : .units(selected)
        }
        guard !ItemPool(packs: ids.compactMap(library.pack(id:)), selection: selection).isEmpty else { return nil }
        return GameConfig(profileID: original.profileID, grade: grade, packIDs: ids, selection: selection, difficulty: difficulty)
    }

    private mutating func resetBook() {
        edition = nil
        packID = nil
        selectAllUnits()
    }
}
