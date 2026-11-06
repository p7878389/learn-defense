import Foundation

public enum QuestionKind: String, Codable, Sendable {
    case charToPinyin       // 看字选拼音
    case pinyinToChar       // 看拼音选字
    case fillCharInWord     // 选字填空
    case pinyinToWord       // 看拼音选词语
    case idiomFill          // 成语补全
    case poemNextLine       // 接下一句
    case choice             // 手写选择题
    case listenPickPicture  // 听音选图（幼儿园）
    case listenPickChar     // 听音选字（幼儿园）
    case englishToMeaning   // 看英文选意思
    case meaningToEnglish   // 看意思选英文
    case listenPickEnglish  // 听英文选单词
    case sentenceMeaning    // 选出英语句子的意思
}

public enum OptionStyle: Sendable {
    case text, pinyin, emoji
}

/// 答对后弹出的单词卡：图片 + 字词 + 拼音，帮孩子再看一遍、听一遍
public struct WordCard: Hashable, Sendable {
    /// emoji，画面层会换成 3D 图片
    public var picture: String?
    public var text: String
    public var pinyin: String?
    /// 组词、成语意思、诗题等
    public var detail: String?

    public init(picture: String? = nil, text: String, pinyin: String? = nil, detail: String? = nil) {
        self.picture = picture
        self.text = text
        self.pinyin = pinyin
        self.detail = detail
    }
}

/// 一道运行时生成的题
public struct Question: Identifiable, Sendable {
    public let id = UUID()
    public var kind: QuestionKind
    /// 对应的学习素材，用于记录对错
    public var itemKey: String
    /// 题目要求，如「选出正确的读音」
    public var instruction: String
    /// 题面，如「晨」「早□」
    public var prompt: String
    /// 怪物牌子上显示的短文字，题面太长时用「？」代替
    public var signText: String
    /// 题面下方的小提示（拼音、诗题等）
    public var hint: String?
    public var options: [String]
    public var optionStyle: OptionStyle
    public var answerIndex: Int
    /// 题目出现时自动朗读（听音题）
    public var promptSpeech: String?
    /// 答对或揭晓答案时朗读
    public var answerSpeech: String?
    /// 揭晓答案时显示的说明
    public var explanation: String?
    /// 答对后弹出的单词卡
    public var card: WordCard?

    public var answer: String { options[answerIndex] }

    public init(
        kind: QuestionKind,
        itemKey: String,
        instruction: String,
        prompt: String,
        signText: String? = nil,
        hint: String? = nil,
        options: [String],
        optionStyle: OptionStyle,
        answerIndex: Int,
        promptSpeech: String? = nil,
        answerSpeech: String? = nil,
        explanation: String? = nil,
        card: WordCard? = nil
    ) {
        self.kind = kind
        self.itemKey = itemKey
        self.instruction = instruction
        self.prompt = prompt
        self.signText = signText ?? (prompt.count <= 8 ? prompt : "？")
        self.hint = hint
        self.options = options
        self.optionStyle = optionStyle
        self.answerIndex = answerIndex
        self.promptSpeech = promptSpeech
        self.answerSpeech = answerSpeech
        self.explanation = explanation
        self.card = card
    }
}
