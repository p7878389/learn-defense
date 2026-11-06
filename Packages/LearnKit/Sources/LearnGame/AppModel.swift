import Foundation
import LearnCore

/// 全局状态：孩子档案、题库、学习记录、成长档案
@MainActor
public final class AppModel: ObservableObject {
    @Published public private(set) var profiles: [Profile]
    @Published public private(set) var library: ContentLibrary
    let speech: Speech
    /// 高质量语音：预先生成的音频 + 火山引擎运行时生成的缓存
    let speechLibrary: SpeechLibrary

    /// 成长系统配置（节奏、徽章、外观），来自 LearnCore 内置 JSON
    let growthCatalog = GrowthCatalog.bundled

    private let profileStore: ProfileStore
    private var progressStores: [UUID: ProgressStore] = [:]
    private var growthStores: [UUID: GrowthStore] = [:]
    /// 本地数据库；打不开时为 nil，档案和记录只留在内存里，并在主页提示
    let database: LearnDatabase?
    private var databaseIssues: [String] = []

    public init() {
        let database: LearnDatabase?
        var issues: [String] = []
        do {
            database = try LearnDatabase(url: AppPaths.databaseFile)
        } catch {
            database = nil
            issues.append("本地数据库打开失败，本次的档案、成长和学习记录不会保存：\(error.localizedDescription)")
        }
        self.database = database
        databaseIssues = issues
        speechLibrary = SpeechLibrary(database: database)
        speech = Speech(library: speechLibrary)
        profileStore = ProfileStore(database: database, legacyFile: AppPaths.profilesFile)
        profiles = profileStore.profiles
        library = Self.loadLibrary(database: database)
        syncConfig()
        prepareSpeech()
    }

    func reloadLibrary() {
        library = Self.loadLibrary(database: database)
        prepareSpeech()
    }

    /// 题库从数据库加载，JSON 文件只在第一次或有变化时读；数据库不可用时直接读 JSON
    private static func loadLibrary(database: LearnDatabase?) -> ContentLibrary {
        let userDirectory = AppPaths.userPacksDirectory
        if let database {
            do {
                return try database.loadContent(userDirectory: userDirectory)
            } catch {
                print("从数据库加载题库失败，改为直接读 JSON：\(error)")
            }
        }
        return ContentLibrary.load(userDirectory: userDirectory)
    }

    /// 配置了语音合成时，在后台把题库和固定提示语里还没有音频的句子生成好（已有的跳过）
    func prepareSpeech() {
        speechLibrary.prepare(SpeechText.gameLines + SpeechText.texts(in: library.packs))
    }

    /// 把系统配置同步进数据库，供查询用；运行时仍用 growthCatalog
    private func syncConfig() {
        do {
            try database?.syncConfig(growthCatalog)
        } catch {
            print("系统配置同步到数据库失败：\(error)")
        }
    }

    func save(_ profile: Profile) {
        profileStore.upsert(profile)
        profiles = profileStore.profiles
    }

    /// 删除档案和它的成长档案、学习记录（界面上会先确认）
    func delete(_ profile: Profile) {
        profileStore.delete(id: profile.id)
        profiles = profileStore.profiles
        progressStores[profile.id] = nil
        growthStores[profile.id] = nil
        do {
            try database?.deletePersonalData(profileID: profile.id)
        } catch {
            print("删除个人数据失败：\(error)")
        }
        for legacy in [AppPaths.progressFile(for: profile.id), AppPaths.growthFile(for: profile.id)] {
            try? FileManager.default.removeItem(at: legacy)
            try? FileManager.default.removeItem(at: AppPaths.migratedBackup(for: legacy))
        }
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
        let store = GrowthStore(
            profileID: profileID,
            database: database,
            legacyFile: AppPaths.growthFile(for: profileID),
            catalog: growthCatalog
        ) { [unowned self] in
            progress(for: profileID).stats.values.reduce(0) { $0 + $1.correct }
        }
        growthStores[profileID] = store
        return store
    }

    /// 一局的对局记录器：答题明细先记在内存里，结束或中途退出时写进数据库
    func recorder(for config: GameConfig) -> GameRecorder {
        GameRecorder(
            database: database,
            profileID: config.profileID,
            grade: config.grade,
            difficulty: config.difficulty,
            packIDs: config.packIDs,
            selection: config.selection)
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
