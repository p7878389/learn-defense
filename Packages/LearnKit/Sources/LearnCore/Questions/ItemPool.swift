import Foundation

/// 一个可以出题的知识点。学习记录按知识点（而不是题型）统计。
public enum LearningItem: Sendable {
    case character(CharacterItem)
    case word(WordItem)
    case idiom(IdiomItem)
    /// 给出第 index 句，接第 index + 1 句
    case poemLine(PoemItem, index: Int)
    case choice(ChoiceItem, scope: String)
    case picture(PictureItem)
    case englishWord(EnglishWordItem)
    case sentence(SentenceItem)

    public var key: String {
        switch self {
        case .character(let c): "char:\(c.char)"
        case .word(let w): "word:\(w.text)"
        case .idiom(let i): "idiom:\(i.text)"
        case .poemLine(let p, let index): "poem:\(p.title)#\(index)"
        case .choice(let q, let scope): "choice:\(scope):\(q.id ?? q.prompt)"
        case .picture(let p): "pic:\(p.text)"
        case .englishWord(let w): "en:\(w.word)"
        case .sentence(let s): "sentence:\(s.sentence)"
        }
    }

    /// 错题本里显示的一行
    public var summary: String {
        switch self {
        case .character(let c):
            let words = (c.words ?? []).joined(separator: " ")
            return words.isEmpty ? "\(c.char)（\(c.pinyin)）" : "\(c.char)（\(c.pinyin)）\(words)"
        case .word(let w):
            return w.pinyin.map { "\(w.text)（\($0)）" } ?? w.text
        case .idiom(let i):
            return i.meaning.map { "\(i.text)：\($0)" } ?? i.text
        case .poemLine(let p, let index):
            return "\(p.lines[index])，\(p.lines[index + 1]) —— \(p.byline)"
        case .choice(let q, _):
            return "\(q.prompt) 答案：\(q.answer)"
        case .picture(let p):
            return "\(p.emoji) \(p.text)"
        case .englishWord(let w):
            return [w.word, w.phonetic, w.meaning].compactMap { $0 }.joined(separator: " ")
        case .sentence(let s):
            return "\(s.sentence) \(s.meaning)"
        }
    }

    var isIdiom: Bool {
        if case .idiom = self { return true }
        return false
    }
}

/// 本局可出题的知识点，以及生成干扰项用的素材（来自同年级同学科的全部题库）。
public struct ItemPool: Sendable {
    public enum Selection: Hashable, Sendable {
        case all
        /// 元素为 "题库id/单元id"
        case units(Set<String>)
        /// 错题复习：只出这些知识点
        case review(Set<String>)
    }

    public let items: [LearningItem]
    /// 大招题优先用成语
    public let ultimateItems: [LearningItem]

    let characters: [CharacterItem]
    let words: [WordItem]
    let idioms: [IdiomItem]
    let poems: [PoemItem]
    let pictures: [PictureItem]
    let englishWords: [EnglishWordItem]
    let sentences: [SentenceItem]

    public var isEmpty: Bool { items.isEmpty }

    public init(packs: [ContentPack], selection: Selection) {
        var items: [LearningItem] = []
        var allItems: [LearningItem] = []
        var seenKeys: Set<String> = []
        var characters: [String: CharacterItem] = [:]
        var words: [String: WordItem] = [:]
        var idioms: [String: IdiomItem] = [:]
        var poems: [String: PoemItem] = [:]
        var pictures: [String: PictureItem] = [:]
        var englishWords: [String: EnglishWordItem] = [:]
        var sentences: [String: SentenceItem] = [:]

        for pack in packs {
            for unit in pack.units {
                let unitKey = "\(pack.id)/\(unit.id)"
                for lesson in unit.lessons {
                    let lessonItems = Self.lessonItems(lesson, scope: "\(unitKey)/\(lesson.id)")

                    for item in lessonItems where seenKeys.insert(item.key).inserted {
                        allItems.append(item)
                        let selected: Bool
                        switch selection {
                        case .all: selected = true
                        case .units(let keys): selected = keys.contains(unitKey)
                        case .review(let keys): selected = keys.contains(item.key)
                        }
                        if selected { items.append(item) }
                    }

                    for c in lesson.characters { characters[c.char] = characters[c.char] ?? c }
                    for w in lesson.words { words[w.text] = words[w.text] ?? w }
                    for i in lesson.idioms { idioms[i.text] = idioms[i.text] ?? i }
                    for p in lesson.poems { poems[p.title] = poems[p.title] ?? p }
                    for p in lesson.pictures { pictures[p.text] = pictures[p.text] ?? p }
                    for w in lesson.englishWords { englishWords[w.word] = englishWords[w.word] ?? w }
                    for s in lesson.sentences { sentences[s.sentence] = sentences[s.sentence] ?? s }
                }
            }
        }

        self.items = items
        self.ultimateItems = allItems.filter(\.isIdiom)
        self.characters = Array(characters.values)
        self.words = Array(words.values)
        self.idioms = Array(idioms.values)
        self.poems = Array(poems.values)
        self.pictures = Array(pictures.values)
        self.englishWords = Array(englishWords.values)
        self.sentences = Array(sentences.values)
    }

    /// 一课里能出题的知识点。scope 为 "题库id/单元id/课id"，手写选择题的 key 里要用
    public static func lessonItems(_ lesson: Lesson, scope: String) -> [LearningItem] {
        var items: [LearningItem] = []
        items += lesson.characters.map { .character($0) }
        items += lesson.words.filter { $0.pinyin != nil }.map { .word($0) }
        items += lesson.idioms.filter { $0.text.count >= 2 }.map { .idiom($0) }
        for poem in lesson.poems where poem.lines.count >= 2 {
            items += (0..<(poem.lines.count - 1)).map { .poemLine(poem, index: $0) }
        }
        items += lesson.questions.filter { $0.options.contains($0.answer) }.map { .choice($0, scope: scope) }
        items += lesson.pictures.map { .picture($0) }
        items += lesson.englishWords.filter { !$0.word.isEmpty && !$0.meaning.isEmpty }.map { .englishWord($0) }
        items += lesson.sentences.filter { !$0.sentence.isEmpty && !$0.meaning.isEmpty }.map { .sentence($0) }
        return items
    }

    /// 按 key 找知识点（错题本用）
    public static func item(forKey key: String, in packs: [ContentPack]) -> LearningItem? {
        ItemPool(packs: packs, selection: .review([key])).items.first
    }
}
