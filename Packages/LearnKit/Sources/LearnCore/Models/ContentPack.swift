import Foundation

/// 题库包，对应一个 JSON 文件。格式说明见 docs/题库格式.md。
public struct ContentPack: Codable, Identifiable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var id: String
    public var title: String
    public var subject: Subject
    public var grade: Grade
    public var term: Term?
    public var edition: String?
    public var units: [ContentUnit]

    public init(
        schemaVersion: Int = ContentPack.currentSchemaVersion,
        id: String,
        title: String,
        subject: Subject,
        grade: Grade,
        term: Term? = nil,
        edition: String? = nil,
        units: [ContentUnit]
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.title = title
        self.subject = subject
        self.grade = grade
        self.term = term
        self.edition = edition
        self.units = units
    }
}

public struct ContentUnit: Codable, Identifiable, Sendable {
    public var id: String
    public var title: String
    /// 战场背景主题的 id（见 SceneTheme），可省略
    public var theme: String?
    public var lessons: [Lesson]

    public init(id: String, title: String, theme: String? = nil, lessons: [Lesson]) {
        self.id = id
        self.title = title
        self.theme = theme
        self.lessons = lessons
    }
}

public struct Lesson: Codable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var characters: [CharacterItem]
    public var words: [WordItem]
    public var idioms: [IdiomItem]
    public var poems: [PoemItem]
    public var pictures: [PictureItem]
    public var questions: [ChoiceItem]

    public init(
        id: String,
        title: String,
        characters: [CharacterItem] = [],
        words: [WordItem] = [],
        idioms: [IdiomItem] = [],
        poems: [PoemItem] = [],
        pictures: [PictureItem] = [],
        questions: [ChoiceItem] = []
    ) {
        self.id = id
        self.title = title
        self.characters = characters
        self.words = words
        self.idioms = idioms
        self.poems = poems
        self.pictures = pictures
        self.questions = questions
    }

    // 课里的各类素材都可以省略
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        characters = try c.decodeIfPresent([CharacterItem].self, forKey: .characters) ?? []
        words = try c.decodeIfPresent([WordItem].self, forKey: .words) ?? []
        idioms = try c.decodeIfPresent([IdiomItem].self, forKey: .idioms) ?? []
        poems = try c.decodeIfPresent([PoemItem].self, forKey: .poems) ?? []
        pictures = try c.decodeIfPresent([PictureItem].self, forKey: .pictures) ?? []
        questions = try c.decodeIfPresent([ChoiceItem].self, forKey: .questions) ?? []
    }
}

/// 生字
public struct CharacterItem: Codable, Hashable, Sendable {
    public var char: String
    public var pinyin: String
    public var words: [String]?

    public init(char: String, pinyin: String, words: [String]? = nil) {
        self.char = char
        self.pinyin = pinyin
        self.words = words
    }
}

/// 词语
public struct WordItem: Codable, Hashable, Sendable {
    public var text: String
    public var pinyin: String?

    public init(text: String, pinyin: String? = nil) {
        self.text = text
        self.pinyin = pinyin
    }
}

/// 成语
public struct IdiomItem: Codable, Hashable, Sendable {
    public var text: String
    public var pinyin: String?
    public var meaning: String?

    public init(text: String, pinyin: String? = nil, meaning: String? = nil) {
        self.text = text
        self.pinyin = pinyin
        self.meaning = meaning
    }
}

/// 古诗，lines 按句拆分、不带标点
public struct PoemItem: Codable, Hashable, Sendable {
    public var title: String
    public var author: String?
    public var dynasty: String?
    public var lines: [String]

    public init(title: String, author: String? = nil, dynasty: String? = nil, lines: [String]) {
        self.title = title
        self.author = author
        self.dynasty = dynasty
        self.lines = lines
    }

    /// 《山行》唐·杜牧
    public var byline: String {
        var s = "《\(title)》"
        if let author {
            s += dynasty.map { "\($0)·" } ?? ""
            s += author
        }
        return s
    }
}

/// 图片词（幼儿园），emoji 暂代图片
public struct PictureItem: Codable, Hashable, Sendable {
    public var text: String
    public var pinyin: String?
    public var emoji: String
    public var en: String?

    public init(text: String, pinyin: String? = nil, emoji: String, en: String? = nil) {
        self.text = text
        self.pinyin = pinyin
        self.emoji = emoji
        self.en = en
    }
}

/// 手写选择题
public struct ChoiceItem: Codable, Hashable, Sendable {
    public var id: String?
    public var prompt: String
    public var options: [String]
    public var answer: String
    public var explain: String?

    public init(id: String? = nil, prompt: String, options: [String], answer: String, explain: String? = nil) {
        self.id = id
        self.prompt = prompt
        self.options = options
        self.answer = answer
        self.explain = explain
    }
}
