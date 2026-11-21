import LearnCore

/// 游戏题库弹窗：按版本分组，再按册、单元选；只整理现有字段，不改变题库格式。
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
        case pack.units.count: return "\(volumeTitle(pack)) · 全部单元"
        case 1: return chosen[0].title
        default: return "已选 \(chosen.count) 个单元"
        }
    }

    static func summary(config: GameConfig, library: ContentLibrary) -> String {
        let packs = config.packIDs.compactMap(library.pack(id:))
        let subject = packs.first?.subject.displayName ?? "题库待选"
        let scope: String
        switch config.selection {
        case .review: scope = "错题复习"
        case .units(let units): scope = packs.first.map { courseSummary(pack: $0, selectedUnits: units) } ?? "题库待选"
        default: scope = packs.first.map { volumeTitle($0) + " · 全部单元" } ?? "题库待选"
        }
        return "\(config.grade.displayName) · \(subject) · \(config.difficulty.displayName) · \(scope)"
    }
}
