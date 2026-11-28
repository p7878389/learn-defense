import Combine
import Foundation
import LearnCore

/// 语音播报与跟读的节奏门控：
/// 1. 语音播报期间或孩子正在跟读时，怪物暂停移动，所有操作按钮等待播报完成后再开放；
/// 2. 答对后先完整播完答案朗读，再切换到下一题并朗读新题，新题播报完成后怪物才继续移动。
extension GameSession {
    func bindSpeechObservation() {
        speechActive = speech.isSpeaking
        speechCancellable = speech.$isSpeaking.sink { [weak self] speaking in
            guard let self else { return }
            if self.speechActive != speaking {
                self.speechActive = speaking
            }
        }
    }

    /// 当前是否因语音播报中而需要暂停怪物、锁定操作按钮
    var isSpeechBlocking: Bool {
        waitsForSpeechCompletion && (speechActive || awaitingSpeechForNextQuestion)
    }

    /// 语音播报或跟读期间，锁定其他交互按钮
    var isInteractionLocked: Bool {
        isSpeechBlocking || isVoiceListening
    }

    /// 在语音播报完成后执行切题动作；若未启用等待或当前未播报则立即执行。
    func runAfterSpeech(_ action: @escaping @MainActor () -> Void) {
        guard waitsForSpeechCompletion, speech.isSpeaking else {
            action()
            return
        }
        awaitingSpeechForNextQuestion = true
        let token = UUID()
        pendingSpeechToken = token
        speech.whenIdle { [weak self] in
            guard let self, self.pendingSpeechToken == token else { return }
            self.pendingSpeechToken = nil
            self.awaitingSpeechForNextQuestion = false
            guard self.phase == .playing else { return }
            action()
        }
    }

    func clearPendingSpeechTransition() {
        pendingSpeechToken = nil
        awaitingSpeechForNextQuestion = false
    }

    /// 呈现已经切好的当前目标题并朗读题面
    func presentTargetQuestion(for id: Int?) {
        targetID = id
        typing = false
        current = id.flatMap { questions[$0]?.question }
        if let id { questions.markShown(id) }
        wrongPicks = id.map { questions.wrongPicks(for: $0) } ?? []
        if let promptSpeech = current?.promptSpeech {
            speech.speak(promptSpeech, interrupt: false, channel: .question)
        } else if inNewItemGrace, current?.kind == .meaningToEnglish {
            speech.speak(current?.answerSpeech, interrupt: false, channel: .question)
        }
    }
}
