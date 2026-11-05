import Foundation
import SwiftData
import Testing
@testable import LearnCore

@Suite("本地数据库")
struct DatabaseTests {
    static let packs = ContentLibrary.load(userDirectory: nil).packs

    @Test func syncContentIndexesEveryLearningItem() throws {
        let db = try LearnDatabase(url: nil)
        try db.syncContent(Self.packs)

        let stored = try db.packs(grade: .g3, subject: .chinese)
        #expect(stored.map(\.id) == ["chinese-g3-sample"])

        // 和出题用的知识点一致（同一知识点在多课出现时，数据库里每课各一行）
        let poolKeys = Set(ItemPool(packs: Self.packs, selection: .all).items.map(\.key))
        let dbKeys = Set(try db.context.fetch(FetchDescriptor<StoredItem>()).map(\.key))
        #expect(dbKeys == poolKeys)
    }

    @Test func resyncReplacesOldContent() throws {
        let db = try LearnDatabase(url: nil)
        try db.syncContent(Self.packs)
        try db.syncContent(Self.packs.filter { $0.grade == .g3 })
        #expect(try db.packs(grade: .k2, subject: .chinese).isEmpty)
        #expect(try db.context.fetch(FetchDescriptor<StoredItem>()).allSatisfy { $0.grade == "g3" })
    }

    @Test func findsWhereTextAppears() throws {
        let db = try LearnDatabase(url: nil)
        try db.syncContent(Self.packs)

        let hits = try db.items(containing: "晨")
        #expect(hits.contains { $0.kind == "character" && $0.text == "晨" && $0.pinyin == "chén" })
        #expect(hits.allSatisfy { $0.text.contains("晨") })

        let poem = try db.items(key: "poem:山行#0")
        #expect(poem.count == 1)
        #expect(poem.first?.packID == "chinese-g3-sample")
    }

    @Test func mistakesSortedByWrongCount() throws {
        let db = try LearnDatabase(url: nil)
        let profileID = UUID()
        let store = ProgressStore(profileID: profileID, database: db)
        let a = LearningItem.character(CharacterItem(char: "晨", pinyin: "chén"))
        let b = LearningItem.character(CharacterItem(char: "霜", pinyin: "shuāng"))
        let c = LearningItem.character(CharacterItem(char: "汉", pinyin: "hàn"))
        store.record(a, correct: false)
        store.record(b, correct: false)
        store.record(b, correct: false)
        store.record(c, correct: true)
        store.save()

        let mistakes = try db.mistakes(profileID: profileID)
        #expect(mistakes.map(\.key) == ["char:霜", "char:晨"])
        #expect(try db.mistakes(profileID: UUID()).isEmpty)

        try db.deleteStats(profileID: profileID)
        #expect(try db.stats(profileID: profileID).isEmpty)
    }

    // MARK: - 个人信息

    @Test func profilesKeepOrderAndSurviveReopen() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("learn-db-\(UUID())", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("learn.store")
        let a = Profile(name: "小明", grade: .g3, avatar: "🐯")
        var b = Profile(name: "小红", grade: .k2, avatar: "🐼", difficulty: .hard)
        do {
            let store = ProfileStore(database: try LearnDatabase(url: url))
            store.upsert(a)
            store.upsert(b)
            b.name = "小红红"
            store.upsert(b)
        }
        let reopened = ProfileStore(database: try LearnDatabase(url: url))
        #expect(reopened.profiles == [a, b])
        reopened.delete(id: a.id)
        #expect(ProfileStore(database: try LearnDatabase(url: url)).profiles == [b])
    }

    @Test func profilesMigrateFromLegacyJSONOnce() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("profiles-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let legacy = dir.appendingPathComponent("profiles.json")
        let old = [Profile(name: "小明", grade: .g3, avatar: "🐯"), Profile(name: "小红", grade: .k2, avatar: "🐼")]
        try JSONEncoder().encode(old).write(to: legacy)

        // 数据库打不开时只读旧文件，不改名
        #expect(ProfileStore(database: nil, legacyFile: legacy).profiles == old)
        #expect(FileManager.default.fileExists(atPath: legacy.path))

        let db = try LearnDatabase(url: nil)
        let store = ProfileStore(database: db, legacyFile: legacy)
        #expect(store.profiles == old)
        #expect(try db.profiles() == old)
        #expect(!FileManager.default.fileExists(atPath: legacy.path))
        #expect(FileManager.default.fileExists(atPath: AppPaths.migratedBackup(for: legacy).path))

        // 全部删掉后重新打开，不会再从旧文件导入
        for p in old { store.delete(id: p.id) }
        #expect(ProfileStore(database: db, legacyFile: legacy).profiles.isEmpty)
    }

    @Test func deletePersonalDataRemovesEverythingForOneChild() throws {
        let db = try LearnDatabase(url: nil)
        let kid = Profile(name: "小明", grade: .g3, avatar: "🐯")
        let other = Profile(name: "小红", grade: .k2, avatar: "🐼")
        ProfileStore(database: db).upsert(kid)
        try db.saveProfiles([kid, other])
        for id in [kid.id, other.id] {
            try db.saveGrowthState(GrowthState(), profileID: id)
            let progress = ProgressStore(profileID: id, database: db)
            progress.record(.character(CharacterItem(char: "晨", pinyin: "chén")), correct: false)
            progress.save()
        }

        try db.deletePersonalData(profileID: kid.id)
        #expect(try db.profiles() == [other])
        #expect(try db.growthState(profileID: kid.id) == nil)
        #expect(try db.stats(profileID: kid.id).isEmpty)
        #expect(try db.growthState(profileID: other.id) != nil)
        #expect(try db.stats(profileID: other.id).count == 1)
    }

    @Test func growthColumnsMirrorState() throws {
        let db = try LearnDatabase(url: nil)
        let id = UUID()
        var state = GrowthState()
        state.xp = 420
        state.coins = 33
        state.stats.gamesPlayed = 7
        state.badges["firstWin"] = Date(timeIntervalSince1970: 1_700_000_000)
        try db.saveGrowthState(state, profileID: id)

        let pid = id.uuidString
        let row = try #require(try db.context.fetch(FetchDescriptor<StoredGrowth>(predicate: #Predicate { $0.profileID == pid })).first)
        #expect(row.xp == 420 && row.coins == 33 && row.gamesPlayed == 7 && row.badgeCount == 1)
        #expect(try db.growthState(profileID: id) == state)
    }

    // MARK: - 系统配置

    @Test func syncConfigStoresFilesBadgesAndCosmetics() throws {
        let catalog = GrowthCatalog.bundled
        let db = try LearnDatabase(url: nil)
        try db.syncConfig(catalog)
        try db.syncConfig(catalog) // 重复同步不会重复插入

        for name in LearnDatabase.configFileNames {
            let file = try #require(try db.configFile(named: name))
            #expect(!file.data.isEmpty)
        }
        #expect(try db.badges().map(\.id) == catalog.badges.map(\.id))
        for slot in CosmeticSlot.allCases {
            let stored = try db.cosmetics(slot: slot)
            #expect(stored.map(\.id) == catalog.cosmetics.filter { $0.slot == slot }.map(\.id))
            for row in stored {
                let decoded = try JSONDecoder().decode(CosmeticKind.self, from: row.itemData)
                #expect(decoded == catalog.cosmetic(id: row.id))
            }
        }
    }
}
