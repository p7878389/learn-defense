import Foundation
import SwiftData

/// 本地数据库（SwiftData，底层是 SQLite）。
/// - 题库：从数据库加载（StoredPackFile），第一次或 JSON 文件有变化时才读文件导入，见 loadContent
/// - 系统配置：JSON 仍是来源，每次加载后整份同步过来，用来查询
/// - 孩子档案、成长档案、学习记录：数据库是唯一存储，旧版 JSON 第一次读取时迁移进来
/// - 对局记录、答题明细：整局结束结算时写入，未结算退出不写对局历史
/// - 语音缓存：运行时用火山引擎生成的音频索引（音频文件在 AppPaths.speechCacheDirectory）
public final class LearnDatabase {
    public static let schema = Schema([
        StoredPackFile.self, StoredPack.self, StoredItem.self, StoredItemStats.self,
        StoredProfile.self, StoredGrowth.self,
        StoredGame.self, StoredAnswer.self,
        StoredConfigFile.self, StoredBadge.self, StoredCosmetic.self,
        StoredSpeechClip.self,
    ])

    public let container: ModelContainer
    /// 自己管理保存时机（ProgressStore.save、syncContent），不自动保存
    public let context: ModelContext
    private var transactionDepth = 0

    /// url 为 nil 时只在内存里（测试用）
    public convenience init(url: URL?) throws {
        let config: ModelConfiguration
        if let url {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            config = ModelConfiguration(schema: Self.schema, url: url)
        } else {
            config = ModelConfiguration(schema: Self.schema, isStoredInMemoryOnly: true)
        }
        try self.init(configuration: config)
    }

    init(configuration: ModelConfiguration) throws {
        container = try ModelContainer(for: Self.schema, configurations: [configuration])
        context = ModelContext(container)
        context.autosaveEnabled = false
    }

    /// 参与操作只暂存变更，由最外层事务一次提交；任何失败都回滚。
    func transaction<T>(_ operation: () throws -> T) throws -> T {
        transactionDepth += 1
        defer { transactionDepth -= 1 }
        do {
            let value = try operation()
            if transactionDepth == 1, context.hasChanges { try context.save() }
            return value
        } catch {
            context.rollback()
            throw error
        }
    }

    func saveChanges() throws {
        if transactionDepth == 0, context.hasChanges { try context.save() }
    }

    // MARK: - 题库

    /// 用当前题库整份替换数据库里的题库查询索引（StoredPack / StoredItem）
    public func syncContent(_ packs: [ContentPack]) throws {
        try transaction { try replaceContent(packs) }
    }

    private func replaceContent(_ packs: [ContentPack]) throws {
        for old in try context.fetch(FetchDescriptor<StoredItem>()) { context.delete(old) }
        for old in try context.fetch(FetchDescriptor<StoredPack>()) { context.delete(old) }

        for (position, pack) in packs.enumerated() {
            context.insert(StoredPack(pack: pack, position: position))
            for unit in pack.units {
                for lesson in unit.lessons {
                    let scope = "\(pack.id)/\(unit.id)/\(lesson.id)"
                    var seen: Set<String> = []
                    for item in ItemPool.lessonItems(lesson, scope: scope) where seen.insert(item.key).inserted {
                        context.insert(StoredItem(item: item, pack: pack, unit: unit, lesson: lesson))
                    }
                }
            }
        }
    }

    public func packs(grade: Grade, subject: Subject) throws -> [StoredPack] {
        let g = grade.rawValue
        let s = subject.rawValue
        let descriptor = FetchDescriptor<StoredPack>(
            predicate: #Predicate { $0.grade == g && $0.subject == s },
            sortBy: [SortDescriptor(\.position)]
        )
        return try context.fetch(descriptor)
    }

    /// 文字里含有 text 的知识点及所在课，例如查「晨」出现在哪几课
    public func items(containing text: String) throws -> [StoredItem] {
        let descriptor = FetchDescriptor<StoredItem>(
            predicate: #Predicate { $0.text.contains(text) },
            sortBy: [SortDescriptor(\.packID), SortDescriptor(\.unitID), SortDescriptor(\.lessonID)]
        )
        return try context.fetch(descriptor)
    }

    /// 某个知识点（LearningItem.key）出现在哪些课
    public func items(key: String) throws -> [StoredItem] {
        try context.fetch(FetchDescriptor<StoredItem>(predicate: #Predicate { $0.key == key }))
    }

    // MARK: - 学习记录

    public func stats(profileID: UUID) throws -> [String: ItemStats] {
        let pid = profileID.uuidString
        let rows = try context.fetch(FetchDescriptor<StoredItemStats>(predicate: #Predicate { $0.profileID == pid }))
        return Dictionary(rows.map { ($0.key, $0.stats) }, uniquingKeysWith: { a, _ in a })
    }

    /// 写入（新增或覆盖）这些知识点的统计
    public func saveStats(_ changes: [String: ItemStats], profileID: UUID) throws {
        guard !changes.isEmpty else { return }
        let pid = profileID.uuidString
        let keys = Array(changes.keys)
        let existing = try context.fetch(FetchDescriptor<StoredItemStats>(
            predicate: #Predicate { $0.profileID == pid && keys.contains($0.key) }
        ))
        var byKey = Dictionary(existing.map { ($0.key, $0) }, uniquingKeysWith: { a, _ in a })
        for (key, stats) in changes {
            if let row = byKey[key] {
                row.update(stats)
            } else {
                let row = StoredItemStats(profileID: pid, key: key, stats: stats)
                context.insert(row)
                byKey[key] = row
            }
        }
        try saveChanges()
    }

    public func deleteStats(profileID: UUID) throws {
        let pid = profileID.uuidString
        for row in try context.fetch(FetchDescriptor<StoredItemStats>(predicate: #Predicate { $0.profileID == pid })) {
            context.delete(row)
        }
        try context.save()
    }

    /// 错得最多的知识点（错误次数从多到少）
    public func mistakes(profileID: UUID, limit: Int = 20) throws -> [StoredItemStats] {
        let pid = profileID.uuidString
        var descriptor = FetchDescriptor<StoredItemStats>(
            predicate: #Predicate { $0.profileID == pid && $0.wrong > 0 },
            sortBy: [SortDescriptor(\.wrong, order: .reverse), SortDescriptor(\.key)]
        )
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }
}
