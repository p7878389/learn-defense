import Foundation
import Testing
@testable import LearnCore

@Suite("对局记录与答题明细")
struct GameRecordTests {
    func question(_ kind: QuestionKind, key: String, prompt: String, options: [String], answer: Int) -> Question {
        Question(kind: kind, itemKey: key, instruction: "选一选", prompt: prompt,
                 options: options, optionStyle: .text, answerIndex: answer)
    }

    let start = Date(timeIntervalSince1970: 1_700_000_000)

    func summary(questions: Int, correct: Int) -> GameSummary {
        GameSummary(questions: questions, firstTryCorrect: correct, stars: 2, score: 120, enemiesDefeated: 5,
                    bossesDefeated: 1, itemsUsed: 1, ultimatesCast: 0, seconds: 95, xp: 40, coins: 12)
    }

    @Test func recorderWritesGameAndAnswersOnce() throws {
        let db = try LearnDatabase(url: nil)
        let kid = UUID()
        let recorder = GameRecorder(database: db, profileID: kid, grade: .g3, difficulty: .normal,
                                    packIDs: ["chinese-g3-sample"], selection: .units(["chinese-g3-sample/u2", "chinese-g3-sample/u1"]),
                                    startedAt: start)
        let chen = question(.charToPinyin, key: "char:晨", prompt: "晨", options: ["chén", "chéng", "shén"], answer: 0)
        let shuang = question(.pinyinToChar, key: "char:霜", prompt: "shuāng", options: ["霜", "双", "爽"], answer: 0)
        let poem = question(.poemNextLine, key: "poem:山行#0", prompt: "远上寒山石径斜", options: ["白云生处有人家", "停车坐爱枫林晚"], answer: 0)
        recorder.recordAnswer(chen, chosenIndex: 0, shownAt: start, at: start.addingTimeInterval(2.5))
        recorder.recordAnswer(shuang, chosenIndex: 1, shownAt: start.addingTimeInterval(3), at: start.addingTimeInterval(7))
        recorder.recordAnswer(poem, chosenIndex: nil, shownAt: nil, at: start.addingTimeInterval(20))

        recorder.finish(.won, summary: summary(questions: 2, correct: 1), at: start.addingTimeInterval(95))
        recorder.finish(.lost, summary: summary(questions: 9, correct: 9))  // 重复结束不生效
        recorder.recordAnswer(chen, chosenIndex: 0, shownAt: nil)          // 结束后不再记

        let games = try db.games(profileID: kid)
        #expect(games.count == 1)
        let game = try #require(games.first)
        #expect(game.id == recorder.id.uuidString)
        #expect(game.outcome == "won" && game.difficulty == "normal" && game.grade == "g3")
        #expect(game.selection == "units" && game.unitKeys == "chinese-g3-sample/u1,chinese-g3-sample/u2")
        #expect(game.questions == 2 && game.firstTryCorrect == 1 && game.accuracy == 0.5)
        #expect(game.xp == 40 && game.coins == 12 && game.seconds == 95)

        let answers = try db.answers(gameID: recorder.id)
        #expect(answers.map(\.itemKey) == ["char:晨", "char:霜", "poem:山行#0"])
        #expect(answers[0].correct && answers[0].chosen == "chén" && answers[0].responseMs == 2500)
        #expect(!answers[1].correct && answers[1].chosen == "双" && answers[1].answer == "霜" && answers[1].responseMs == 4000)
        #expect(answers[2].missed && answers[2].chosen == nil && answers[2].responseMs == nil)
    }

    @Test func statsAcrossGames() throws {
        let db = try LearnDatabase(url: nil)
        let kid = UUID()
        let shuang = question(.pinyinToChar, key: "char:霜", prompt: "shuāng", options: ["霜", "双", "爽"], answer: 0)
        let chen = question(.charToPinyin, key: "char:晨", prompt: "晨", options: ["chén", "chéng"], answer: 0)

        for day in 0..<3 {
            let begin = start.addingTimeInterval(Double(day) * 86_400)
            let r = GameRecorder(database: db, profileID: kid, grade: .g3, difficulty: .easy,
                                 packIDs: ["chinese-g3-sample"], selection: .all, startedAt: begin)
            r.recordAnswer(shuang, chosenIndex: 1, shownAt: begin, at: begin.addingTimeInterval(3))
            r.recordAnswer(chen, chosenIndex: 0, shownAt: begin, at: begin.addingTimeInterval(1))
            r.finish(day == 2 ? .quit : .won, summary: summary(questions: 2, correct: 1), at: begin.addingTimeInterval(60))
        }
        // 别的孩子的数据不应该算进来
        let other = GameRecorder(database: db, profileID: UUID(), grade: .g3, difficulty: .easy,
                                 packIDs: [], selection: .all, startedAt: start)
        other.recordAnswer(chen, chosenIndex: 1, shownAt: nil, at: start)
        other.finish(.lost, summary: summary(questions: 1, correct: 0))

        let games = try db.games(profileID: kid)
        #expect(games.count == 3)
        #expect(games.first?.outcome == "quit", "新的在前")
        #expect(try db.games(profileID: kid, since: start.addingTimeInterval(86_400)).count == 2)
        #expect(try db.games(profileID: kid, limit: 1).count == 1)

        let kinds = try db.kindAccuracy(profileID: kid)
        #expect(kinds.map(\.kind) == [.pinyinToChar, .charToPinyin], "正确率低的在前")
        #expect(kinds[0].answered == 3 && kinds[0].correct == 0 && kinds[0].averageMs == 3000)
        #expect(kinds[1].accuracy == 1)

        let confusions = try db.confusions(profileID: kid)
        #expect(confusions == [Confusion(itemKey: "char:霜", answer: "霜", chosen: "双", count: 3)])
        #expect(try db.answers(profileID: kid, itemKey: "char:晨").count == 3)
    }

    @Test func deletePersonalDataRemovesGames() throws {
        let db = try LearnDatabase(url: nil)
        let kid = UUID()
        let r = GameRecorder(database: db, profileID: kid, grade: .k2, difficulty: .easy,
                             packIDs: [], selection: .review(["pic:苹果"]), startedAt: start)
        r.recordAnswer(question(.listenPickPicture, key: "pic:苹果", prompt: "苹果", options: ["🍎", "🍌"], answer: 0),
                       chosenIndex: 0, shownAt: nil)
        r.finish(.won, summary: summary(questions: 1, correct: 1))
        #expect(try db.games(profileID: kid).first?.selection == "review")

        try db.deletePersonalData(profileID: kid)
        #expect(try db.games(profileID: kid).isEmpty)
        #expect(try db.answers(gameID: r.id).isEmpty)
    }

    @Test func withoutDatabaseKeepsInMemoryOnly() {
        let r = GameRecorder(database: nil, profileID: UUID(), grade: .g1, difficulty: .easy,
                             packIDs: [], selection: .all)
        r.recordAnswer(question(.choice, key: "choice:x", prompt: "?", options: ["a", "b"], answer: 1),
                       chosenIndex: 0, shownAt: nil)
        r.finish(.lost, summary: summary(questions: 1, correct: 0))
        #expect(r.answers.count == 1 && r.record?.outcome == .lost)
    }
}
