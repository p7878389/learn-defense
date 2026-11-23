import Foundation
import LearnCore
import Testing
@testable import LearnGame

@Suite("对局题目状态")
struct SessionQuestionsTests {
    private func entry(_ prompt: String = "山") -> (item: LearningItem, question: Question) {
        let choice = ChoiceItem(id: prompt, prompt: "选\(prompt)", options: [prompt, "水"], answer: prompt)
        let item = LearningItem.choice(choice, scope: "state-tests")
        return (item, Question(kind: .choice, itemKey: item.key, instruction: "选字", prompt: choice.prompt,
                              options: choice.options, optionStyle: .text, answerIndex: 0))
    }

    @Test func replacingQuestionClearsItsPreviousAnswerMetadata() {
        var questions = SessionQuestions()
        let old = entry(), new = entry("林")
        questions.insert(old, for: 2)
        questions.markShown(2, at: Date(timeIntervalSince1970: 10))
        let firstWrongPick = questions.markWrong(2, pick: 1)
        #expect(firstWrongPick == [1])
        questions.insert(new, for: 2)
        #expect(questions[2]?.question.id == new.question.id)
        #expect(questions.wrongPicks(for: 2).isEmpty)
        #expect(questions.shownAt(for: 2) == nil)
    }

    @Test func firstPresentationAndRepeatedWrongPickAreStable() {
        var questions = SessionQuestions()
        questions.insert(entry(), for: 7)
        questions.markShown(7, at: Date(timeIntervalSince1970: 20))
        questions.markShown(7, at: Date(timeIntervalSince1970: 40))
        #expect(questions.shownAt(for: 7) == Date(timeIntervalSince1970: 20))
        let firstWrongPick = questions.markWrong(7, pick: 1)
        #expect(firstWrongPick == [1])
        let repeatedWrongPick = questions.markWrong(7, pick: 1)
        #expect(repeatedWrongPick == [1])
        questions.remove(7)
        #expect(questions[7] == nil && questions.shownAt(for: 7) == nil)
        #expect(questions.wrongPicks(for: 7).isEmpty)
        let lateWrongPick = questions.markWrong(7, pick: 1)
        #expect(lateWrongPick.isEmpty, "迟到作答不能重新创建已移除的题")
    }

    @Test func roundResetClearsEntriesAndGraceUsesTheBattleClock() {
        var questions = SessionQuestions()
        questions.insert(entry(), for: 9)
        questions.insert(entry("林"), for: 3)
        #expect(questions.ids == [3, 9])
        let initialGrace = questions.isInGrace(9, at: 10, seconds: 8)
        #expect(initialGrace)
        let beforeExpiry = questions.isInGrace(9, at: 17.9, seconds: 8)
        #expect(beforeExpiry)
        let atExpiry = questions.isInGrace(9, at: 18, seconds: 8)
        #expect(!atExpiry)
        questions.insert(entry("田"), for: 9)
        let replacementGrace = questions.isInGrace(9, at: 30, seconds: 8)
        #expect(replacementGrace, "同一怪物换题应重新计算缓冲时间")
        questions.removeAll()
        #expect(questions.ids.isEmpty && questions[9] == nil)
        let afterReset = questions.isInGrace(9, at: 30, seconds: 8)
        #expect(!afterReset)
    }
}
