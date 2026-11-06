import AVFoundation
import Testing
@testable import LearnGame

@Suite("答题提示音")
@MainActor
struct AnswerFeedbackTests {
    @Test func bothFeedbackTonesDecodeAsShortAudio() throws {
        let correct = AnswerFeedback.wave(correct: true)
        let wrong = AnswerFeedback.wave(correct: false)
        #expect(correct != wrong)
        for data in [correct, wrong] {
            let player = try AVAudioPlayer(data: data)
            #expect(abs(player.duration - 0.25) < 0.001)
            #expect(player.numberOfChannels == 1)
        }
    }
}
