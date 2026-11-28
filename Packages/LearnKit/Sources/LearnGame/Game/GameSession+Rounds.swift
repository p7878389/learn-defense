import Foundation
import LearnCore

extension GameSession {
    func resumePlayTimer() {
        if battleStartedAt == nil { battleStartedAt = clockNow() }
    }

    func pausePlayTimer() {
        guard let started = battleStartedAt else { return }
        accumulatedPlayTime += max(0, clockNow().timeIntervalSince(started))
        battleStartedAt = nil
    }

    func togglePause() {
        switch phase {
        case .playing:
            pausePlayTimer()
            phase = .paused
            scene.setGamePaused(true)
        case .paused:
            phase = .playing
            resumePlayTimer()
            if ultimate == nil { scene.setGamePaused(false) }
        default:
            break
        }
    }

    /// 切到后台只暂停，不结束或记录本局。
    func suspend() {
        guard phase != .abandoned else { return }
        if phase == .playing {
            pausePlayTimer()
            phase = .paused
        }
        if phase == .paused || phase == .resting { scene.setGamePaused(true) }
        clearPendingSpeechTransition()
        isVoiceListening = false
        speech.stop()
        progress.save()
    }

    /// 离开界面时放弃未结算对局；已结束的对局保留原结果。
    func end() {
        guard phase != .abandoned else { return }
        pausePlayTimer()
        scene.setGamePaused(true)
        clearPendingSpeechTransition()
        isVoiceListening = false
        speech.stop()
        progress.save()
        guard phase != .won && phase != .lost else { return }
        phase = .abandoned
        typing = false
        ultimate = nil
        ultimateItem = nil
        isUnleashing = false
    }

    func checkFinished() {
        guard phase == .playing, totalEnemies > 0,
              spawned >= totalEnemies, resolved >= spawned else { return }
        pausePlayTimer()
        completedRounds += 1
        roundScore = score - roundStartScore
        let answered = attempted - roundStartAttempted
        roundAccuracy = answered == 0 ? 0 : Double(firstTryCorrect - roundStartCorrect) / Double(answered)
        restRemaining = rules.restSeconds(afterRound: round)
        restUntil = clockNow().addingTimeInterval(Double(restRemaining))
        phase = .resting
        typing = false
        ultimate = nil
        ultimateItem = nil
        current = nil
        targetID = nil
        questionIDs = []
        scene.setGamePaused(true, keepingAnimations: true)
        clearPendingSpeechTransition()
        isVoiceListening = false
        progress.save()
        speech.stop()
    }

    /// 明确结束整局才结算；回合结束不发成长奖励。
    func finishGame() {
        finish(won: completedRounds > 0)
    }

    func updateRest(now: Date? = nil) {
        let current = now ?? clockNow()
        guard phase == .resting, let restUntil else { return }
        restRemaining = max(0, Int(ceil(restUntil.timeIntervalSince(current))))
        if restRemaining == 0 { self.restUntil = nil }
    }

    func continueRound() {
        updateRest()
        guard phase == .resting, restRemaining == 0 else { return }
        round += 1
        roundQuestions = initialQuestions + (round - 1) * rules.questionIncrement[config.difficulty]
        spawnPlan = tuning.waves.kinds(questions: roundQuestions, using: &rng)
        UnitSprites.preloadCombat(defenders: plantable, enemies: spawnPlan, loadout: loadout)
        totalEnemies = spawnPlan.count
        spawned = 0
        resolved = 0
        roundResolved = 0
        questions.removeAll()
        wrongPicks = []
        roundReviewCards = []
        spokenRestCardIDs = []
        lastMistakeTip = nil
        roundStartScore = score
        roundStartAttempted = attempted
        roundStartCorrect = firstTryCorrect
        restUntil = nil
        phase = .playing
        resumePlayTimer()
        scene.beginRound()
    }

    var selectedQuestionID: Int? { targetID }

    func selectQuestion(_ id: Int) {
        guard phase == .playing, ultimate == nil, questions[id] != nil else { return }
        scene.selectTarget(id)
    }

    func finish(won: Bool) {
        guard phase == .playing || phase == .paused || phase == .resting else { return }
        pausePlayTimer()
        phase = won ? .won : .lost
        typing = false
        ultimate = nil
        scene.setGamePaused(true)
        progress.save()
        playSeconds = Int(accumulatedPlayTime)
        speech.speak(won ? SpeechText.Line.won : SpeechText.Line.lost, interrupt: false)
        settlementReport = GameReport(
            won: won, difficulty: config.difficulty, questions: attempted,
            firstTryCorrect: firstTryCorrect, stars: stars, bossesDefeated: bossesDefeated,
            enemiesDefeated: defeated, itemsUsed: itemsUsed, ultimatesCast: ultimatesCast, seconds: playSeconds)
        retrySettlement()
    }

    /// 保存成功前保留本局结果；重试沿用同一份报告，不重复计算奖励。
    func retrySettlement() {
        guard (phase == .won || phase == .lost), let report = settlementReport, !isEmpty else { return }
        guard growthResult == nil, recorder?.record == nil else { return }
        let summary = GameSummary(
            questions: attempted,
            firstTryCorrect: firstTryCorrect,
            stars: stars,
            score: score,
            enemiesDefeated: defeated,
            bossesDefeated: bossesDefeated,
            itemsUsed: itemsUsed,
            ultimatesCast: ultimatesCast,
            seconds: playSeconds)
        do {
            if growth?.loadError != nil { try growth?.reload() }
            if let recorder {
                growthResult = try recorder.finish(phase == .won ? .won : .lost, summary: summary,
                                                   at: report.date,
                                                   growth: growth, report: growth == nil ? nil : report)
            } else if let growth {
                growthResult = try growth.settle(report)
            }
            settlementError = nil
            if let result = growthResult, result.leveledUp {
                speech.speak("升到第\(result.after.level)级啦！", interrupt: false)
            }
        } catch {
            settlementError = "本局尚未保存，请重试：\(error.localizedDescription)"
        }
    }
}
