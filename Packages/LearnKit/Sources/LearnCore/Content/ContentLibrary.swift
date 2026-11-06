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

    /// App 内置题库目录（Resources/Packs）
    public static var bundledDirectory: URL? {
        Bundle.module.url(forResource: "Packs", withExtension: nil)
    }

    /// 直接读 JSON 文件加载。App 平时用 LearnDatabase.loadContent（只在文件有变化时读 JSON）；
    /// 数据库不可用时、命令行工具和测试用这里
    public static func load(userDirectory: URL?) -> ContentLibrary {
        var entries: [(pack: ContentPack?, issues: [String])] = []
        for (source, directory) in sources(userDirectory: userDirectory) {
            for file in jsonFiles(in: directory) {
                let label = "\(source)/\(file.lastPathComponent)"
                do {
                    entries.append(read(try Data(contentsOf: file), label: label))
                } catch {
                    entries.append((nil, ["\(label) 读取失败：\(describe(error))"]))
                }
            }
        }
        return assemble(entries)
    }

    /// 题库来源，按加载顺序：内置在前，导入在后（同 id 时导入的覆盖内置的）
    static func sources(userDirectory: URL?) -> [(source: String, directory: URL)] {
        [bundledDirectory.map { ("内置", $0) }, userDirectory.map { ("导入", $0) }].compactMap { $0 }
    }

    /// 目录下的题库 JSON 文件，按文件名排序
    static func jsonFiles(in directory: URL, keys: [URLResourceKey] = []) -> [URL] {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: keys)) ?? []
        return files
            .filter { $0.pathExtension.lowercased() == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// 解析并校验一个题库文件的内容。label 形如「内置/xxx.json」，用在问题说明里
    static func read(_ data: Data, label: String) -> (pack: ContentPack?, issues: [String]) {
        do {
            let pack = try decode(data)
            return (pack, validate(pack).map { "\(label)：\($0)" })
        } catch {
            return (nil, ["\(label) 读取失败：\(describe(error))"])
        }
    }

    /// 按加载顺序合成题库列表：同 id 的后来者覆盖先来的，位置保持第一次出现的地方
    static func assemble(_ entries: [(pack: ContentPack?, issues: [String])]) -> ContentLibrary {
        var byID: [String: ContentPack] = [:]
        var order: [String] = []
        var issues: [String] = []
        for entry in entries {
            issues += entry.issues
            guard let pack = entry.pack else { continue }
            if byID[pack.id] == nil { order.append(pack.id) }
            byID[pack.id] = pack
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
                for w in lesson.englishWords where w.word.isEmpty || w.meaning.isEmpty {
                    problems.append("\(at)：英语单词「\(w.word)」缺少单词或中文意思")
                }
                for s in lesson.sentences where s.sentence.isEmpty || s.meaning.isEmpty {
                    problems.append("\(at)：英语句子「\(s.sentence)」缺少句子或中文意思")
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
