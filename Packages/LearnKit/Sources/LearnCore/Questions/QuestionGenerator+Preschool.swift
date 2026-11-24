import Foundation

extension QuestionGenerator {
    public func makeQuestion<R: RandomNumberGenerator>(for item: LearningItem, stats: ItemStats?, using rng: inout R) -> Question? {
        guard settings.preschool, let range = settings.ladder else {
            return makeQuestion(for: item, using: &rng)
        }
        let rung = min(range.upperBound, max(range.lowerBound, PreschoolLadder.level(stats)))
        return makeQuestion(for: item, rung: rung, using: &rng)
    }

    /// 素材不支持某阶时逐级回退；始终保留听音选择题作为最后的兜底。
    func makeQuestion<R: RandomNumberGenerator>(for item: LearningItem, rung: Int, using rng: inout R) -> Question? {
        for level in stride(from: min(3, max(0, rung)), through: 0, by: -1) {
            switch item {
            case .character(let c):
                if let q = preschoolCharacter(c, key: item.key, rung: level, &rng) { return q }
            case .picture(let p):
                if level >= 2 {
                    if let base = makeQuestion(for: item, mode: .choice, using: &rng),
                       let q = firstLetter(base, p, &rng) { return q }
                } else if level == 1 {
                    let others = pool.pictures.filter { $0.emoji != p.emoji && $0.text != p.text }
                        .map(\.text).shuffled(using: &rng)
                    if let q = build(kind: .pictureToWord, key: item.key, instruction: "看图，选出词语",
                                     prompt: p.emoji, hint: nil, correct: p.text, distractors: others, style: .text,
                                     answerSpeech: p.text, explanation: "\(p.emoji) \(p.text)",
                                     card: WordCard(picture: p.emoji, text: p.text, pinyin: p.pinyin.map(Pinyin.normalize)), &rng) {
                        return q
                    }
                } else {
                    return makeQuestion(for: item, mode: .choice, using: &rng)
                }
            default:
                return makeQuestion(for: item, using: &rng)
            }
        }
        return nil
    }

    /// 不朗读含答案字的联想，避免字谜直接泄露答案；语音清单复用同一校验。
    static func shapeRiddleText(_ c: CharacterItem) -> String? {
        guard !c.char.isEmpty, let hint = c.imageHint.flatMap(SpeechText.normalize),
              !hint.contains(c.char) else { return nil }
        return hint
    }

    private func preschoolCharacter<R: RandomNumberGenerator>(
        _ c: CharacterItem, key: String, rung: Int, _ rng: inout R
    ) -> Question? {
        if rung == 3 || (rung == 2 && Self.shapeRiddleText(c) == nil) {
            guard let base = preschoolCharacter(c, key: key, rung: 0, &rng) else { return nil }
            return listenPinyin(base, c, whole: rung == 3, &rng)
        }

        let kind: QuestionKind
        let instruction: String
        let prompt: String
        let speech: String
        switch rung {
        case 2:
            guard let riddle = Self.shapeRiddleText(c) else { return nil }
            kind = .shapeRiddle
            instruction = "听字谜，找出这个字"
            prompt = "🔊"
            speech = riddle
        case 1:
            let words = Self.charWords(c).filter { $0.components(separatedBy: c.char).count == 2 }
            guard let word = words.randomElement(using: &rng) else { return nil }
            kind = .listenFillChar
            instruction = "听词语，填出缺的字"
            prompt = word.replacingOccurrences(of: c.char, with: "□")
            speech = word
        default:
            kind = .listenPickChar
            instruction = "听一听，是哪个字？"
            prompt = "🔊"
            speech = "找一找，\(Self.charSpeech(c))"
        }
        return build(kind: kind, key: key, instruction: instruction, prompt: prompt, hint: nil,
                     correct: c.char, distractors: preschoolCharDistractors(to: c, &rng), style: .text,
                     promptSpeech: speech, answerSpeech: c.char, explanation: "\(c.char) \(c.pinyin)",
                     card: charCard(c), &rng)
    }

    /// 标准交替放入同部首、近音字，挑战先放同部首；不足时用随机字补足。
    func preschoolCharDistractors<R: RandomNumberGenerator>(to c: CharacterItem, _ rng: inout R) -> [String] {
        let others = pool.characters.filter { $0.char != c.char }.shuffled(using: &rng)
        guard settings.strategy != .easy else { return others.map(\.char) }
        let radical = Radical.of(c.imageHint)
        let sameRadical = others.filter { radical != nil && Radical.of($0.imageHint) == radical }.map(\.char)
        let target = Pinyin.parse(c.pinyin).base
        let (initial, final) = Pinyin.split(target)
        let near = similarChars(to: c, &rng).filter { char in
            guard let other = others.first(where: { $0.char == char }) else { return false }
            let base = Pinyin.parse(other.pinyin).base
            let parts = Pinyin.split(base)
            return base == target || (!initial.isEmpty && parts.initial == initial) || parts.final == final
        }
        if settings.strategy == .hard { return sameRadical + near + others.map(\.char) }
        var mixed: [String] = []
        for i in 0..<max(sameRadical.count, near.count) {
            if i < sameRadical.count { mixed.append(sameRadical[i]) }
            if i < near.count { mixed.append(near[i]) }
        }
        return mixed + others.map(\.char)
    }
}
