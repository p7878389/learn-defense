import AVFoundation

/// 系统语音朗读。拼音等对读音要求高的内容，以后可以换成预先录好的音频。
@MainActor
final class Speech {
    private let synthesizer = AVSpeechSynthesizer()
    private let voice = AVSpeechSynthesisVoice(language: "zh-CN")
    /// 英语题库的音标是英式的，用英式发音
    private let englishVoice = AVSpeechSynthesisVoice(language: "en-GB")

    init() {
        #if os(iOS)
        // 静音模式下也要能听到读音
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        #endif
    }

    /// interrupt 为 true 时打断正在读的内容，否则排队读。
    /// 中英混排时分段，英文用英语语音读（纯中文仍是一整句）
    func speak(_ text: String?, interrupt: Bool) {
        guard let text, !text.isEmpty else { return }
        if interrupt { synthesizer.stopSpeaking(at: .immediate) }
        for part in Self.segments(text) {
            let utterance = AVSpeechUtterance(string: part.text)
            utterance.voice = part.english ? englishVoice : voice
            utterance.rate = 0.42
            utterance.pitchMultiplier = 1.1
            synthesizer.speak(utterance)
        }
    }

    /// 按拉丁字母（含带重音的）和其他文字切段；标点、数字、空格跟着前一段，只有标点的段丢掉
    nonisolated static func segments(_ text: String) -> [(text: String, english: Bool)] {
        var result: [(text: String, english: Bool)] = []
        var current = ""
        var english: Bool?
        var hasLetter = false
        for ch in text {
            let latin = ch.unicodeScalars.first.map { $0.value < 0x0250 } ?? false
            let kind: Bool? = ch.isLetter ? latin : nil
            if let kind, let english, kind != english {
                if hasLetter { result.append((current, english)) }
                current = ""
                hasLetter = false
            }
            if let kind {
                english = kind
                hasLetter = true
            }
            current.append(ch)
        }
        if hasLetter { result.append((current, english ?? false)) }
        return result
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}
