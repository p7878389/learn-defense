import Foundation
import Testing
@testable import LearnCore

@Suite("家长设置")
struct ParentSettingsTests {
    @Test func threeWrongAnswersPersistCooldown() throws {
        let db = try LearnDatabase(url: nil)
        var gate = ParentGate()
        let now = Date(timeIntervalSince1970: 1000)
        for _ in 0..<3 { _ = gate.submit(-1, now: now) }
        try db.saveSetting(gate, named: "parent-gate")
        let restored: ParentGate = try db.setting(named: "parent-gate", fallback: ParentGate())
        #expect(!restored.canAnswer(now: now.addingTimeInterval(59)))
        #expect(restored.canAnswer(now: now.addingTimeInterval(60)))
        gate = restored
        let success = gate.submit(gate.answer, now: now.addingTimeInterval(60))
        #expect(success)
        #expect(gate.failures == 0)
    }

    @Test func importReplaceAndDeleteLeavesBuiltInAvailable() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let manager = PackManager(directory: dir)
        let pack = ContentLibrary.load(userDirectory: nil).packs[0]
        let data = try JSONEncoder().encode(pack)
        let draft = try manager.preview(data)
        try manager.install(draft)
        #expect(manager.imported().count == 1)
        try manager.install(draft)
        #expect(manager.imported().count == 1)
        try manager.remove(id: pack.id)
        #expect(manager.imported().isEmpty)
        #expect(ContentLibrary.load(userDirectory: nil).pack(id: pack.id) != nil)
    }

    @Test func invalidImportDoesNotWriteFiles() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let manager = PackManager(directory: dir)
        #expect(throws: (any Error).self) { try manager.preview(Data("{}".utf8)) }
        #expect(manager.imported().isEmpty)
    }

    @Test func backupRoundTripAndInvalidRestorePreserveData() throws {
        let db = try LearnDatabase(url: nil)
        let profile = Profile(name: "备份孩子", grade: .g3, avatar: "🐯")
        try db.saveProfiles([profile])
        var stats = ItemStats(); stats.wrong = 2
        try db.saveStats(["char:晨": stats], profileID: profile.id)
        var growth = GrowthState(); growth.coins = 42
        try db.saveGrowthState(growth, profileID: profile.id)
        let data = try db.backupData(importedPacks: [])
        try db.resetLearning(profileID: profile.id)
        #expect(try db.stats(profileID: profile.id).isEmpty)
        #expect(try db.profiles() == [profile])
        #expect(try db.growthState(profileID: profile.id)?.coins == 42)
        let archive = try SettingsBackup.decode(data)
        try db.restore(archive)
        #expect(try db.stats(profileID: profile.id)["char:晨"]?.wrong == 2)
        #expect(throws: (any Error).self) { try SettingsBackup.decode(Data("{}".utf8)) }
        #expect(try db.growthState(profileID: profile.id)?.coins == 42)
    }
    @Test func backupRestoresHistoryAfterDatabaseReopen() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("learn.store")
        let child = Profile(name: "小明", grade: .g3, avatar: "🐯")
        var gameID = UUID()
        do {
            let db = try LearnDatabase(url: url)
            try db.saveProfiles([child])
            let recorder = GameRecorder(database: db, profileID: child.id, grade: .g3,
                                        difficulty: .easy, packIDs: [], selection: .all)
            gameID = recorder.id
            let question = Question(kind: .listenPickChar, itemKey: "char:晨", instruction: "听音选字",
                                    prompt: "🔊", options: ["晨", "霜"], optionStyle: .text, answerIndex: 0)
            recorder.recordAnswer(question, chosenIndex: 0, shownAt: nil)
            recorder.finish(.won, summary: GameSummary(questions: 1, firstTryCorrect: 1, stars: 1, score: 10,
                enemiesDefeated: 1, bossesDefeated: 0, itemsUsed: 0, ultimatesCast: 0, seconds: 5))
            let backup = try SettingsBackup.decode(db.backupData(importedPacks: []))
            try db.restore(backup)
            try db.restore(backup)
        }
        let reopened = try LearnDatabase(url: url)
        #expect(try reopened.games(profileID: child.id).count == 1)
        #expect(try reopened.answers(gameID: gameID).first?.correct == true)
        let disabled: Bool = try reopened.setting(named: "legacy-disabled", fallback: false)
        #expect(disabled)
    }

    @Test func renewedChallengeCannotBypassCooldown() {
        var gate = ParentGate()
        let now = Date()
        for _ in 0..<3 { _ = gate.submit(-1, now: now) }
        gate.renewChallenge()
        let accepted = gate.submit(gate.answer, now: now)
        #expect(!accepted)
        #expect(gate.failures == 3)
    }

    @Test func invalidArchiveDoesNotReplacePackFiles() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let sentinel = dir.appendingPathComponent("keep.txt")
        try Data("original".utf8).write(to: sentinel)
        let db = try LearnDatabase(url: nil)
        var backup = SettingsBackup(children: [], games: [], settings: [:], importedPacks: [])
        backup.version = 99
        #expect(throws: (any Error).self) { try SettingsFiles.restore(backup, database: db, packsDirectory: dir) }
        #expect(try String(contentsOf: sentinel) == "original")
    }

    @Test func importedAudioRoundTripsWithBackup() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let db = try LearnDatabase(url: nil)
        let audio = Data([1, 2, 3])
        let backup = try SettingsBackup.decode(db.backupData(importedPacks: [], packAudio: ["lesson.mp3": audio]))
        try SettingsFiles.restore(backup, database: db, packsDirectory: dir)
        #expect(try Data(contentsOf: dir.appendingPathComponent("Audio/lesson.mp3")) == audio)
        var invalid = backup
        invalid.packAudio = ["../outside.mp3": audio]
        #expect(throws: (any Error).self) { try SettingsFiles.restore(invalid, database: db, packsDirectory: dir) }
        #expect(try Data(contentsOf: dir.appendingPathComponent("Audio/lesson.mp3")) == audio)
    }

    @Test func emptyRestoreResetsPersonalDataAndPreferences() throws {
        let db = try LearnDatabase(url: nil)
        let child = Profile(name: "小明", grade: .g3, avatar: "🐯")
        try db.saveProfiles([child])
        try db.saveGrowthState(GrowthState(), profileID: child.id)
        var reader = ReaderPreferences(); reader.volume = 0.2
        try db.saveSetting(reader, named: "reader-preferences")
        try db.restore(SettingsBackup(children: [], games: [], settings: [:], importedPacks: []))
        #expect(try db.profiles().isEmpty)
        #expect(try db.growthState(profileID: child.id) == nil)
        #expect(try db.configFile(named: "reader-preferences") == nil)
    }

    @Test func numericTonePinyinIsRejectedBeforeImport() throws {
        let manager = PackManager(directory: FileManager.default.temporaryDirectory)
        let pack = ContentPack(id: "invalid", title: "错误", subject: .chinese, grade: .g3,
            units: [ContentUnit(id: "u1", title: "单元",
                lessons: [Lesson(id: "l1", title: "课文", characters: [CharacterItem(char: "晨", pinyin: "chen2")])])])
        #expect(throws: (any Error).self) { try manager.preview(JSONEncoder().encode(pack)) }
    }

}
