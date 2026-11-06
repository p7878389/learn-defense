import AVFoundation
import LearnCore

/// 朗读。有预先生成的高质量语音（见 SpeechLibrary）就播放音频文件，
/// 没有就用系统语音读，并在后台生成，下次读到同一句时换成高质量语音。
@MainActor
final class Speech: NSObject {
    let library: SpeechLibrary?
    private let synthesizer = AVSpeechSynthesizer()
    private let voice = Speech.bestSystemVoice(language: "zh-CN")
    /// 英语题库的音标是英式的，用英式发音
    private let englishVoice = Speech.bestSystemVoice(language: "en-GB")
    private var player: AVAudioPlayer?
    /// 系统语音正在读的这句话的最后一段；读完它才算这句读完
    private var utterance: AVSpeechUtterance?
    /// 排队等着读的文本
    private var queue: [String] = []

    init(library: SpeechLibrary? = nil) {
        self.library = library
        super.init()
        synthesizer.delegate = self
        #if os(iOS)
        // 静音模式下也要能听到读音
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        #endif
    }

    /// interrupt 为 true 时打断正在读的内容，否则排队读
    func speak(_ text: String?, interrupt: Bool) {
        guard let text = text.flatMap(SpeechText.normalize) else { return }
        if interrupt { stop() }
        queue.append(text)
        if !isPlaying { playNext() }
    }

    func stop() {
        queue.removeAll()
        player?.stop()
        player = nil
        utterance = nil
        synthesizer.stopSpeaking(at: .immediate)
    }

    private var isPlaying: Bool { player != nil || utterance != nil }

    private func playNext() {
        guard !queue.isEmpty else { return }
        let text = queue.removeFirst()
        if let url = library?.audioFile(for: text), let player = try? AVAudioPlayer(contentsOf: url) {
            player.delegate = self
            self.player = player
            if player.play() { return }
            self.player = nil
        }
        library?.requestSoon(text)
        speakWithSystemVoice(text)
    }

    /// 中英混排时分段，英文用英语语音读（纯中文仍是一整句）
    private func speakWithSystemVoice(_ text: String) {
        var last: AVSpeechUtterance?
        for part in Self.segments(text) {
            let utterance = AVSpeechUtterance(string: part.text)
            utterance.voice = part.english ? englishVoice : voice
            // 比默认（0.5）稍慢，方便孩子听清；不改音调，改了反而更像机器声
            utterance.rate = 0.46
            utterance.pitchMultiplier = 1.0
            synthesizer.speak(utterance)
            last = utterance
        }
        utterance = last
        // 只有标点、没有可读内容：直接读下一句
        if last == nil { playNext() }
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

    private func finished(player id: ObjectIdentifier) {
        guard let player, ObjectIdentifier(player) == id else { return }
        self.player = nil
        playNext()
    }

    private func finished(utterance id: ObjectIdentifier) {
        guard let utterance, ObjectIdentifier(utterance) == id else { return }
        self.utterance = nil
        playNext()
    }

    // MARK: - 系统语音

    /// 系统里品质最好的语音。增强 / 高品质语音需要先在
    /// 「设置 → 辅助功能 → 朗读内容 → 声音」里下载，没下载时只有默认的精简版
    static func bestSystemVoice(language: String) -> AVSpeechSynthesisVoice? {
        let candidates = AVSpeechSynthesisVoice.speechVoices().filter {
            $0.language == language && !$0.voiceTraits.contains(.isNoveltyVoice)
        }
        return candidates.max { $0.quality.rawValue < $1.quality.rawValue }
            ?? AVSpeechSynthesisVoice(language: language)
    }

    /// 设置页显示：当前用的系统语音和品质
    var systemVoiceDescription: String {
        [("中文", voice), ("英语", englishVoice)]
            .map { label, voice in voice.map { "\(label)：\($0.name)（\(Self.qualityName($0))）" } ?? "\(label)：无" }
            .joined(separator: "\n")
    }

    var systemVoiceIsCompact: Bool {
        [voice, englishVoice].contains { voice in
            guard let voice else { return true }
            return voice.quality != .enhanced && voice.quality != .premium
        }
    }

    private static func qualityName(_ voice: AVSpeechSynthesisVoice) -> String {
        switch voice.quality {
        case .premium: "高品质"
        case .enhanced: "增强"
        default: "精简"
        }
    }
}

extension Speech: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let id = ObjectIdentifier(player)
        Task { @MainActor in self.finished(player: id) }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        let id = ObjectIdentifier(player)
        Task { @MainActor in self.finished(player: id) }
    }
}

extension Speech: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.finished(utterance: id) }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.finished(utterance: id) }
    }
}
