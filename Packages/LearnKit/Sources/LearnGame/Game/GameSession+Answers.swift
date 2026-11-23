import Foundation
import LearnCore

extension GameSession {
    func answer(_ index: Int) {
        guard phase == .playing, ultimate == nil, let id = targetID, let entry = questions[id] else { return }
        let question = entry.question
        guard question.input == nil, question.options.indices.contains(index) else { return }
        submit(id: id, entry: entry, correct: index == question.answerIndex, pick: index) { [recorder] shownAt in
            recorder?.recordAnswer(question, chosenIndex: index, shownAt: shownAt)
        }
    }

    /// 字块题交卷：texts 依次是每个空放进去的字块
    func answerInput(_ texts: [String]) {
        guard phase == .playing, ultimate == nil, let id = targetID, let entry = questions[id],
              let spec = entry.question.input else { return }
        let question = entry.question
        let correct = spec.accepts(texts)
        let typedText = spec.compose(texts)
        submit(id: id, entry: entry, correct: correct, pick: questions.wrongPicks(for: id).count + 1) { [recorder] shownAt in
            recorder?.recordAnswer(question, typed: typedText, correct: correct, shownAt: shownAt)
        }
    }

    /// 孩子开始点字块：战场放慢、瞄准的怪物停下；交卷或换目标后恢复
    func setTyping(_ on: Bool) {
        typing = on && phase == .playing && ultimate == nil && current?.input != nil
    }

    /// 选择题和输入题共用的判题：pick 是这次作答的标记（选项序号或第几次输入），
    /// record 只在第一次作答时调用，记下这一题的成绩
    private func submit(id: Int, entry: (item: LearningItem, question: Question), correct: Bool, pick index: Int,
                        record: (Date?) -> Void) {
        let question = entry.question
        let picks = questions.wrongPicks(for: id)

        if correct {
            guard scene.canAttack(id) else {
                scene.play(FloatingTextEffect(text: "先选卡片，再点战场空位", color: Palette.hurt, fontSize: 28))
                speech.speak(SpeechText.Line.plantFirst, interrupt: true)
                return
            }
            if picks.isEmpty {
                attempted += 1
                firstTryCorrect += 1
                score += 10
                let wasFull = energy >= tuning.ultimateEnergy
                energy = min(energy + 1, tuning.ultimateEnergy)
                if !wasFull && energy >= tuning.ultimateEnergy {
                    feedback.play(.ultimateReady, volume: speech.effectsVolume)
                }
                tuner.record(correct: true)
                progress.record(entry.item, correct: true)
                record(questions.shownAt(for: id))
            } else {
                score += 2
            }
            feedback.play(correct: true, volume: speech.effectsVolume)
            typing = false
            scene.noteCorrectAnswer()

            questions.remove(id)
            questionIDs = questions.ids
            // 打败时场景会马上瞄准下一个怪物，并回调 targetChanged
            if scene.fire(at: id) == false {
                // 还没打倒（血量多的怪物）：换一道题继续打它
                if let next = makeQuestion() {
                    questions.insert(next, for: id)
                    questionIDs = questions.ids
                    questions.markShown(id)
                    scene.setSign(id, next.question.signText)
                    current = next.question
                    wrongPicks = []
                    speech.speak(next.question.promptSpeech, interrupt: false, channel: .question)
                } else {
                    scene.fire(at: id, overwhelming: true)
                }
            }
        } else {
            guard !picks.contains(index) else { return }
            if picks.isEmpty {
                attempted += 1
                tuner.record(correct: false)
                progress.record(entry.item, correct: false)
                progress.save()
                mistakes.append(Mistake(question: question, missed: false))
                record(questions.shownAt(for: id))
            }
            wrongPicks = questions.markWrong(id, pick: index)
            feedback.play(correct: false, volume: speech.effectsVolume)
            scene.penalize(id)
        }
    }

    func replayPrompt() {
        speech.speak((ultimate ?? current)?.promptSpeech, interrupt: true, channel: .preview)
    }

    // MARK: - 大招

    func startUltimate() {
        guard ultimateReady, let pair = generator.makeUltimateQuestion(using: &rng) else { return }
        ultimateItem = pair.0
        ultimate = pair.1
        typing = false
        ultimateWrongPicks = []
        ultimateShownAt = Date()
        scene.setGamePaused(true)
        speech.speak(pair.1.promptSpeech, interrupt: true, channel: .question)
    }

    /// 不放大招了：关掉题目、继续战斗。还没作答就取消，能量留着下次再放；
    /// 已经答错过再取消，和「答错后再点对只是关掉」一样清空能量，免得靠取消换一道题
    func cancelUltimate() {
        guard ultimate != nil else { return }
        if !ultimateWrongPicks.isEmpty { energy = 0 }
        ultimate = nil
        ultimateItem = nil
        ultimateWrongPicks = []
        ultimateShownAt = nil
        speech.stop()
        if phase == .playing { scene.setGamePaused(false) }
    }

    func answerUltimate(_ index: Int) {
        guard phase == .playing, let question = ultimate, let item = ultimateItem, question.options.indices.contains(index) else { return }
        if index == question.answerIndex {
            let firstTry = ultimateWrongPicks.isEmpty
            if firstTry {
                attempted += 1
                firstTryCorrect += 1
                progress.record(item, correct: true)
                recorder?.recordAnswer(question, chosenIndex: index, ultimate: true, shownAt: ultimateShownAt)
            }
            feedback.play(correct: true, volume: speech.effectsVolume)
            ultimate = nil
            ultimateItem = nil
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
            guard !ultimateWrongPicks.contains(index) else { return }
            if ultimateWrongPicks.isEmpty {
                attempted += 1
                progress.record(item, correct: false)
                progress.save()
                mistakes.append(Mistake(question: question, missed: false))
                recorder?.recordAnswer(question, chosenIndex: index, ultimate: true, shownAt: ultimateShownAt)
            }
            ultimateWrongPicks.insert(index)
            feedback.play(correct: false, volume: speech.effectsVolume)
        }
    }
}

extension GameSession.Mistake {
    init(question: Question, missed: Bool) {
        self.init(prompt: question.prompt, answer: question.answer, explanation: question.explanation, missed: missed)
    }
}
