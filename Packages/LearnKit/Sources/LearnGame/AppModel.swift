import Foundation
import LearnCore

/// 全局状态：孩子档案、题库、学习记录、成长档案
@MainActor
public final class AppModel: ObservableObject {
    @Published public private(set) var profiles: [Profile]
    @Published public private(set) var library: ContentLibrary
    let speech = Speech()

    /// 成长系统配置（节奏、徽章、外观），来自 LearnCore 内置 JSON
    let growthCatalog = GrowthCatalog.bundled

    private let profileStore: ProfileStore
    private var progressStores: [UUID: ProgressStore] = [:]
    private var growthStores: [UUID: GrowthStore] = [:]
    /// 本地数据库；打不开时为 nil，学习记录只留在内存里，并在主页提示
    let database: LearnDatabase?
    private var databaseIssues: [String] = []

    public init() {
        profileStore = ProfileStore(url: AppPaths.profilesFile)
        profiles = profileStore.profiles
        library = ContentLibrary.load(userDirectory: AppPaths.userPacksDirectory)
        do {
            database = try LearnDatabase(url: AppPaths.databaseFile)
        } catch {
            database = nil
            databaseIssues.append("本地数据库打开失败，本次学习记录不会保存：\(error.localizedDescription)")
        }
        syncContent()
    }

    func reloadLibrary() {
        library = ContentLibrary.load(userDirectory: AppPaths.userPacksDirectory)
        syncContent()
    }

    /// 把题库同步进数据库，供查询用；失败不影响出题
    private func syncContent() {
        do {
            try database?.syncContent(library.packs)
        } catch {
            print("题库同步到数据库失败：\(error)")
        }
    }

    func save(_ profile: Profile) {
        profileStore.upsert(profile)
        profiles = profileStore.profiles
    }

    /// 删除档案和它的学习记录（界面上会先确认）
    func delete(_ profile: Profile) {
        profileStore.delete(id: profile.id)
        profiles = profileStore.profiles
        progressStores[profile.id] = nil
        growthStores[profile.id] = nil
        do {
            try database?.deleteStats(profileID: profile.id)
        } catch {
            print("删除学习记录失败：\(error)")
        }
        let legacyProgress = AppPaths.progressFile(for: profile.id)
        try? FileManager.default.removeItem(at: legacyProgress)
        try? FileManager.default.removeItem(at: ProgressStore.migratedFile(for: legacyProgress))
        try? FileManager.default.removeItem(at: AppPaths.growthFile(for: profile.id))
    }

    func progress(for profileID: UUID) -> ProgressStore {
        if let store = progressStores[profileID] { return store }
        let store = ProgressStore(
            profileID: profileID,
            database: database,
            legacyFile: AppPaths.progressFile(for: profileID)
        )
        progressStores[profileID] = store
        return store
    }

    /// 成长档案。老档案第一次打开时按学习记录里的答对次数补发经验和积分
    func growth(for profileID: UUID) -> GrowthStore {
        if let store = growthStores[profileID] { return store }
        let store = GrowthStore(url: AppPaths.growthFile(for: profileID), catalog: growthCatalog) { [unowned self] in
            progress(for: profileID).stats.values.reduce(0) { $0 + $1.correct }
        }
        growthStores[profileID] = store
        return store
    }

    /// 用积分买外观；成功后刷新界面
    func purchase(_ item: CosmeticKind, for profileID: UUID) -> GrowthState.PurchaseResult {
        let result = growth(for: profileID).purchase(item)
        objectWillChange.send()
        return result
    }

    func equip(_ item: CosmeticKind, for profileID: UUID) {
        growth(for: profileID).equip(item)
        objectWillChange.send()
    }

    func unequip(key: String, for profileID: UUID) {
        growth(for: profileID).unequip(key: key)
        objectWillChange.send()
    }

    /// 题库和成长配置里的问题，显示在主页
    var issues: [String] { databaseIssues + library.issues + growthCatalog.issues }
}

/// 开一局游戏需要的信息
struct GameConfig: Identifiable, Hashable {
    var id = UUID()
    var profileID: UUID
    var grade: Grade
    var packIDs: [String]
    var selection: ItemPool.Selection
    var difficulty: Difficulty

    /// 同样的设置再来一局
    func again() -> GameConfig {
        var copy = self
        copy.id = UUID()
        return copy
    }
}
