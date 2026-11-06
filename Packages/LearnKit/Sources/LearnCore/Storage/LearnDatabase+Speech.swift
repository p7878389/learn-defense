import Foundation
import SwiftData

/// 运行时生成的语音缓存。音频文件放在 AppPaths.speechCacheDirectory，这里记录索引：
/// 哪段文本、用哪个音色生成、存成哪个文件。换音色后旧音色的缓存整批清掉。
@Model
public final class StoredSpeechClip {
    /// "音色标签#文本key"
    @Attribute(.unique) public var id: String
    /// SpeechText.key(for:)
    public var key: String
    /// TTSSettings.voiceTag
    public var voice: String
    public var text: String
    /// 相对 AppPaths.speechCacheDirectory 的路径
    public var fileName: String
    public var bytes: Int
    public var createdAt: Date

    public init(key: String, voice: String, text: String, fileName: String, bytes: Int, createdAt: Date = .now) {
        id = "\(voice)#\(key)"
        self.key = key
        self.voice = voice
        self.text = text
        self.fileName = fileName
        self.bytes = bytes
        self.createdAt = createdAt
    }
}

extension LearnDatabase {
    public func speechClip(key: String, voice: String) throws -> StoredSpeechClip? {
        let id = "\(voice)#\(key)"
        var descriptor = FetchDescriptor<StoredSpeechClip>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// 新增或覆盖一条缓存记录
    public func saveSpeechClip(key: String, voice: String, text: String, fileName: String, bytes: Int) throws {
        if let row = try speechClip(key: key, voice: voice) {
            row.text = text
            row.fileName = fileName
            row.bytes = bytes
            row.createdAt = .now
        } else {
            context.insert(StoredSpeechClip(key: key, voice: voice, text: text, fileName: fileName, bytes: bytes))
        }
        try context.save()
    }

    /// 某个音色已缓存的文本 key
    public func speechClipKeys(voice: String) throws -> Set<String> {
        let rows = try context.fetch(FetchDescriptor<StoredSpeechClip>(predicate: #Predicate { $0.voice == voice }))
        return Set(rows.map(\.key))
    }

    /// 删除其他音色的缓存记录，返回要一并删除的音频文件（相对路径）
    @discardableResult
    public func deleteSpeechClips(exceptVoice voice: String?) throws -> [String] {
        let rows = try context.fetch(FetchDescriptor<StoredSpeechClip>())
        var files: [String] = []
        for row in rows where row.voice != voice {
            files.append(row.fileName)
            context.delete(row)
        }
        try context.save()
        return files
    }
}
