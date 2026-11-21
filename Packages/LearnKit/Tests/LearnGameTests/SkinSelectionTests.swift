import Foundation
import LearnCore
import Testing
@testable import LearnGame

@Suite("已装备皮肤进入游戏")
@MainActor
struct SkinSelectionTests {
    private func model(database: LearnDatabase) -> AppModel {
        AppModel(database: database, library: ContentLibrary.load(userDirectory: nil),
                 speechLibrary: SpeechLibrary(database: database, settings: nil, premadeDirectories: []))
    }

    @Test func selectingSkinReplacesSameShooterAndReachesNextGame() throws {
        let database = try LearnDatabase(url: nil)
        let profile = Profile(name: "皮肤测试", grade: .g3, avatar: "🐯")
        try database.saveProfiles([profile])
        let model = model(database: database)
        let book = try #require(model.growthCatalog.cosmetic(id: "defender.spellbook"))
        let mecha = try #require(model.growthCatalog.cosmetic(id: "defender.mecha"))
        let bullet = try #require(model.growthCatalog.cosmetic(id: "projectile.iceCrystal"))
        model.equip(bullet, for: profile.id)
        model.equip(book, for: profile.id)
        #expect(model.growth(for: profile.id).loadout.defenderSkins == ["inkling": .spellbook])
        model.equip(mecha, for: profile.id)
        #expect(!model.growth(for: profile.id).state.isEquipped(book))
        #expect(model.growth(for: profile.id).state.isEquipped(mecha))
        #expect(model.growth(for: profile.id).state.isEquipped(bullet))

        // 重读同一数据库后，新对局及种下的角色都用最后装备的皮肤。
        let reloaded = self.model(database: database)
        let pack = try #require(reloaded.library.packs.first { $0.grade == .g3 })
        let session = GameSession(config: GameConfig(profileID: profile.id, grade: .g3, packIDs: [pack.id],
                                                     selection: .all, difficulty: .normal),
                                  library: reloaded.library, progress: reloaded.progress(for: profile.id),
                                  speech: reloaded.speech, growth: reloaded.growth(for: profile.id))
        defer { session.end() }
        #expect(session.loadout.defenderSkins == ["inkling": .mecha])
        let inklingCards = session.tuning.plantable.filter { $0.id == "inkling" }
        #expect(inklingCards.count == 1)
        #expect(session.scene.plant(.inkling, in: DefenderCell(lane: 0, column: 0)))
        let defender = try #require(session.scene.children.compactMap { $0 as? DefenderNode }.first)
        let artwork = try #require(defender.childNode(withName: "themeSkin"))
        let shell = try #require(artwork.childNode(withName: "//shell"))
        #expect(shell.userData?["texture"] as? String == "MechaShell")
        #expect(defender.childNode(withName: "spellbookSkin") == nil)
        #expect(defender.childNode(withName: "unitSprite") == nil)
    }

    @Test func selectingOriginalResetsOnlyThatShooter() throws {
        let database = try LearnDatabase(url: nil)
        let model = model(database: database)
        let profileID = UUID()
        let mecha = try #require(model.growthCatalog.cosmetic(id: "defender.mecha"))
        let original = try #require(model.growthCatalog.cosmetic(id: "defender.original"))
        let bullet = try #require(model.growthCatalog.cosmetic(id: "projectile.iceCrystal"))
        model.equip(bullet, for: profileID)
        model.equip(mecha, for: profileID)
        #expect(model.growth(for: profileID).loadout.defenderSkins == ["inkling": .mecha])
        model.equip(original, for: profileID)
        #expect(model.growth(for: profileID).loadout.defenderSkins.isEmpty)
        #expect(model.growth(for: profileID).state.isEquipped(bullet))
    }

}
