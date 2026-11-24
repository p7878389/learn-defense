import Foundation
import Testing
@testable import LearnCore

@Suite("道具")
struct ItemTests {
    @Test func inventoryCapacity() {
        var inventory = Inventory(capacity: 2)
        let added = [inventory.add(.frostCharm), inventory.add(.luckyStar), inventory.add(.heartLeaf)]
        #expect(added == [true, true, false], "装满后不再收")
        let first = inventory.take(at: 0)
        let missing = inventory.take(at: 5)
        #expect(first == .frostCharm)
        #expect(missing == nil)
        #expect(inventory.items == [.luckyStar])
    }

    @Test func dropsAndCatalog() {
        var rng = SeededRNG(state: 11)
        #expect(ItemDrop(.luckyStar, chance: 1).roll(using: &rng) == .luckyStar)
        #expect(ItemDrop(.luckyStar, chance: 0).roll(using: &rng) == nil)
        #expect(ItemKind.heartLeaf.onlyHeals)
        #expect(!ItemKind.frostCharm.onlyHeals)
        #expect(Set(UnitCatalog.items.map(\.id)).count == UnitCatalog.items.count)
        for kind in UnitCatalog.enemies {
            if let drop = kind.drop {
                #expect(UnitCatalog.item(id: drop.item.id) == drop.item, "\(kind.id) 掉落的道具不在目录里")
            }
        }
        for grade in Grade.allCases {
            for difficulty in Difficulty.allCases {
                #expect(GameTuning.make(grade: grade, difficulty: difficulty).ultimate.effects.contains(.clearField))
            }
        }
    }
}

@Suite("画面主题")
struct SceneThemeTests {
    static let library = ContentLibrary.load(userDirectory: nil)

    @Test func idsUniqueAndComplete() {
        #expect(Set(SceneTheme.all.map(\.id)).count == SceneTheme.all.count)
        for theme in SceneTheme.all {
            #expect(!theme.lanes.isEmpty)
            #expect(!theme.horizon.isEmpty)
            #expect(!theme.base.isEmpty)
        }
    }

    @Test func chooseByUnitThenGrade() {
        let k2 = Self.library.packs(grade: .k2, subject: .chinese)
        #expect(SceneTheme.choose(packs: k2, selection: .units(["chinese-k2-sample/u2"]), grade: .k2) == .orchard)
        #expect(SceneTheme.choose(packs: k2, selection: .units(["chinese-k2-sample/u3"]), grade: .k2) == .starry)
        // 选了好几个单元：用得最多的主题，一样多时取靠前的
        #expect(SceneTheme.choose(packs: k2, selection: .units(["chinese-k2-sample/u1", "chinese-k2-sample/u2"]), grade: .k2) == .meadow)
        // 单元没写主题：按年级
        #expect(SceneTheme.choose(packs: k2, selection: .units(["chinese-k2-sample/u4"]), grade: .k2) == .meadow)
        #expect(SceneTheme.choose(packs: [], selection: .all, grade: .g3) == .academy)

        let g3 = Self.library.packs(grade: .g3, subject: .chinese)
        #expect(SceneTheme.choose(packs: g3, selection: .all, grade: .g3) == .academy)
        #expect(SceneTheme.choose(packs: g3, selection: .units(["chinese-g3-up-pep/u2"]), grade: .g3) == .orchard)
    }

    @Test func unknownThemeIgnored() throws {
        let json = """
        {"schemaVersion":1,"id":"t","title":"t","subject":"chinese","grade":"g1",
         "units":[{"id":"u1","title":"u","theme":"moon-base","lessons":[]}]}
        """
        let pack = try ContentLibrary.decode(Data(json.utf8))
        #expect(pack.units[0].theme == "moon-base")
        #expect(SceneTheme.choose(packs: [pack], selection: .all, grade: .g1) == .academy)
    }
}
