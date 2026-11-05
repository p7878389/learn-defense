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

/// 孩子档案（对应 Profile）
@Model
public final class StoredProfile {
    /// Profile.id.uuidString
    @Attribute(.unique) public var id: String
    public var name: String
    /// Grade.rawValue
    public var grade: String
    public var avatar: String
    /// Difficulty.rawValue
    public var difficulty: String
    /// 在档案列表里的顺序
    public var position: Int

    public init(profile: Profile, position: Int) {
        id = profile.id.uuidString
        name = profile.name
        grade = profile.grade.rawValue
        avatar = profile.avatar
        difficulty = profile.difficulty.rawValue
        self.position = position
    }

    func update(_ profile: Profile, position: Int) {
        name = profile.name
        grade = profile.grade.rawValue
        avatar = profile.avatar
        difficulty = profile.difficulty.rawValue
        self.position = position
    }

    /// 年级、难度取值不认识时返回 nil（比如被旧版 App 读到新版写的数据）
    public var profile: Profile? {
        guard let uuid = UUID(uuidString: id), let g = Grade(rawValue: grade) else { return nil }
        return Profile(id: uuid, name: name, grade: g, avatar: avatar, difficulty: Difficulty(rawValue: difficulty) ?? .easy)
    }
}

/// 一个孩子的成长档案。完整状态存在 stateData（GrowthState 的 JSON），
/// 常用数值另存成列，方便直接查询排序
@Model
public final class StoredGrowth {
    /// Profile.id.uuidString
    @Attribute(.unique) public var profileID: String
    public var stateData: Data
    public var xp: Int
    public var coins: Int
    public var badgeCount: Int
    public var gamesPlayed: Int
    public var gamesWon: Int
    public var questionsAnswered: Int
    public var firstTryCorrect: Int
    public var playSeconds: Int
    public var updatedAt: Date

    init(profileID: String, state: GrowthState, data: Data) {
        self.profileID = profileID
        stateData = data
        xp = state.xp
        coins = state.coins
        badgeCount = state.badges.count
        gamesPlayed = state.stats.gamesPlayed
        gamesWon = state.stats.gamesWon
        questionsAnswered = state.stats.questionsAnswered
        firstTryCorrect = state.stats.firstTryCorrect
        playSeconds = state.stats.playSeconds
        updatedAt = Date()
    }

    func update(_ state: GrowthState, data: Data) {
        stateData = data
        xp = state.xp
        coins = state.coins
        badgeCount = state.badges.count
        gamesPlayed = state.stats.gamesPlayed
        gamesWon = state.stats.gamesWon
        questionsAnswered = state.stats.questionsAnswered
        firstTryCorrect = state.stats.firstTryCorrect
        playSeconds = state.stats.playSeconds
        updatedAt = Date()
    }
}

/// 系统配置原文件（Resources/Config 下的 JSON），启动时整份同步
@Model
public final class StoredConfigFile {
    /// 文件名，如 pacing.json
    @Attribute(.unique) public var name: String
    public var data: Data
    public var syncedAt: Date

    public init(name: String, data: Data) {
        self.name = name
        self.data = data
        syncedAt = Date()
    }

    /// 文件内容（UTF-8 文本）
    public var text: String { String(decoding: data, as: UTF8.self) }
}

/// 徽章配置（来自 badges.json，已校验，写错的不会进来）
@Model
public final class StoredBadge {
    @Attribute(.unique) public var id: String
    public var name: String
    public var icon: String
    public var summary: String
    public var coins: Int
    public var stat: String?
    public var atLeast: Int?
    public var level: Int?
    public var position: Int

    public init(badge: BadgeKind, position: Int) {
        id = badge.id
        name = badge.name
        icon = badge.icon
        summary = badge.summary
        coins = badge.coins
        stat = badge.stat
        atLeast = badge.atLeast
        level = badge.level
        self.position = position
    }
}

/// 外观配置（来自 cosmetics.json，已校验）。特效参数在 itemData（CosmeticKind 的 JSON）里
@Model
public final class StoredCosmetic {
    @Attribute(.unique) public var id: String
    /// CosmeticSlot.rawValue
    public var slot: String
    public var name: String
    public var icon: String
    public var summary: String
    /// CosmeticRarity.rawValue
    public var rarity: String
    public var unlockLevel: Int
    public var price: Int
    public var itemData: Data
    public var position: Int

    public init(item: CosmeticKind, data: Data, position: Int) {
        id = item.id
        slot = item.slot.rawValue
        name = item.name
        icon = item.icon
        summary = item.summary
        rarity = item.rarity.rawValue
        unlockLevel = item.unlockLevel
        price = item.price
        itemData = data
        self.position = position
    }
}
