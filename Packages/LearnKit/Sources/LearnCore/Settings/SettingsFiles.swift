import Foundation

/// 课本文件先完整准备，交换目录失败时不动数据库；数据库失败时换回原目录。
public enum SettingsFiles {
    public static func restore(_ archive: SettingsBackup, database: LearnDatabase, packsDirectory: URL) throws {
        try archive.validate()
        let fm = FileManager.default
        let staging = packsDirectory.deletingLastPathComponent().appendingPathComponent("restore-" + UUID().uuidString)
        let previous = packsDirectory.deletingLastPathComponent().appendingPathComponent("previous-" + UUID().uuidString)
        try fm.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: staging) }
        for data in archive.importedPacks {
            try PackManager(directory: staging).install(PackManager(directory: staging).preview(data))
        }
        if !archive.packAudio.isEmpty {
            let audio = staging.appendingPathComponent("Audio", isDirectory: true)
            try fm.createDirectory(at: audio, withIntermediateDirectories: true)
            for (name, data) in archive.packAudio { try data.write(to: audio.appendingPathComponent(name), options: .atomic) }
        }
        let hadOriginal = fm.fileExists(atPath: packsDirectory.path)
        if hadOriginal { try fm.moveItem(at: packsDirectory, to: previous) }
        do {
            try fm.moveItem(at: staging, to: packsDirectory)
            try database.restore(archive)
        } catch {
            try? fm.removeItem(at: packsDirectory)
            if hadOriginal { try fm.moveItem(at: previous, to: packsDirectory) }
            throw error
        }
        try? fm.removeItem(at: previous)
    }

    public static func bytes(in directory: URL) -> Int64 {
        let fm = FileManager.default
        guard let files = fm.enumerator(at: directory, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]) else { return 0 }
        return files.compactMap { $0 as? URL }.reduce(0) { sum, file in
            let values = try? file.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            return sum + (values?.isRegularFile == true ? Int64(values?.fileSize ?? 0) : 0)
        }
    }
}
