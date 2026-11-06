import Foundation

public struct ImportedPack: Identifiable {
    public let pack: ContentPack
    public let files: [URL]
    public var id: String { pack.id }
}

public struct PackImport: Identifiable {
    public let id = UUID()
    public let pack: ContentPack
    public let data: Data
    public var itemCount: Int { ItemPool(packs: [pack], selection: .all).items.count }
}

public enum SettingsError: LocalizedError {
    case invalid(String)
    public var errorDescription: String? {
        switch self { case .invalid(let message): message }
    }
}

public struct PackManager {
    public let directory: URL
    public init(directory: URL) { self.directory = directory }

    public func preview(_ data: Data) throws -> PackImport {
        guard data.count <= 20_000_000 else { throw SettingsError.invalid("课本文件超过 20 MB") }
        let pack = try ContentLibrary.decode(data)
        var issues = ContentLibrary.validate(pack)
        if pack.schemaVersion < 1 { issues.append("schemaVersion 必须为 1") }
        if Set(pack.units.map(\.id)).count != pack.units.count { issues.append("单元 id 不能重复") }
        for unit in pack.units {
            if Set(unit.lessons.map(\.id)).count != unit.lessons.count { issues.append("\(unit.title)：课文 id 不能重复") }
            for lesson in unit.lessons {
                let pinyin = lesson.characters.map(\.pinyin)
                    + lesson.words.compactMap(\.pinyin)
                    + lesson.idioms.compactMap(\.pinyin)
                if pinyin.contains(where: { $0.contains(where: \.isNumber) }) {
                    issues.append("\(unit.title)/\(lesson.title)：拼音请使用声调符号（如 chén），不能使用数字声调（chen2）")
                }
            }
        }
        guard !pack.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !pack.title.isEmpty, !ItemPool(packs: [pack], selection: .all).isEmpty else {
            throw SettingsError.invalid("课本需要有效的 id、书名和可出题的内容")
        }
        guard issues.isEmpty else { throw SettingsError.invalid(issues.joined(separator: "\n")) }
        return PackImport(pack: pack, data: data)
    }

    public func imported() -> [ImportedPack] {
        let files = ((try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension.lowercased() == "json" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        var entries: [String: (ContentPack, [URL])] = [:]
        for file in files {
            guard let data = try? Data(contentsOf: file), let pack = try? ContentLibrary.decode(data) else { continue }
            let old = entries[pack.id]?.1 ?? []
            entries[pack.id] = (pack, old + [file])
        }
        return entries.values.map { ImportedPack(pack: $0.0, files: $0.1) }.sorted { $0.pack.title < $1.pack.title }
    }

    public func install(_ draft: PackImport) throws {
        // 在原文件上原子写入，覆盖同 id 的导入文件；文件名不使用不可信的课本 id。
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let existing = imported().first { $0.id == draft.pack.id }?.files ?? []
        let destination = existing.last ?? directory.appendingPathComponent(UUID().uuidString + ".json")
        try draft.data.write(to: destination, options: .atomic)
        for duplicate in existing where duplicate != destination { try fm.removeItem(at: duplicate) }
    }

    public func remove(id: String) throws {
        for file in imported().first(where: { $0.id == id })?.files ?? [] {
            try FileManager.default.removeItem(at: file)
        }
    }
}
