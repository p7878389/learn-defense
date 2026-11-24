import Foundation
import LearnCore
import Testing
@testable import LearnGame

@MainActor
@Suite("答错换题防排除")
struct WrongAnswerRetryTests {
    private func session(single: Bool = false, review: Bool = false) throws -> (GameSession, GameRecorder) {
        let db = try LearnDatabase(url: nil)
        let profile = Profile(name: "重试", grade: .k3, avatar: "🐯")
        try db.saveProfiles([profile])
        let choices = [ChoiceItem(id: "a", prompt: "一加一", options: ["二", "三", "四"], answer: "二"),
                       ChoiceItem(id: "b", prompt: "二加三", options: ["三", "四", "五"], answer: "五")]
        let pack = ContentPack(id: "retry", title: "重试题库", subject: .chinese, grade: .k3,
            units: [ContentUnit(id: "u", title: "单元", lessons: [Lesson(id: "l", title: "课", questions: single ? [choices[0]] : choices)])])
        let selection: ItemPool.Selection = review ? .review(["choice:retry/u/l:a"]) : .all
        let config = GameConfig(profileID: profile.id, grade: .k3, packIDs: [pack.id], selection: selection, difficulty: .easy)
        let recorder = GameRecorder(database: db, profileID: profile.id, grade: .k3, difficulty: .easy,
                                    packIDs: [pack.id], selection: selection)
        let s = GameSession(config: config, library: ContentLibrary(packs: [pack]), progress: ProgressStore(),
                            speech: Speech(), recorder: recorder)
        _ = s.scene.plant(.inkling, in: DefenderCell(lane: 0, column: 0))
        s.startBattle()
        return (s, recorder)
    }

    private func spawn(_ s: GameSession) throws -> Question {
        let enemy = try #require(s.nextEnemy())
        s.scene.spawn(enemy, lane: 0)
        s.selectQuestion(enemy.id)
        return try #require(s.current)
    }

    @Test func wrongAnswerChangesTheAnswerWithoutGrantingFreshAttackRewards() throws {
        let (s, recorder) = try session()
        defer { s.end() }
        let old = try spawn(s)
        let target = s.selectedQuestionID
        s.answer((old.answerIndex + 1) % old.options.count)
        let next = try #require(s.current)
        #expect(next.id != old.id && next.itemKey != old.itemKey && next.answer != old.answer)
        #expect(s.selectedQuestionID == target && s.wrongPicks.isEmpty)
        #expect(!s.holdsTarget && !s.typing, "换题不能反复获得新题停怪时间")
        #expect(s.progress.stats[old.itemKey]?.wrong == 1)
        #expect(s.score == 0 && s.energy == 0 && s.attempted == 1)
        s.answer(next.answerIndex)
        #expect(s.score == 2 && s.energy == 0, "同一次攻击重试只能拿 2 分，不充能")
        #expect(s.attempted == 2 && s.firstTryCorrect == 1)
        #expect(s.progress.stats[next.itemKey]?.correct == 1)
        #expect(recorder.answers.map(\.correct) == [false, true])
        #expect(recorder.answers.map(\.itemKey) == [old.itemKey, next.itemKey])
    }

    @Test(arguments: [false, true])
    func smallPoolsReorderAllOptionsAndStayWithinReviewSelection(review: Bool) throws {
        let (s, _) = try session(single: !review, review: review)
        defer { s.end() }
        var old = try spawn(s)
        for _ in 0..<4 {
            s.answer((old.answerIndex + 1) % old.options.count)
            let next = try #require(s.current)
            #expect(next.id != old.id && next.itemKey == old.itemKey)
            #expect(next.options != old.options && Set(next.options) == Set(old.options))
            #expect(next.answer == old.answer && s.wrongPicks.isEmpty)
            old = next
        }
        #expect(s.attempted == 4 && s.mistakes.count == 4)
    }

    @Test func ultimateRetryChangesTheAnswerButStillCannotCast() throws {
        let (s, recorder) = try session()
        defer { s.end() }
        s.energy = s.tuning.ultimateEnergy
        s.startUltimate()
        let old = try #require(s.ultimate)
        s.answerUltimate((old.answerIndex + 1) % old.options.count)
        let next = try #require(s.ultimate)
        #expect(next.id != old.id && next.answer != old.answer)
        #expect(s.ultimateWrongPicks.isEmpty)
        s.answerUltimate(next.answerIndex)
        #expect(s.ultimate == nil && s.energy == 0 && s.ultimatesCast == 0 && s.score == 0)
        #expect(s.attempted == 2 && s.firstTryCorrect == 1)
        #expect(recorder.answers.map(\.correct) == [false, true])
    }

    @Test func delayedCallbacksFromOldChoiceAndUltimateAreIgnored() throws {
        let (s, recorder) = try session()
        defer { s.end() }
        let old = try spawn(s)
        s.answer((old.answerIndex + 1) % old.options.count, questionID: old.id)
        let next = try #require(s.current)
        s.answer(next.answerIndex, questionID: old.id)
        #expect(s.attempted == 1 && s.score == 0 && s.current?.id == next.id)
        s.energy = s.tuning.ultimateEnergy
        s.startUltimate()
        let original = try #require(s.ultimate)
        s.answerUltimate((original.answerIndex + 1) % original.options.count, questionID: original.id)
        let retry = try #require(s.ultimate)
        s.answerUltimate(retry.answerIndex, questionID: original.id)
        #expect(s.attempted == 2 && s.ultimate?.id == retry.id && recorder.answers.count == 2)
        s.cancelUltimate()
        #expect(s.energy == 0)
    }

    @Test func retryInputResetsTypingAndRejectsAnOldSubmission() throws {
        let (s, old, spec) = try InputAnswerTests().typedQuestion()
        defer { s.end() }
        s.setTyping(true)
        s.answerInput(spec.blanks.map { _ in "zzz" }, questionID: old.id)
        let next = try #require(s.current)
        #expect(next.id != old.id && next.answer != old.answer)
        #expect(!s.typing && s.wrongPicks.isEmpty && s.retrying)
        s.answerInput(next.input?.blanks.map(\.answer) ?? [], questionID: old.id)
        #expect(s.attempted == 1 && s.current?.id == next.id && s.score == 0)
        if let input = next.input { s.answerInput(input.blanks.map(\.answer), questionID: next.id) }
        else { s.answer(next.answerIndex, questionID: next.id) }
        #expect(s.attempted == 2 && s.score == 2 && s.energy == 0)
    }

    @Test func fallbackShufflesEachTileGroupWithoutLosingRepeatedLetters() throws {
        let spec = InputSpec(style: .letters, blanks: [InputBlank(answer: "a"), InputBlank(answer: "a")],
                             groups: [TileGroup(tiles: ["a", "a", "b"])], hint: "不要显示答案", isMulti: false)
        let q = Question(kind: .listenPickEnglish, itemKey: "test", instruction: "拼字", prompt: "🔊",
                         options: [spec.answerText], optionStyle: .text, answerIndex: 0, input: spec)
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<20 {
            let retry = q.shuffledForRetry(comparedTo: q, using: &rng)
            let next = try #require(retry.input)
            #expect(retry.id != q.id && retry.answer == q.answer)
            #expect(next.groups[0].tiles != spec.groups[0].tiles)
            #expect(next.groups[0].tiles.sorted() == ["a", "a", "b"])
            #expect(next.accepts(["a", "a"]))
        }
    }
}
