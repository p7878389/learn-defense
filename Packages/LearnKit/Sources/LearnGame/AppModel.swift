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

    public init() {
        profileStore = ProfileStore(url: AppPaths.profilesFile)
        profiles = profileStore.profiles
        library = ContentLibrary.load(userDirectory: AppPaths.userPacksDirectory)
    }

    func reloadLibrary() {
        library = ContentLibrary.load(userDirectory: AppPaths.userPacksDirectory)
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
        try? FileManager.default.removeItem(at: AppPaths.progressFile(for: profile.id))
        try? FileManager.default.removeItem(at: AppPaths.growthFile(for: profile.id))
    }

    func progress(for profileID: UUID) -> ProgressStore {
        if let store = progressStores[profileID] { return store }
        let store = ProgressStore(url: AppPaths.progressFile(for: profileID))
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
    var issues: [String] { library.issues + growthCatalog.issues }
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
