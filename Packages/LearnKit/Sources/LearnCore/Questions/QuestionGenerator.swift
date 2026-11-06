import Foundation

public struct GeneratorSettings: Sendable {
    public var optionCount: Int
    public var strategy: DistractorStrategy
    /// 显示拼音等提示
    public var showHint: Bool
    /// 幼儿园：听音题，不出需要识字的题
    public var preschool: Bool
    /// 选择、单空、多空各占多少
    public var answerMix: AnswerMix

    public init(optionCount: Int, strategy: DistractorStrategy, showHint: Bool, preschool: Bool,
                answerMix: AnswerMix = .choiceOnly) {
        self.optionCount = optionCount
        self.strategy = strategy
        self.showHint = showHint
        self.preschool = preschool
        self.answerMix = answerMix
    }
}

/// 根据知识点和难度生成题目，干扰项从同年级题库中自动挑选。
public struct QuestionGenerator: Sendable {
    public let pool: ItemPool
    public var settings: GeneratorSettings

    public init(pool: ItemPool, settings: GeneratorSettings) {
        self.pool = pool
        self.settings = settings
    }

    /// 按难度的作答方式比例出题
    public func makeQuestion<R: RandomNumberGenerator>(for item: LearningItem, using rng: inout R) -> Question? {
        makeQuestion(for: item, mode: settings.answerMix.pick(using: &rng), using: &rng)
    }

    /// 指定作答方式出题。没有多空写法的题退成单空，也没有单空写法的（自定义选择题）保持选择
    public func makeQuestion<R: RandomNumberGenerator>(for item: LearningItem, mode: AnswerMode, using rng: inout R) -> Question? {
        guard let base = choiceQuestion(for: item, using: &rng) else { return nil }
        switch mode {
        case .choice: return base
        case .single: return typed(base, item: item, multi: false, &rng) ?? base
        case .multi: return typed(base, item: item, multi: true, &rng) ?? typed(base, item: item, multi: false, &rng) ?? base
        }
    }

    private func choiceQuestion<R: RandomNumberGenerator>(for item: LearningItem, using rng: inout R) -> Question? {
        switch item {
        case .character(let c):
            return settings.preschool ? listenPickChar(c, item.key, &rng) : character(c, item.key, &rng)
        case .word(let w):
            return pinyinToWord(w, item.key, &rng)
        case .idiom(let i):
            return idiomFill(i, item.key, &rng)
        case .poemLine(let p, let index):
            return poemNextLine(p, index, item.key, &rng)
        case .choice(let q, _):
            return choice(q, item.key, &rng)
        case .picture(let p):
            return listenPickPicture(p, item.key, &rng)
        case .englishWord(let w):
            return englishWord(w, item.key, &rng)
        case .sentence(let s):
            return sentenceMeaning(s, item.key, &rng)
        }
    }

    /// 大招题：优先成语，没有成语就随便出一道
    public func makeUltimateQuestion<R: RandomNumberGenerator>(using rng: inout R) -> (LearningItem, Question)? {
        let candidates = settings.preschool ? pool.items : (pool.ultimateItems.isEmpty ? pool.items : pool.ultimateItems)
        for item in candidates.shuffled(using: &rng) {
            // 大招要快，始终是选择题
            if let q = makeQuestion(for: item, mode: .choice, using: &rng) { return (item, q) }
        }
        return nil
    }

    // MARK: - 朗读文本

    /// 这个知识点出题时可能朗读的全部文本（各题型的题目和答案），用来预先生成高质量语音。
    /// 与下面各题型里的 promptSpeech / answerSpeech 保持一致，测试会逐题核对。
    public static func speechTexts(for item: LearningItem) -> [String] {
        switch item {
        case .character(let c):
            let speech = charSpeech(c)
            return [speech, "找一找，\(speech)", c.char] + charWords(c)
        case .word(let w):
            return [w.text]
        case .idiom(let i):
            return [i.text]
        case .poemLine(let p, let index):
            guard index + 1 < p.lines.count else { return [] }
            return ["\(p.lines[index])，\(p.lines[index + 1])"]
        case .choice(let q, _):
            return [q.answer]
        case .picture(let p):
            return ["找一找，\(p.text)", p.text]
        case .englishWord(let w):
            return [w.word, englishWordSpeech(w)]
        case .sentence(let s):
            return [s.sentence]
        }
    }

    /// 英语单词答对后读「apple，苹果」
    static func englishWordSpeech(_ w: EnglishWordItem) -> String {
        "\(w.word)，\(w.meaning)"
    }

    /// 生字的组词（含这个字、两个字以上）
    static func charWords(_ c: CharacterItem) -> [String] {
        (c.words ?? []).filter { $0.contains(c.char) && $0.count > 1 }
    }

    /// 生字读法：有组词时读「晨，早晨的晨」，避免单字读错音
    static func charSpeech(_ c: CharacterItem) -> String {
        charWords(c).first.map { "\(c.char)，\($0)的\(c.char)" } ?? c.char
    }

    // MARK: - 各题型

    private func character<R: RandomNumberGenerator>(_ c: CharacterItem, _ key: String, _ rng: inout R) -> Question? {
        let words = Self.charWords(c)
        var kinds: [QuestionKind] = [.charToPinyin, .pinyinToChar]
        if !words.isEmpty { kinds.append(.fillCharInWord) }
        let kind = kinds.randomElement(using: &rng)!
        let speech = Self.charSpeech(c)
        let explanation = ([c.char + " " + c.pinyin] + words).joined(separator: "  ")
        let card = charCard(c)

        switch kind {
        case .charToPinyin:
            let distractors = Pinyin.distractors(
                for: c.pinyin, count: settings.optionCount - 1, strategy: settings.strategy,
                pool: pool.characters.map(\.pinyin), using: &rng)
            return build(
                kind: kind, key: key, instruction: "选出正确的读音", prompt: c.char, hint: nil,
                correct: Pinyin.normalize(c.pinyin), distractors: distractors, style: .pinyin,
                answerSpeech: speech, explanation: explanation, card: card, &rng)
        case .pinyinToChar:
            // 同音字很多，有组词时用组词做提示
            let hint = words.randomElement(using: &rng).map { $0.replacingOccurrences(of: c.char, with: "□") }
            return build(
                kind: kind, key: key, instruction: "选出正确的汉字", prompt: Pinyin.normalize(c.pinyin), hint: hint,
                correct: c.char, distractors: similarChars(to: c, &rng), style: .text,
                answerSpeech: speech, explanation: explanation, card: card, &rng)
        default:
            let word = words.randomElement(using: &rng)!
            return build(
                kind: .fillCharInWord, key: key, instruction: "选字填空",
                prompt: word.replacingOccurrences(of: c.char, with: "□"),
                hint: settings.showHint ? Pinyin.normalize(c.pinyin) : nil,
                correct: c.char, distractors: similarChars(to: c, &rng), style: .text,
                answerSpeech: word, explanation: explanation, card: card, &rng)
        }
    }

    private func listenPickChar<R: RandomNumberGenerator>(_ c: CharacterItem, _ key: String, _ rng: inout R) -> Question? {
        let speech = Self.charSpeech(c)
        let others = pool.characters.map(\.char).filter { $0 != c.char }.shuffled(using: &rng)
        return build(
            kind: .listenPickChar, key: key, instruction: "听一听，是哪个字？", prompt: "🔊", hint: nil,
            correct: c.char, distractors: others, style: .text,
            promptSpeech: "找一找，\(speech)", answerSpeech: c.char, explanation: "\(c.char) \(c.pinyin)",
            card: charCard(c), &rng)
    }

    private func pinyinToWord<R: RandomNumberGenerator>(_ w: WordItem, _ key: String, _ rng: inout R) -> Question? {
        guard let pinyin = w.pinyin else { return nil }
        let others = pool.words.map(\.text).filter { $0 != w.text && $0.count == w.text.count }.shuffled(using: &rng)
        return build(
            kind: .pinyinToWord, key: key, instruction: "选出正确的词语", prompt: Pinyin.normalize(pinyin), hint: nil,
            correct: w.text, distractors: others, style: .text,
            answerSpeech: w.text, explanation: "\(w.text)（\(pinyin)）",
            card: WordCard(text: w.text, pinyin: Pinyin.normalize(pinyin)), &rng)
    }

    private func idiomFill<R: RandomNumberGenerator>(_ idiom: IdiomItem, _ key: String, _ rng: inout R) -> Question? {
        var chars = Array(idiom.text)
        let index = Int.random(in: 0..<chars.count, using: &rng)
        let correct = String(chars[index])
        chars[index] = "□"
        let own = Set(idiom.text.map(String.init))
        var others = pool.idioms.flatMap { $0.text.map(String.init) } + pool.characters.map(\.char)
        others = Array(Set(others).subtracting(own)).shuffled(using: &rng)
        return build(
            kind: .idiomFill, key: key, instruction: "补全成语", prompt: String(chars),
            hint: settings.showHint ? idiom.pinyin.map(Pinyin.normalize) : nil,
            correct: correct, distractors: others, style: .text,
            answerSpeech: idiom.text,
            explanation: idiom.meaning.map { "\(idiom.text)：\($0)" } ?? idiom.text,
            card: WordCard(text: idiom.text, pinyin: idiom.pinyin.map(Pinyin.normalize), detail: idiom.meaning), &rng)
    }

    private func poemNextLine<R: RandomNumberGenerator>(_ poem: PoemItem, _ index: Int, _ key: String, _ rng: inout R) -> Question? {
        let line = poem.lines[index]
        let correct = poem.lines[index + 1]
        let sameLength: (String) -> Bool = { $0.count == correct.count && $0 != correct && $0 != line }
        let ownLines = poem.lines.filter(sameLength).shuffled(using: &rng)
        let otherLines = pool.poems.filter { $0.title != poem.title }
            .flatMap(\.lines).filter(sameLength).shuffled(using: &rng)
        // 难度高时干扰项多来自同一首诗
        let distractors = settings.strategy == .easy ? otherLines + ownLines : ownLines + otherLines
        return build(
            kind: .poemNextLine, key: key, instruction: "接下一句", prompt: line, hint: poem.byline,
            correct: correct, distractors: distractors, style: .text,
            answerSpeech: "\(line)，\(correct)", explanation: "\(line)，\(correct)。\(poem.byline)",
            card: WordCard(text: correct, detail: poem.byline), &rng)
    }

    private func choice<R: RandomNumberGenerator>(_ q: ChoiceItem, _ key: String, _ rng: inout R) -> Question? {
        let options = q.options.shuffled(using: &rng)
        guard let answerIndex = options.firstIndex(of: q.answer), options.count >= 2 else { return nil }
        return Question(
            kind: .choice, itemKey: key, instruction: "选一选", prompt: q.prompt, signText: "？",
            options: options, optionStyle: .text, answerIndex: answerIndex,
            answerSpeech: q.answer, explanation: q.explain.map { "\(q.answer)。\($0)" } ?? q.answer,
            card: WordCard(text: q.answer, detail: q.explain))
    }

    private func listenPickPicture<R: RandomNumberGenerator>(_ p: PictureItem, _ key: String, _ rng: inout R) -> Question? {
        let others = pool.pictures.filter { $0.emoji != p.emoji }.map(\.emoji).shuffled(using: &rng)
        return build(
            kind: .listenPickPicture, key: key, instruction: "听一听，找出来", prompt: "🔊", hint: nil,
            correct: p.emoji, distractors: others, style: .emoji,
            promptSpeech: "找一找，\(p.text)", answerSpeech: p.text, explanation: "\(p.emoji) \(p.text)",
            card: WordCard(picture: p.emoji, text: p.text, pinyin: p.pinyin.map(Pinyin.normalize)), &rng)
    }

    /// 英语单词：看英文选意思、看意思选英文、听英文选单词（幼儿园只出听音题）
    private func englishWord<R: RandomNumberGenerator>(_ w: EnglishWordItem, _ key: String, _ rng: inout R) -> Question? {
        let kinds: [QuestionKind] = settings.preschool
            ? [.listenPickEnglish]
            : [.englishToMeaning, .meaningToEnglish, .listenPickEnglish]
        let kind = kinds.randomElement(using: &rng)!
        // 意思有重叠的词（hello「喂；你好」和 hi「嗨；你好」）不能互相当干扰项
        let others = pool.englishWords.filter {
            $0.word.lowercased() != w.word.lowercased() && !Self.sharesMeaning($0.meaning, w.meaning)
        }.shuffled(using: &rng)
        let answerSpeech = Self.englishWordSpeech(w)
        let explanation = [w.word, w.phonetic, w.meaning].compactMap { $0 }.joined(separator: " ")
        let card = WordCard(text: w.word, pinyin: w.phonetic, detail: w.meaning)

        switch kind {
        case .englishToMeaning:
            return build(
                kind: kind, key: key, instruction: "选出正确的意思", prompt: w.word,
                hint: settings.showHint ? w.phonetic : nil,
                correct: w.meaning, distractors: others.map(\.meaning), style: .text,
                answerSpeech: answerSpeech, explanation: explanation, card: card, &rng)
        case .meaningToEnglish:
            return build(
                kind: kind, key: key, instruction: "选出正确的英文", prompt: w.meaning, hint: nil,
                correct: w.word, distractors: others.map(\.word), style: .text,
                answerSpeech: answerSpeech, explanation: explanation, card: card, &rng)
        default:
            return build(
                kind: .listenPickEnglish, key: key, instruction: "听一听，是哪个单词？", prompt: "🔊", hint: nil,
                correct: w.word, distractors: others.map(\.word), style: .text,
                promptSpeech: w.word, answerSpeech: answerSpeech, explanation: explanation, card: card, &rng)
        }
    }

    private func sentenceMeaning<R: RandomNumberGenerator>(_ s: SentenceItem, _ key: String, _ rng: inout R) -> Question? {
        let others = pool.sentences
            .filter { $0.sentence != s.sentence && $0.meaning != s.meaning }
            .map(\.meaning).shuffled(using: &rng)
        return build(
            kind: .sentenceMeaning, key: key, instruction: "选出句子的意思", prompt: s.sentence, hint: nil,
            correct: s.meaning, distractors: others, style: .text,
            answerSpeech: s.sentence, explanation: "\(s.sentence) \(s.meaning)",
            card: WordCard(text: s.sentence, detail: s.meaning), &rng)
    }

    // MARK: - 工具

    /// 两个中文意思是否有相同的义项（按「；」「，」「/」等拆开比较）
    static func sharesMeaning(_ a: String, _ b: String) -> Bool {
        let separators = CharacterSet(charactersIn: "；;，,、/／")
        func senses(_ s: String) -> Set<String> {
            Set(s.components(separatedBy: separators)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty })
        }
        return !senses(a).isDisjoint(with: senses(b))
    }

    private func charCard(_ c: CharacterItem) -> WordCard {
        let words = (c.words ?? []).filter { $0.contains(c.char) && $0.count > 1 }
        return WordCard(text: c.char, pinyin: Pinyin.normalize(c.pinyin),
                        detail: words.isEmpty ? nil : words.prefix(3).joined(separator: "  "))
    }

    /// 读音相近的字更容易混淆，难度越高越优先选
    func similarChars<R: RandomNumberGenerator>(to c: CharacterItem, _ rng: inout R) -> [String] {
        let target = Pinyin.parse(c.pinyin)
        let (ini, fin) = Pinyin.split(target.base)
        let candidates = pool.characters.filter {
            $0.char != c.char && Pinyin.normalize($0.pinyin) != Pinyin.normalize(c.pinyin)
        }.shuffled(using: &rng)
        guard settings.strategy != .easy else { return candidates.map(\.char) }

        func score(_ other: CharacterItem) -> Int {
            let s = Pinyin.parse(other.pinyin)
            if s.base == target.base { return 2 }
            let (i, f) = Pinyin.split(s.base)
            return (i == ini || f == fin) ? 1 : 0
        }
        // 同分时保持洗牌后的顺序
        return candidates.enumerated()
            .sorted { (score($0.element), -$0.offset) > (score($1.element), -$1.offset) }
            .map(\.element.char)
    }

    private func build<R: RandomNumberGenerator>(
        kind: QuestionKind,
        key: String,
        instruction: String,
        prompt: String,
        hint: String?,
        correct: String,
        distractors: [String],
        style: OptionStyle,
        promptSpeech: String? = nil,
        answerSpeech: String?,
        explanation: String?,
        card: WordCard?,
        _ rng: inout R
    ) -> Question? {
        var picked: [String] = []
        for d in distractors where d != correct && !picked.contains(d) && picked.count < settings.optionCount - 1 {
            picked.append(d)
        }
        guard !picked.isEmpty else { return nil }
        let options = (picked + [correct]).shuffled(using: &rng)
        return Question(
            kind: kind, itemKey: key, instruction: instruction, prompt: prompt, hint: hint,
            options: options, optionStyle: style, answerIndex: options.firstIndex(of: correct)!,
            promptSpeech: promptSpeech, answerSpeech: answerSpeech, explanation: explanation, card: card)
    }
}
