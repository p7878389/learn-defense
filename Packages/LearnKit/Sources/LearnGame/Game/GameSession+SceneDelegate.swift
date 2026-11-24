import Foundation
import LearnCore

extension GameSession: GameSceneDelegate {
    func ultimateAnimationStarted() { isUnleashing = true }
    func ultimateAnimationFinished() { isUnleashing = false }

    /// 拼字块题时战场放慢到一半
    var speedFactor: Double { tuner.speedFactor * (typing ? 0.5 : 1) }
    var holdsTarget: Bool { typing || inNewItemGrace }

    /// 瞄准的这道题是孩子第一次见的知识点（还没有作答记录）：从瞄准它起的几秒内，
    /// 这只怪物原地等着。答过一次（对或错）就有了记录，之后照常逼近。
    /// 按战场时钟计时，暂停时不走
    private var inNewItemGrace: Bool {
        guard newItemGrace > 0, let id = targetID, let entry = questions[id],
              progress.stats[entry.item.key] == nil else { return false }
        return questions.isInGrace(id, at: scene.clock, seconds: newItemGrace)
    }

    func nextEnemy() -> EnemySpawn? {
        guard phase == .playing, spawned < totalEnemies else { return nil }
        guard let entry = makeQuestion() else {
            // 题库无法继续出题时结束，不能卡在空回合。
            finishGame()
            return nil
        }
        let kind = spawned < spawnPlan.count ? spawnPlan[spawned] : .blob
        lastEnemyID += 1
        spawned += 1
        questions.insert(entry, for: lastEnemyID)
        enemyKinds[lastEnemyID] = kind
        questionIDs = questions.ids
        return EnemySpawn(id: lastEnemyID, sign: entry.question.signText, kind: kind)
    }

    func bossAppeared(name: String) {
        guard phase == .playing else { return }
        feedback.play(.bossArrive, volume: speech.effectsVolume)
        speech.speak(SpeechText.Line.bossArrive(name), interrupt: false)
    }

    func makeQuestion() -> (item: LearningItem, question: Question)? {
        // 个别知识点可能凑不齐干扰项，换一个再试
        for _ in 0..<8 {
            guard let item = scheduler.next(from: generator.pool.items, stats: progress.stats, using: &rng, reviewEvery: rules.reviewEvery) else { break }
            if let question = generator.makeQuestion(for: item, using: &rng) {
                return (item, question)
            }
        }
        return nil
    }

    func targetChanged(to id: Int?) {
        guard phase == .playing else { return }
        targetID = id
        typing = false
        current = id.flatMap { questions[$0]?.question }
        if let id { questions.markShown(id) }
        wrongPicks = id.map { questions.wrongPicks(for: $0) } ?? []
        speech.speak(current?.promptSpeech, interrupt: false, channel: .question)
    }

    func enemyReachedBase(_ id: Int) -> Bool {
        guard phase == .playing, enemyKinds[id] != nil, let hearts else { return false }
        if let entry = questions[id] {
            mistakes.append(Mistake(question: entry.question, missed: true))
            // 已经答错过的那次作答已记录；一次都没答的记为没来得及答
            if questions.wrongPicks(for: id).isEmpty {
                attempted += 1
                progress.record(entry.item, correct: false)
                recorder?.recordAnswer(entry.question, chosenIndex: nil, shownAt: questions.shownAt(for: id))
            }
        }
        questions.remove(id)
        enemyKinds[id] = nil
        resolved += 1
        roundResolved = resolved
        questionIDs = questions.ids
        self.hearts = hearts - 1
        if hearts - 1 <= 0 {
            finish(won: false)
        } else {
            checkFinished()
        }
        return true
    }

    func enemyDefeated(_ id: Int, at point: CGPoint) {
        guard phase == .playing, let kind = enemyKinds.removeValue(forKey: id) else { return }
        questions.remove(id)
        questionIDs = questions.ids
        var textY = point.y + 34
        if kind.bonus > 0 {
            score += kind.bonus
            scene.play(FloatingTextEffect(text: "+\(kind.bonus)"), at: CGPoint(x: point.x, y: textY))
            textY += 36
        }
        sun += kind.sunReward
        scene.play(
            FloatingTextEffect(text: "☀️ +\(kind.sunReward)", color: Palette.bullet, fontSize: 32),
            at: CGPoint(x: point.x, y: textY))
        textY += 38
        if tuning.waves.isBoss(kind) {
            bossesDefeated += 1
            feedback.play(.bossDefeated, volume: speech.effectsVolume)
            scene.play(ScreenFlashEffect(color: Palette.bullet, alpha: 0.5, duration: 0.6))
            scene.play(FloatingTextEffect(text: "🏆 打败首领！", color: Palette.target, fontSize: 40),
                       at: CGPoint(x: point.x, y: textY + 6))
            speech.speak(SpeechText.Line.bossDefeated, interrupt: false)
        }
        rollDrop(from: kind, at: point)
        defeated += 1
        resolved += 1
        roundResolved = resolved
        checkFinished()
    }

    func doomCooldownChanged(_ seconds: Int) {
        if doomCooldown != seconds { doomCooldown = seconds }
    }
}

extension GameSession {
    func bossEnraged(_ id: Int) {
        guard phase == .playing else { return }
        feedback.play(.bossEnrage, volume: speech.effectsVolume)
        speech.speak(SpeechText.Line.bossEnraged, interrupt: false)
    }

    func barricadeRemoved() {
        barricadeDown = false
    }
}

extension GameSession: Battlefield {
    func clearField() {
        scene.unleash()
    }

    func freezeField(seconds: Double) {
        scene.freeze(seconds: seconds)
    }

    func heal(hearts gained: Int) {
        guard let hearts, let maxHearts = tuning.hearts else { return }
        self.hearts = min(maxHearts, hearts + gained)
    }

    func addScore(_ points: Int) {
        score += points
    }
}
