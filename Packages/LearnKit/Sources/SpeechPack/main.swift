import Foundation
import LearnCore

// 用火山引擎（豆包语音）为题库预先生成语音：每句一个 <文本key>.mp3。
// 文件名规则与 App 里查找时相同（SpeechText.key），所以只要文本一样就能命中。

let usage = """
用法：swift run speech-pack [选项]

  --packs <路径>   题库 JSON 文件或目录（可重复）
  --bundled        加上 App 内置题库
  --game-lines     加上游戏里固定的提示语、植物和道具名
  --out <目录>     音频输出目录：
                   内置语音放 Sources/LearnGame/Resources/Speech；
                   随题库分发时放题库 JSON 旁边的 Audio 目录（iPad 上为 Packs/Audio）
  --list           只列出要朗读的文本和文件名，不调用接口
  --force          已有的文件也重新生成

账号和音色从环境变量读：
  VOLC_TTS_API_KEY（新版控制台）或 VOLC_TTS_APP_ID + VOLC_TTS_ACCESS_TOKEN（旧版）
  VOLC_TTS_RESOURCE_ID（默认 \(TTSSettings.defaultResourceID)）
  VOLC_TTS_SPEAKER：中文、中英混合（默认 \(TTSSettings.defaultSpeaker)）
  VOLC_TTS_ENGLISH_SPEAKER：纯英文（默认 \(TTSSettings.defaultEnglishSpeaker)）
  VOLC_TTS_SPEECH_RATE（[-50, 100]，默认 \(TTSSettings.defaultSpeechRate)）
"""

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("\(message)\n".utf8))
    exit(1)
}

var packPaths: [String] = []
var includeBundled = false
var includeGameLines = false
var outDirectory: String?
var listOnly = false
var force = false

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
    case "--list": listOnly = true
    case "--force": force = true
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
var texts = SpeechText.texts(in: packs)
if includeGameLines { texts = SpeechText.unique(SpeechText.gameLines + texts) }
guard !texts.isEmpty else { fail("没有要朗读的文本：用 --packs、--bundled 或 --game-lines 指定\n\n\(usage)") }

if listOnly {
    for text in texts { print("\(SpeechText.fileName(for: text))\t\(text)") }
    print("共 \(texts.count) 句，\(texts.reduce(0) { $0 + $1.count }) 字")
    exit(0)
}

// MARK: - 生成

guard let outDirectory else { fail("缺少 --out\n\n\(usage)") }
let settings = TTSSettings.fromEnvironment()
guard settings.isUsable else { fail("缺少账号：设置 VOLC_TTS_API_KEY（或 VOLC_TTS_APP_ID + VOLC_TTS_ACCESS_TOKEN）") }

let out = URL(fileURLWithPath: outDirectory, isDirectory: true)
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

// manifest.json：文件名 → 文本，方便人工核对；与已有的合并
let manifestURL = out.appendingPathComponent("manifest.json")
var manifest = (try? JSONDecoder().decode([String: String].self, from: Data(contentsOf: manifestURL))) ?? [:]

let client = VolcengineTTS(settings: settings)
var generated = 0
var skipped = 0
var failed: [(String, String)] = []
print("音色 \(settings.voiceTag)，共 \(texts.count) 句 → \(out.path)")

for (index, text) in texts.enumerated() {
    let name = SpeechText.fileName(for: text)
    let file = out.appendingPathComponent(name)
    manifest[name] = text
    if !force, FileManager.default.fileExists(atPath: file.path) {
        skipped += 1
        continue
    }
    do {
        let audio = try await client.synthesize(text)
        try audio.write(to: file, options: .atomic)
        generated += 1
        print("[\(index + 1)/\(texts.count)] \(name) \(text)")
    } catch {
        failed.append((text, error.localizedDescription))
        print("[\(index + 1)/\(texts.count)] 失败：\(text)：\(error.localizedDescription)")
        if (error as? TTSError)?.needsSettingsChange == true { break }
    }
}

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
try encoder.encode(manifest).write(to: manifestURL, options: .atomic)

print("生成 \(generated) 句，跳过已有 \(skipped) 句，失败 \(failed.count) 句")
if !failed.isEmpty { exit(2) }
