import Foundation
import SwiftData

/// 一个题库 JSON 文件的内容。题库从这里加载：只有第一次、或文件新增、改动时才读 JSON 文件写进来，
/// 文件删掉后这里也删掉。完整内容存 JSON 原文（data），读的时候再解析成 ContentPack
@Model
public final class StoredPackFile {
    /// "来源/文件名"，如「内置/chinese-g3-up-pep.json」
    @Attribute(.unique) public var path: String
    /// 文件大小和修改时间，变了就重新读文件
    public var fingerprint: String
    /// 解析出的题库 id；文件读不出来时为 nil
    public var packID: String?
    /// 文件原文；读不出来时为 nil
    public var data: Data?
    /// 读取、校验时发现的问题，给家长看
    public var issues: [String]
    public var importedAt: Date

    public init(path: String, fingerprint: String, packID: String?, data: Data?, issues: [String]) {
        self.path = path
        self.fingerprint = fingerprint
        self.packID = packID
        self.data = data
        self.issues = issues
        importedAt = .now
    }
}

extension LearnDatabase {
    /// 加载题库。
    ///
    /// 题库内容从数据库读；只有第一次（数据库里还没有）、或 JSON 文件新增、改动时才读文件并写进数据库，
    /// 文件删掉了就从数据库删掉。有变化时顺带重建 StoredPack / StoredItem 查询索引。
    /// 加载顺序和覆盖规则同 ContentLibrary.load：内置在前、导入在后，同 id 时导入的覆盖内置的。
    public func loadContent(userDirectory: URL?) throws -> ContentLibrary {
        try loadContent(sources: ContentLibrary.sources(userDirectory: userDirectory))
    }

    func loadContent(sources: [(source: String, directory: URL)]) throws -> ContentLibrary {
        let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey]
        var rows = Dictionary(
            try context.fetch(FetchDescriptor<StoredPackFile>()).map { ($0.path, $0) },
            uniquingKeysWith: { a, _ in a })
        var entries: [(pack: ContentPack?, issues: [String])] = []
        var changed = false

        for (source, directory) in sources {
            for file in ContentLibrary.jsonFiles(in: directory, keys: keys) {
                let path = "\(source)/\(file.lastPathComponent)"
                let fingerprint = Self.fingerprint(of: file, keys: keys)
                let row = rows.removeValue(forKey: path)
                if let row, row.fingerprint == fingerprint, let entry = Self.entry(from: row) {
                    entries.append(entry)
                    continue
                }
                // 第一次、文件有变化，或数据库里的内容解析不了（比如 App 升级后格式变了）：读文件
                let entry: (pack: ContentPack?, issues: [String])
                var stored: Data?
                do {
                    let data = try Data(contentsOf: file)
                    entry = ContentLibrary.read(data, label: path)
                    if entry.pack != nil { stored = data }
                } catch {
                    entry = (nil, ["\(path) 读取失败：\(error.localizedDescription)"])
                }
                if let row {
                    row.fingerprint = fingerprint
                    row.packID = entry.pack?.id
                    row.data = stored
                    row.issues = entry.issues
                    row.importedAt = .now
                } else {
                    context.insert(StoredPackFile(
                        path: path, fingerprint: fingerprint, packID: entry.pack?.id, data: stored, issues: entry.issues))
                }
                entries.append(entry)
                changed = true
            }
        }
        // 文件已经删掉的
        for row in rows.values {
            context.delete(row)
            changed = true
        }

        let library = ContentLibrary.assemble(entries)
        if changed {
            do {
                try context.save()
                try syncContent(library.packs)
            } catch {
                // 没写成的改动不要留在 context 里，免得被别处的 save 带进去
                context.rollback()
                throw error
            }
        }
        return library
    }

    /// 数据库里的一条题库文件记录。文件读不出来的直接给出当时的问题；原文解析不了返回 nil，改读文件
    private static func entry(from row: StoredPackFile) -> (pack: ContentPack?, issues: [String])? {
        guard let data = row.data else { return (nil, row.issues) }
        guard let pack = try? ContentLibrary.decode(data) else { return nil }
        return (pack, row.issues)
    }

    private static func fingerprint(of file: URL, keys: [URLResourceKey]) -> String {
        let values = try? file.resourceValues(forKeys: Set(keys))
        let size = values?.fileSize ?? -1
        let modified = values?.contentModificationDate?.timeIntervalSinceReferenceDate ?? 0
        return "\(size)@\(modified)"
    }
}
