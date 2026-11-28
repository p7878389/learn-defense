import Foundation

/// 儿童开口朗读的宽松匹配器：
/// - 英文：忽略大小写和标点，支持包含匹配、单词编辑距离容错、句子关键词命中率；
/// - 中文：支持包含匹配、同音字/无声调拼音匹配与多字音节命中率，尽量保护低龄儿童开口积极性。
public enum SpeechMatcher {
    public static func matches(spoken: String, expected: String) -> Bool {
        let normExpected = normalize(expected)
        let normSpoken = normalize(spoken)
        guard !normExpected.isEmpty, !normSpoken.isEmpty else { return false }
        if normSpoken.contains(normExpected) { return true }

        if SpeechText.isEnglish(expected) {
            return matchEnglish(spoken: normSpoken, expected: normExpected)
        }
        return matchChinese(spoken: normSpoken, expected: normExpected)
    }

    // MARK: - 英文匹配

    private static func matchEnglish(spoken: String, expected: String) -> Bool {
        let expectedWords = englishWords(expected)
        let spokenWords = englishWords(spoken)
        guard !expectedWords.isEmpty, !spokenWords.isEmpty else { return false }

        if expectedWords.count == 1 {
            let target = expectedWords[0]
            return spokenWords.contains { englishWordClose($0, target) }
        }
        let hits = expectedWords.filter { target in
            spokenWords.contains { englishWordClose($0, target) }
        }.count
        return Double(hits) / Double(expectedWords.count) >= 0.6
    }

    private static func englishWordClose(_ a: String, _ b: String) -> Bool {
        if a == b || a.contains(b) || b.contains(a) && min(a.count, b.count) >= 3 { return true }
        let maxDist = b.count >= 7 ? 2 : (b.count >= 4 ? 1 : 0)
        guard maxDist > 0 else { return false }
        return editDistance(Array(a), Array(b)) <= maxDist
    }

    private static func englishWords(_ text: String) -> [String] {
        text.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    // MARK: - 中文匹配（同音字 / 拼音容错）

    private static func matchChinese(spoken: String, expected: String) -> Bool {
        let expectedSyllables = pinyinSyllables(expected)
        let spokenSyllables = pinyinSyllables(spoken)
        guard !expectedSyllables.isEmpty, !spokenSyllables.isEmpty else { return false }

        if expectedSyllables.count == 1 {
            let target = expectedSyllables[0]
            return spokenSyllables.contains { syllableClose($0, target) }
        }
        let hits = expectedSyllables.filter { target in
            spokenSyllables.contains { syllableClose($0, target) }
        }.count
        return Double(hits) / Double(expectedSyllables.count) >= 0.65
    }

    /// 平翘舌 / 前后鼻音对幼儿园孩子宽容处理
    private static func syllableClose(_ a: String, _ b: String) -> Bool {
        if a == b { return true }
        let fa = fuzzyMandarin(a)
        let fb = fuzzyMandarin(b)
        if fa == fb { return true }
        return max(fa.count, fb.count) >= 3 && editDistance(Array(fa), Array(fb)) <= 1
    }

    private static func fuzzyMandarin(_ s: String) -> String {
        var r = s
        for (from, to) in [("zh", "z"), ("ch", "c"), ("sh", "s"), ("ang", "an"), ("eng", "en"), ("ing", "in")] {
            r = r.replacingOccurrences(of: from, with: to)
        }
        return r
    }

    private static func pinyinSyllables(_ text: String) -> [String] {
        let mutable = NSMutableString(string: text) as CFMutableString
        CFStringTransform(mutable, nil, kCFStringTransformToLatin, false)
        CFStringTransform(mutable, nil, kCFStringTransformStripDiacritics, false)
        return (mutable as String)
            .lowercased()
            .components(separatedBy: CharacterSet.letters.inverted)
            .filter { !$0.isEmpty }
    }

    // MARK: - 工具

    private static func normalize(_ text: String) -> String {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.union(.whitespaces).inverted)
            .joined(separator: " ")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func editDistance<T: Equatable>(_ a: [T], _ b: [T]) -> Int {
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var prev = Array(0...b.count)
        for (i, ca) in a.enumerated() {
            var curr = [i + 1] + Array(repeating: 0, count: b.count)
            for (j, cb) in b.enumerated() {
                curr[j + 1] = ca == cb ? prev[j] : min(prev[j], prev[j + 1], curr[j]) + 1
            }
            prev = curr
        }
        return prev[b.count]
    }
}
