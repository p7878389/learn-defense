import Foundation
import SwiftData

// 系统配置：Resources/Config 下的 pacing / badges / cosmetics.json。
// App 运行时仍读 GrowthCatalog.bundled（JSON 是来源），这里只是同步一份，方便查询。
extension LearnDatabase {
    public static let configFileNames = ["pacing.json", "badges.json", "cosmetics.json"]

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

    /// 森林塔防的怪物、英雄、炮塔数值。数据库里没有时写入默认值；之后以数据库为准，不被 syncConfig 覆盖。
    public func forestRules() throws -> ForestRules {
        if let row = try configFile(named: Self.forestRulesName) {
            // 损坏时保留原数据供排查，本次使用默认值。
            return ForestRules.decode(row.data) ?? .defaults
        }
        try saveForestRules(.defaults)
        return .defaults
    }

    public func saveForestRules(_ rules: ForestRules) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        let data = try encoder.encode(rules.validated())
        if let row = try configFile(named: Self.forestRulesName) {
            row.data = data
            row.syncedAt = Date()
        } else {
            context.insert(StoredConfigFile(name: Self.forestRulesName, data: data))
        }
        try context.save()
    }
}
