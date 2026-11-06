import Foundation

/// 把选择题改写成字块题。题干、朗读、单词卡、讲解沿用选择题，只换作答方式：
/// 不用键盘，从一行字块里依次点出答案。单空填一个字、一个拼音或一个单词；多空一题几个格子
extension QuestionGenerator {
    func typed<R: RandomNumberGenerator>(_ base: Question, item: LearningItem, multi: Bool, _ rng: inout R) -> Question? {
        switch item {
        case .character(let c):
            if settings.preschool { return listenPinyin(base, c, whole: multi, &rng) }
            return multi ? nil : character(base, c, &rng)
        case .word(let w):
            return word(base, w, multi: multi, &rng)
        case .idiom(let i):
            return missingChars(base, text: i.text, count: multi ? 2 : 1, instruction: "补全成语",
                                hint: i.pinyin.map(Pinyin.normalize) ?? i.meaning ?? "想想这个成语", multi: multi, &rng)
        case .poemLine(let p, let index):
            guard index + 1 < p.lines.count else { return nil }
            return missingChars(base, text: p.lines[index + 1], count: multi ? Int.random(in: 2...3, using: &rng) : 1,
                                instruction: "补全下一句", hint: p.byline, multi: multi, &rng)
        case .englishWord(let w):
            return multi ? nil : spell(base, w, &rng)
        case .sentence(let s):
            return sentence(base, s, count: multi ? 2 : 1, &rng)
        case .picture(let p):
            return firstLetter(base, p, &rng)
        case .choice:
            return nil
        }
    }

    // MARK: - 字块数量：幼儿园最少，挑战最多

    private var hanziTiles: Int { settings.preschool ? 4 : (settings.strategy == .hard ? 8 : 6) }
    private var groupOptions: Int { settings.strategy == .hard && !settings.preschool ? 4 : 3 }
    private var extraLetters: Int { settings.preschool ? 1 : (settings.strategy == .hard ? 3 : 2) }

    // MARK: - 各题型

    /// 看字拼拼音 / 看拼音选字块 / 词语缺一个字
    private func character<R: RandomNumberGenerator>(_ base: Question, _ c: CharacterItem, _ rng: inout R) -> Question? {
        let pinyin = Pinyin.normalize(c.pinyin)
        switch base.kind {
        case .charToPinyin:
            return pinyinTiles(base, pinyin: pinyin, instruction: "拼出读音", prompt: c.char,
                               hint: "开头字母是 \(Pinyin.parse(pinyin).base.prefix(1))", &rng)
        case .pinyinToChar:
            let word = Self.charWords(c).first
            return make(base, instruction: "找出这个字", prompt: pinyin, hintLine: base.hint, style: .hanzi,
                        answers: [c.char], distractors: similarChars(to: c, &rng), template: nil,
                        hint: word.map { "组词：\($0.replacingOccurrences(of: c.char, with: "□"))" } ?? "读音是 \(pinyin)",
                        multi: false, &rng)
        default:
            // 叠字词（叽叽喳喳）挖空后有两个 □，只挑这个字只出现一次的组词
            let once = Self.charWords(c).filter { $0.components(separatedBy: c.char).count == 2 }
            guard let word = once.randomElement(using: &rng) else { return nil }
            let template = word.replacingOccurrences(of: c.char, with: "□")
            return make(base, instruction: "填出缺的字", prompt: template, hintLine: nil, style: .hanzi,
                        answers: [c.char], distractors: similarChars(to: c, &rng), template: template,
                        hint: "读音是 \(pinyin)", multi: false, &rng)
        }
    }

    /// 单空：词语缺一个字；多空：看拼音把整个词拼出来
    private func word<R: RandomNumberGenerator>(_ base: Question, _ w: WordItem, multi: Bool, _ rng: inout R) -> Question? {
        guard let pinyin = w.pinyin.map(Pinyin.normalize) else { return nil }
        let chars = w.text.map(String.init)
        if multi {
            guard chars.count >= 2, Set(chars).count == chars.count else { return nil }
            return make(base, instruction: "看拼音拼词语", prompt: pinyin, hintLine: nil, style: .hanzi,
                        answers: chars, distractors: otherChars(excluding: chars, &rng),
                        template: String(repeating: "□", count: chars.count),
                        hint: "第一个字是「\(chars[0])」", multi: true, &rng)
        }
        let syllables = pinyin.split(separator: " ").map(String.init)
        let index = Int.random(in: 0..<chars.count, using: &rng)
        var shown = chars
        shown[index] = "□"
        let template = shown.joined()
        let reading = syllables.count == chars.count ? syllables[index] : pinyin
        return make(base, instruction: "填出缺的字", prompt: template, hintLine: pinyin, style: .hanzi,
                    answers: [chars[index]], distractors: otherChars(excluding: chars, &rng), template: template,
                    hint: "这个字读 \(reading)", multi: false, &rng)
    }

    /// 成语、诗句里挖掉几个字（只挖汉字，不挖标点，也不挖重复的字），按顺序点
    private func missingChars<R: RandomNumberGenerator>(
        _ base: Question, text: String, count: Int, instruction: String, hint: String, multi: Bool, _ rng: inout R
    ) -> Question? {
        var chars = text.map(String.init)
        let candidates = chars.indices.filter { i in
            chars[i].unicodeScalars.allSatisfy { $0.properties.isIdeographic } && chars.filter { $0 == chars[i] }.count == 1
        }
        guard candidates.count > count else { return nil }
        let picked = Array(candidates.shuffled(using: &rng).prefix(count)).sorted()
        let answers = picked.map { chars[$0] }
        for i in picked { chars[i] = "□" }
        let template = chars.joined()
        // 诗句题的题面是上一句，挖空的是下一句；成语题题面就是挖空后的成语
        let prompt = base.kind == .poemNextLine ? base.prompt : template
        return make(base, instruction: instruction, prompt: prompt, hintLine: base.hint, style: .hanzi,
                    answers: answers, distractors: otherChars(excluding: text.map(String.init), &rng),
                    template: template, hint: hint, multi: multi, &rng)
    }

    /// 用打乱的字母块拼单词，只多几个干扰字母；太长的单词仍出选择题
    private func spell<R: RandomNumberGenerator>(_ base: Question, _ w: EnglishWordItem, _ rng: inout R) -> Question? {
        let letters = Array(w.word.lowercased().filter(\.isLetter)).map(String.init)
        guard (2...8).contains(letters.count) else { return nil }
        let listen = base.kind == .listenPickEnglish
        let extras = "abcdefghijklmnopqrstuvwxyz".map(String.init).filter { !letters.contains($0) }
            .shuffled(using: &rng).prefix(extraLetters)
        return finish(base, instruction: listen ? "听一听，拼出单词" : "拼出单词", prompt: listen ? base.prompt : w.meaning,
                      hintLine: nil, style: .letters, blanks: letters.map { InputBlank(answer: $0) },
                      groups: [TileGroup(tiles: (letters + extras).shuffled(using: &rng))], template: nil,
                      hint: "首字母是 \(letters[0])，一共 \(letters.count) 个字母", multi: false)
    }

    /// 按中文意思，把英文句子里挖掉的单词放回去
    private func sentence<R: RandomNumberGenerator>(_ base: Question, _ s: SentenceItem, count: Int, _ rng: inout R) -> Question? {
        var words = s.sentence.split(separator: " ").map(String.init)
        let core: (String) -> String = { $0.trimmingCharacters(in: .letters.inverted) }
        let candidates = words.indices.filter { i in
            core(words[i]).count >= 2 && words.filter { core($0).lowercased() == core(words[i]).lowercased() }.count == 1
        }
        guard candidates.count >= count else { return nil }
        let picked = Array(candidates.shuffled(using: &rng).prefix(count)).sorted()
        let answers = picked.map { core(words[$0]) }
        for i in picked { words[i] = words[i].replacingOccurrences(of: core(words[i]), with: "□") }
        let taken = Set(answers.map { $0.lowercased() })
        let others = (pool.sentences.flatMap { $0.sentence.split(separator: " ").map { core(String($0)) } } + pool.englishWords.map(\.word))
            .filter { $0.count >= 2 && !taken.contains($0.lowercased()) }
        var seen = Set<String>()
        let distractors = others.shuffled(using: &rng).filter { seen.insert($0.lowercased()).inserted }
            .prefix(settings.strategy == .hard ? 4 : 3)
        let initials = answers.map { String($0.prefix(1)) }.joined(separator: "、")
        return finish(base, instruction: "按意思放回单词", prompt: s.meaning, hintLine: nil, style: .words,
                      blanks: answers.map { InputBlank(answer: $0) },
                      groups: [TileGroup(tiles: (answers + distractors).shuffled(using: &rng))],
                      template: words.joined(separator: " "), hint: "首字母依次是 \(initials)", multi: count > 1)
    }

    /// 幼儿园听音：单空选声母，多空选声母 + 韵母（不考声调）
    private func listenPinyin<R: RandomNumberGenerator>(_ base: Question, _ c: CharacterItem, whole: Bool, _ rng: inout R) -> Question? {
        let (initial, final) = Pinyin.split(Pinyin.parse(c.pinyin).base)
        guard !initial.isEmpty else { return nil }
        var blanks = [InputBlank(answer: initial, group: 0)]
        var groups = [TileGroup(title: "声母", tiles: initialChoices(initial, &rng))]
        if whole {
            blanks.append(InputBlank(answer: final, group: 1))
            groups.append(TileGroup(title: "韵母", tiles: finalChoices(final, &rng)))
        }
        return finish(base, instruction: whole ? "听一听，拼出声母和韵母" : "听一听，选出声母", prompt: base.prompt,
                      hintLine: nil, style: .pinyin, blanks: blanks, groups: groups, template: nil,
                      hint: "就是这个字：\(c.char)", multi: whole)
    }

    /// 幼儿园听音选图：选出拼音的第一个字母
    private func firstLetter<R: RandomNumberGenerator>(_ base: Question, _ p: PictureItem, _ rng: inout R) -> Question? {
        guard let pinyin = p.pinyin, let first = Pinyin.parse(pinyin).base.first, first.isLetter else { return nil }
        let answer = String(first)
        let others = "bpmfdtnlgkhjqxzcsryw".map(String.init).filter { $0 != answer }.shuffled(using: &rng).prefix(groupOptions - 1)
        return finish(base, instruction: "听一听，选出拼音的第一个字母", prompt: base.prompt, hintLine: nil, style: .letters,
                      blanks: [InputBlank(answer: answer)], groups: [TileGroup(tiles: ([answer] + others).shuffled(using: &rng))],
                      template: nil, hint: "就是它：\(p.emoji) \(p.text)", multi: false)
    }

    // MARK: - 拼音字块

    /// 声母、韵母、声调各一组；没有声母的音节只拼韵母和声调，轻声不考声调
    private func pinyinTiles<R: RandomNumberGenerator>(
        _ base: Question, pinyin: String, instruction: String, prompt: String, hint: String, _ rng: inout R
    ) -> Question? {
        let syllable = Pinyin.parse(pinyin)
        let (initial, final) = Pinyin.split(syllable.base)
        var blanks: [InputBlank] = []
        var groups: [TileGroup] = []
        if !initial.isEmpty {
            blanks.append(InputBlank(answer: initial, group: groups.count))
            groups.append(TileGroup(title: "声母", tiles: initialChoices(initial, &rng)))
        }
        blanks.append(InputBlank(answer: final, group: groups.count))
        groups.append(TileGroup(title: "韵母", tiles: finalChoices(final, &rng)))
        if (1...4).contains(syllable.tone) {
            blanks.append(InputBlank(answer: InputSpec.toneMarks[syllable.tone - 1], group: groups.count))
            groups.append(TileGroup(title: "声调", tiles: InputSpec.toneMarks))
        }
        return finish(base, instruction: instruction, prompt: prompt, hintLine: nil, style: .pinyin,
                      blanks: blanks, groups: groups, template: nil, hint: hint, multi: false)
    }

    private static let initialSwaps = ["zh": "z", "z": "zh", "ch": "c", "c": "ch", "sh": "s", "s": "sh", "n": "l", "l": "n",
                                       "b": "p", "p": "b", "d": "t", "t": "d", "f": "h", "h": "f"]
    private static let finalSwaps = ["en": "eng", "eng": "en", "in": "ing", "ing": "in", "an": "ang", "ang": "an",
                                     "ian": "iang", "iang": "ian", "uan": "uang", "uang": "uan", "un": "ong", "ong": "un"]

    /// 正确的声母 + 最容易混的那个 + 随机凑够
    private func initialChoices<R: RandomNumberGenerator>(_ answer: String, _ rng: inout R) -> [String] {
        let all = ["b", "p", "m", "f", "d", "t", "n", "l", "g", "k", "h", "j", "q", "x", "zh", "ch", "sh", "r", "z", "c", "s", "y", "w"]
        return choices(answer, near: Self.initialSwaps[answer], from: all, &rng)
    }

    private func finalChoices<R: RandomNumberGenerator>(_ answer: String, _ rng: inout R) -> [String] {
        let fromPool = pool.characters.map { Pinyin.split(Pinyin.parse($0.pinyin).base).final }
        let common = ["a", "o", "e", "i", "u", "ai", "ei", "ao", "ou", "an", "en", "ang", "eng", "ong", "in", "ing", "ie", "uo"]
        return choices(answer, near: Self.finalSwaps[answer], from: Array(Set(fromPool + common)).sorted(), &rng)
    }

    private func choices<R: RandomNumberGenerator>(_ answer: String, near: String?, from all: [String], _ rng: inout R) -> [String] {
        var picked = [answer]
        if let near { picked.append(near) }
        for other in all.shuffled(using: &rng) where picked.count < groupOptions && !picked.contains(other) {
            picked.append(other)
        }
        return Array(picked.prefix(groupOptions)).shuffled(using: &rng)
    }

    // MARK: - 汉字字块

    /// 题库里别的字（生字、词语、成语），不含这题的字
    private func otherChars<R: RandomNumberGenerator>(excluding own: [String], _ rng: inout R) -> [String] {
        let all = pool.characters.map(\.char)
            + pool.words.flatMap { $0.text.map(String.init) }
            + pool.idioms.flatMap { $0.text.map(String.init) }
        let ownSet = Set(own)
        return Array(Set(all.filter { !ownSet.contains($0) && $0.unicodeScalars.allSatisfy { $0.properties.isIdeographic } }))
            .sorted().shuffled(using: &rng)
    }

    /// 汉字题：正确的字 + 干扰字，凑够这一档的字块数
    private func make<R: RandomNumberGenerator>(
        _ base: Question, instruction: String, prompt: String, hintLine: String?, style: TileStyle,
        answers: [String], distractors: [String], template: String?, hint: String, multi: Bool, _ rng: inout R
    ) -> Question? {
        var tiles = answers
        for d in distractors where !tiles.contains(d) && tiles.count < max(hanziTiles, answers.count + 3) {
            tiles.append(d)
        }
        guard tiles.count > answers.count else { return nil }
        return finish(base, instruction: instruction, prompt: prompt, hintLine: hintLine, style: style,
                      blanks: answers.map { InputBlank(answer: $0) }, groups: [TileGroup(tiles: tiles.shuffled(using: &rng))],
                      template: template, hint: hint, multi: multi)
    }

    private func finish(_ base: Question, instruction: String, prompt: String, hintLine: String?, style: TileStyle,
                        blanks: [InputBlank], groups: [TileGroup], template: String?, hint: String, multi: Bool) -> Question {
        let spec = InputSpec(style: style, blanks: blanks, groups: groups, template: template, hint: hint, isMulti: multi)
        var q = base
        q.instruction = instruction
        q.prompt = prompt
        q.hint = hintLine
        q.options = [spec.answerText]
        q.answerIndex = 0
        q.optionStyle = .text
        q.input = spec
        return q
    }
}
