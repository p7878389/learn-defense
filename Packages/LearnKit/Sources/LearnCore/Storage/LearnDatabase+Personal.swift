import Foundation
import SwiftData

// 个人信息：孩子档案、成长档案
extension LearnDatabase {
    // MARK: - 孩子档案

    /// 按列表顺序返回全部档案
    public func profiles() throws -> [Profile] {
        try context.fetch(FetchDescriptor<StoredProfile>(sortBy: [SortDescriptor(\.position)]))
            .compactMap(\.profile)
    }

    /// 用这份列表整体覆盖档案表（顺序即列表顺序；不在列表里的删除）
    public func saveProfiles(_ profiles: [Profile]) throws {
        let rows = try context.fetch(FetchDescriptor<StoredProfile>())
        var byID = Dictionary(rows.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for (position, profile) in profiles.enumerated() {
            let id = profile.id.uuidString
            if let row = byID.removeValue(forKey: id) {
                row.update(profile, position: position)
            } else {
                context.insert(StoredProfile(profile: profile, position: position))
            }
        }
        for stale in byID.values { context.delete(stale) }
        try context.save()
    }

    // MARK: - 成长档案

    /// 没有记录时返回 nil；记录存在但内容读不出来时抛错
    public func growthState(profileID: UUID) throws -> GrowthState? {
        let pid = profileID.uuidString
        var descriptor = FetchDescriptor<StoredGrowth>(predicate: #Predicate { $0.profileID == pid })
        descriptor.fetchLimit = 1
        guard let row = try context.fetch(descriptor).first else { return nil }
        return try JSONDecoder.growth.decode(GrowthState.self, from: row.stateData)
    }

    public func saveGrowthState(_ state: GrowthState, profileID: UUID) throws {
        let pid = profileID.uuidString
        let data = try JSONEncoder.growth.encode(state)
        var descriptor = FetchDescriptor<StoredGrowth>(predicate: #Predicate { $0.profileID == pid })
        descriptor.fetchLimit = 1
        if let row = try context.fetch(descriptor).first {
            row.update(state, data: data)
        } else {
            context.insert(StoredGrowth(profileID: pid, state: state, data: data))
        }
        try context.save()
    }

    /// 删除一个孩子在数据库里的全部个人数据：档案、成长档案、学习记录
    public func deletePersonalData(profileID: UUID) throws {
        let pid = profileID.uuidString
        for row in try context.fetch(FetchDescriptor<StoredGrowth>(predicate: #Predicate { $0.profileID == pid })) {
            context.delete(row)
        }
        for row in try context.fetch(FetchDescriptor<StoredItemStats>(predicate: #Predicate { $0.profileID == pid })) {
            context.delete(row)
        }
        for row in try context.fetch(FetchDescriptor<StoredProfile>(predicate: #Predicate { $0.id == pid })) {
            context.delete(row)
        }
        try context.save()
    }
}
