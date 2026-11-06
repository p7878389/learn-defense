import Foundation
import LearnCore
import SwiftUI
import Testing
#if os(macOS)
import AppKit
#endif
@testable import LearnGame

@Suite("家长设置集成")
@MainActor
struct ParentSettingsUITests {
    private func model() throws -> AppModel {
        let db = try LearnDatabase(url: nil)
        let profile = Profile(name: "小明", grade: .g3, avatar: "🐯")
        try db.saveProfiles([profile])
        return AppModel(database: db, library: ContentLibrary.load(userDirectory: nil),
                        speechLibrary: SpeechLibrary(database: db, settings: nil, premadeDirectories: []))
    }

    @Test func savedRulesAndReaderPreferencesReachLiveConsumers() throws {
        let model = try model()
        var rules = model.gameRules
        rules.initialRestSeconds = 15
        try model.updateRules(rules)
        #expect(model.growth(for: model.profiles[0].id).rules.restSeconds(afterRound: 1) == 15)
        var reader = model.readerPreferences
        reader.source = .system
        reader.effectsVolume = 0
        try model.updateReader(reader)
        #expect(model.speech.effectsVolume == 0)
        #expect(!model.speechLibrary.canGenerate)
        let saved: ReaderPreferences = try model.database!.setting(named: "reader-preferences", fallback: ReaderPreferences())
        #expect(saved.source == .system)
    }

    @Test func resettingLearningClearsCachedStoreWithoutRemovingGrowth() throws {
        let model = try model()
        let child = model.profiles[0]
        let item = LearningItem.character(CharacterItem(char: "晨", pinyin: "chén"))
        model.progress(for: child.id).record(item, correct: false)
        model.progress(for: child.id).save()
        try model.resetLearning(child)
        #expect(model.progress(for: child.id).stats.isEmpty)
        #expect(model.profiles == [child])
    }

    @Test func renderSettingsPanes() throws {
        #if os(macOS)
        let model = try model()
        let directory = URL(fileURLWithPath: "/tmp/learn-defense-settings-preview")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for section in ParentSection.allCases {
            let content = ParentSettingsContent(section: section, onClose: {})
                .environmentObject(model).frame(width: 1194, height: 834)
            let host = NSHostingView(rootView: content)
            let window = NSWindow(contentRect: CGRect(x: -5000, y: -5000, width: 1194, height: 834),
                                  styleMask: .borderless, backing: .buffered, defer: false)
            window.contentView = host
            host.frame = CGRect(x: 0, y: 0, width: 1194, height: 834)
            host.layoutSubtreeIfNeeded()
            window.displayIfNeeded()
            let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            try #require(bitmap.representation(using: .png, properties: [:]))
                .write(to: directory.appendingPathComponent(section.id + ".png"))
            window.orderOut(nil)
        }
        #endif
    }
}
