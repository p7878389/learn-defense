import Testing
@testable import LearnCore

@Suite("单元选题去重")
struct ItemPoolSelectionTests {
    private var pack: ContentPack {
        ContentPack(id: "selection", title: "选题", subject: .chinese, grade: .g3, units: [
            ContentUnit(id: "u1", title: "第一单元", lessons: [
                Lesson(id: "l1", title: "第一课", characters: [CharacterItem(char: "行", pinyin: "xíng")],
                       idioms: [IdiomItem(text: "坚持不懈")])]),
            ContentUnit(id: "u2", title: "第二单元", lessons: [
                Lesson(id: "l2", title: "第二课", characters: [
                    CharacterItem(char: "行", pinyin: "háng"), CharacterItem(char: "晨", pinyin: "chén")],
                       idioms: [IdiomItem(text: "坚持不懈")]),
                Lesson(id: "l3", title: "第三课", characters: [CharacterItem(char: "晨", pinyin: "chén")])])])
    }

    @Test func laterUnitKeepsRepeatedItemsAndItsOwnContent() throws {
        let pool = ItemPool(packs: [pack], selection: .units(["selection/u2"]))
        #expect(pool.items.map(\.key) == ["char:行", "char:晨", "idiom:坚持不懈"])
        let item = try #require(pool.items.first)
        guard case .character(let character) = item else { Issue.record("应保留第二单元的生字"); return }
        #expect(character.pinyin == "háng")
        #expect(pool.ultimateItems.map(\.key) == ["idiom:坚持不懈"])
    }

    @Test func multiUnitAllAndReviewStillDeduplicate() {
        for selection: ItemPool.Selection in [.all, .units(["selection/u1", "selection/u2"])] {
            let pool = ItemPool(packs: [pack], selection: selection)
            #expect(pool.items.map(\.key) == ["char:行", "idiom:坚持不懈", "char:晨"])
        }
        let review = ItemPool(packs: [pack], selection: .review(["char:行", "char:晨"]))
        #expect(review.items.map(\.key) == ["char:行", "char:晨"])
    }

    @Test func selectedPackIsNotShadowedByEarlierPack() {
        var later = pack
        later.id = "later"
        let pool = ItemPool(packs: [pack, later], selection: .units(["later/u2"]))
        #expect(pool.items.map(\.key) == ["char:行", "char:晨", "idiom:坚持不懈"])
    }

    @Test(arguments: [("u7", 50), ("u8", 55)])
    func bundledLaterUnitsKeepAllTheirItems(unitID: String, count: Int) throws {
        let pack = try #require(ContentLibrary.load(userDirectory: nil).pack(id: "chinese-g3-up-pep"))
        let pool = ItemPool(packs: [pack], selection: .units(["chinese-g3-up-pep/\(unitID)"]))
        #expect(pool.items.count == count)
        #expect(pool.items.contains { $0.key == (unitID == "u7" ? "char:威" : "word:庭院") })
    }
}
