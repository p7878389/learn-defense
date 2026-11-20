import Foundation
import CryptoKit
import LearnCore
import ZIPFoundation

/// ZIP 在独立目录验证完毕才发布指针；中途失败或退出不影响正在使用的语音。
enum SpeechArchive {
    struct Installed: Sendable {
        let directory: URL
        let manifest: SpeechManifest
    }

    private struct Receipt: Codable {
        let folder: String
        let sha256: String
    }

    enum Failure: LocalizedError {
        case checksum, invalidArchive
        var errorDescription: String? {
            switch self {
            case .checksum: "语音包校验失败，请重试下载"
            case .invalidArchive: "语音包不完整或格式不正确，请重试下载"
            }
        }
    }

    static func current(in root: URL, sha256: String? = nil) -> Installed? {
        guard let data = try? Data(contentsOf: root.appendingPathComponent("installed.json")),
              let receipt = try? JSONDecoder().decode(Receipt.self, from: data),
              sha256 == nil || receipt.sha256 == sha256,
              safePath(receipt.folder), !receipt.folder.contains("/"),
              let result = try? validate(root.appendingPathComponent(receipt.folder)) else { return nil }
        return result
    }

    static func install(_ zip: URL, sha256: String, in root: URL) throws -> Installed {
        let handle = try FileHandle(forReadingFrom: zip)
        defer { try? handle.close() }
        var digest = SHA256()
        while let chunk = try handle.read(upToCount: 64 * 1024), !chunk.isEmpty {
            try Task.checkCancellation()
            digest.update(data: chunk)
        }
        guard digest.finalize().map({ String(format: "%02x", $0) }).joined() == sha256 else {
            throw Failure.checksum
        }
        let manager = FileManager.default
        let folder = "pack-" + UUID().uuidString
        let staging = root.appendingPathComponent(folder, isDirectory: true)
        try manager.createDirectory(at: staging, withIntermediateDirectories: true)
        var published = false
        defer { if !published { try? manager.removeItem(at: staging) } }
        let archive = try Archive(url: zip, accessMode: .read)
        var total: UInt64 = 0
        var paths = Set<String>()
        for entry in archive {
            try Task.checkCancellation()
            let path = entry.path.hasSuffix("/") ? String(entry.path.dropLast()) : entry.path
            guard safePath(path), entry.type != .symlink,
                  paths.insert(path.lowercased()).inserted, paths.count <= 20_000 else { throw Failure.invalidArchive }
            total += entry.uncompressedSize
            guard total <= 256 * 1024 * 1024 else { throw Failure.invalidArchive }
            let target = staging.appendingPathComponent(path)
            let checksum = try archive.extract(entry, to: target)
            guard checksum == entry.checksum else { throw Failure.invalidArchive }
        }
        let result = try validate(staging)
        try Task.checkCancellation()
        let receipt = Receipt(folder: folder, sha256: sha256)
        try JSONEncoder().encode(receipt).write(to: root.appendingPathComponent("installed.json"), options: .atomic)
        published = true
        return result
    }

    private static func validate(_ directory: URL) throws -> Installed {
        guard let manifest = SpeechManifest.load(from: directory.appendingPathComponent(SpeechManifest.fileName)),
              manifest.version == SpeechManifest.currentVersion,
              !manifest.voice.isEmpty, !manifest.clips.isEmpty else { throw Failure.invalidArchive }
        for path in manifest.clips.values {
            guard safePath(path), path.hasSuffix(".mp3") else { throw Failure.invalidArchive }
            let values = try directory.appendingPathComponent(path).resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true, (values.fileSize ?? 0) > 0 else {
                throw Failure.invalidArchive
            }
        }
        return Installed(directory: directory, manifest: manifest)
    }

    private static func safePath(_ path: String) -> Bool {
        !path.isEmpty && !path.hasPrefix("/") && !path.contains("\\") && !path.contains("\0")
            && path.split(separator: "/", omittingEmptySubsequences: false).allSatisfy { !$0.isEmpty && $0 != ".." && $0 != "." }
    }
}
