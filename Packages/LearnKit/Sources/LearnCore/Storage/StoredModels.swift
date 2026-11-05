import Foundation
import SwiftData

// SwiftData 表结构。学科、年级等枚举存 rawValue 字符串，方便在 #Predicate 里比较。

/// 题库包（题库 JSON 仍是来源，这里是同步过来的索引，方便查询）
@Model
public final class StoredPack {
    @Attribute(.unique) public var id: String
    public var title: String
    /// Subject.rawValue
    public var subject: String
    /// Grade.rawValue
    public var grade: String
    /// Term.rawValue
    public var term: String?
    public var edition: String?
    /// 在题库列表里的顺序
    public var position: Int

    public init(pack: ContentPack, position: Int) {
        id = pack.id
        title = pack.title
        subject = pack.subject.rawValue
        grade = pack.grade.rawValue
        term = pack.term?.rawValue
        edition = pack.edition
        self.position = position
    }
}

/// 能出题的知识点，以及它在哪个题库、单元、课里出现
@Model
public final class StoredItem {
    /// "题库id/单元id/课id|知识点key"，同一个知识点出现在多课时各有一行
    @Attribute(.unique) public var uid: String
    /// LearningItem.key，和学习记录 StoredItemStats.key 对应
    public var key: String
    /// character / word / idiom / poem / choice / picture
    public var kind: String
    /// 生字、词语、成语、图片词本身；古诗为诗题；选择题为题干
    public var text: String
    public var pinyin: String?
    public var summary: String
    public var packID: String
    public var unitID: String
    public var unitTitle: String
    public var lessonID: String
    public var lessonTitle: String
    /// Subject.rawValue
    public var subject: String
    /// Grade.rawValue
    public var grade: String

    public init(item: LearningItem, pack: ContentPack, unit: ContentUnit, lesson: Lesson) {
        let scope = "\(pack.id)/\(unit.id)/\(lesson.id)"
        uid = "\(scope)|\(item.key)"
        key = item.key
        let described = Self.describe(item)
        kind = described.kind
        text = described.text
        pinyin = described.pinyin
        summary = item.summary
        packID = pack.id
        unitID = unit.id
        unitTitle = unit.title
        lessonID = lesson.id
        lessonTitle = lesson.title
        subject = pack.subject.rawValue
        grade = pack.grade.rawValue
    }

    private static func describe(_ item: LearningItem) -> (kind: String, text: String, pinyin: String?) {
        switch item {
        case .character(let c): ("character", c.char, c.pinyin)
        case .word(let w): ("word", w.text, w.pinyin)
        case .idiom(let i): ("idiom", i.text, i.pinyin)
        case .poemLine(let p, _): ("poem", p.title, nil)
        case .choice(let q, _): ("choice", q.prompt, nil)
        case .picture(let p): ("picture", p.text, p.pinyin)
        }
    }
}

/// 某个孩子在某个知识点上的答题统计（对应 ItemStats）
@Model
public final class StoredItemStats {
    /// "档案id|知识点key"
    @Attribute(.unique) public var uid: String
    /// Profile.id.uuidString
    public var profileID: String
    public var key: String
    public var seen: Int
    public var correct: Int
    public var wrong: Int
    public var streak: Int
    public var lastSeen: Date?
    public var lastWrong: Date?
    public var summary: String?

    public init(profileID: String, key: String, stats: ItemStats) {
        uid = Self.uid(profileID: profileID, key: key)
        self.profileID = profileID
        self.key = key
        seen = stats.seen
        correct = stats.correct
        wrong = stats.wrong
        streak = stats.streak
        lastSeen = stats.lastSeen
        lastWrong = stats.lastWrong
        summary = stats.summary
    }

    static func uid(profileID: String, key: String) -> String { "\(profileID)|\(key)" }

    func update(_ s: ItemStats) {
        seen = s.seen
        correct = s.correct
        wrong = s.wrong
        streak = s.streak
        lastSeen = s.lastSeen
        lastWrong = s.lastWrong
        summary = s.summary
    }

    public var stats: ItemStats {
        var s = ItemStats()
        s.seen = seen
        s.correct = correct
        s.wrong = wrong
        s.streak = streak
        s.lastSeen = lastSeen
        s.lastWrong = lastWrong
        s.summary = summary
        return s
    }
}
