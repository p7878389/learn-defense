import AVFoundation
import Foundation

/// 独立短提示音，不占用题目朗读队列，也不触发语音合成请求。
@MainActor
final class AnswerFeedback {
    /// 提示音的种类
    enum Cue: CaseIterable {
        case correct, wrong
        /// 首领登场：低沉的「咚、咚、咚——」三声号角
        case bossArrive
        /// 首领暴走：越来越急的警报，末尾一声低吼
        case bossEnrage
        /// 打败首领：一串上行的胜利音
        case bossDefeated
        /// 大招释放：蓄力的上滑音，接一声轰响和高处的余音
        case ultimateCast
        /// 大招能量充满：两声上行的轻铃，比释放轻得多
        case ultimateReady

        /// 首领和大招的音效较长，单独占一个播放位，不会被紧跟着的答题提示音掐断
        fileprivate var isBossCue: Bool { self != .correct && self != .wrong }
    }

    private var player: AVAudioPlayer?
    private var bossPlayer: AVAudioPlayer?

    func play(correct: Bool, volume: Float = 0.45) {
        play(correct ? .correct : .wrong, volume: volume)
    }

    func play(_ cue: Cue, volume: Float = 0.45) {
        do {
            let player = try AVAudioPlayer(data: Self.wave(cue))
            player.volume = volume
            // 充满提示只是点缀：首领或大招的长音效还在响时不去打断它。
            if cue == .ultimateReady && bossPlayer?.isPlaying == true { return }
            if cue.isBossCue { bossPlayer = player } else { self.player = player }
            player.play()
        } catch {
            print("提示音播放失败：\(error)")
        }
    }

    static func wave(_ cue: Cue) -> Data {
        switch cue {
        case .correct: wave(correct: true)
        case .wrong: wave(correct: false)
        case .bossArrive: wav(Self.bossArrive)
        case .bossEnrage: wav(Self.bossEnrage)
        case .bossDefeated: wav(Self.bossDefeated)
        case .ultimateCast: wav(Self.ultimateCast)
        case .ultimateReady: wav(Self.ultimateReady)
        }
    }

    /// 一个音：从 start 秒开始响 duration 秒。harmonics 是各次泛音的相对音量（第一个是基音），
    /// 泛音越多越像号角；glide 不为 nil 时音高从 frequency 滑到 glide
    struct Tone {
        var start: Double
        var duration: Double
        var frequency: Double
        var amplitude: Double
        var harmonics: [Double] = [1]
        var glide: Double?
        /// 指数衰减的快慢，0 表示不衰减（鼓点用大一点的值）
        var decay: Double = 0
    }

    /// 首领登场：G3、G3、降 E3 三声号角（最后一声拖长下滑），每声带一下鼓点
    static let bossArrive: [Tone] = {
        let horn = [1, 0.55, 0.35, 0.2, 0.1]
        var tones: [Tone] = []
        for (start, duration, frequency, glide) in [(0.0, 0.26, 196.0, nil as Double?), (0.32, 0.26, 196.0, nil),
                                                    (0.64, 0.75, 155.56, 146.83)] {
            tones.append(Tone(start: start, duration: duration, frequency: frequency, amplitude: 0.42,
                              harmonics: horn, glide: glide))
            tones.append(Tone(start: start, duration: 0.2, frequency: 130, amplitude: 0.5, glide: 75, decay: 16))
        }
        return tones
    }()

    /// 首领暴走：三声越来越高、越来越密的警报（A4、C5、降 E5，减三和弦听着紧张），
    /// 最后一声从 G3 往下滑的低吼
    static let bossEnrage: [Tone] = {
        var tones: [Tone] = []
        for (start, frequency) in [(0.0, 440.0), (0.17, 523.25), (0.31, 622.25)] {
            tones.append(Tone(start: start, duration: 0.12, frequency: frequency, amplitude: 0.34,
                              harmonics: [1, 0.6, 0.4, 0.25], glide: frequency * 1.06))
        }
        tones.append(Tone(start: 0.44, duration: 0.5, frequency: 196, amplitude: 0.5,
                          harmonics: [1, 0.7, 0.5, 0.35, 0.2], glide: 110, decay: 2))
        tones.append(Tone(start: 0.44, duration: 0.22, frequency: 140, amplitude: 0.45, glide: 70, decay: 14))
        return tones
    }()

    /// 能量充满：G5、C6 两声轻铃，晚 0.18 秒起，排在答对提示音之后
    static let ultimateReady: [Tone] = [
        Tone(start: 0.18, duration: 0.16, frequency: 783.99, amplitude: 0.22, harmonics: [1, 0.3], decay: 9),
        Tone(start: 0.3, duration: 0.24, frequency: 1046.5, amplitude: 0.26, harmonics: [1, 0.3], decay: 7),
    ]

    /// 大招释放：0.45 秒从 C4 滑到 C6 的蓄力（叠一层高八度），落在一声轰响上，
    /// 再用 C6、E6、G6 三个渐弱的高音收尾
    static let ultimateCast: [Tone] = [
        Tone(start: 0, duration: 0.45, frequency: 261.63, amplitude: 0.3, harmonics: [1, 0.4, 0.2], glide: 1046.5),
        Tone(start: 0, duration: 0.45, frequency: 523.25, amplitude: 0.14, glide: 2093),
        Tone(start: 0.45, duration: 0.45, frequency: 160, amplitude: 0.6, harmonics: [1, 0.5, 0.3], glide: 55, decay: 7),
        Tone(start: 0.45, duration: 0.5, frequency: 1046.5, amplitude: 0.26, harmonics: [1, 0.3], decay: 5),
        Tone(start: 0.55, duration: 0.45, frequency: 1318.51, amplitude: 0.2, harmonics: [1, 0.3], decay: 5),
        Tone(start: 0.65, duration: 0.5, frequency: 1567.98, amplitude: 0.18, harmonics: [1, 0.3], decay: 5),
    ]

    /// 打败首领：C5、E5、G5 快速上行，停在高八度的 C6，末尾再点一下更高的 G6
    static let bossDefeated: [Tone] = [
        Tone(start: 0, duration: 0.12, frequency: 523.25, amplitude: 0.4, harmonics: [1, 0.3]),
        Tone(start: 0.11, duration: 0.12, frequency: 659.25, amplitude: 0.4, harmonics: [1, 0.3]),
        Tone(start: 0.22, duration: 0.12, frequency: 783.99, amplitude: 0.4, harmonics: [1, 0.3]),
        Tone(start: 0.33, duration: 0.5, frequency: 1046.5, amplitude: 0.42, harmonics: [1, 0.3], decay: 3),
        Tone(start: 0.45, duration: 0.38, frequency: 1567.98, amplitude: 0.18, decay: 5),
    ]

    static let sampleRate = 22050

    /// 把几个音混在一起，生成 16 位单声道 PCM WAV。每个音首尾有包络，避免爆音；混音后限幅
    static func wav(_ tones: [Tone]) -> Data {
        let rate = Double(sampleRate)
        let count = Int(((tones.map { $0.start + $0.duration }.max() ?? 0) * rate).rounded(.up))
        var mix = [Double](repeating: 0, count: count)
        for tone in tones {
            let first = Int(tone.start * rate), length = Int(tone.duration * rate)
            let total = tone.harmonics.reduce(0, +)
            guard length > 0, total > 0 else { continue }
            var phase = 0.0
            for i in 0..<length where first + i < count {
                let t = Double(i) / rate
                let progress = Double(i) / Double(length)
                let frequency = tone.glide.map { tone.frequency + ($0 - tone.frequency) * progress } ?? tone.frequency
                phase += 2 * .pi * frequency / rate
                var sample = 0.0
                for (index, weight) in tone.harmonics.enumerated() {
                    sample += sin(phase * Double(index + 1)) * weight
                }
                let attack = min(1, Double(i) / (rate * 0.01))
                let release = min(1, Double(length - i) / (rate * 0.05))
                mix[first + i] += sample / total * tone.amplitude * attack * release * exp(-tone.decay * t)
            }
        }
        var data = Data()
        func string(_ s: String) { data.append(contentsOf: s.utf8) }
        func word<T: FixedWidthInteger>(_ n: T) {
            var value = n.littleEndian
            withUnsafeBytes(of: &value) { data.append(contentsOf: $0) }
        }
        string("RIFF"); word(UInt32(36 + count * 2)); string("WAVEfmt ")
        word(UInt32(16)); word(UInt16(1)); word(UInt16(1))
        word(UInt32(sampleRate)); word(UInt32(sampleRate * 2)); word(UInt16(2)); word(UInt16(16))
        string("data"); word(UInt32(count * 2))
        for sample in mix {
            word(Int16(max(-1, min(1, sample)) * 26000))
        }
        return data
    }

    /// 生成 PCM WAV：正确为上行双音，错误为低音，首尾包络避免爆音。
    static func wave(correct: Bool) -> Data {
        let rate = 22050
        let count = rate / 4
        var data = Data()
        func string(_ s: String) { data.append(contentsOf: s.utf8) }
        func word<T: FixedWidthInteger>(_ n: T) {
            var value = n.littleEndian
            withUnsafeBytes(of: &value) { data.append(contentsOf: $0) }
        }
        string("RIFF"); word(UInt32(36 + count * 2)); string("WAVEfmt ")
        word(UInt32(16)); word(UInt16(1)); word(UInt16(1))
        word(UInt32(rate)); word(UInt32(rate * 2)); word(UInt16(2)); word(UInt16(16))
        string("data"); word(UInt32(count * 2))
        for i in 0..<count {
            let t = Double(i) / Double(rate)
            let frequency = correct ? (i < count / 2 ? 660.0 : 880.0) : 220.0
            let envelope = min(1, min(Double(i) / 200, Double(count - i) / 400))
            word(Int16(sin(2 * .pi * frequency * t) * envelope * 12000))
        }
        return data
    }
}
