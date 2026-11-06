import Foundation

/// 作答方式：选择、填一个空、填多个空
public enum AnswerMode: String, Sendable, CaseIterable {
    case choice, single, multi
}

/// 各作答方式出现的比例。入门只选；标准以选择为主、夹一些单空；挑战只出单空和多空
public struct AnswerMix: Sendable, Equatable {
    public var choice: Double
    public var single: Double
    public var multi: Double

    public init(choice: Double, single: Double, multi: Double) {
        self.choice = choice
        self.single = single
        self.multi = multi
    }

    public static let choiceOnly = AnswerMix(choice: 1, single: 0, multi: 0)
    public static let standard = AnswerMix(choice: 0.7, single: 0.3, multi: 0)
    public static let challenge = AnswerMix(choice: 0, single: 0.5, multi: 0.5)

    public static func make(for difficulty: Difficulty) -> AnswerMix {
        switch difficulty {
        case .easy: .choiceOnly
        case .normal: .standard
        case .hard: .challenge
        }
    }

    /// 只出选择题时不消耗随机数，入门难度的出题顺序和以前一样
    public func pick<R: RandomNumberGenerator>(using rng: inout R) -> AnswerMode {
        let total = choice + single + multi
        guard total > 0, choice < total else { return .choice }
        let roll = Double.random(in: 0..<total, using: &rng)
        if roll < choice { return .choice }
        return roll < choice + single ? .single : .multi
    }
}

/// 字块拼出来的是什么：决定拼好后怎么显示、怎么记录
public enum TileStyle: String, Sendable {
    /// 一个或几个汉字
    case hanzi
    /// 声母 + 韵母 + 声调拼成一个音节
    case pinyin
    /// 一个个字母拼成英文单词
    case letters
    /// 几个英文单词填进句子
    case words
}

/// 一组字块。拼音分「声母」「韵母」「声调」三组，其他题只有一组
public struct TileGroup: Hashable, Sendable {
    public var title: String?
    public var tiles: [String]

    public init(title: String? = nil, tiles: [String]) {
        self.title = title
        self.tiles = tiles
    }
}

/// 一个空：答案是某一组里的一块
public struct InputBlank: Hashable, Sendable {
    public var answer: String
    public var group: Int

    public init(answer: String, group: Int = 0) {
        self.answer = answer
        self.group = group
    }
}

/// 字块题：不用键盘，从给出的字块里依次点出答案。拼满自动判题；
/// 答错两次给提示，三次把正确的字块高亮出来
public struct InputSpec: Sendable {
    public var style: TileStyle
    public var blanks: [InputBlank]
    public var groups: [TileGroup]
    /// 题面模板，□ 依次对应每个空；nil 表示空格单独排在题面下方
    public var template: String?
    /// 答错两次后显示的提示
    public var hint: String
    /// 多空题（挑战难度）。拼音虽然有三个空，只算单空
    public var isMulti: Bool

    public static let toneMarks = ["ˉ", "ˊ", "ˇ", "ˋ"]

    public init(style: TileStyle, blanks: [InputBlank], groups: [TileGroup], template: String? = nil,
                hint: String, isMulti: Bool) {
        self.style = style
        self.blanks = blanks
        self.groups = groups
        self.template = template
        self.hint = hint
        self.isMulti = isMulti
    }

    /// 字块是原样拿来的，逐个对上就算对
    public func accepts(_ texts: [String]) -> Bool {
        texts.count == blanks.count && zip(blanks, texts).allSatisfy { $0.answer == $1 }
    }

    /// 把各空拼成一个答案：拼音标上声调，单词连写，句子空格隔开
    public func compose(_ texts: [String]) -> String {
        switch style {
        case .hanzi, .letters:
            return texts.joined()
        case .words:
            return texts.joined(separator: " ")
        case .pinyin:
            let marks = Self.toneMarks
            let tone = texts.last.flatMap { marks.firstIndex(of: $0) }.map { $0 + 1 }
            let base = (tone == nil ? texts : Array(texts.dropLast())).joined()
            return tone.map { Pinyin.mark(base, tone: $0) } ?? base
        }
    }

    public var answerText: String { compose(blanks.map(\.answer)) }
}
