import Foundation

/// 孩子档案
public struct Profile: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var grade: Grade
    public var avatar: String
    /// 上次选的难度
    public var difficulty: Difficulty

    public init(id: UUID = UUID(), name: String, grade: Grade, avatar: String, difficulty: Difficulty = .easy) {
        self.id = id
        self.name = name
        self.grade = grade
        self.avatar = avatar
        self.difficulty = difficulty
    }

    public static let avatars = ["🐯", "🐼", "🦊", "🐰", "🐨", "🦁", "🐸", "🐧", "🦄", "🐳"]
}

/// 孩子档案列表，存在本地数据库（LearnDatabase）里。
public final class ProfileStore {
    public private(set) var profiles: [Profile]
    private let database: LearnDatabase?

    /// legacyFile 是旧版的 profiles.json：数据库里还没有档案时导入一次，导入成功后改名为 .json.migrated。
    /// database 为 nil 时只在内存里（测试用，或数据库打不开时），此时只读取 legacyFile、不改动它。
    public init(database: LearnDatabase?, legacyFile: URL? = nil) {
        self.database = database
        let legacy = legacyFile.flatMap(Self.readLegacy)
        guard let database else {
            profiles = legacy ?? []
            return
        }
        do {
            profiles = try database.profiles()
        } catch {
            print("读取孩子档案失败：\(error)")
            profiles = []
            return
        }
        if profiles.isEmpty, let legacyFile, let legacy {
            do {
                try database.saveProfiles(legacy)
                profiles = legacy
                AppPaths.markMigrated(legacyFile)
            } catch {
                print("迁移孩子档案失败：\(error)")
                profiles = legacy
            }
        }
    }

    private static func readLegacy(_ file: URL) -> [Profile]? {
        guard let data = try? Data(contentsOf: file) else { return nil }
        return try? JSONDecoder().decode([Profile].self, from: data)
    }

    public func upsert(_ profile: Profile) {
        if let i = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[i] = profile
        } else {
            profiles.append(profile)
        }
        save()
    }

    public func delete(id: UUID) {
        profiles.removeAll { $0.id == id }
        save()
    }

    private func save() {
        guard let database else { return }
        do {
            try database.saveProfiles(profiles)
        } catch {
            print("保存孩子档案失败：\(error)")
        }
    }
}

/// 本地存储位置
public enum AppPaths {
    /// 本地数据库和旧版 JSON 所在目录
    public static var dataDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LearnDefense", isDirectory: true)
    }

    /// 本地数据库（SwiftData）：档案、成长档案、学习记录，以及题库和系统配置的副本
    public static var databaseFile: URL { dataDirectory.appendingPathComponent("learn.store") }

    /// 旧版 JSON 导入数据库后改名成的备份文件（xxx.json.migrated）
    public static func migratedBackup(for legacyFile: URL) -> URL {
        legacyFile.appendingPathExtension("migrated")
    }

    /// 旧版 JSON 已导入数据库：改名留作备份，以后不再读取
    static func markMigrated(_ legacyFile: URL) {
        let backup = migratedBackup(for: legacyFile)
        try? FileManager.default.removeItem(at: backup)
        try? FileManager.default.moveItem(at: legacyFile, to: backup)
    }

    /// 旧版档案列表 JSON，只用于迁移到数据库
    public static var profilesFile: URL { dataDirectory.appendingPathComponent("profiles.json") }

    /// 旧版学习记录 JSON，只用于迁移到数据库
    public static func progressFile(for id: UUID) -> URL {
        dataDirectory.appendingPathComponent("progress", isDirectory: true)
            .appendingPathComponent("\(id.uuidString).json")
    }

    /// 旧版成长档案 JSON，只用于迁移到数据库
    public static func growthFile(for id: UUID) -> URL {
        dataDirectory.appendingPathComponent("growth", isDirectory: true)
            .appendingPathComponent("\(id.uuidString).json")
    }

    /// 用户导入题库的目录。iOS 上在「文件」App 里可见（Documents/Packs）
    public static var userPacksDirectory: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Packs", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
