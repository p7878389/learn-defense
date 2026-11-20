import Foundation

/// 一句要朗读的文本，以及它的音频按业务分类存放的相对路径
public struct SpeechClip: Equatable, Sendable {
    public var text: String
    /// 相对语音根目录的路径，如 `packs/<题库>/<单元>/<课>/震.mp3`
    public var path: String

    public init(text: String, path: String) {
        self.text = text
        self.path = path
    }
}

/// 语音目录清单（manifest.json），放在语音根目录下：记录「文本 → 音频相对路径」。
/// 预先生成的语音（OSS、App 内置、题库自带）都按这份清单查找，文件名就能直接看出读的是哪句话。
public struct SpeechManifest: Codable, Equatable, Sendable {
    public static let fileName = "manifest.json"
    public static let currentVersion = 1

    public var version: Int
    /// 生成这批语音用的音色（TTSSettings.voiceTag）
    public var voice: String
    /// 规范化文本 → 相对路径
    public var clips: [String: String]

    public init(version: Int = SpeechManifest.currentVersion, voice: String, clips: [String: String] = [:]) {
        self.version = version
        self.voice = voice
        self.clips = clips
    }

    public func path(for text: String) -> String? {
        SpeechText.normalize(text).flatMap { clips[$0] }
    }

    /// 读不到或不是这个格式（例如旧版「文件名 → 文本」清单）时返回 nil
    public static func decode(_ data: Data) -> SpeechManifest? {
        try? JSONDecoder().decode(SpeechManifest.self, from: data)
    }

    public static func load(from url: URL) -> SpeechManifest? {
        (try? Data(contentsOf: url)).flatMap(decode)
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }
}

/// 预先生成语音的目录规划：游戏提示语放 `game/<分类>/`，题库文本放 `packs/<题库>/<单元>/<课>/`，
/// 文件名就是朗读的文本。同一句话只存一份，放在第一次出现的位置。
///
/// 目录名用「id_标题」：id 保证稳定，标题方便人看。
public enum SpeechCatalog {
    /// 文件名里文本最多保留的字数，超出时截断并加上文本 key 的前 8 位，避免重名
    static let maxNameLength = 40

    public static func clips(packs: [ContentPack], includeGameLines: Bool) -> [SpeechClip] {
        var groups: [(folder: String, texts: [String])] = []
        if includeGameLines {
            groups += SpeechText.gameLineGroups.map { ("game/\(segment($0.folder))", $0.texts) }
        }
        for pack in packs {
            let packFolder = "packs/\(folder(id: pack.id, title: pack.title))"
            for unit in pack.units {
                let unitFolder = "\(packFolder)/\(folder(id: unit.id, title: unit.title))"
                for lesson in unit.lessons {
                    let scope = "\(pack.id)/\(unit.id)/\(lesson.id)"
                    let texts = ItemPool.lessonItems(lesson, scope: scope).flatMap(QuestionGenerator.speechTexts)
                    // 英语题库不分课时合成的那一课和单元同名，直接放在单元目录下
                    let lessonFolder = lesson.title == unit.title
                        ? unitFolder : "\(unitFolder)/\(folder(id: lesson.id, title: lesson.title))"
                    groups.append((lessonFolder, texts))
                }
            }
        }
        return layout(groups)
    }

    /// 按顺序分配路径：重复的文本跳过；同一目录下文件名相同（不区分大小写）时加 key 后缀
    static func layout(_ groups: [(folder: String, texts: [String])]) -> [SpeechClip] {
        var seen: Set<String> = []
        var taken: Set<String> = []
        var result: [SpeechClip] = []
        for group in groups {
            for text in group.texts.compactMap(SpeechText.normalize) where seen.insert(text).inserted {
                var name = fileStem(for: text)
                if taken.contains("\(group.folder)/\(name)".lowercased()) {
                    name += "~\(SpeechText.key(for: text).prefix(8))"
                }
                let path = "\(group.folder)/\(name).\(SpeechText.audioExtension)"
                taken.insert("\(group.folder)/\(name)".lowercased())
                result.append(SpeechClip(text: text, path: path))
            }
        }
        return result
    }

    static func folder(id: String, title: String) -> String {
        let title = segment(title)
        return title.isEmpty || title == "_" ? segment(id) : "\(segment(id))_\(title)"
    }

    /// 文本做文件名：过长时截断，并加上 key 后缀区分
    static func fileStem(for text: String) -> String {
        let name = segment(text)
        guard name.count > maxNameLength else { return name }
        let head = String(name.prefix(maxNameLength)).trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        return "\(head)~\(SpeechText.key(for: text).prefix(8))"
    }

    /// 一段路径：去掉文件系统和 URL 里有特殊含义的字符，合并空白，去掉首尾的点和空格
    static func segment(_ text: String) -> String {
        let reserved: Set<Character> = ["/", "\\", ":", "*", "?", "\"", "<", ">", "|", "#", "%"]
        var result = ""
        var lastWasSpace = false
        for ch in text {
            if ch.isWhitespace || ch.isNewline {
                if !lastWasSpace, !result.isEmpty { result.append(" ") }
                lastWasSpace = true
                continue
            }
            lastWasSpace = false
            let isControl = ch.unicodeScalars.contains { $0.properties.generalCategory == .control }
            result.append(reserved.contains(ch) || isControl ? "_" : ch)
        }
        let trimmed = result.trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        return trimmed.isEmpty ? "_" : trimmed
    }
}
