import Foundation
import SwiftData

// 系统配置：Resources/Config 下的 pacing / badges / cosmetics.json。
// App 运行时仍读 GrowthCatalog.bundled，这里同步一份，方便查询。
extension LearnDatabase {
    public static let configFileNames = ["pacing.json", "badges.json", "cosmetics.json"]

    /// 整份替换数据库里的配置：原文件 + 校验后的徽章、外观
    /// bundle 为 nil 时读 LearnCore 自带的 Resources/Config
    public func syncConfig(_ catalog: GrowthCatalog, bundle: Bundle? = nil) throws {
        let bundle = bundle ?? .module
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        var files: [String: Data] = [:]
        for name in Self.configFileNames {
            let base = (name as NSString).deletingPathExtension
            guard let url = bundle.url(forResource: base, withExtension: "json", subdirectory: "Config") else {
                throw SettingsError.invalid("缺少系统配置：\(name)")
            }
            files[name] = try Data(contentsOf: url)
        }
        let itemData = try catalog.cosmetics.map { try encoder.encode($0) }
        let currentFiles = try context.fetch(FetchDescriptor<StoredConfigFile>())
        let currentBadges = try badges()
        let currentItems = try context.fetch(FetchDescriptor<StoredCosmetic>(sortBy: [SortDescriptor(\.position)]))
        let filesMatch = Self.configFileNames.allSatisfy { name in currentFiles.first { $0.name == name }?.data == files[name] }
        let badgesMatch = currentBadges.count == catalog.badges.count && zip(currentBadges, catalog.badges).enumerated().allSatisfy { index, pair in
            let (row, badge) = pair
            return row.position == index && row.id == badge.id && row.name == badge.name && row.icon == badge.icon
                && row.summary == badge.summary && row.coins == badge.coins && row.stat == badge.stat
                && row.atLeast == badge.atLeast && row.level == badge.level
        }
        let itemsMatch = currentItems.count == itemData.count && zip(currentItems, itemData).enumerated().allSatisfy {
            index, pair in pair.0.position == index && pair.0.itemData == pair.1
        }
        let retiredNames = ["forest.json", "forest-rules.json"]
        if filesMatch && badgesMatch && itemsMatch && !currentFiles.contains(where: { retiredNames.contains($0.name) }) { return }
        try transaction {
            // 只清理已退役试验的两份配置，保留经典规则、朗读设置和个人数据。
            let replacedNames = Self.configFileNames + ["forest.json", "forest-rules.json"]
            for old in try context.fetch(FetchDescriptor<StoredConfigFile>()) where replacedNames.contains(old.name) { context.delete(old) }
            for old in try context.fetch(FetchDescriptor<StoredBadge>()) { context.delete(old) }
            for old in try context.fetch(FetchDescriptor<StoredCosmetic>()) { context.delete(old) }
            for name in Self.configFileNames {
                if let data = files[name] {
                    context.insert(StoredConfigFile(name: name, data: data))
                }
            }
            for (position, badge) in catalog.badges.enumerated() {
                context.insert(StoredBadge(badge: badge, position: position))
            }
            for (position, item) in catalog.cosmetics.enumerated() {
                context.insert(StoredCosmetic(item: item, data: itemData[position], position: position))
            }
        }
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
