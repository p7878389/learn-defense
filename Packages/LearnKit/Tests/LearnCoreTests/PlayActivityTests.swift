import Foundation
import Testing
@testable import LearnCore

@Suite("首页游玩概况")
struct PlayActivityTests {
    var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return c
    }()

    /// 2026-11-06 的某个时刻（北京时间）
    func date(day: Int, hour: Int = 10) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))!
    }

    var now: Date { date(day: 6, hour: 20) }

    @Test func neverPlayed() {
        let a = PlayActivity(playedAt: [], now: now, calendar: calendar)
        #expect(a == .none)
        #expect(a.daysSinceLastPlay(now: now, calendar: calendar) == nil)
    }

    @Test func streakCountsUpToToday() {
        // 4、5、6 号都玩了，6 号玩了两局；2 号单独一天不连着
        let dates = [date(day: 6, hour: 9), date(day: 4), date(day: 6, hour: 19), date(day: 5, hour: 23), date(day: 2)]
        let a = PlayActivity(playedAt: dates, now: now, calendar: calendar)
        #expect(a.streakDays == 3)
        #expect(a.lastPlayedAt == date(day: 6, hour: 19))
        #expect(a.daysSinceLastPlay(now: now, calendar: calendar) == 0)
    }

    @Test func streakStillCountsWhenTodayNotPlayedYet() {
        let a = PlayActivity(playedAt: [date(day: 5), date(day: 4)], now: now, calendar: calendar)
        #expect(a.streakDays == 2)
        #expect(a.daysSinceLastPlay(now: now, calendar: calendar) == 1)
    }

    @Test func streakBreaksAfterMissingADay() {
        let a = PlayActivity(playedAt: [date(day: 4), date(day: 3)], now: now, calendar: calendar)
        #expect(a.streakDays == 0)
        #expect(a.daysSinceLastPlay(now: now, calendar: calendar) == 2)
    }

    @Test func futureDatesAreIgnored() {
        let a = PlayActivity(playedAt: [date(day: 9), date(day: 6, hour: 8)], now: now, calendar: calendar)
        #expect(a.lastPlayedAt == date(day: 6, hour: 8))
        #expect(a.streakDays == 1)
    }

    @Test func homeOrderPutsRecentFirstAndKeepsNeverPlayedOrder() {
        let a = Profile(name: "小虎", grade: .g3, avatar: "🐯")
        let b = Profile(name: "朵朵", grade: .k3, avatar: "🐰")
        let c = Profile(name: "圆圆", grade: .g1, avatar: "🐼")
        let d = Profile(name: "乐乐", grade: .g2, avatar: "🦊")
        let activity: [UUID: PlayActivity] = [
            c.id: PlayActivity(lastPlayedAt: date(day: 6), streakDays: 1),
            a.id: PlayActivity(lastPlayedAt: date(day: 3), streakDays: 0),
            d.id: .none,
        ]
        let ordered = PlayActivity.homeOrder([a, b, c, d], activity: activity)
        #expect(ordered.map(\.name) == ["圆圆", "小虎", "朵朵", "乐乐"])
    }

    @Test func databaseActivityIncludesQuitGames() throws {
        let db = try LearnDatabase(url: nil)
        let kid = UUID()
        let other = UUID()
        let summary = GameSummary(questions: 1, firstTryCorrect: 1, stars: 0, score: 0, enemiesDefeated: 0,
                                  bossesDefeated: 0, itemsUsed: 0, ultimatesCast: 0, seconds: 30)
        for (profile, start, outcome) in [(kid, date(day: 5), GameOutcome.won), (kid, date(day: 6), .quit),
                                          (other, date(day: 6, hour: 18), .won)] {
            GameRecorder(database: db, profileID: profile, grade: .g3, difficulty: .easy,
                         packIDs: ["p"], selection: .all, startedAt: start)
                .finish(outcome, summary: summary, at: start.addingTimeInterval(30))
        }
        let a = try db.playActivity(profileID: kid, now: now, calendar: calendar)
        #expect(a.lastPlayedAt == date(day: 6))
        #expect(a.streakDays == 2)
        #expect(try db.playActivity(profileID: UUID(), now: now, calendar: calendar) == .none)
    }
}
