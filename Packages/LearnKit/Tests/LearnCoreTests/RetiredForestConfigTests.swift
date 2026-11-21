import Foundation
import Testing
@testable import LearnCore

@Suite("退役森林试验配置")
struct RetiredForestConfigTests {
    @Test func configSyncRemovesTrialSettingsAndPreservesClassicData() throws {
        let database = try LearnDatabase(url: nil)
        let child = Profile(name: "小明", grade: .g3, avatar: "🐯")
        try database.saveProfiles([child])
        try database.saveSetting(["old": true], named: "forest.json")
        try database.saveSetting(["old": true], named: "forest-rules.json")
        var reader = ReaderPreferences()
        reader.volume = 0.2
        try database.saveSetting(reader, named: "reader-preferences")
        var rules = GameRules.defaults
        rules.initialRestSeconds = 20
        try database.saveGameRules(rules)

        try database.syncConfig(.bundled)
        try database.syncConfig(.bundled)

        #expect(try database.configFile(named: "forest.json") == nil)
        #expect(try database.configFile(named: "forest-rules.json") == nil)
        #expect(try database.configFile(named: "pacing.json") != nil)
        #expect(try database.profiles() == [child])
        #expect(try database.gameRules().initialRestSeconds == 20)
        let saved: ReaderPreferences = try database.setting(named: "reader-preferences", fallback: ReaderPreferences())
        #expect(saved.volume == 0.2)
    }
}
