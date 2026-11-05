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
}
