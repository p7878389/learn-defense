import Foundation

/// 干扰项的难度：简单时用差别大的选项，难时用容易混淆的选项
public enum DistractorStrategy: Sendable {
    case easy, normal, hard
}

/// 带声调拼音的拆分、标调和易混淆变体。只处理单个音节，多音节按空格分开处理。
public enum Pinyin {
    public struct Syllable: Hashable, Sendable {
        /// 不带声调，ü 保留，如 "lü"
        public var base: String
        /// 1～4，5 表示轻声
        public var tone: Int

        public var marked: String { Pinyin.mark(base, tone: tone) }
    }

    private static let toned: [Character: [Character]] = [
        "a": ["ā", "á", "ǎ", "à"],
        "e": ["ē", "é", "ě", "è"],
        "i": ["ī", "í", "ǐ", "ì"],
        "o": ["ō", "ó", "ǒ", "ò"],
        "u": ["ū", "ú", "ǔ", "ù"],
        "ü": ["ǖ", "ǘ", "ǚ", "ǜ"],
    ]

    private static let untone: [Character: (Character, Int)] = {
        var map: [Character: (Character, Int)] = [:]
        for (plain, marks) in toned {
            for (i, m) in marks.enumerated() { map[m] = (plain, i + 1) }
        }
        return map
    }()

    private static let initials = [
        "zh", "ch", "sh", "b", "p", "m", "f", "d", "t", "n", "l",
        "g", "k", "h", "j", "q", "x", "r", "z", "c", "s", "y", "w",
    ]

    private static let initialSwaps: [String: String] = [
        "zh": "z", "z": "zh", "ch": "c", "c": "ch", "sh": "s", "s": "sh", "n": "l", "l": "n",
    ]

    public static func parse(_ text: String) -> Syllable {
        var base = ""
        var tone = 5
        for ch in text.precomposedStringWithCanonicalMapping.lowercased() {
            if let (plain, t) = untone[ch] {
                base.append(plain)
                tone = t
            } else if ch == "v" {
                base.append("ü")
            } else {
                base.append(ch)
            }
        }
        return Syllable(base: base, tone: tone)
    }

    /// 按标调规则加声调：有 a 标 a，没有 a 有 e 标 e，ou 标 o，其余标最后一个元音
    public static func mark(_ base: String, tone: Int) -> String {
        guard (1...4).contains(tone) else { return base }
        var chars = Array(base)
        let index: Int?
        if let i = chars.firstIndex(of: "a") {
            index = i
        } else if let i = chars.firstIndex(of: "e") {
            index = i
        } else if let r = base.range(of: "ou") {
            index = base.distance(from: base.startIndex, to: r.lowerBound)
        } else {
            index = chars.lastIndex { "iouü".contains($0) }
        }
        guard let index, let marks = toned[chars[index]] else { return base }
        chars[index] = marks[tone - 1]
        return String(chars)
    }

    public static func split(_ base: String) -> (initial: String, final: String) {
        for ini in initials where base.hasPrefix(ini) && base.count > ini.count {
            return (ini, String(base.dropFirst(ini.count)))
        }
        return ("", base)
    }

    /// 同一个音节的其他声调
    public static func toneVariants(of text: String) -> [String] {
        let s = parse(text)
        return (1...4).filter { $0 != s.tone }.map { mark(s.base, tone: $0) }
    }

    /// 平翘舌、n/l、前后鼻音的变体，声调不变
    public static func confusableVariants(of text: String) -> [String] {
        let s = parse(text)
        let (ini, fin) = split(s.base)
        var bases: [String] = []
        if let swapped = initialSwaps[ini] {
            bases.append(swapped + fin)
        }
        if fin.hasSuffix("ng"), !fin.hasSuffix("ong") {
            bases.append(ini + fin.dropLast())
        } else if fin.hasSuffix("n"), !["un", "ün"].contains(fin),
                  !(fin == "uan" && ["j", "q", "x", "y"].contains(ini)) {
            bases.append(ini + fin + "g")
        }
        return bases.map { mark($0, tone: s.tone) }
    }

    /// 生成拼音干扰项。多音节拼音（如 "zǎo chen"）随机改其中一个音节。
    public static func distractors<R: RandomNumberGenerator>(
        for correct: String,
        count: Int,
        strategy: DistractorStrategy,
        pool: [String],
        using rng: inout R
    ) -> [String] {
        let normalizedCorrect = normalize(correct)
        let syllables = normalizedCorrect.split(separator: " ").map(String.init)
        guard !syllables.isEmpty else { return [] }

        func vary(_ variants: (String) -> [String]) -> [String] {
            var out: [String] = []
            for (i, syl) in syllables.enumerated() {
                for v in variants(syl) {
                    var copy = syllables
                    copy[i] = v
                    out.append(copy.joined(separator: " "))
                }
            }
            return out.shuffled(using: &rng)
        }

        let tones = vary(toneVariants)
        let confusables = vary(confusableVariants)
        let sameLength = pool.map(normalize).filter { $0.split(separator: " ").count == syllables.count }
        let others = sameLength.shuffled(using: &rng)

        let ordered: [String]
        switch strategy {
        case .easy:
            ordered = others + tones + confusables
        case .normal:
            ordered = Array(tones.prefix(1)) + Array(confusables.prefix(1)) + others + tones + confusables
        case .hard:
            ordered = confusables + tones + others
        }

        var seen: Set<String> = [normalizedCorrect]
        var result: [String] = []
        for candidate in ordered where result.count < count {
            if seen.insert(candidate).inserted { result.append(candidate) }
        }
        return result
    }

    public static func normalize(_ text: String) -> String {
        text.precomposedStringWithCanonicalMapping
            .lowercased()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}
