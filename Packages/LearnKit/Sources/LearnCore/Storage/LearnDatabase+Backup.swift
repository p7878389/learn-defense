import Foundation
import SwiftData

public struct SettingsBackup: Codable {
    public struct Child: Codable {
        public var profile: Profile
        public var stats: [String: ItemStats]
        public var growth: GrowthState?
    }
    public struct Battle: Codable {
        public var record: GameRecord
        public var answers: [AnswerRecord]
    }
    public var version = 1
    public var createdAt = Date()
    public var children: [Child]
    public var games: [Battle]
    public var settings: [String: Data]
    public var importedPacks: [Data]
    public var packAudio: [String: Data]

    public init(children: [Child], games: [Battle], settings: [String: Data], importedPacks: [Data], packAudio: [String: Data] = [:]) {
        self.children = children; self.games = games; self.settings = settings; self.importedPacks = importedPacks; self.packAudio = packAudio
    }

    public static func decode(_ data: Data) throws -> Self {
        guard data.count <= 100_000_000 else { throw SettingsError.invalid("备份文件超过 100 MB") }
        let backup = try JSONDecoder().decode(Self.self, from: data)
        try backup.validate()
        return backup
    }

    public func validate() throws {
        let ids = Set(children.map { $0.profile.id })
        guard version == 1, ids.count == children.count,
              Set(games.map { $0.record.id }).count == games.count,
              games.allSatisfy({ ids.contains($0.record.profileID) }) else {
            throw SettingsError.invalid("备份版本不支持，或存在重复/无所属档案的记录")
        }
        for child in children {
            guard !child.profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw SettingsError.invalid("备份中存在空名字档案")
            }
        }
        guard packAudio.keys.allSatisfy({ !$0.isEmpty && !$0.contains("/") && !$0.contains("\\") && $0.hasSuffix(".mp3") }) else {
            throw SettingsError.invalid("课本音频文件名无效")
        }
        let manager = PackManager(directory: FileManager.default.temporaryDirectory)
        let packs = try importedPacks.map { try manager.preview($0).pack }
        guard Set(packs.map(\.id)).count == packs.count else { throw SettingsError.invalid("备份包含重复课本") }
        if let data = settings["reader-preferences"] { _ = try JSONDecoder().decode(ReaderPreferences.self, from: data) }
        if let data = settings["game-rules.json"] { _ = try JSONDecoder().decode(GameRules.self, from: data) }
    }
}

extension LearnDatabase {
    public func setting<T: Codable>(named name: String, fallback: T) throws -> T {
        guard let row = try configFile(named: name) else { return fallback }
        return try JSONDecoder().decode(T.self, from: row.data)
    }

    public func saveSetting<T: Codable>(_ value: T, named name: String) throws {
        let data = try JSONEncoder().encode(value)
        if let row = try configFile(named: name) {
            row.data = data; row.syncedAt = Date()
        } else { context.insert(StoredConfigFile(name: name, data: data)) }
        try context.save()
    }

    /// 仅清学习与历史，不移除孩子档案或成长资产。
    public func resetLearning(profileID: UUID) throws {
        let pid = profileID.uuidString
        do {
            for row in try context.fetch(FetchDescriptor<StoredItemStats>()) where row.profileID == pid { context.delete(row) }
            for row in try context.fetch(FetchDescriptor<StoredGame>()) where row.profileID == pid { context.delete(row) }
            for row in try context.fetch(FetchDescriptor<StoredAnswer>()) where row.profileID == pid { context.delete(row) }
            let key = "reset-learning-" + pid
            if let row = try configFile(named: key) { row.data = try JSONEncoder().encode(true) }
            else { context.insert(StoredConfigFile(name: key, data: try JSONEncoder().encode(true))) }
            try context.save()
        } catch { context.rollback(); throw error }
    }

    public func backupData(importedPacks: [Data], packAudio: [String: Data] = [:]) throws -> Data {
        let children = try profiles().map {
            SettingsBackup.Child(profile: $0, stats: try stats(profileID: $0.id), growth: try growthState(profileID: $0.id))
        }
        let allAnswers = try context.fetch(FetchDescriptor<StoredAnswer>())
        let answersByGame = Dictionary(grouping: allAnswers, by: \.gameID)
        let games = try context.fetch(FetchDescriptor<StoredGame>()).map { row in
            SettingsBackup.Battle(record: try GameRecord(stored: row),
                                  answers: try (answersByGame[row.id] ?? []).sorted { $0.index < $1.index }.map { try AnswerRecord(stored: $0) })
        }
        var settings: [String: Data] = [:]
        for row in try context.fetch(FetchDescriptor<StoredConfigFile>()) where ["reader-preferences", "game-rules.json"].contains(row.name) {
            settings[row.name] = row.data
        }
        let backup = SettingsBackup(children: children, games: games, settings: settings, importedPacks: importedPacks, packAudio: packAudio)
        try backup.validate()
        let data = try JSONEncoder().encode(backup)
        guard data.count <= 100_000_000 else { throw SettingsError.invalid("备份超过 100 MB，请先减少导入课本音频") }
        return data
    }

    /// 所有校验在删除之前完成，最后只保存一次；失败时回滚未保存的数据库变更。
    public func restore(_ backup: SettingsBackup) throws {
        try backup.validate()
        do {
            for row in try context.fetch(FetchDescriptor<StoredAnswer>()) { context.delete(row) }
            for row in try context.fetch(FetchDescriptor<StoredGame>()) { context.delete(row) }
            for row in try context.fetch(FetchDescriptor<StoredItemStats>()) { context.delete(row) }
            for row in try context.fetch(FetchDescriptor<StoredGrowth>()) { context.delete(row) }
            for row in try context.fetch(FetchDescriptor<StoredProfile>()) { context.delete(row) }
            // 先保存删除会破坏原子性，因此使用现有模型的唯一键更新并不可行；
            // SwiftData 同一上下文删除后插入同键在一次 save 内完成替换。
            for (index, child) in backup.children.enumerated() {
                context.insert(StoredProfile(profile: child.profile, position: index))
                for (key, stats) in child.stats {
                    context.insert(StoredItemStats(profileID: child.profile.id.uuidString, key: key, stats: stats))
                }
                if let growth = child.growth {
                    context.insert(StoredGrowth(profileID: child.profile.id.uuidString, state: growth, data: try JSONEncoder.growth.encode(growth)))
                }
            }
            for game in backup.games {
                context.insert(StoredGame(record: game.record))
                for (i, answer) in game.answers.enumerated() {
                    context.insert(StoredAnswer(answer: answer, gameID: game.record.id.uuidString,
                                                profileID: game.record.profileID.uuidString, index: i))
                }
            }
            for row in try context.fetch(FetchDescriptor<StoredConfigFile>()) where ["reader-preferences", "game-rules.json"].contains(row.name) {
                context.delete(row)
            }
            for (name, data) in backup.settings where ["reader-preferences", "game-rules.json"].contains(name) {
                context.insert(StoredConfigFile(name: name, data: data))
            }
            let legacyKey = "legacy-disabled"
            if let row = try configFile(named: legacyKey) { row.data = try JSONEncoder().encode(true) }
            else { context.insert(StoredConfigFile(name: legacyKey, data: try JSONEncoder().encode(true))) }
            try context.save()
        } catch { context.rollback(); throw error }
    }
}

private extension GameRecord {
    init(stored s: StoredGame) throws {
        guard let id = UUID(uuidString: s.id), let pid = UUID(uuidString: s.profileID),
              let outcome = GameOutcome(rawValue: s.outcome), let grade = Grade(rawValue: s.grade),
              let difficulty = Difficulty(rawValue: s.difficulty) else { throw SettingsError.invalid("对局记录损坏") }
        self.init(id: id, profileID: pid, outcome: outcome, startedAt: s.startedAt, endedAt: s.endedAt,
                  grade: grade, difficulty: difficulty, packIDs: s.packIDs.split(separator: ",").map(String.init),
                  selection: s.selection, unitKeys: s.unitKeys.split(separator: ",").map(String.init),
                  questions: s.questions, firstTryCorrect: s.firstTryCorrect, stars: s.stars, score: s.score,
                  enemiesDefeated: s.enemiesDefeated, bossesDefeated: s.bossesDefeated,
                  itemsUsed: s.itemsUsed, ultimatesCast: s.ultimatesCast, seconds: s.seconds, xp: s.xp, coins: s.coins)
    }
}

private extension AnswerRecord {
    init(stored s: StoredAnswer) throws {
        guard let kind = QuestionKind(rawValue: s.kind) else { throw SettingsError.invalid("作答记录损坏") }
        itemKey = s.itemKey; self.kind = kind; prompt = s.prompt; answer = s.answer
        chosen = s.chosen; correct = s.correct; missed = s.missed; ultimate = s.ultimate
        responseMs = s.responseMs; answeredAt = s.answeredAt
    }
}
