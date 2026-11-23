import Foundation
import LearnCore
import Testing
@testable import LearnGame

@MainActor
@Suite("游戏内确认题库")
struct QuestionBankPreparationTests {
    private final class Preferences {
        let domain = "bank-tests-\(UUID())"
        let defaults: UserDefaults
        init() { defaults = UserDefaults(suiteName: domain)! }
        deinit { defaults.removePersistentDomain(forName: domain) }
    }
    private func library() -> ContentLibrary {
        ContentLibrary(packs: [pack("cn", grade: .g3, subject: .chinese),
                               pack("en", grade: .g3, subject: .english),
                               pack("cn1", grade: .g1, subject: .chinese)])
    }

    private func pack(_ id: String, grade: Grade, subject: Subject) -> ContentPack {
        ContentPack(id: id, title: id, subject: subject, grade: grade,
            units: [ContentUnit(id: "u", title: "第一单元", lessons: [Lesson(id: "l", title: "课文",
                questions: [ChoiceItem(id: "q", prompt: "选出春", options: ["春", "夏"], answer: "春")])]),
                    ContentUnit(id: "u2", title: "第二单元", lessons: [Lesson(id: "l2", title: "课文二",
                questions: [ChoiceItem(id: "q2", prompt: "选出夏", options: ["春", "夏"], answer: "夏")])])])
    }

    private func config(_ packID: String = "cn") -> GameConfig {
        GameConfig(profileID: UUID(), grade: .g3, packIDs: [packID], selection: .all, difficulty: .easy)
    }

    @Test func changingSubjectOrGradeClearsOldUnitSelection() throws {
        let initial = config()
        var draft = QuestionBankDraft(config: initial, library: library())
        draft.toggleUnit("cn/u2")
        #expect(try #require(draft.confirmedConfig()).selection == .units(["cn/u"]))
        draft.selectSubject(.english)
        let english = try #require(draft.confirmedConfig())
        #expect(english.packIDs == ["en"])
        #expect(english.selection == .all)
        #expect(english.profileID == initial.profileID && english.difficulty == .easy)
        draft.selectGrade(.g1)
        #expect(draft.confirmedConfig() == nil)
        draft.selectSubject(.chinese)
        #expect(try #require(draft.confirmedConfig()).packIDs == ["cn1"])
    }

    @Test func reviewConfirmationKeepsOnlySelectedSubjectAndRealReviewItems() throws {
        let library = library()
        let english = try #require(library.pack(id: "en"))
        let keys = Set(ItemPool(packs: [english], selection: .all).items.map(\.key))
        var initial = config()
        initial.packIDs = ["cn", "en"]
        initial.selection = .review(keys)
        let draft = QuestionBankDraft(config: initial, library: library)
        #expect(draft.subject == .english)
        let result = try #require(draft.confirmedConfig())
        #expect(result.packIDs == ["en"])
        #expect(result.selection == .review(keys))
    }

    @Test func firstUseShowsPreparationWithoutOpeningPickerAndCannotStartUnconfirmed() throws {
        let db = try LearnDatabase(url: nil)
        let model = AppModel(database: db, library: library(), speechLibrary: SpeechLibrary(database: db, settings: nil, premadeDirectories: []))
        let initial = config()
        let preferences = Preferences()
        let preparation = GamePreparation(config: initial, model: model, preferences: preferences.defaults)
        let preview = try #require(preparation.session)
        #expect(preview.phase == .preparing && !preparation.choosingBank)
        _ = preview.scene.plant(.inkling, in: DefenderCell(lane: 0, column: 0))
        preview.startBattle()
        #expect(preview.phase == .preparing && !preview.canStartBattle)
        var chosen = initial
        chosen.packIDs = ["en"]
        #expect(preparation.confirm(chosen))
        let session = try #require(preparation.session)
        #expect(session.config.packIDs == ["en"] && !preparation.choosingBank)
        _ = session.scene.plant(.inkling, in: DefenderCell(lane: 0, column: 0))
        session.startBattle()
        #expect(!preparation.chooseBank())
        #expect(!preparation.confirm(initial))
        #expect(preparation.session === session)
        #expect(model.growth(for: initial.profileID).state.coins == 0)
        session.end()
    }

    @Test func cancellingStaysInPreparationAndReselectionDiscardsOnlyPreparation() throws {
        let db = try LearnDatabase(url: nil)
        let model = AppModel(database: db, library: library(), speechLibrary: SpeechLibrary(database: db, settings: nil, premadeDirectories: []))
        let initial = config()
        let preferences = Preferences()
        let preparation = GamePreparation(config: initial, model: model, preferences: preferences.defaults)
        preparation.chooseBank()
        preparation.cancelChoosing()
        #expect(preparation.session?.phase == .preparing && !preparation.choosingBank)
        #expect(preparation.confirm(initial))
        let old = try #require(preparation.session)
        #expect(preparation.chooseBank())
        preparation.cancelChoosing()
        #expect(preparation.session === old)
        var next = initial.again()
        next.packIDs = ["en"]
        #expect(preparation.confirm(next))
        #expect(old.phase == .abandoned)
        #expect(preparation.session?.config.packIDs == ["en"])
        #expect(try db.games(profileID: initial.profileID).isEmpty)
        preparation.session?.end()
    }

    @Test func lastBankRestoresAfterReopeningButNeverCrossesProfiles() throws {
        let db = try LearnDatabase(url: nil)
        let model = AppModel(database: db, library: library(), speechLibrary: SpeechLibrary(database: db, settings: nil, premadeDirectories: []))
        let preferences = Preferences()
        var initial = config()
        initial.packIDs = []
        let first = GamePreparation(config: initial, model: model, preferences: preferences.defaults)
        var selected = initial
        selected.grade = .g1
        selected.packIDs = ["cn1"]
        selected.selection = .units(["cn1/u"])
        #expect(first.confirm(selected))
        first.session?.end()
        let reopened = GamePreparation(config: initial.again(), model: model, preferences: preferences.defaults)
        #expect(reopened.config.grade == .g1)
        #expect(reopened.config.packIDs == ["cn1"])
        #expect(reopened.config.selection == .units(["cn1/u"]))
        #expect(reopened.session?.bankConfirmed == true && !reopened.choosingBank)
        let other = GamePreparation(config: config(), model: model, preferences: preferences.defaults)
        #expect(other.session?.bankConfirmed == false)
        reopened.session?.end()
        other.session?.end()
    }

    @Test func startReviewConfirmsOnlyAfterExplicitApprovalAndCancelKeepsConfigEditable() throws {
        let db = try LearnDatabase(url: nil)
        let model = AppModel(database: db, library: library(), speechLibrary: SpeechLibrary(database: db, settings: nil, premadeDirectories: []))
        let preferences = Preferences()
        let initial = config()
        let preparation = GamePreparation(config: initial, model: model, preferences: preferences.defaults)
        #expect(!preparation.requestStartConfirmation())
        #expect(preparation.confirm(initial))
        let before = try #require(preparation.session)
        _ = before.scene.plant(.inkling, in: DefenderCell(lane: 0, column: 0))
        #expect(preparation.requestStartConfirmation())
        #expect(before.phase == .preparing && preparation.confirmingStart)
        preparation.cancelStartConfirmation()
        #expect(preparation.session === before && before.plantedLaneCount == 1)
        #expect(preparation.chooseBank())
        var modified = initial.again()
        modified.packIDs = ["en"]
        modified.difficulty = .hard
        #expect(preparation.confirm(modified))
        let session = try #require(preparation.session)
        #expect(session.config.difficulty == .hard && session.config.packIDs == ["en"])
        _ = session.scene.plant(.inkling, in: DefenderCell(lane: 0, column: 0))
        preparation.confirmStart()
        #expect(session.phase == .preparing)
        #expect(preparation.requestStartConfirmation())
        preparation.confirmStart()
        #expect(session.phase == .playing && !preparation.confirmingStart)
        session.end()
    }

    @Test func unitCheckboxesSupportAllSomeAndNoneWithoutChangingMeaning() throws {
        var draft = QuestionBankDraft(config: config(), library: library())
        #expect(draft.units == ["cn/u", "cn/u2"])
        draft.toggleUnit("cn/u2")
        #expect(try #require(draft.confirmedConfig()).selection == .units(["cn/u"]))
        draft.toggleUnit("cn/u")
        #expect(draft.confirmedConfig() == nil)
        draft.selectAllUnits()
        #expect(try #require(draft.confirmedConfig()).selection == .all)
        draft.clearUnits()
        #expect(draft.confirmedConfig() == nil)
    }

    @Test func existingGameHistorySeedsLastBankForUpgradeWithoutOpeningPicker() throws {
        let db = try LearnDatabase(url: nil)
        let initial = config()
        let recorder = GameRecorder(database: db, profileID: initial.profileID, grade: .g3, difficulty: .easy,
                                    packIDs: ["en"], selection: .units(["en/u2"]))
        try recorder.finish(.lost, summary: GameSummary(questions: 0, firstTryCorrect: 0, stars: 0, score: 0,
                                                   enemiesDefeated: 0, bossesDefeated: 0, itemsUsed: 0, ultimatesCast: 0, seconds: 1))
        let model = AppModel(database: db, library: library(), speechLibrary: SpeechLibrary(database: db, settings: nil, premadeDirectories: []))
        let preferences = Preferences()
        let preparation = GamePreparation(config: initial, model: model, preferences: preferences.defaults)
        #expect(preparation.config.packIDs == ["en"])
        #expect(preparation.config.selection == .units(["en/u2"]))
        #expect(preparation.session?.bankConfirmed == true && !preparation.choosingBank)
        preparation.session?.end()
    }

    @Test func removedSavedBankRequiresManualChoiceInsteadOfSilentlySelectingAll() throws {
        let db = try LearnDatabase(url: nil)
        let preferences = Preferences()
        let initial = config("en")
        let model = AppModel(database: db, library: library(), speechLibrary: SpeechLibrary(database: db, settings: nil, premadeDirectories: []))
        let first = GamePreparation(config: initial, model: model, preferences: preferences.defaults)
        #expect(first.confirm(initial))
        first.session?.end()
        let changed = AppModel(database: db, library: ContentLibrary(packs: [pack("cn", grade: .g3, subject: .chinese)]),
                               speechLibrary: SpeechLibrary(database: db, settings: nil, premadeDirectories: []))
        let reopened = GamePreparation(config: initial, model: changed, preferences: preferences.defaults)
        #expect(reopened.session?.bankConfirmed == false && !reopened.choosingBank)
        #expect(!reopened.requestStartConfirmation())
        reopened.session?.end()
    }

    @Test func confirmingUnchangedSettingsPreservesExistingFormation() throws {
        let db = try LearnDatabase(url: nil)
        let preferences = Preferences()
        let initial = config()
        let model = AppModel(database: db, library: library(), speechLibrary: SpeechLibrary(database: db, settings: nil, premadeDirectories: []))
        let preparation = GamePreparation(config: initial, model: model, preferences: preferences.defaults)
        #expect(preparation.confirm(initial))
        let session = try #require(preparation.session)
        _ = session.scene.plant(.inkling, in: DefenderCell(lane: 0, column: 0))
        #expect(preparation.chooseBank())
        #expect(preparation.confirm(initial.again()))
        #expect(preparation.session === session)
        #expect(session.phase == .preparing && session.plantedLaneCount == 1)
        session.end()
    }
}
