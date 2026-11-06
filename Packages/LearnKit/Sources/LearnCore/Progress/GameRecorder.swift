import Foundation

public enum GameOutcome: String, Codable, Sendable {
    case won, lost
    /// 开始闯关后中途退出
    case quit
}

/// 一道题的第一次作答
public struct AnswerRecord: Codable, Sendable, Equatable {
    public var itemKey: String
    public var kind: QuestionKind
    public var prompt: String
    public var answer: String
    public var chosen: String?
    public var correct: Bool
    public var missed: Bool
    public var ultimate: Bool
    public var responseMs: Int?
    public var answeredAt: Date

    public init(question: Question, chosenIndex: Int?, ultimate: Bool, shownAt: Date?, answeredAt: Date) {
        itemKey = question.itemKey
        kind = question.kind
        prompt = question.prompt
        answer = question.answer
        chosen = chosenIndex.flatMap { question.options.indices.contains($0) ? question.options[$0] : nil }
        correct = chosenIndex == question.answerIndex
        missed = chosenIndex == nil
        self.ultimate = ultimate
        responseMs = shownAt.map { max(0, Int(answeredAt.timeIntervalSince($0) * 1000)) }
        self.answeredAt = answeredAt
    }

    /// 输入题：记下孩子写的内容
    public init(question: Question, typed: String, correct: Bool, ultimate: Bool, shownAt: Date?, answeredAt: Date) {
        self.init(question: question, chosenIndex: nil, ultimate: ultimate, shownAt: shownAt, answeredAt: answeredAt)
        chosen = typed
        self.correct = correct
        missed = false
    }
}

/// 一局结束时的统计
public struct GameSummary: Sendable, Equatable {
    public var questions: Int
    public var firstTryCorrect: Int
    public var stars: Int
    public var score: Int
    public var enemiesDefeated: Int
    public var bossesDefeated: Int
    public var itemsUsed: Int
    public var ultimatesCast: Int
    public var seconds: Int
    public var xp: Int?
    public var coins: Int?

    public init(questions: Int, firstTryCorrect: Int, stars: Int, score: Int, enemiesDefeated: Int,
                bossesDefeated: Int, itemsUsed: Int, ultimatesCast: Int, seconds: Int,
                xp: Int? = nil, coins: Int? = nil) {
        self.questions = questions
        self.firstTryCorrect = firstTryCorrect
        self.stars = stars
        self.score = score
        self.enemiesDefeated = enemiesDefeated
        self.bossesDefeated = bossesDefeated
        self.itemsUsed = itemsUsed
        self.ultimatesCast = ultimatesCast
        self.seconds = seconds
        self.xp = xp
        self.coins = coins
    }
}

/// 写进数据库的一局
public struct GameRecord: Codable, Sendable, Equatable {
    public var id: UUID
    public var profileID: UUID
    public var outcome: GameOutcome
    public var startedAt: Date
    public var endedAt: Date
    public var grade: Grade
    public var difficulty: Difficulty
    public var packIDs: [String]
    /// all / units / review
    public var selection: String
    public var unitKeys: [String]
    public var questions: Int
    public var firstTryCorrect: Int
    public var stars: Int
    public var score: Int
    public var enemiesDefeated: Int
    public var bossesDefeated: Int
    public var itemsUsed: Int
    public var ultimatesCast: Int
    public var seconds: Int
    public var xp: Int?
    public var coins: Int?
}

/// 记录一局的作答明细，结束时连同对局统计一起写进数据库（只写一次）。
/// database 为 nil 时只在内存里记录（测试用，或数据库打不开时）
public final class GameRecorder {
    public let id = UUID()
    public let profileID: UUID
    public private(set) var answers: [AnswerRecord] = []
    /// 已经结束的对局；nil 表示还没结束
    public private(set) var record: GameRecord?
    private let database: LearnDatabase?
    private let grade: Grade
    private let difficulty: Difficulty
    private let packIDs: [String]
    private let selection: ItemPool.Selection
    private let startedAt: Date

    public init(database: LearnDatabase?, profileID: UUID, grade: Grade, difficulty: Difficulty,
                packIDs: [String], selection: ItemPool.Selection, startedAt: Date = Date()) {
        self.database = database
        self.profileID = profileID
        self.grade = grade
        self.difficulty = difficulty
        self.packIDs = packIDs
        self.selection = selection
        self.startedAt = startedAt
    }

    /// 记一道题的第一次作答；chosenIndex 为 nil 表示没来得及答
    public func recordAnswer(_ question: Question, chosenIndex: Int?, ultimate: Bool = false,
                             shownAt: Date?, at date: Date = Date()) {
        guard record == nil else { return }
        answers.append(AnswerRecord(question: question, chosenIndex: chosenIndex, ultimate: ultimate,
                                    shownAt: shownAt, answeredAt: date))
    }

    public func recordAnswer(_ question: Question, typed: String, correct: Bool, ultimate: Bool = false,
                             shownAt: Date?, at date: Date = Date()) {
        guard record == nil else { return }
        answers.append(AnswerRecord(question: question, typed: typed, correct: correct, ultimate: ultimate,
                                    shownAt: shownAt, answeredAt: date))
    }

    /// 结束对局并写库。重复调用只有第一次生效
    public func finish(_ outcome: GameOutcome, summary: GameSummary, at date: Date = Date()) {
        guard record == nil else { return }
        let selectionName: String
        var unitKeys: [String] = []
        switch selection {
        case .all: selectionName = "all"
        case .units(let keys):
            selectionName = "units"
            unitKeys = keys.sorted()
        case .review: selectionName = "review"
        }
        let record = GameRecord(
            id: id, profileID: profileID, outcome: outcome, startedAt: startedAt, endedAt: date,
            grade: grade, difficulty: difficulty, packIDs: packIDs, selection: selectionName, unitKeys: unitKeys,
            questions: summary.questions, firstTryCorrect: summary.firstTryCorrect, stars: summary.stars,
            score: summary.score, enemiesDefeated: summary.enemiesDefeated, bossesDefeated: summary.bossesDefeated,
            itemsUsed: summary.itemsUsed, ultimatesCast: summary.ultimatesCast, seconds: summary.seconds,
            xp: summary.xp, coins: summary.coins)
        self.record = record
        do {
            try database?.saveGame(record, answers: answers)
        } catch {
            print("保存对局记录失败：\(error)")
        }
    }
}
