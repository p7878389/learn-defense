import Foundation
import SwiftData
import Testing
@testable import LearnCore

@Suite("题库从数据库加载")
struct ContentLoadTests {
    /// 临时的「内置」「导入」两个目录
    final class Folders {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ContentLoadTests-\(UUID().uuidString)", isDirectory: true)
        var bundled: URL { root.appendingPathComponent("bundled", isDirectory: true) }
        var user: URL { root.appendingPathComponent("user", isDirectory: true) }
        var sources: [(source: String, directory: URL)] { [("内置", bundled), ("导入", user)] }

        init() throws {
            try FileManager.default.createDirectory(at: bundled, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: user, withIntermediateDirectories: true)
        }

        deinit { try? FileManager.default.removeItem(at: root) }

        /// 写一个题库文件；modified 不为 nil 时把修改时间改成它
        @discardableResult
        func write(_ name: String, in directory: URL, id: String, title: String, modified: Date? = nil) throws -> URL {
            let json = """
            {"schemaVersion":1,"id":"\(id)","title":"\(title)","subject":"chinese","grade":"g3",
             "units":[{"id":"u1","title":"单元","lessons":[{"id":"l1","title":"课","characters":[{"char":"山","pinyin":"shān"}]}]}]}
            """
            let url = directory.appendingPathComponent(name)
            try Data(json.utf8).write(to: url)
            if let modified {
                try FileManager.default.setAttributes([.modificationDate: modified], ofItemAtPath: url.path)
            }
            return url
        }
    }

    @Test func firstLoadImportsJSONThenReadsFromDatabase() throws {
        let folders = try Folders()
        let db = try LearnDatabase(url: nil)
        // 整秒的修改时间：写回修改时间会丢掉秒以下的精度
        let modified = Date(timeIntervalSinceReferenceDate: 800_000_000)
        try folders.write("a.json", in: folders.user, id: "p1", title: "AAAA", modified: modified)

        let first = try db.loadContent(sources: folders.sources)
        #expect(first.packs.map(\.title) == ["AAAA"])
        #expect(try db.context.fetch(FetchDescriptor<StoredPackFile>()).map(\.path) == ["导入/a.json"])

        // 文件内容换掉，但大小和修改时间不变：不重新读文件，仍是数据库里的内容
        try folders.write("a.json", in: folders.user, id: "p1", title: "BBBB", modified: modified)
        let second = try db.loadContent(sources: folders.sources)
        #expect(second.packs.map(\.title) == ["AAAA"])
    }

    @Test func changedFileIsImportedAgain() throws {
        let folders = try Folders()
        let db = try LearnDatabase(url: nil)
        try folders.write("a.json", in: folders.user, id: "p1", title: "AAAA")
        _ = try db.loadContent(sources: folders.sources)

        try folders.write("a.json", in: folders.user, id: "p1", title: "新标题", modified: .now.addingTimeInterval(60))
        let library = try db.loadContent(sources: folders.sources)
        #expect(library.packs.map(\.title) == ["新标题"])
        #expect(try db.packs(grade: .g3, subject: .chinese).map(\.title) == ["新标题"])
    }

    @Test func newAndDeletedFilesFollowTheFolder() throws {
        let folders = try Folders()
        let db = try LearnDatabase(url: nil)
        let a = try folders.write("a.json", in: folders.user, id: "p1", title: "A")
        _ = try db.loadContent(sources: folders.sources)

        try folders.write("b.json", in: folders.user, id: "p2", title: "B")
        #expect(try db.loadContent(sources: folders.sources).packs.map(\.id) == ["p1", "p2"])

        try FileManager.default.removeItem(at: a)
        let library = try db.loadContent(sources: folders.sources)
        #expect(library.packs.map(\.id) == ["p2"])
        #expect(try db.context.fetch(FetchDescriptor<StoredPackFile>()).map(\.path) == ["导入/b.json"])
        #expect(try db.packs(grade: .g3, subject: .chinese).map(\.id) == ["p2"])
    }

    @Test func importedPackOverridesBundledWithSameID() throws {
        let folders = try Folders()
        let db = try LearnDatabase(url: nil)
        try folders.write("a.json", in: folders.bundled, id: "p1", title: "内置版")
        try folders.write("b.json", in: folders.bundled, id: "p2", title: "其他")
        try folders.write("a.json", in: folders.user, id: "p1", title: "导入版")

        for _ in 0..<2 {  // 第一次读文件，第二次读数据库，结果一样
            let library = try db.loadContent(sources: folders.sources)
            #expect(library.packs.map(\.title) == ["导入版", "其他"])
        }
    }

    @Test func brokenFileKeepsItsIssueWithoutRereading() throws {
        let folders = try Folders()
        let db = try LearnDatabase(url: nil)
        try Data("不是 JSON".utf8).write(to: folders.user.appendingPathComponent("bad.json"))

        let first = try db.loadContent(sources: folders.sources)
        #expect(first.packs.isEmpty)
        #expect(first.issues.count == 1 && first.issues[0].hasPrefix("导入/bad.json 读取失败"))
        #expect(try db.loadContent(sources: folders.sources).issues == first.issues)
    }

    @Test func unreadableStoredDataFallsBackToFile() throws {
        let folders = try Folders()
        let db = try LearnDatabase(url: nil)
        try folders.write("a.json", in: folders.user, id: "p1", title: "AAAA")
        _ = try db.loadContent(sources: folders.sources)

        // 比如 App 升级后旧格式解析不了：改读文件，并把数据库里的内容更新
        let row = try #require(try db.context.fetch(FetchDescriptor<StoredPackFile>()).first)
        row.data = Data("{}".utf8)
        try db.context.save()
        #expect(try db.loadContent(sources: folders.sources).packs.map(\.title) == ["AAAA"])
        #expect(try ContentLibrary.decode(#require(row.data)).title == "AAAA")
    }

    @Test func bundledPacksMatchDirectJSONLoad() throws {
        let db = try LearnDatabase(url: nil)
        let direct = ContentLibrary.load(userDirectory: nil)
        for _ in 0..<2 {
            let library = try db.loadContent(userDirectory: nil)
            #expect(library.packs.map(\.id) == direct.packs.map(\.id))
            #expect(library.packs.map { $0.units.count } == direct.packs.map { $0.units.count })
            #expect(library.issues == direct.issues)
        }
        let indexed = Set(try db.context.fetch(FetchDescriptor<StoredPack>()).map(\.id))
        #expect(indexed == Set(direct.packs.map(\.id)))
    }
}
