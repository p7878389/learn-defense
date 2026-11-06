import Testing
@testable import LearnGame

@Suite("朗读分段")
struct SpeechTests {
    private func parts(_ text: String) -> [String] {
        Speech.segments(text).map { "\($0.english ? "en" : "zh"):\($0.text)" }
    }

    @Test func chineseStaysOneUtterance() {
        #expect(parts("先种下一个字灵，再答题打僵尸") == ["zh:先种下一个字灵，再答题打僵尸"])
        #expect(parts("晨，早晨的晨") == ["zh:晨，早晨的晨"])
    }

    @Test func accentedLatinStaysInOneRun() {
        #expect(parts("café 咖啡") == ["en:café ", "zh:咖啡"])
    }

    @Test func mixedTextSplitsByLanguage() {
        #expect(parts("apple，苹果") == ["en:apple，", "zh:苹果"])
        #expect(parts("Hello! I'm Miss Wu. What's your name?") == ["en:Hello! I'm Miss Wu. What's your name?"])
        #expect(parts("How old are you? 你几岁了？") == ["en:How old are you? ", "zh:你几岁了？"])
        #expect(parts("（共）十元") == ["zh:（共）十元"])
    }

    @Test func punctuationOnlyIsSkipped() {
        #expect(parts("？").isEmpty)
        #expect(parts("").isEmpty)
    }
}
