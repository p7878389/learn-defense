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

public final class ProfileStore {
    public private(set) var profiles: [Profile]
    private let url: URL?

    public init(url: URL?) {
        self.url = url
        if let url, let data = try? Data(contentsOf: url),
           let saved = try? JSONDecoder().decode([Profile].self, from: data) {
            profiles = saved
        } else {
            profiles = []
        }
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
        guard let url else { return }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(profiles).write(to: url, options: .atomic)
        } catch {
            print("保存孩子档案失败：\(error)")
        }
    }
}

/// 本地存储位置
public enum AppPaths {
    /// 档案和学习记录
    public static var dataDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LearnDefense", isDirectory: true)
    }

    public static var profilesFile: URL { dataDirectory.appendingPathComponent("profiles.json") }

    public static func progressFile(for id: UUID) -> URL {
        dataDirectory.appendingPathComponent("progress", isDirectory: true)
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
