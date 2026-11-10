import Foundation
import SwiftData

// 系统配置：Resources/Config 下的 pacing / badges / cosmetics / forest.json。
// App 运行时仍读内置 JSON（GrowthCatalog.bundled、ForestRules.defaults），这里只是同步一份，方便查询。
extension LearnDatabase {
    public static let configFileNames = ["pacing.json", "badges.json", "cosmetics.json", "forest.json"]

    /// 整份替换数据库里的配置：原文件 + 校验后的徽章、外观
    /// bundle 为 nil 时读 LearnCore 自带的 Resources/Config
    public func syncConfig(_ catalog: GrowthCatalog, bundle: Bundle? = nil) throws {
        let bundle = bundle ?? .module
        for old in try context.fetch(FetchDescriptor<StoredConfigFile>()) where Self.configFileNames.contains(old.name) { context.delete(old) }
        for old in try context.fetch(FetchDescriptor<StoredBadge>()) { context.delete(old) }
        for old in try context.fetch(FetchDescriptor<StoredCosmetic>()) { context.delete(old) }
        try context.save()

        for name in Self.configFileNames {
            let base = (name as NSString).deletingPathExtension
            if let url = bundle.url(forResource: base, withExtension: "json", subdirectory: "Config"),
               let data = try? Data(contentsOf: url) {
                context.insert(StoredConfigFile(name: name, data: data))
            }
        }
        for (position, badge) in catalog.badges.enumerated() {
            context.insert(StoredBadge(badge: badge, position: position))
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        for (position, item) in catalog.cosmetics.enumerated() {
            context.insert(StoredCosmetic(item: item, data: try encoder.encode(item), position: position))
        }
        try context.save()
    }

    public func configFile(named name: String) throws -> StoredConfigFile? {
        var descriptor = FetchDescriptor<StoredConfigFile>(predicate: #Predicate { $0.name == name })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    public func badges() throws -> [StoredBadge] {
        try context.fetch(FetchDescriptor<StoredBadge>(sortBy: [SortDescriptor(\.position)]))
    }

    /// 某个槽位的外观，按配置顺序
    public func cosmetics(slot: CosmeticSlot) throws -> [StoredCosmetic] {
        let s = slot.rawValue
        return try context.fetch(FetchDescriptor<StoredCosmetic>(
            predicate: #Predicate { $0.slot == s },
            sortBy: [SortDescriptor(\.position)]
        ))
    }
}

extension LearnDatabase {
    /// 独立于内置 JSON 的配置同步，不被 syncConfig 覆盖。
    public func gameRules() throws -> GameRules {
        if let row = try configFile(named: "game-rules.json") {
            // 损坏时保留原数据供排查，本次使用默认值。
            return (try? JSONDecoder().decode(GameRules.self, from: row.data))?.validated() ?? .defaults
        }
        try saveGameRules(.defaults)
        return .defaults
    }

    public func saveGameRules(_ rules: GameRules) throws {
        let data = try JSONEncoder().encode(rules.validated())
        if let row = try configFile(named: "game-rules.json") {
            row.data = data
            row.syncedAt = Date()
        } else {
            context.insert(StoredConfigFile(name: "game-rules.json", data: data))
        }
        try context.save()
    }
}

extension LearnDatabase {
    public static let forestRulesName = "forest-rules.json"

    /// 森林塔防的怪物、英雄、炮塔数值：内置 forest.json 的默认值，叠加数据库里的改动项。
    /// 数据库只存改动过的值，不被 syncConfig 覆盖；没改过的值始终跟随内置默认值。
    public func forestRules() throws -> ForestRules {
        guard let row = try configFile(named: Self.forestRulesName) else { return .defaults }
        // 损坏时保留原数据供排查，本次使用默认值。
        guard let rules = ForestRules.applying(overrides: row.data) else { return .defaults }
        // 没有版本号的是早先整份写入的快照：收敛成改动项，免得把当时的默认值一直钉在库里。
        let stored = try? JSONSerialization.jsonObject(with: row.data) as? [String: Any]
        if stored?["version"] == nil { try saveForestRules(rules) }
        return rules
    }

    /// 只写入相对默认值的改动项；与默认值完全一致时删除这一行。
    public func saveForestRules(_ rules: ForestRules) throws {
        let row = try configFile(named: Self.forestRulesName)
        if let data = rules.overrides() {
            if let row {
                row.data = data
                row.syncedAt = Date()
            } else {
                context.insert(StoredConfigFile(name: Self.forestRulesName, data: data))
            }
        } else if let row {
            context.delete(row)
        }
        try context.save()
    }
}
