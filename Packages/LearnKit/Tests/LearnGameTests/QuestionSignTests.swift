import Foundation
import LearnCore
import SpriteKit
import Testing
@testable import LearnGame

@Suite("怪物题牌与作答同步")
@MainActor
struct QuestionSignTests {
    @Test func spawningSwitchingAndReplacingQuestionsUseFinalBlanks() throws {
        let pack = ContentPack(id: "sign-test", title: "成语题牌", subject: .chinese, grade: .g3,
                               units: [ContentUnit(id: "u", title: "成语", lessons: [
                                Lesson(id: "l", title: "成语", idioms: [
                                    IdiomItem(text: "春暖花开"), IdiomItem(text: "一心一意"),
                                    IdiomItem(text: "山清水秀"), IdiomItem(text: "天高云淡"),
                                ]),
                               ])])
        let session = GameSession(config: GameConfig(profileID: UUID(), grade: .g3, packIDs: [pack.id],
                                                     selection: .all, difficulty: .hard),
                                  library: ContentLibrary(packs: [pack]), progress: ProgressStore(), speech: Speech())
        defer { session.end() }
        #expect(session.scene.plant(.inkling, in: DefenderCell(lane: 0, column: 0)))
        session.startBattle()
        let first = try #require(session.nextEnemy())
        let enemy = session.scene.spawn(EnemySpawn(id: first.id, sign: first.sign, kind: .armored), lane: 0)
        session.selectQuestion(first.id)
        let original = try #require(session.current)
        try checkSign(enemy, question: original)

        let second = try #require(session.nextEnemy())
        let other = session.scene.spawn(second, lane: 0)
        session.selectQuestion(second.id)
        try checkSign(other, question: #require(session.current))
        session.selectQuestion(first.id)
        #expect(session.current?.id == original.id)
        try checkSign(enemy, question: #require(session.current))

        let input = try #require(original.input)
        session.answerInput(input.blanks.map(\.answer))
        #expect(enemy.health.current == 1)
        let replacement = try #require(session.current)
        #expect(replacement.id != original.id)
        #expect(session.selectedQuestionID == first.id)
        try checkSign(enemy, question: replacement)
    }

    private func checkSign(_ enemy: EnemyNode, question: Question) throws {
        let input = try #require(question.input)
        let template = try #require(input.template)
        let labels = textLabels(in: enemy)
        #expect(labels.contains(template), "实际怪物题牌必须与下方填空题使用相同空位")
        for blank in input.blanks {
            #expect(input.groups[blank.group].tiles.contains(blank.answer))
        }
    }

    private func textLabels(in node: SKNode) -> [String] {
        ((node as? SKLabelNode)?.text.map { [$0] } ?? []) + node.children.flatMap { textLabels(in: $0) }
    }
}
