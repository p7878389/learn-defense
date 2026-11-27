import Foundation
import LearnCore
import Testing
@testable import LearnGame

@MainActor
@Suite("错题跨年级闭环、道具防浪费与结算反馈")
struct ReviewAndFeedbackTests {
    private func makePack(_ id: String, grade: Grade, subject: Subject = .chinese, prompt: String = "选出春", answer: String = "春") -> ContentPack {
        ContentPack(id: id, title: id, subject: subject, grade: grade,
            units: [ContentUnit(id: "u", title: "第一单元", lessons: [Lesson(id: "l", title: "第一课",
                questions: [ChoiceItem(id: "q", prompt: prompt, options: [answer, "冬"], answer: answer)])])])
    }

    @Test func crossGradeMistakesAreIncludedInReviewConfigAndPreparation() throws {
        let g3Pack = makePack("cn-g3", grade: .g3)
        let g1Pack = makePack("cn-g1", grade: .g1, prompt: "选出秋", answer: "秋")
        let library = ContentLibrary(packs: [g3Pack, g1Pack])
        let loadedG1 = try #require(library.pack(id: "cn-g1"))
        let profile = Profile(name: "跨年级", grade: .g3, avatar: "🐯")
        let progress = ProgressStore()
        let g1Item = try #require(ItemPool(packs: [loadedG1], selection: .all).items.first)
        progress.record(g1Item, correct: false)
        #expect(progress.reviewKeys.contains(g1Item.key))

        let reviewConfig = try #require(GamePreparation.reviewConfig(for: profile, library: library, reviewKeys: progress.reviewKeys))
        #expect(reviewConfig.packIDs.contains("cn-g1"))
        let pool = ItemPool(packs: reviewConfig.packIDs.compactMap(library.pack(id:)), selection: reviewConfig.selection)
        #expect(pool.items.map { $0.key } == [g1Item.key])

        let draft = QuestionBankDraft(config: reviewConfig, library: library)
        let confirmed = try #require(draft.confirmedConfig())
        #expect(confirmed.grade == Grade.g1 && confirmed.packIDs == ["cn-g1"])
    }

    @Test func useItemBlocksWastedHealAtFullHeartsAndFreezeOnEmptyField() throws {
        let pack = makePack("items", grade: .g3)
        let config = GameConfig(profileID: UUID(), grade: .g3, packIDs: [pack.id], selection: .all, difficulty: .normal)
        let s = GameSession(config: config, library: ContentLibrary(packs: [pack]), progress: ProgressStore(), speech: Speech())
        defer { s.end() }
        _ = s.scene.plant(.inkling, in: DefenderCell(lane: 0, column: 0))
        s.startBattle()

        _ = s.inventory.add(.heartLeaf)
        _ = s.inventory.add(.frostCharm)
        _ = s.inventory.add(.luckyStar)
        #expect(s.inventory.items.count == 3)

        // 满血时点爱心叶：不消耗
        s.useItem(at: 0)
        #expect(s.inventory.items.first == .heartLeaf && s.itemsUsed == 0)

        // 空场无怪物时点冰冻符：不消耗
        s.useItem(at: 1)
        #expect(s.inventory.items[1] == .frostCharm && s.itemsUsed == 0)

        // 点幸运星：立即加分并消耗
        s.useItem(at: 2)
        #expect(s.score == 20 && s.itemsUsed == 1 && s.inventory.items.count == 2)

        // 扣血后再用爱心叶：生效并消耗
        s.hearts = (s.tuning.hearts ?? 3) - 1
        s.useItem(at: 0)
        #expect(s.hearts == s.tuning.hearts && s.itemsUsed == 2 && s.inventory.items == [.frostCharm])

        // 出怪后再用冰冻符：生效并消耗
        let enemy = try #require(s.nextEnemy())
        s.scene.spawn(enemy, lane: 0)
        s.useItem(at: 0)
        #expect(s.inventory.items.isEmpty && s.itemsUsed == 3)
    }

    @Test func mistakeNotebookIncludesCorrectAnswerAndReadableAudioPrompt() {
        let audioMistake = GameSession.Mistake(prompt: "🔊", answer: "春", explanation: "春 chūn", missed: false)
        let audioText = MistakeNotebook.summaryText(for: audioMistake)
        #expect(audioText.contains("听音题") && audioText.contains("春"))

        let missedMistake = GameSession.Mistake(prompt: "床前明月光", answer: "疑是地上霜", explanation: nil, missed: true)
        let missedText = MistakeNotebook.summaryText(for: missedMistake)
        #expect(missedText.contains("床前明月光") && missedText.contains("疑是地上霜") && missedText.contains("未作答"))
    }

    @Test func questionTabTitleDisplaysSignTextInsteadOfGenericIndexOnly() throws {
        let pack = ContentPack(id: "tabs", title: "切题测试", subject: .chinese, grade: .g3,
            units: [ContentUnit(id: "u", title: "单元", lessons: [Lesson(id: "l", title: "课",
                characters: [CharacterItem(char: "春", pinyin: "chūn", words: ["春天"])])])])
        let config = GameConfig(profileID: UUID(), grade: .g3, packIDs: [pack.id], selection: .all, difficulty: .easy)
        let s = GameSession(config: config, library: ContentLibrary(packs: [pack]), progress: ProgressStore(), speech: Speech())
        defer { s.end() }
        _ = s.scene.plant(.inkling, in: DefenderCell(lane: 0, column: 0))
        s.startBattle()
        let enemy = try #require(s.nextEnemy())
        s.scene.spawn(enemy, lane: 0)
        let title = s.questionTabTitle(for: enemy.id, index: 0)
        #expect(!title.isEmpty && title != "题目 1")
    }
}
