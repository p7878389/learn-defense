import AVFoundation
import Foundation
import LearnCore
import Testing
@testable import LearnGame

private final class SpySynthesizer: AVSpeechSynthesizer {
    var spoken: [String] = []
    var pending: [AVSpeechUtterance] = []
    override func speak(_ utterance: AVSpeechUtterance) {
        spoken.append(utterance.speechString)
        pending.append(utterance)
    }

    func finishCurrent() {
        let items = pending
        pending.removeAll()
        for item in items {
            delegate?.speechSynthesizer?(self, didFinish: item)
        }
    }
}

@MainActor
@Suite("多听多说对局联动")
struct ListenAndSpeakTests {
    private func makeSession() -> (GameSession, SpySynthesizer) {
        let pack = ContentPack(
            id: "en-speak-test", title: "英语测试", subject: .english, grade: .g3,
            units: [ContentUnit(id: "u1", title: "Unit 1", lessons: [
                Lesson(id: "l1", title: "L1", englishWords: [
                    EnglishWordItem(word: "apple", phonetic: "/ˈæpl/", meaning: "苹果"),
                    EnglishWordItem(word: "banana", phonetic: "/bəˈnɑːnə/", meaning: "香蕉"),
                    EnglishWordItem(word: "orange", phonetic: "/ˈɒrɪndʒ/", meaning: "橙子"),
                ])
            ])]
        )
        let spy = SpySynthesizer()
        let speech = Speech(library: nil, synthesizer: spy)
        var prefs = ReaderPreferences()
        prefs.source = .system
        speech.apply(prefs)
        let config = GameConfig(profileID: UUID(), grade: .g3, packIDs: [pack.id], selection: .all, difficulty: .easy)
        let session = GameSession(config: config, library: ContentLibrary(packs: [pack]), progress: ProgressStore(), speech: speech)
        _ = session.scene.plant(.inkling, in: DefenderCell(lane: 0, column: 0))
        session.startBattle()
        return (session, spy)
    }

    @Test func correctAnswerShowsWordCardSpeaksAnswerAndRecordsFlashcard() throws {
        let (session, spy) = makeSession()
        defer { session.end() }
        let enemy = try #require(session.nextEnemy())
        session.scene.spawn(enemy, lane: 0)
        session.selectQuestion(enemy.id)
        let q = try #require(session.current)
        spy.spoken.removeAll()

        session.answer(q.answerIndex, questionID: q.id)
        #expect(session.scene.childNode(withName: WordCardEffect.nodeName) != nil, "答对后应弹出单词卡")
        #expect(!spy.spoken.isEmpty, "答对后应播放答案朗读")
        #expect(session.roundReviewCards.contains(where: { $0.id == q.itemKey }))
    }

    @Test func voiceCritAwardsBonusSunAndResolvesQuestion() throws {
        let (session, _) = makeSession()
        defer { session.end() }
        let enemy = try #require(session.nextEnemy())
        session.scene.spawn(enemy, lane: 0)
        session.selectQuestion(enemy.id)
        let q = try #require(session.current)
        let sunBefore = session.sun

        session.answerByVoice(questionID: q.id)
        #expect(session.sun >= sunBefore + 15)
        #expect(session.firstTryCorrect == 1)
    }

    @Test func wrongAnswerSetsMistakeTipAndSpeech() throws {
        let (session, _) = makeSession()
        defer { session.end() }
        let enemy = try #require(session.nextEnemy())
        session.scene.spawn(enemy, lane: 0)
        session.selectQuestion(enemy.id)
        let q = try #require(session.current)

        session.answer((q.answerIndex + 1) % q.options.count, questionID: q.id)
        #expect(session.lastMistakeTip != nil)
        #expect(session.mistakes.first?.speech != nil)
        #expect(session.roundReviewCards.first?.wasWrong == true)
    }

    @Test func restFlashcardBonusCanOnlyBeClaimedOncePerCard() throws {
        let (session, _) = makeSession()
        defer { session.end() }
        session.phase = .resting
        let sunBefore = session.sun
        #expect(session.claimRestFlashcardBonus(cardID: "en:apple"))
        #expect(session.sun == sunBefore + 15)
        #expect(!session.claimRestFlashcardBonus(cardID: "en:apple"))
        #expect(session.sun == sunBefore + 15)
    }

    @Test func waitsForSpeechCompletionBeforeNextQuestionAndMonsterMovement() async throws {
        let (session, spy) = makeSession()
        defer { session.end() }
        session.waitsForSpeechCompletion = true
        session.speech.stop()
        #expect(!session.speechActive)

        let e1 = try #require(session.nextEnemy())
        let e2 = try #require(session.nextEnemy())
        session.scene.spawn(e1, lane: 0)
        session.scene.spawn(e2, lane: 0)
        session.selectQuestion(e1.id)

        // 若当前题有自动读题，播报期间怪物暂停且交互锁定
        if session.speechActive {
            #expect(session.speedFactor == 0)
            #expect(session.isInteractionLocked)
            spy.finishCurrent()
            try await Task.sleep(for: .milliseconds(30))
        }
        #expect(session.speedFactor > 0)
        #expect(!session.isInteractionLocked)

        // 跟读期间同样暂停怪物并锁定其他操作按钮
        session.isVoiceListening = true
        #expect(session.speedFactor == 0)
        #expect(session.isInteractionLocked)
        session.isVoiceListening = false

        // 语音答对后，答案朗读播报期间暂不切下一题且怪物不动
        let q1 = try #require(session.current)
        session.answerByVoice(questionID: q1.id)
        #expect(session.speechActive)
        #expect(session.current == nil)
        #expect(session.speedFactor == 0)
        #expect(session.isInteractionLocked)

        // 答案朗读播完后，才切出下一题
        spy.finishCurrent()
        try await Task.sleep(for: .milliseconds(30))
        #expect(session.current != nil)
        if session.speechActive {
            #expect(session.speedFactor == 0)
            spy.finishCurrent()
            try await Task.sleep(for: .milliseconds(30))
        }
        #expect(session.speedFactor > 0)
        #expect(!session.isInteractionLocked)
    }
}
