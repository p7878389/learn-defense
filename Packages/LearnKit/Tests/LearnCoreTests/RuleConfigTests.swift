import Foundation
import Testing
@testable import LearnCore

@Suite("运行规则数据库配置")
struct RuleConfigTests {
    @Test func storedRulesSurviveConfigSyncAndReopen() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("rules-\(UUID())")
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("learn.store")
        do {
            let db = try LearnDatabase(url: url)
            var rules = try db.gameRules()
            rules.initialRestRounds = 2
            rules.restIncrementSeconds = 7
            rules.coinLimits["answers"] = 4
            try db.saveGameRules(rules)
            try db.syncConfig(.bundled)
        }
        let db = try LearnDatabase(url: url)
        let rules = try db.gameRules()
        #expect(rules.restSeconds(afterRound: 1) == 10)
        #expect(rules.restSeconds(afterRound: 3) == 17)
        var state = GrowthState()
        let report = GameReport(won: false, difficulty: .easy, questions: 10, firstTryCorrect: 10, stars: 0)
        #expect(state.settle(report, catalog: .bundled, rules: rules).coins == 4)
        #expect(state.settle(report, catalog: .bundled, rules: rules).coins == 0)
    }

    @Test func wrongItemsAreScheduledAlongsideFreshOnes() throws {
        let wrong = LearningItem.character(CharacterItem(char: "错", pinyin: "cuò"))
        let fresh = (0..<8).map { LearningItem.character(CharacterItem(char: "新\($0)", pinyin: "xīn")) }
        var stats = ItemStats()
        stats.wrong = 1
        var scheduler = ItemScheduler()
        var rng = SystemRandomNumberGenerator()
        for i in 1...9 {
            let item = try #require(scheduler.next(from: fresh + [wrong], stats: [wrong.key: stats], using: &rng))
            #expect((item.key == wrong.key) == (i % 3 == 0))
        }
    }
    @Test func newItemGraceCanBeTurnedOffButNotSetOutOfRange() throws {
        func decode(_ json: String) throws -> GameRules {
            try JSONDecoder().decode(GameRules.self, from: Data(json.utf8)).validated()
        }
        #expect(try decode(#"{"newItemGraceSeconds":0}"#).newItemGraceSeconds == 0)
        #expect(try decode(#"{"newItemGraceSeconds":20}"#).newItemGraceSeconds == 20)
        #expect(try decode(#"{"newItemGraceSeconds":-1}"#).newItemGraceSeconds == 8)
        #expect(try decode(#"{"newItemGraceSeconds":600}"#).newItemGraceSeconds == 8)
    }

    @Test func partialAndInvalidConfigFallsBackPerField() throws {
        let rules = try JSONDecoder().decode(GameRules.self,
            from: Data(#"{"initialRestRounds":0,"reviewEvery":0,"coinLimits":{"answers":0,"badge":-3}}"#.utf8)).validated()
        #expect(rules.restSeconds(afterRound: 1) == 10)
        #expect(rules.restSeconds(afterRound: 4) == 15)
        #expect(rules.restSeconds(afterRound: 100) == 90)
        #expect(rules.reviewEvery == 3)
        #expect(rules.newItemGraceSeconds == 8, "旧配置里没有这一项时用默认值")
        #expect(rules.coinLimit(.answers) == 0)
        #expect(rules.coinLimit(.badge) == 100)
    }

}
