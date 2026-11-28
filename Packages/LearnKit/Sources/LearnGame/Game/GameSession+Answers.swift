import Foundation
import LearnCore

extension GameSession {
    func answer(_ index: Int, questionID: Question.ID? = nil) {
        guard phase == .playing, ultimate == nil, let id = targetID, let entry = questions[id] else { return }
        let question = entry.question
        guard questionID == nil || questionID == question.id,
              question.input == nil, question.options.indices.contains(index) else { return }
        submit(id: id, entry: entry, correct: index == question.answerIndex) { [recorder] shownAt in
            recorder?.recordAnswer(question, chosenIndex: index, shownAt: shownAt)
        }
    }

    /// 字块题交卷：texts 依次是每个空放进去的字块
    func answerInput(_ texts: [String], questionID: Question.ID? = nil) {
        guard phase == .playing, ultimate == nil, let id = targetID, let entry = questions[id],
              let spec = entry.question.input else { return }
        let question = entry.question
        guard questionID == nil || questionID == question.id else { return }
        let correct = spec.accepts(texts)
        let typedText = spec.compose(texts)
        submit(id: id, entry: entry, correct: correct) { [recorder] shownAt in
            recorder?.recordAnswer(question, typed: typedText, correct: correct, shownAt: shownAt)
        }
    }

    /// 孩子开始点字块：战场放慢、瞄准的怪物停下；交卷或换目标后恢复
    func setTyping(_ on: Bool) {
        typing = on && phase == .playing && ultimate == nil && current?.input != nil
    }

    /// 每张题只有一次有效作答；答错换成新题，攻击的重试标记独立于新题的统计。
    private func submit(id: Int, entry: (item: LearningItem, question: Question), correct: Bool,
                        record: (Date?) -> Void) {
        let question = entry.question

        if correct {
            guard scene.canAttack(id) else {
                scene.play(FloatingTextEffect(text: "先选卡片，再点战场空位", color: Palette.hurt, fontSize: 28))
                speech.speak(SpeechText.Line.plantFirst, interrupt: true)
                return
            }
            attempted += 1
            firstTryCorrect += 1
            if questions.isRetry(for: id) {
                score += 2
            } else {
                score += 10
                let wasFull = energy >= tuning.ultimateEnergy
                energy = min(energy + 1, tuning.ultimateEnergy)
                if !wasFull && energy >= tuning.ultimateEnergy {
                    feedback.play(.ultimateReady, volume: speech.effectsVolume)
                }
            }
            tuner.record(correct: true)
            progress.record(entry.item, correct: true)
            record(questions.shownAt(for: id))
            feedback.play(correct: true, volume: speech.effectsVolume)
            typing = false
            lastMistakeTip = nil
            scene.noteCorrectAnswer()
            if let card = question.card {
                scene.showCard(card, near: id)
                recordRoundReviewCard(question, wasWrong: false)
            }
            speech.speak(question.answerSpeech, interrupt: true, channel: .question)

            questions.remove(id)
            questionIDs = questions.ids
            // 打败时场景会马上瞄准下一个怪物，并回调 targetChanged
            if scene.fire(at: id) == false {
                // 还没打倒（血量多的怪物）：换一道题继续打它
                if let next = makeQuestion() {
                    questions.insert(next, for: id)
                    questionIDs = questions.ids
                    scene.setSign(id, next.question.signText)
                    if waitsForSpeechCompletion, speech.isSpeaking {
                        current = nil
                        wrongPicks = []
                        runAfterSpeech { [weak self] in
                            guard let self, self.targetID == id else { return }
                            self.presentTargetQuestion(for: id)
                        }
                    } else {
                        questions.markShown(id)
                        current = next.question
                        wrongPicks = []
                        speech.speak(next.question.promptSpeech, interrupt: false, channel: .question)
                    }
                } else {
                    scene.fire(at: id, overwhelming: true)
                }
            }
        } else {
            attempted += 1
            tuner.record(correct: false)
            progress.record(entry.item, correct: false)
            progress.save()
            mistakes.append(Mistake(question: question, missed: false))
            record(questions.shownAt(for: id))
            feedback.play(correct: false, volume: speech.effectsVolume)
            scene.penalize(id)
            replaceWrongQuestion(entry, for: id)
        }
    }

    func replayPrompt() {
        speech.speak((ultimate ?? current)?.promptSpeech, interrupt: true, channel: .preview)
    }

    /// 孩子通过语音大声读出当前题目目标词：直接答对并触发「开口暴击」阳光奖励。
    func answerByVoice(questionID: Question.ID? = nil) {
        guard phase == .playing, ultimate == nil, let id = targetID, let entry = questions[id] else { return }
        let question = entry.question
        guard questionID == nil || questionID == question.id else { return }
        guard scene.canAttack(id) else {
            scene.play(FloatingTextEffect(text: "先选卡片，再点战场空位", color: Palette.hurt, fontSize: 28))
            speech.speak(SpeechText.Line.plantFirst, interrupt: true)
            return
        }
        sun += 15
        score += 5
        scene.play(FloatingTextEffect(text: "🎤 开口暴击！☀️+15", color: Palette.bullet, fontSize: 34))
        if let spec = question.input {
            answerInput(spec.blanks.map(\.answer), questionID: question.id)
        } else {
            answer(question.answerIndex, questionID: question.id)
        }
    }

    /// 孩子通过大声念出咒语释放大招
    func answerUltimateByVoice(questionID: Question.ID? = nil) {
        guard phase == .playing, let question = ultimate else { return }
        guard questionID == nil || questionID == question.id else { return }
        answerUltimate(question.answerIndex, questionID: question.id)
    }

    // MARK: - 大招

    func startUltimate() {
        guard ultimateReady, let pair = generator.makeUltimateQuestion(using: &rng) else { return }
        ultimateItem = pair.0
        ultimate = pair.1
        typing = false
        ultimateWrongPicks = []
        ultimateRetrying = false
        ultimateShownAt = Date()
        scene.setGamePaused(true)
        speech.speak(pair.1.promptSpeech, interrupt: true, channel: .question)
    }

    /// 不放大招了：关掉题目、继续战斗。还没作答就取消，能量留着下次再放；
    /// 已经答错过再取消，和「答错后再点对只是关掉」一样清空能量，免得靠取消换一道题
    func cancelUltimate() {
        guard ultimate != nil else { return }
        if ultimateRetrying { energy = 0 }
        ultimate = nil
        ultimateItem = nil
        ultimateWrongPicks = []
        ultimateRetrying = false
        ultimateShownAt = nil
        speech.stop()
        if phase == .playing { scene.setGamePaused(false) }
    }

    func answerUltimate(_ index: Int, questionID: Question.ID? = nil) {
        guard phase == .playing, let question = ultimate, let item = ultimateItem, question.options.indices.contains(index) else { return }
        guard questionID == nil || questionID == question.id else { return }
        if index == question.answerIndex {
            let firstTry = !ultimateRetrying
            attempted += 1
            firstTryCorrect += 1
            progress.record(item, correct: true)
            recorder?.recordAnswer(question, chosenIndex: index, ultimate: true, shownAt: ultimateShownAt)
            feedback.play(correct: true, volume: speech.effectsVolume)
            if let card = question.card {
                scene.showCard(card, near: nil)
                recordRoundReviewCard(question, wasWrong: false)
            }
            ultimate = nil
            ultimateItem = nil
            ultimateRetrying = false
            ultimateShownAt = nil
            energy = 0
            if phase == .playing { scene.setGamePaused(false) }
            // 第一次就答对才放大招；答错后再点对只是关掉

            if firstTry {
                score += 30
                ultimatesCast += 1
                feedback.play(.ultimateCast, volume: speech.effectsVolume)
                speech.speak(SpeechText.Line.ultimateCast(tuning.ultimate.name), interrupt: true)
                tuning.ultimate.use(on: self)
            }
        } else {
            attempted += 1
            progress.record(item, correct: false)
            progress.save()
            mistakes.append(Mistake(question: question, missed: false))
            recorder?.recordAnswer(question, chosenIndex: index, ultimate: true, shownAt: ultimateShownAt)
            feedback.play(correct: false, volume: speech.effectsVolume)
            let next = retryQuestion(after: (item, question), ultimate: true)
            ultimateItem = next.item
            ultimate = next.question
            ultimateWrongPicks = []
            ultimateRetrying = true
            ultimateShownAt = Date()
            speech.speak(next.question.promptSpeech, interrupt: true, channel: .question)
        }
    }
    /// 回合休息期跟读闪卡：每张卡首次读对奖励下一回合 +15 阳光
    @discardableResult
    func claimRestFlashcardBonus(cardID: String) -> Bool {
        guard phase == .resting, spokenRestCardIDs.insert(cardID).inserted else { return false }
        sun += 15
        feedback.play(correct: true, volume: speech.effectsVolume)
        return true
    }

    func recordRoundReviewCard(_ question: Question, wasWrong: Bool) {
        guard let card = question.card else { return }
        let audio = question.answerSpeech ?? question.promptSpeech
        if let idx = roundReviewCards.firstIndex(where: { $0.id == question.itemKey }) {
            if wasWrong { roundReviewCards[idx].wasWrong = true }
        } else {
            roundReviewCards.append(RoundReviewCard(id: question.itemKey, card: card, speech: audio, wasWrong: wasWrong))
        }
        roundReviewCards.sort { lhs, rhs in
            if lhs.wasWrong != rhs.wasWrong { return lhs.wasWrong }
            return false
        }
    }
}

extension GameSession.Mistake {
    init(question: Question, missed: Bool) {
        self.init(
            prompt: question.prompt,
            answer: question.answer,
            explanation: question.explanation,
            missed: missed,
            speech: question.answerSpeech ?? question.promptSpeech
        )
    }
}
