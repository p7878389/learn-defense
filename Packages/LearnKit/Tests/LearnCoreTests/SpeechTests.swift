import Foundation
import SwiftData
import Testing
@testable import LearnCore

@Suite("朗读文本")
struct SpeechTextTests {
    static let library = ContentLibrary.load(userDirectory: nil)

    @Test func keyIsStableAndIgnoresSurroundingWhitespace() {
        // 与 Python hashlib.sha256("你好".encode()).hexdigest()[:32] 一致，服务端可以用同样规则命名
        #expect(SpeechText.key(for: "你好") == "670d9743542cae3ea7ebe36af56bd536")
        #expect(SpeechText.key(for: " 你好\n") == SpeechText.key(for: "你好"))
        #expect(SpeechText.fileName(for: "你好") == "670d9743542cae3ea7ebe36af56bd536.mp3")
        #expect(SpeechText.normalize("  ") == nil)
    }

    /// 出题时实际朗读的每一句，都要在预先生成的清单里，否则高质量语音命中不了
    @Test(arguments: Difficulty.allCases)
    func everySpokenLineIsListed(difficulty: Difficulty) {
        let groups = Set(Self.library.packs.map { "\($0.grade.rawValue)|\($0.subject.rawValue)" })
        #expect(groups.contains { $0.hasSuffix("|english") }, "要覆盖英语题库")
        for group in groups {
            let parts = group.split(separator: "|").map(String.init)
            let grade = Grade(rawValue: parts[0])!
            let packs = Self.library.packs(grade: grade, subject: Subject(rawValue: parts[1])!)
            let listed = Set(SpeechText.texts(in: packs))
            let pool = ItemPool(packs: packs, selection: .all)
            let generator = QuestionGenerator(pool: pool, settings: GameTuning.make(grade: grade, difficulty: difficulty).generator)
            var rng = SeededRNG(state: 7)
            for item in pool.items {
                for _ in 0..<8 {
                    guard let q = generator.makeQuestion(for: item, using: &rng) else { continue }
                    for line in [q.promptSpeech, q.answerSpeech].compactMap({ $0 }).compactMap(SpeechText.normalize) {
                        #expect(listed.contains(line), "\(item.key) 的「\(line)」不在清单里")
                    }
                }
            }
        }
    }

    @Test func gameLinesCoverFixedPrompts() {
        let lines = SpeechText.gameLines
        #expect(lines.contains(SpeechText.Line.battleStart))
        #expect(lines.contains(SpeechText.Line.planted(DefenderKind.inkling.name)))
        #expect(lines.contains(ItemKind.frostCharm.name))
        #expect(Set(lines).count == lines.count)
        // 首领和大招的播报都会预先生成：每个可能当首领的怪物一句出场，加暴走、击杀、两种大招
        for boss in [EnemyKind.king] + EnemyKind.forestBosses {
            #expect(lines.contains("小心，\(boss.name)来了！"))
        }
        #expect(lines.contains(SpeechText.Line.bossEnraged))
        #expect(lines.contains(SpeechText.Line.bossDefeated))
        #expect(lines.contains("成语大招，发射！") && lines.contains("彩虹大招，发射！"))
        // 每一档难度的首领候选都有出场播报
        for grade in Grade.allCases {
            for difficulty in Difficulty.allCases {
                for boss in GameTuning.make(grade: grade, difficulty: difficulty).waves.bosses {
                    #expect(lines.contains(SpeechText.Line.bossArrive(boss.name)), "\(boss.id)")
                }
            }
        }
    }
}

@Suite("火山引擎语音合成")
struct VolcengineTTSTests {
    @Test func decodesChunkedAudio() throws {
        // [1,2,3] 和 [4,5] 两个音频包，再加结束包；message 里的花括号不能打乱切分
        let separated = """
        {"code":0,"message":"","data":"AQID"}
        {"code":0,"message":"a{b}\\"c","data":"BAU="}
        {"code":0,"message":"","data":null,"sentence":{"text":"你好"}}
        {"code":20000000,"message":"ok","data":null}
        """
        #expect(try VolcengineTTS.decodeAudio(Data(separated.utf8)) == Data([1, 2, 3, 4, 5]))

        let joined = #"{"code":0,"data":"AQID"}{"code":0,"data":"BAU="}{"code":20000000}"#
        #expect(try VolcengineTTS.decodeAudio(Data(joined.utf8)) == Data([1, 2, 3, 4, 5]))
    }

    @Test func reportsServiceErrors() {
        let body = #"{"code":45000000,"message":"speaker permission denied","data":null}"#
        #expect(throws: TTSError.service(code: 45_000_000, message: "speaker permission denied")) {
            try VolcengineTTS.decodeAudio(Data(body.utf8))
        }
        #expect(TTSError.service(code: 45_000_000, message: "").needsSettingsChange)
        #expect(TTSError.http(status: 401, message: "").needsSettingsChange)
        #expect(!TTSError.http(status: 503, message: "").needsSettingsChange)
        #expect(throws: TTSError.emptyAudio) {
            try VolcengineTTS.decodeAudio(Data(#"{"code":20000000}"#.utf8))
        }
        #expect(throws: TTSError.badResponse) {
            try VolcengineTTS.decodeAudio(Data(#"{"code":0,"data":"AQID""#.utf8))
        }
    }

    @Test func readsErrorMessageFromBody() {
        let header = #"{"header":{"reqid":"x","code":45000010,"message":"Invalid X-Api-Key"}}"#
        #expect(VolcengineTTS.errorMessage(Data(header.utf8)) == "45000010 Invalid X-Api-Key")
        let flat = #"{"code":45000030,"message":"resource not granted"}"#
        #expect(VolcengineTTS.errorMessage(Data(flat.utf8)) == "45000030 resource not granted")
        #expect(VolcengineTTS.errorMessage(Data("forbidden".utf8)) == "forbidden")
    }

    @Test func buildsRequestWithApiKey() throws {
        let tts = VolcengineTTS(settings: TTSSettings(apiKey: " key-1 ", speaker: "zh_test", speechRate: -20))
        let request = try tts.request(for: "晨，早晨的晨")
        #expect(request.url == VolcengineTTS.endpoint)
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "X-Api-Key") == "key-1")
        #expect(request.value(forHTTPHeaderField: "X-Api-App-Id") == nil)
        #expect(request.value(forHTTPHeaderField: "X-Api-Resource-Id") == "seed-tts-2.0")

        let body = try #require(request.httpBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        let params = try #require(json["req_params"] as? [String: Any])
        #expect(params["text"] as? String == "晨，早晨的晨")
        #expect(params["speaker"] as? String == "zh_test")
        let audio = try #require(params["audio_params"] as? [String: Any])
        #expect(audio["format"] as? String == "mp3")
        #expect(audio["speech_rate"] as? Int == -20)
    }

    @Test func buildsRequestWithLegacyAccount() throws {
        let tts = VolcengineTTS(settings: TTSSettings(appID: "123", accessToken: "token"))
        let request = try tts.request(for: "你好")
        #expect(request.value(forHTTPHeaderField: "X-Api-App-Id") == "123")
        #expect(request.value(forHTTPHeaderField: "X-Api-Access-Key") == "token")
        #expect(request.value(forHTTPHeaderField: "X-Api-Key") == nil)

        #expect(throws: TTSError.notConfigured) {
            try VolcengineTTS(settings: TTSSettings(appID: "123")).request(for: "你好")
        }
    }

    @Test func voiceTagChangesWithVoiceAndRate() {
        let base = TTSSettings(apiKey: "k")
        var other = base
        other.speechRate += 5
        #expect(base.voiceTag != other.voiceTag)
        var newKey = base
        newKey.apiKey = "k2"
        #expect(base.voiceTag == newKey.voiceTag, "换 key 不该让缓存失效")
    }

    @Test func pureEnglishUsesEnglishSpeaker() throws {
        #expect(SpeechText.isEnglish("apple"))
        #expect(SpeechText.isEnglish("What's your name?"))
        #expect(SpeechText.isEnglish("café"))
        #expect(!SpeechText.isEnglish("apple，苹果"))
        #expect(!SpeechText.isEnglish("晨，早晨的晨"))
        #expect(!SpeechText.isEnglish("123！"))

        let settings = TTSSettings(apiKey: "k")
        #expect(settings.speaker(for: "apple") == TTSSettings.defaultEnglishSpeaker)
        #expect(settings.speaker(for: "apple，苹果") == "zh_female_vv_uranus_bigtts")

        let body = try #require(try VolcengineTTS(settings: settings).request(for: "Hello!").httpBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        let params = try #require(json["req_params"] as? [String: Any])
        #expect(params["speaker"] as? String == TTSSettings.defaultEnglishSpeaker)
    }

    /// 早先存进钥匙串的设置没有 englishSpeaker 字段，升级后要能读出来，不用重新填 key
    @Test func decodesSettingsSavedBeforeEnglishSpeaker() throws {
        let old = #"{"apiKey":"k","appID":"","accessToken":"","resourceID":"seed-tts-2.0","speaker":"zh_x","speechRate":-10}"#
        let settings = try JSONDecoder().decode(TTSSettings.self, from: Data(old.utf8))
        #expect(settings.apiKey == "k")
        #expect(settings.speaker == "zh_x")
        #expect(settings.englishSpeaker == TTSSettings.defaultEnglishSpeaker)
        #expect(settings.isUsable)

        // 早期默认音色自动换成现在的默认
        let retired = #"{"apiKey":"k","speaker":"zh_female_xiaohe_uranus_bigtts"}"#
        #expect(try JSONDecoder().decode(TTSSettings.self, from: Data(retired.utf8)).speaker == TTSSettings.defaultSpeaker)
    }

    @Test func readsSettingsFromEnvironment() {
        let settings = TTSSettings.fromEnvironment(["VOLC_TTS_API_KEY": "abc", "VOLC_TTS_SPEECH_RATE": "5"])
        #expect(settings.isUsable)
        #expect(settings.speechRate == 5)
        #expect(settings.speaker == TTSSettings.defaultSpeaker)
        #expect(!TTSSettings.fromEnvironment([:]).isUsable)
    }
}

@Suite("语音缓存表")
struct SpeechCacheTests {
    @Test func savesAndClearsClipsPerVoice() throws {
        let db = try LearnDatabase(url: nil)
        try db.saveSpeechClip(key: "k1", voice: "v1", text: "你好", fileName: "a/k1.mp3", bytes: 10)
        try db.saveSpeechClip(key: "k1", voice: "v1", text: "你好", fileName: "a/k1.mp3", bytes: 12)
        try db.saveSpeechClip(key: "k2", voice: "v2", text: "再见", fileName: "b/k2.mp3", bytes: 20)

        #expect(try db.speechClip(key: "k1", voice: "v1")?.bytes == 12)
        #expect(try db.speechClipKeys(voice: "v1") == ["k1"])

        let removed = try db.deleteSpeechClips(exceptVoice: "v1")
        #expect(removed == ["b/k2.mp3"])
        #expect(try db.speechClip(key: "k2", voice: "v2") == nil)
        #expect(try db.speechClipKeys(voice: "v1") == ["k1"])

        try db.deleteSpeechClips(exceptVoice: nil)
        #expect(try db.context.fetch(FetchDescriptor<StoredSpeechClip>()).isEmpty)
    }

    /// 已经装过旧版本（没有语音缓存表）的数据库文件，升级后要能直接打开，原有数据不丢
    @Test func opensDatabaseCreatedBeforeSpeechCache() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("learn.store")

        do {
            let oldSchema = Schema([
                StoredPack.self, StoredItem.self, StoredItemStats.self,
                StoredProfile.self, StoredGrowth.self,
                StoredGame.self, StoredAnswer.self,
                StoredConfigFile.self, StoredBadge.self, StoredCosmetic.self,
            ])
            let container = try ModelContainer(for: oldSchema, configurations: [ModelConfiguration(schema: oldSchema, url: url)])
            let context = ModelContext(container)
            context.insert(StoredConfigFile(name: "pacing.json", data: Data("{}".utf8)))
            try context.save()
        }

        let db = try LearnDatabase(url: url)
        #expect(try db.configFile(named: "pacing.json") != nil)
        try db.saveSpeechClip(key: "k", voice: "v", text: "你好", fileName: "x/k.mp3", bytes: 1)
        #expect(try db.speechClipKeys(voice: "v") == ["k"])
    }
}
