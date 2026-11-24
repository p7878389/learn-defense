import Foundation
import LearnCore
import Testing
@testable import LearnGame

@MainActor
@Suite("幼儿园题阶对局接入")
struct PreschoolSessionTests {
    private func session(difficulty: Difficulty = .easy, review: Bool = false) -> GameSession {
        let pack = ContentPack(id: "ladder", title: "题阶测试", subject: .chinese, grade: .k3,
            units: [ContentUnit(id: "u", title: "单元", lessons: [Lesson(id: "l", title: "课文", characters: [
                CharacterItem(char: "水", pinyin: "shuǐ", words: ["河水"], imageHint: "像中间流淌的河流。"),
                CharacterItem(char: "木", pinyin: "mù", words: ["木头"], imageHint: "像长着枝丫的大树。"),
                CharacterItem(char: "人", pinyin: "rén", words: ["大人"], imageHint: "像张开的两条腿。"),
            ])])])
        let keys: Set<String> = ["char:水", "char:木", "char:人"]
        let config = GameConfig(profileID: UUID(), grade: .k3, packIDs: [pack.id],
                                selection: review ? .review(keys) : .all, difficulty: difficulty)
        return GameSession(config: config, library: ContentLibrary(packs: [pack]), progress: ProgressStore(), speech: Speech())
    }

    @Test func ordinaryQuestionsUseCurrentProgressAndResetAfterWrongAnswer() throws {
        let session = session()
        defer { session.end() }
        for item in session.generator.pool.items { session.progress.record(item, correct: true) }
        let first = try #require(session.makeQuestion())
        #expect(first.question.kind == .listenFillChar)
        for item in session.generator.pool.items { session.progress.record(item, correct: false) }
        let reset = try #require(session.makeQuestion())
        #expect(reset.question.kind == .listenPickChar && reset.question.input == nil)
    }

    @Test func reviewAndUltimateKeepLegacyQuestions() throws {
        let review = session(review: true)
        defer { review.end() }
        for item in review.generator.pool.items { review.progress.record(item, correct: true) }
        #expect(try #require(review.makeQuestion()).question.kind == .listenPickChar)
        let normal = session(difficulty: .hard)
        defer { normal.end() }
        var rng = SystemRandomNumberGenerator()
        let ultimate = try #require(normal.generator.makeUltimateQuestion(using: &rng))
        #expect(ultimate.1.kind == .listenPickChar && ultimate.1.input == nil)
    }

    @Test func layoutSampleReservesTheLargestAllowedInput() throws {
        for difficulty in Difficulty.allCases {
            let session = session(difficulty: difficulty)
            defer { session.end() }
            let sample = try #require(session.layoutSample)
            #expect((sample.input != nil) == (difficulty != .easy))
            #expect((sample.input?.isMulti == true) == (difficulty == .hard))
        }
    }
}
