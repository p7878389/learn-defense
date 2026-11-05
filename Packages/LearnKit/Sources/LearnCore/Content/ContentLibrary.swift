import Foundation

/// 所有可用题库：内置题库 + 用户导入的题库（同 id 时导入的覆盖内置的）。
public final class ContentLibrary {
    public private(set) var packs: [ContentPack]
    /// 加载或校验时发现的问题，给家长看
    public private(set) var issues: [String]

    public init(packs: [ContentPack], issues: [String] = []) {
        self.packs = packs
        self.issues = issues
    }

    public static func load(userDirectory: URL?) -> ContentLibrary {
        var byID: [String: ContentPack] = [:]
        var order: [String] = []
        var issues: [String] = []

        func add(from directory: URL, source: String) {
            let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
            for file in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
            where file.pathExtension.lowercased() == "json" {
                do {
                    let pack = try decode(Data(contentsOf: file))
                    issues += validate(pack).map { "\(source)/\(file.lastPathComponent)：\($0)" }
                    if byID[pack.id] == nil { order.append(pack.id) }
                    byID[pack.id] = pack
                } catch {
                    issues.append("\(source)/\(file.lastPathComponent) 读取失败：\(describe(error))")
                }
            }
        }

        if let bundled = Bundle.module.url(forResource: "Packs", withExtension: nil) {
            add(from: bundled, source: "内置")
        }
        if let userDirectory {
            add(from: userDirectory, source: "导入")
        }
        return ContentLibrary(packs: order.compactMap { byID[$0] }, issues: issues)
    }

    public static func decode(_ data: Data) throws -> ContentPack {
        try JSONDecoder().decode(ContentPack.self, from: data)
    }

    public func packs(grade: Grade, subject: Subject) -> [ContentPack] {
        packs.filter { $0.grade == grade && $0.subject == subject }
    }

    public func pack(id: String) -> ContentPack? {
        packs.first { $0.id == id }
    }

    /// 只检查会导致出错题的问题，不追求完整
    public static func validate(_ pack: ContentPack) -> [String] {
        var problems: [String] = []
        if pack.schemaVersion > ContentPack.currentSchemaVersion {
            problems.append("schemaVersion \(pack.schemaVersion) 比 App 支持的更新，请升级 App")
        }
        for unit in pack.units {
            for lesson in unit.lessons {
                let at = "\(unit.title)/\(lesson.title)"
                for c in lesson.characters where c.char.count != 1 {
                    problems.append("\(at)：生字「\(c.char)」应该只有一个字")
                }
                for c in lesson.characters where c.pinyin.trimmingCharacters(in: .whitespaces).isEmpty {
                    problems.append("\(at)：生字「\(c.char)」缺少拼音")
                }
                for p in lesson.poems where p.lines.count < 2 {
                    problems.append("\(at)：古诗《\(p.title)》至少需要两句")
                }
                for q in lesson.questions where !q.options.contains(q.answer) {
                    problems.append("\(at)：选择题「\(q.prompt)」的答案不在选项里")
                }
            }
        }
        return problems
    }

    private static func describe(_ error: Error) -> String {
        switch error {
        case DecodingError.keyNotFound(let key, let ctx):
            return "缺少字段 \(key.stringValue)（位置 \(path(ctx))）"
        case DecodingError.typeMismatch(_, let ctx), DecodingError.valueNotFound(_, let ctx):
            return "字段类型不对（位置 \(path(ctx))）"
        case DecodingError.dataCorrupted(let ctx):
            return ctx.codingPath.isEmpty ? "不是合法的 JSON" : "取值不合法（位置 \(path(ctx))）"
        default:
            return error.localizedDescription
        }
    }

    private static func path(_ ctx: DecodingError.Context) -> String {
        ctx.codingPath.map { $0.intValue.map(String.init) ?? $0.stringValue }.joined(separator: ".")
    }
}
