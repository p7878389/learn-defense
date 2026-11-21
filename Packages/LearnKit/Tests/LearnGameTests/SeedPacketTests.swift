import LearnCore
import Testing
@testable import LearnGame

@Suite("植物卡牌只展示已装备皮肤")
@MainActor
struct SeedPacketTests {
    @Test func equippedSkinReplacesOriginalCardAndDuplicates() throws {
        let strip = SeedPacketStrip(kinds: [.inkling, .frost, .inkling, .wallnut], sun: 300,
                                    enabled: true, draggingID: nil, skins: ["inkling": .mecha],
                                    onDragChanged: { _, _ in }, onDragEnded: { _, _ in })
        #expect(strip.packets.map(\.id) == ["inkling", "frost", "wallnut"])
        let shooter = try #require(strip.packets.first)
        #expect(shooter.name == "雷霆小机甲")
        #expect(shooter.skin == .mecha)
        #expect(shooter.kind == .inkling)
        #expect(shooter.kind.sunCost == DefenderKind.inkling.sunCost)
        #expect(strip.packets[1].skin == nil)
        #expect(strip.packets[1].name == DefenderKind.frost.name)
    }

    @Test func cardNameAndPortraitFollowOnlyEquippedSkin() throws {
        let growth = GrowthStore(catalog: .bundled)
        let book = try #require(growth.catalog.cosmetic(id: "defender.spellbook"))
        let teapot = try #require(growth.catalog.cosmetic(id: "defender.teapot"))
        #expect(growth.equip(book))
        func strip() -> SeedPacketStrip {
            SeedPacketStrip(kinds: [.inkling], sun: 300, enabled: true, draggingID: nil,
                            skins: growth.loadout.defenderSkins,
                            onDragChanged: { _, _ in }, onDragEnded: { _, _ in })
        }
        #expect(strip().packets.map(\.name) == ["星轨魔导书"])
        // 收藏馆里存在其他可用皮肤，不会在战斗栏额外生成卡牌。
        #expect(!growth.state.isEquipped(teapot))
        #expect(strip().packets.count == 1)
        #expect(growth.equip(teapot))
        let packet = try #require(strip().packets.first)
        #expect(packet.name == "云游茶壶")
        #expect(packet.skin == .teapot)
        #expect(UnitSprites.portrait(of: packet.kind, skin: packet.skin) != nil)
        let original = try #require(growth.catalog.cosmetic(id: "defender.original"))
        #expect(growth.equip(original))
        #expect(strip().packets.first?.skin == nil)
        #expect(strip().packets.first?.name == DefenderKind.inkling.name)
    }
}
