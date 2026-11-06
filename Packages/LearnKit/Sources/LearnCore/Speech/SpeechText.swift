import CryptoKit
import Foundation

/// 朗读文本：音频文件的命名规则、题库里要读的全部文本、游戏里固定的提示语。
///
/// 预先生成的语音（内置、题库自带、运行时缓存）都按「文本」找，不按题目 id 找：
/// 文件名是规范化文本的 SHA-256 前 32 位十六进制，加 .mp3。
/// 题库存在 JSON 还是数据库里、题目怎么编号，都不影响语音能否命中。
public enum SpeechText {
    public static let audioExtension = "mp3"

    /// 去掉首尾空白；空文本返回 nil
    public static func normalize(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// 音频文件名（不含扩展名）
    public static func key(for text: String) -> String {
        let normalized = normalize(text) ?? ""
        let digest = SHA256.hash(data: Data(normalized.utf8))
        return digest.prefix(16).map { String(format: "%02x", $0) }.joined()
    }

    public static func fileName(for text: String) -> String {
        "\(key(for: text)).\(audioExtension)"
    }

    /// 题库里出题时会朗读的全部文本（去重，保持出现顺序）
    public static func texts(in packs: [ContentPack]) -> [String] {
        var texts: [String] = []
        for pack in packs {
            for unit in pack.units {
                for lesson in unit.lessons {
                    let scope = "\(pack.id)/\(unit.id)/\(lesson.id)"
                    for item in ItemPool.lessonItems(lesson, scope: scope) {
                        texts += QuestionGenerator.speechTexts(for: item)
                    }
                }
            }
        }
        return unique(texts)
    }

    /// 游戏里固定的提示语，以及植物、道具的名字
    public static var gameLines: [String] {
        unique(Line.all
            + UnitCatalog.defenders.map { Line.planted($0.name) }
            + UnitCatalog.items.map(\.name))
    }

    /// 纯英文：有字母，且所有字母都是拉丁字母（含带重音的）。标点、数字不算
    public static func isEnglish(_ text: String) -> Bool {
        let letters = text.filter(\.isLetter)
        return !letters.isEmpty && letters.allSatisfy { ch in
            ch.unicodeScalars.first.map { $0.value < 0x0250 } ?? false
        }
    }

    /// 去掉空文本和重复（按规范化后的文本）
    public static func unique(_ texts: [String]) -> [String] {
        var seen: Set<String> = []
        return texts.compactMap(normalize).filter { seen.insert($0).inserted }
    }

    /// 游戏里固定朗读的句子。集中放在这里，预先生成语音时才能一并列出
    public enum Line {
        public static let plantFirst = "先种下一个字灵，再答题打僵尸"
        public static let battleStart = "准备完成，第一只僵尸来了！"
        public static let notEnoughSun = "阳光不够"
        public static let cellTaken = "这里已经有植物了，换个空格吧"
        public static let cellBlocked = "这里不能种，换个空的草坪位置"
        public static let won = "太棒了，书本守住了！"
        public static let lost = "没关系，再来一次吧！"
        public static let gateDown = "铁栅门挡住僵尸啦，慢慢答"
        public static let gateBusy = "铁栅门还在挡着呢"
        public static let gateNoTarget = "僵尸来了再放铁栅门"
        /// 设置页试听用
        public static let sample = "你好，我们一起来认字吧！晨，早晨的晨。apple，苹果。"
        public static let englishSample = "Hello! Let's learn the word apple together. A-P-P-L-E, apple."

        public static func planted(_ name: String) -> String { "\(name)种下了" }
        public static func bought(_ name: String) -> String { "买到\(name)啦，已经换上了！" }

        /// 预先生成的固定提示语（试听句不在内）
        static let all = [plantFirst, battleStart, notEnoughSun, cellTaken, cellBlocked, won, lost,
                          gateDown, gateBusy, gateNoTarget]
    }
}
