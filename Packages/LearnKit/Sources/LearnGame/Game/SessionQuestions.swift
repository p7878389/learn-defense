import Foundation
import LearnCore

/// 每只怪物的一道题与其作答元数据同存同删，替换题目不会沿用上道题的错选和计时。
struct SessionQuestions {
    typealias QuestionEntry = (item: LearningItem, question: Question)

    private struct Entry {
        let content: QuestionEntry
        var wrongPicks: Set<Int> = []
        var shownAt: Date?
        var isRetry = false
    }

    private var entries: [Int: Entry] = [:]
    private var graceMark: (question: Question.ID, start: TimeInterval)?

    var ids: [Int] { entries.keys.sorted() }
    subscript(id: Int) -> QuestionEntry? { entries[id]?.content }

    mutating func insert(_ content: QuestionEntry, for id: Int, isRetry: Bool = false) {
        entries[id] = Entry(content: content, isRetry: isRetry)
    }

    func isRetry(for id: Int) -> Bool { entries[id]?.isRetry ?? false }

    mutating func remove(_ id: Int) {
        entries[id] = nil
    }

    mutating func removeAll() {
        entries.removeAll()
        graceMark = nil
    }

    func wrongPicks(for id: Int) -> Set<Int> { entries[id]?.wrongPicks ?? [] }
    func shownAt(for id: Int) -> Date? { entries[id]?.shownAt }

    mutating func markShown(_ id: Int, at date: Date = Date()) {
        guard entries[id]?.shownAt == nil else { return }
        entries[id]?.shownAt = date
    }

    @discardableResult
    mutating func markWrong(_ id: Int, pick: Int) -> Set<Int> {
        entries[id]?.wrongPicks.insert(pick)
        return wrongPicks(for: id)
    }

    mutating func isInGrace(_ id: Int, at clock: TimeInterval, seconds: TimeInterval) -> Bool {
        guard seconds > 0, let question = entries[id]?.content.question else { return false }
        if graceMark?.question != question.id { graceMark = (question.id, clock) }
        return clock - (graceMark?.start ?? clock) < seconds
    }
}
