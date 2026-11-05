import AVFoundation

/// 系统语音朗读。拼音等对读音要求高的内容，以后可以换成预先录好的音频。
@MainActor
final class Speech {
    private let synthesizer = AVSpeechSynthesizer()
    private let voice = AVSpeechSynthesisVoice(language: "zh-CN")

    init() {
        #if os(iOS)
        // 静音模式下也要能听到读音
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        #endif
    }

    /// interrupt 为 true 时打断正在读的内容，否则排队读
    func speak(_ text: String?, interrupt: Bool) {
        guard let text, !text.isEmpty else { return }
        if interrupt { synthesizer.stopSpeaking(at: .immediate) }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = 0.42
        utterance.pitchMultiplier = 1.1
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}
