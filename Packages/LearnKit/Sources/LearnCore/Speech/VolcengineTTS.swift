import Foundation

/// 火山引擎（豆包语音）语音合成的账号和音色设置。
/// App 里存在钥匙串（不写进数据库和 JSON）；命令行工具从环境变量读。
public struct TTSSettings: Codable, Equatable, Sendable {
    /// 新版控制台的 API Key（填了它就不用 appID / accessToken）
    public var apiKey: String
    /// 旧版控制台的 APP ID 和 Access Token
    public var appID: String
    public var accessToken: String
    /// seed-tts-2.0 只能用 2.0 音色；seed-tts-1.0 只能用 1.0 音色
    public var resourceID: String
    /// 中文和中英混合的句子用的音色（发音人），见火山引擎「音色列表」
    public var speaker: String
    /// 纯英文句子（英语题库的单词、句子）用的音色
    public var englishSpeaker: String
    /// 语速，[-50, 100]，0 为正常，-50 为 0.5 倍
    public var speechRate: Int

    public static let defaultResourceID = "seed-tts-2.0"
    public static let defaultSpeaker = "zh_female_vv_uranus_bigtts"
    /// 英语题库的音标是英式的，默认用英式女声
    public static let defaultEnglishSpeaker = "en_female_authoritative-british_uranus_bigtts"
    /// 给孩子听，比正常略慢一点
    public static let defaultSpeechRate = -10
    /// 以前用过的默认音色，读到时换成 defaultSpeaker
    static let retiredDefaultSpeakers: Set<String> = ["zh_female_xiaohe_uranus_bigtts"]

    /// 官方推荐的 2.0 音色（豆包语音合成模型 2.0）
    public struct Voice: Sendable, Identifiable {
        public var id: String
        public var name: String
    }

    public static let chineseVoices = [
        Voice(id: "zh_female_vv_uranus_bigtts", name: "Vivi 2.0（通用女声，中英混合）"),
        Voice(id: "zh_male_m191_uranus_bigtts", name: "云舟 2.0（通用男声，中英混合）"),
    ]

    public static let englishVoices = [
        Voice(id: "en_female_authoritative-british_uranus_bigtts", name: "Charlotte（英式女声）"),
        Voice(id: "en_female_female_tutor_ms-jenny_uranus_bigtts", name: "Holly（美式女声，教学）"),
        Voice(id: "en_female_hayley_uranus_bigtts", name: "Hayley（美式女声）"),
        Voice(id: "en_male_alberto_uranus_bigtts", name: "Alberto（美式男声）"),
    ]

    public init(
        apiKey: String = "", appID: String = "", accessToken: String = "",
        resourceID: String = TTSSettings.defaultResourceID,
        speaker: String = TTSSettings.defaultSpeaker,
        englishSpeaker: String = TTSSettings.defaultEnglishSpeaker,
        speechRate: Int = TTSSettings.defaultSpeechRate
    ) {
        self.apiKey = apiKey
        self.appID = appID
        self.accessToken = accessToken
        self.resourceID = resourceID
        self.speaker = speaker
        self.englishSpeaker = englishSpeaker
        self.speechRate = speechRate
    }

    /// 旧版本存的设置缺少后来加的字段时用默认值，不用重新填 key
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = TTSSettings()
        apiKey = try c.decodeIfPresent(String.self, forKey: .apiKey) ?? defaults.apiKey
        appID = try c.decodeIfPresent(String.self, forKey: .appID) ?? defaults.appID
        accessToken = try c.decodeIfPresent(String.self, forKey: .accessToken) ?? defaults.accessToken
        resourceID = try c.decodeIfPresent(String.self, forKey: .resourceID) ?? defaults.resourceID
        speaker = try c.decodeIfPresent(String.self, forKey: .speaker) ?? defaults.speaker
        // 早期版本的默认音色不在官方推荐列表里（账号可能没有权限），换成现在的默认
        if Self.retiredDefaultSpeakers.contains(speaker) { speaker = defaults.speaker }
        englishSpeaker = try c.decodeIfPresent(String.self, forKey: .englishSpeaker) ?? defaults.englishSpeaker
        speechRate = try c.decodeIfPresent(Int.self, forKey: .speechRate) ?? defaults.speechRate
    }

    /// 账号信息齐全，可以调用接口
    public var isUsable: Bool {
        let hasKey = !apiKey.trimmed.isEmpty
        let hasLegacy = !appID.trimmed.isEmpty && !accessToken.trimmed.isEmpty
        return (hasKey || hasLegacy) && !resourceID.trimmed.isEmpty
            && !speaker.trimmed.isEmpty && !englishSpeaker.trimmed.isEmpty
    }

    /// 这句话用哪个音色：纯英文用英语音色，其余（中文、中英混合）用中文音色
    public func speaker(for text: String) -> String {
        SpeechText.isEnglish(text) ? englishSpeaker.trimmed : speaker.trimmed
    }

    /// 区分缓存音频用：换了模型、音色或语速，旧缓存就不再使用
    public var voiceTag: String {
        "\(resourceID.trimmed)/\(speaker.trimmed)/\(englishSpeaker.trimmed)/\(speechRate)"
    }

    /// 从环境变量读：VOLC_TTS_API_KEY，或 VOLC_TTS_APP_ID + VOLC_TTS_ACCESS_TOKEN；
    /// 可选 VOLC_TTS_RESOURCE_ID、VOLC_TTS_SPEAKER、VOLC_TTS_ENGLISH_SPEAKER、VOLC_TTS_SPEECH_RATE
    public static func fromEnvironment(_ env: [String: String] = ProcessInfo.processInfo.environment) -> TTSSettings {
        TTSSettings(
            apiKey: env["VOLC_TTS_API_KEY"] ?? "",
            appID: env["VOLC_TTS_APP_ID"] ?? "",
            accessToken: env["VOLC_TTS_ACCESS_TOKEN"] ?? "",
            resourceID: env["VOLC_TTS_RESOURCE_ID"] ?? defaultResourceID,
            speaker: env["VOLC_TTS_SPEAKER"] ?? defaultSpeaker,
            englishSpeaker: env["VOLC_TTS_ENGLISH_SPEAKER"] ?? defaultEnglishSpeaker,
            speechRate: env["VOLC_TTS_SPEECH_RATE"].flatMap(Int.init) ?? defaultSpeechRate)
    }
}

public enum TTSError: Error, LocalizedError, Equatable {
    case notConfigured
    /// HTTP 状态码不是 200
    case http(status: Int, message: String)
    /// 接口返回的业务错误码
    case service(code: Int, message: String)
    case badResponse
    case emptyAudio

    public var errorDescription: String? {
        switch self {
        case .notConfigured: "还没有填写语音合成的 API Key"
        case .http(let status, let message):
            switch status {
            case 401: "API Key 不对（HTTP 401）：\(message)"
            case 403: "账号没有权限（HTTP 403），请在火山引擎控制台确认已开通「豆包语音合成模型 2.0」，并且这个音色可用：\(message)"
            default: "语音合成请求失败（HTTP \(status)）：\(message)"
            }
        case .service(let code, let message): "语音合成出错（\(code)）：\(message)"
        case .badResponse: "语音合成返回的内容看不懂"
        case .emptyAudio: "语音合成没有返回音频"
        }
    }

    /// 账号、权限、参数类错误：重试也没用，要等家长改设置
    public var needsSettingsChange: Bool {
        switch self {
        case .notConfigured: true
        case .http(let status, _): (400..<500).contains(status) && status != 429
        case .service(let code, _): code >= 40_000_000 && code < 50_000_000
        case .badResponse, .emptyAudio: false
        }
    }
}

/// 火山引擎语音合成 V3 HTTP Chunked 单向流式接口：一次传入整句文本，返回 mp3。
/// 文档：https://www.volcengine.com/docs/6561/1598757
public struct VolcengineTTS: Sendable {
    public static let endpoint = URL(string: "https://openspeech.bytedance.com/api/v3/tts/unidirectional")!
    /// 结束包的 code
    static let finishedCode = 20_000_000

    public let settings: TTSSettings
    private let session: URLSession

    public init(settings: TTSSettings, session: URLSession = .shared) {
        self.settings = settings
        self.session = session
    }

    /// 合成一句话，返回 mp3 数据
    public func synthesize(_ text: String) async throws -> Data {
        let (body, response) = try await session.data(for: request(for: text))
        let http = response as? HTTPURLResponse
        let status = http?.statusCode ?? 0
        guard status == 200 else {
            let logID = http?.value(forHTTPHeaderField: "X-Tt-Logid") ?? "-"
            // 排查用：不含 key
            print("语音合成失败 HTTP \(status) logid=\(logID) resource=\(settings.resourceID) speaker=\(settings.speaker(for: text)) body=\(String(decoding: body.prefix(500), as: UTF8.self))")
            var message = Self.errorMessage(body)
            message += "\n音色 \(settings.speaker(for: text))，logid \(logID)"
            throw TTSError.http(status: status, message: message)
        }
        return try Self.decodeAudio(body)
    }

    /// 错误返回体：{"header":{"code":45000010,"message":"Invalid X-Api-Key"}}，或 {"code":..,"message":..}
    static func errorMessage(_ body: Data) -> String {
        guard let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            return String(decoding: body.prefix(300), as: UTF8.self)
        }
        let fields = json["header"] as? [String: Any] ?? json
        let code = (fields["code"] as? NSNumber).map { "\($0.intValue) " } ?? ""
        let message = fields["message"] as? String ?? String(decoding: body.prefix(300), as: UTF8.self)
        return "\(code)\(message)"
    }

    public func request(for text: String) throws -> URLRequest {
        guard settings.isUsable else { throw TTSError.notConfigured }
        var request = URLRequest(url: Self.endpoint, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !settings.apiKey.trimmed.isEmpty {
            request.setValue(settings.apiKey.trimmed, forHTTPHeaderField: "X-Api-Key")
        } else {
            request.setValue(settings.appID.trimmed, forHTTPHeaderField: "X-Api-App-Id")
            request.setValue(settings.accessToken.trimmed, forHTTPHeaderField: "X-Api-Access-Key")
        }
        request.setValue(settings.resourceID.trimmed, forHTTPHeaderField: "X-Api-Resource-Id")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Api-Request-Id")
        let payload = Payload(
            user: .init(uid: "learn-defense"),
            req_params: .init(
                text: text,
                speaker: settings.speaker(for: text),
                audio_params: .init(format: "mp3", sample_rate: 24_000, speech_rate: settings.speechRate)))
        request.httpBody = try JSONEncoder().encode(payload)
        return request
    }

    /// 返回体是一串 JSON 对象：音频包 {"code":0,"data":"<base64>"}，
    /// 结束包 {"code":20000000}，其余 code 为错误。把音频包按顺序拼起来。
    public static func decodeAudio(_ body: Data) throws -> Data {
        var audio = Data()
        for object in try splitJSONObjects(body) {
            guard let json = try? JSONSerialization.jsonObject(with: object) as? [String: Any],
                  let code = (json["code"] as? NSNumber)?.intValue
            else { throw TTSError.badResponse }
            switch code {
            case 0:
                if let base64 = json["data"] as? String {
                    guard let chunk = Data(base64Encoded: base64) else { throw TTSError.badResponse }
                    audio.append(chunk)
                }
            case finishedCode:
                break
            default:
                throw TTSError.service(code: code, message: json["message"] as? String ?? "")
            }
        }
        guard !audio.isEmpty else { throw TTSError.emptyAudio }
        return audio
    }

    /// 按花括号配对切出顶层 JSON 对象（对象之间可能有换行，也可能紧挨着）
    static func splitJSONObjects(_ data: Data) throws -> [Data] {
        let bytes = [UInt8](data)
        var objects: [Data] = []
        var depth = 0
        var start = 0
        var inString = false
        var escaped = false
        for (i, byte) in bytes.enumerated() {
            if inString {
                if escaped { escaped = false }
                else if byte == UInt8(ascii: "\\") { escaped = true }
                else if byte == UInt8(ascii: "\"") { inString = false }
                continue
            }
            switch byte {
            case UInt8(ascii: "\""):
                inString = true
            case UInt8(ascii: "{"):
                if depth == 0 { start = i }
                depth += 1
            case UInt8(ascii: "}"):
                depth -= 1
                if depth < 0 { throw TTSError.badResponse }
                if depth == 0 { objects.append(Data(bytes[start...i])) }
            default:
                break
            }
        }
        guard depth == 0, !inString else { throw TTSError.badResponse }
        return objects
    }

    // 字段名与接口文档一致
    private struct Payload: Encodable {
        struct User: Encodable { var uid: String }
        struct AudioParams: Encodable {
            var format: String
            var sample_rate: Int
            var speech_rate: Int
        }
        struct ReqParams: Encodable {
            var text: String
            var speaker: String
            var audio_params: AudioParams
        }
        var user: User
        var req_params: ReqParams
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
