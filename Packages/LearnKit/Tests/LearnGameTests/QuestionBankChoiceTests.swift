import LearnCore
import Testing
@testable import LearnGame

@Suite("主页选题库")
struct QuestionBankChoiceTests {
    private func pack(_ id: String, title: String, term: Term? = nil, edition: String? = nil, units: [String] = ["一", "二"]) -> ContentPack {
        ContentPack(id: id, title: title, subject: .chinese, grade: .g3, term: term, edition: edition,
                    units: units.enumerated().map { ContentUnit(id: "u\($0.offset)", title: $0.element, lessons: []) })
    }

    @Test func groupsPacksByEditionInOrder() {
        let packs = [
            pack("rj-up", title: "三年级语文", term: .up, edition: "人教版"),
            pack("bs-up", title: "三年级语文", term: .up, edition: "北师大版"),
            pack("rj-down", title: "三年级语文", term: .down, edition: "人教版"),
            pack("misc", title: "课外古诗", edition: "  "),
        ]
        #expect(QuestionBankChoice.editions(in: packs) == ["人教版", "北师大版", "通用版"], "没写版本的归到通用版")
        #expect(QuestionBankChoice.packs(packs, edition: "人教版").map(\.id) == ["rj-up", "rj-down"])
    }

    @Test func volumeTitleAddsTermOnce() {
        #expect(QuestionBankChoice.volumeTitle(pack("a", title: "三年级语文", term: .up)) == "三年级语文 · 上册")
        #expect(QuestionBankChoice.volumeTitle(pack("b", title: "三年级语文下册", term: .down)) == "三年级语文下册")
        #expect(QuestionBankChoice.volumeTitle(pack("c", title: "课外古诗")) == "课外古诗")
    }

    @Test func courseSummaryDescribesChosenUnits() {
        let p = pack("rj", title: "三年级语文", term: .up, units: ["校园", "秋天", "童话"])
        let key = { (i: Int) in QuestionBankChoice.unitKey(pack: p, unit: p.units[i]) }
        #expect(QuestionBankChoice.courseSummary(pack: p, selectedUnits: []) == "三年级语文 · 上册 · 全部单元")
        #expect(QuestionBankChoice.courseSummary(pack: p, selectedUnits: [key(1)]) == "秋天")
        #expect(QuestionBankChoice.courseSummary(pack: p, selectedUnits: [key(0), key(2)]) == "已选 2 个单元")
        #expect(QuestionBankChoice.courseSummary(pack: p, selectedUnits: ["other/u0"]) == "三年级语文 · 上册 · 全部单元",
                "别的册的单元不算")
    }
}
