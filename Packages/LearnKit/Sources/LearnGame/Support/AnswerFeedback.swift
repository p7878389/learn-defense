import AVFoundation
import Foundation

/// 独立短提示音，不占用题目朗读队列，也不触发语音合成请求。
@MainActor
final class AnswerFeedback {
    private var player: AVAudioPlayer?

    func play(correct: Bool, volume: Float = 0.45) {
        do {
            let player = try AVAudioPlayer(data: Self.wave(correct: correct))
            player.volume = volume
            self.player = player
            player.play()
        } catch {
            print("答题提示音播放失败：\(error)")
        }
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
