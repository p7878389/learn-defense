import Foundation
import SwiftData

/// 一局对局（通关、失败或中途退出）
@Model
public final class StoredGame {
    /// GameRecord.id.uuidString
    @Attribute(.unique) public var id: String
    /// Profile.id.uuidString
    public var profileID: String
    /// GameOutcome.rawValue：won / lost / quit
    public var outcome: String
    public var startedAt: Date
    public var endedAt: Date
    /// Grade.rawValue
    public var grade: String
    /// Difficulty.rawValue
    public var difficulty: String
    /// 本局题库 id，逗号分隔
    public var packIDs: String
    /// all / units / review
    public var selection: String
    /// selection 为 units 时选的 "题库id/单元id"，逗号分隔
    public var unitKeys: String
    public var questions: Int
    public var firstTryCorrect: Int
    public var stars: Int
    public var score: Int
    public var enemiesDefeated: Int
    public var bossesDefeated: Int
    public var itemsUsed: Int
    public var ultimatesCast: Int
    /// 从开始闯关到结束的秒数（含暂停）
    public var seconds: Int
    /// 本局得到的经验、积分（含升级和徽章奖励）；中途退出或没有成长档案时为 nil
    public var xp: Int?
    public var coins: Int?

    public init(record: GameRecord) {
        id = record.id.uuidString
        profileID = record.profileID.uuidString
        outcome = record.outcome.rawValue
        startedAt = record.startedAt
        endedAt = record.endedAt
        grade = record.grade.rawValue
        difficulty = record.difficulty.rawValue
        packIDs = record.packIDs.joined(separator: ",")
        selection = record.selection
        unitKeys = record.unitKeys.joined(separator: ",")
        questions = record.questions
        firstTryCorrect = record.firstTryCorrect
        stars = record.stars
        score = record.score
        enemiesDefeated = record.enemiesDefeated
        bossesDefeated = record.bossesDefeated
        itemsUsed = record.itemsUsed
        ultimatesCast = record.ultimatesCast
        seconds = record.seconds
        xp = record.xp
        coins = record.coins
    }

    /// 首答正确率
    public var accuracy: Double { questions == 0 ? 0 : Double(firstTryCorrect) / Double(questions) }
}

/// 一道题的作答（只记第一次作答；没来得及答的记为 missed）
@Model
public final class StoredAnswer {
    /// "对局id#序号"
    @Attribute(.unique) public var uid: String
    public var gameID: String
    public var profileID: String
    /// 本局第几道（从 0 开始）
    public var index: Int
    /// LearningItem.key
    public var itemKey: String
    /// QuestionKind.rawValue
    public var kind: String
    public var prompt: String
    public var answer: String
    /// 第一次选的选项；missed 时为 nil
    public var chosen: String?
    public var correct: Bool
    /// 没来得及答，僵尸就走到了书架
    public var missed: Bool
    /// 大招题
    public var ultimate: Bool
    /// 从题目出现到第一次作答的毫秒数（含暂停）；不知道出现时间时为 nil
    public var responseMs: Int?
    public var answeredAt: Date

    public init(answer a: AnswerRecord, gameID: String, profileID: String, index: Int) {
        uid = "\(gameID)#\(index)"
        self.gameID = gameID
        self.profileID = profileID
        self.index = index
        itemKey = a.itemKey
        kind = a.kind.rawValue
        prompt = a.prompt
        answer = a.answer
        chosen = a.chosen
        correct = a.correct
        missed = a.missed
        ultimate = a.ultimate
        responseMs = a.responseMs
        answeredAt = a.answeredAt
    }
}
