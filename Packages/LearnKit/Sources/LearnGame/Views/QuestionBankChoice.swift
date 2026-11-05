import LearnCore

/// 主页选题库：按版本（人教版等）分组，再按册、单元选。只整理已有题库字段（edition、term、units），不改题库格式
enum QuestionBankChoice {
    /// 题库没写版本时归到这一组
    static let defaultEdition = "通用版"

    static func edition(of pack: ContentPack) -> String {
        let name = pack.edition?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? defaultEdition : name
    }

    /// 按题库出现的顺序列出版本，不重复
    static func editions(in packs: [ContentPack]) -> [String] {
        var seen = Set<String>()
        return packs.map(edition(of:)).filter { seen.insert($0).inserted }
    }

    static func packs(_ packs: [ContentPack], edition: String) -> [ContentPack] {
        packs.filter { self.edition(of: $0) == edition }
    }

    /// 册名：「三年级语文 · 上册」；标题里已经写了上下册就不再重复
    static func volumeTitle(_ pack: ContentPack) -> String {
        guard let term = pack.term, !pack.title.contains(term.displayName) else { return pack.title }
        return "\(pack.title) · \(term.displayName)"
    }

    static func unitKey(pack: ContentPack, unit: ContentUnit) -> String {
        "\(pack.id)/\(unit.id)"
    }

    /// 课程按钮上显示的文字
    static func courseSummary(pack: ContentPack, selectedUnits: Set<String>) -> String {
        let chosen = pack.units.filter { selectedUnits.contains(unitKey(pack: pack, unit: $0)) }
        switch chosen.count {
        case 0: return "\(volumeTitle(pack)) · 全部单元"
        case 1: return chosen[0].title
        default: return "已选 \(chosen.count) 个单元"
        }
    }
}
