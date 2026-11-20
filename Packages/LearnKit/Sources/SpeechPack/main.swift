import Foundation
import LearnCore

// 用火山引擎（豆包语音）为题库和游戏提示语预先生成语音。
// 音频按业务分类存放、以文本命名（见 SpeechCatalog），根目录的 manifest.json 记录「文本 → 路径」，
// App 按这份清单查找或从 OSS 下载。

let usage = """
用法：swift run speech-pack [选项]

  --packs <路径>   题库 JSON 文件或目录（可重复）
  --bundled        加上 App 内置题库
  --game-lines     加上游戏里固定的提示语、植物和道具名
  --out <目录>     语音根目录（manifest.json 和分类目录都放在这里）：
                   上传 OSS 时放一个单独的目录，再整个同步到 OSS 的音色目录；
                   内置语音放 Sources/LearnGame/Resources/Speech；
                   随题库分发时放题库 JSON 旁边的 Audio 目录（iPad 上为 Packs/Audio），并加 --flat
  --flat           不分目录，文件名用文本 key（Packs/Audio 的备份和恢复只认这种平铺的文件）
  --reuse <目录>   旧版按 key 命名的音频目录（如 App 缓存导出的 <音色目录>）：
                   有同一句话的音频就直接复制过来，不再调用接口
  --list           只列出要朗读的文本和路径，不生成
  --force          已有的文件也重新生成

账号和音色从环境变量读：
  VOLC_TTS_API_KEY（新版控制台）或 VOLC_TTS_APP_ID + VOLC_TTS_ACCESS_TOKEN（旧版）
  VOLC_TTS_RESOURCE_ID（默认 \(TTSSettings.defaultResourceID)）
  VOLC_TTS_SPEAKER：中文、中英混合（默认 \(TTSSettings.defaultSpeaker)）
  VOLC_TTS_ENGLISH_SPEAKER：纯英文（默认 \(TTSSettings.defaultEnglishSpeaker)）
  VOLC_TTS_SPEECH_RATE（[-50, 100]，默认 \(TTSSettings.defaultSpeechRate)）
只用 --reuse 复制、不需要生成时可以不填账号，但音色和语速要和旧音频一致：清单会记下这套音色。
"""

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("\(message)\n".utf8))
    exit(1)
}

var packPaths: [String] = []
var includeBundled = false
var includeGameLines = false
var outDirectory: String?
var reuseDirectory: String?
var listOnly = false
var force = false
var flat = false

var args = CommandLine.arguments.dropFirst()
func value(after flag: String) -> String {
    guard let value = args.popFirst(), !value.hasPrefix("--") else { fail("\(flag) 后面要跟路径") }
    return value
}
while let arg = args.popFirst() {
    switch arg {
    case "--packs": packPaths.append(value(after: arg))
    case "--bundled": includeBundled = true
    case "--game-lines": includeGameLines = true
    case "--out": outDirectory = value(after: arg)
    case "--reuse": reuseDirectory = value(after: arg)
    case "--list": listOnly = true
    case "--force": force = true
    case "--flat": flat = true
    case "-h", "--help": print(usage); exit(0)
    default: fail("不认识的参数：\(arg)\n\n\(usage)")
    }
}

// MARK: - 收集文本

func loadPacks(at path: String) -> [ContentPack] {
    let url = URL(fileURLWithPath: path)
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else { fail("找不到：\(path)") }
    let files = isDirectory.boolValue
        ? ((try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension.lowercased() == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        : [url]
    return files.map { file in
        do {
            let pack = try ContentLibrary.decode(Data(contentsOf: file))
            for issue in ContentLibrary.validate(pack) { print("⚠️ \(file.lastPathComponent)：\(issue)") }
            return pack
        } catch {
            fail("\(file.path) 读取失败：\(error)")
        }
    }
}

var packs = packPaths.flatMap(loadPacks)
if includeBundled { packs = ContentLibrary.load(userDirectory: nil).packs + packs }
let clips = SpeechCatalog.clips(packs: packs, includeGameLines: includeGameLines).map { clip in
    flat ? SpeechClip(text: clip.text, path: SpeechText.fileName(for: clip.text)) : clip
}
guard !clips.isEmpty else { fail("没有要朗读的文本：用 --packs、--bundled 或 --game-lines 指定\n\n\(usage)") }

if listOnly {
    for clip in clips { print("\(clip.path)\t\(clip.text)") }
    print("共 \(clips.count) 句，\(clips.reduce(0) { $0 + $1.text.count }) 字")
    exit(0)
}

// MARK: - 生成

guard let outDirectory else { fail("缺少 --out\n\n\(usage)") }
let settings = TTSSettings.fromEnvironment()
let fileManager = FileManager.default
let out = URL(fileURLWithPath: outDirectory, isDirectory: true)
let reuse = reuseDirectory.map { URL(fileURLWithPath: $0, isDirectory: true) }
try fileManager.createDirectory(at: out, withIntermediateDirectories: true)

// 已有清单：音色必须一致，否则同一目录里会混进两种声音
let manifestURL = out.appendingPathComponent(SpeechManifest.fileName)
var manifest = SpeechManifest.load(from: manifestURL) ?? SpeechManifest(voice: settings.voiceTag)
if manifest.voice != settings.voiceTag {
    fail("""
    \(out.path) 里的语音是另一套音色：\(manifest.voice)
    当前设置：\(settings.voiceTag)
    换音色请用新的输出目录（OSS 上对应新的音色目录）
    """)
}
let previous = manifest.clips

func saveManifest() throws {
    try manifest.encoded().write(to: manifestURL, options: .atomic)
}

/// 生成之前先确认账号可用；只复制、不生成时不需要账号
var client: VolcengineTTS?
func synthesizer() -> VolcengineTTS {
    if let client { return client }
    guard settings.isUsable else { fail("有句子需要生成，但缺少账号：设置 VOLC_TTS_API_KEY（或 VOLC_TTS_APP_ID + VOLC_TTS_ACCESS_TOKEN）") }
    let made = VolcengineTTS(settings: settings)
    client = made
    return made
}

var generated = 0
var copied = 0
var moved = 0
var skipped = 0
var failed: [(String, String)] = []
print("音色 \(settings.voiceTag)，共 \(clips.count) 句 → \(out.path)")

for (index, clip) in clips.enumerated() {
    let file = out.appendingPathComponent(clip.path)
    let progress = "[\(index + 1)/\(clips.count)]"
    if !force, fileManager.fileExists(atPath: file.path) {
        manifest.clips[clip.text] = clip.path
        skipped += 1
        continue
    }
    do {
        try fileManager.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: file.path) { try fileManager.removeItem(at: file) }
        // 题库调整后这句话换了位置：把原来的文件挪过来
        if !force, let old = previous[clip.text], old != clip.path,
           fileManager.fileExists(atPath: out.appendingPathComponent(old).path) {
            try fileManager.moveItem(at: out.appendingPathComponent(old), to: file)
            moved += 1
            print("\(progress) 移动 \(old) → \(clip.path)")
        } else if !force, let reuse,
                  fileManager.fileExists(atPath: reuse.appendingPathComponent(SpeechText.fileName(for: clip.text)).path) {
            try fileManager.copyItem(at: reuse.appendingPathComponent(SpeechText.fileName(for: clip.text)), to: file)
            copied += 1
        } else {
            let audio = try await synthesizer().synthesize(clip.text)
            try audio.write(to: file, options: .atomic)
            generated += 1
            print("\(progress) 生成 \(clip.path)")
        }
        manifest.clips[clip.text] = clip.path
        // 生成很慢：每 50 句存一次清单，中途中断也不用从头来
        if (generated + copied + moved) % 50 == 0 { try saveManifest() }
    } catch {
        failed.append((clip.text, error.localizedDescription))
        print("\(progress) 失败：\(clip.text)：\(error.localizedDescription)")
        if (error as? TTSError)?.needsSettingsChange == true { break }
    }
}

// 清单里文件已经不在的条目去掉（其他题库的条目保留，同一个目录可以分几次生成）
manifest.clips = manifest.clips.filter { fileManager.fileExists(atPath: out.appendingPathComponent($0.value).path) }
try saveManifest()

// 不在清单里的音频：多半是题库删掉的句子，列出来让人决定要不要删
let listed = Set(manifest.clips.values)
let root = out.resolvingSymlinksInPath().path
let orphans = (fileManager.enumerator(at: out, includingPropertiesForKeys: nil)?.compactMap { $0 as? URL } ?? [])
    .filter { $0.pathExtension == SpeechText.audioExtension }
    .map { String($0.resolvingSymlinksInPath().path.dropFirst(root.count + 1)) }
    .filter { !listed.contains($0) }
    .sorted()

print("生成 \(generated) 句，复制 \(copied) 句，移动 \(moved) 句，跳过已有 \(skipped) 句，失败 \(failed.count) 句")
print("清单 \(manifestURL.path)：\(manifest.clips.count) 句")
if !orphans.isEmpty {
    print("⚠️ 有 \(orphans.count) 个音频不在清单里（可以删掉）：")
    for path in orphans.prefix(20) { print("  \(path)") }
    if orphans.count > 20 { print("  …") }
}
if !failed.isEmpty { exit(2) }
