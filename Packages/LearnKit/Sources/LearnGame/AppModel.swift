import Foundation
import LearnCore

/// 全局状态：孩子档案、题库、学习记录
@MainActor
public final class AppModel: ObservableObject {
    @Published public private(set) var profiles: [Profile]
    @Published public private(set) var library: ContentLibrary
    let speech = Speech()

    private let profileStore: ProfileStore
    private var progressStores: [UUID: ProgressStore] = [:]

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
        try? FileManager.default.removeItem(at: AppPaths.progressFile(for: profile.id))
    }

    func progress(for profileID: UUID) -> ProgressStore {
        if let store = progressStores[profileID] { return store }
        let store = ProgressStore(url: AppPaths.progressFile(for: profileID))
        progressStores[profileID] = store
        return store
    }
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
