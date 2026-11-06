import Foundation
import SwiftData
import Testing
@testable import LearnCore

@Suite("直映识字幼儿园题库")
struct KindergartenPackTests {
    @Test(arguments: [Grade.k2, .k3])
    func bothGradesCanSelectEachVolumeAndHearEveryCharacter(grade: Grade) throws {
        let library = ContentLibrary.load(userDirectory: nil)
        #expect(library.issues.isEmpty, "\(library.issues)")
        let id = "zhijing-literacy-\(grade.rawValue)"
        let pack = try #require(library.packs(grade: grade, subject: .chinese).first { $0.id == id })
        #expect(pack.units.count == 6)

        for (unitID, expected) in [
            ("u1", "人头目耳口手一二马鱼天山水火女"),
            ("u2", "宋李球脸眼嘴正好爱车太阳"),
            ("u3", "借知识魔术讲完成老师听懂朋友学校升旗礼敬"),
            ("u4", "雀收藏铅姑娘玩具抱单满积搭奇怪蜜蜂蜻蜓珍珠"),
            ("u5", "整齐池塘蝌蚪捕捞平稳交转铁挖受伤首击赞英"),
            ("u6", "剧痛批评严肃扶梯肚肠承修改诚实温度沉浮演奏躲震"),
        ] {
            let pool = ItemPool(packs: [pack], selection: .units(["\(id)/\(unitID)"]))
            #expect(Set(pool.items.map(\.key)) == Set(expected.map { "char:\($0)" }))
            for difficulty in Difficulty.allCases {
                let generator = QuestionGenerator(pool: pool, settings: GameTuning.make(grade: grade, difficulty: difficulty).generator)
                var rng = SeededRNG(state: 42)
                for item in pool.items {
                    let question = try #require(generator.makeQuestion(for: item, mode: .choice, using: &rng))
                    #expect(question.kind == .listenPickChar)
                    #expect(question.input == nil)
                    #expect(question.promptSpeech?.isEmpty == false)
                    #expect(question.options.count >= 2)
                    #expect(Set(question.options).count == question.options.count)
                    #expect(question.options.contains(question.answerSpeech ?? ""))
                    #expect(question.card?.pinyin?.isEmpty == false)

                    // 标准、挑战难度还会按现有规则生成听音拼音字块题。
                    let mixed = try #require(generator.makeQuestion(for: item, using: &rng))
                    #expect(mixed.promptSpeech?.isEmpty == false)
                    if let input = mixed.input {
                        #expect(difficulty != .easy)
                        #expect(!input.blanks.isEmpty)
                        #expect(input.accepts(input.blanks.map(\.answer)))
                    } else {
                        #expect(mixed.kind == .listenPickChar)
                        #expect(mixed.options.count >= 2)
                    }
                }
            }
        }
    }

    @Test func databaseLoadsBothGradesAndKeepsThemOnReload() throws {
        let database = try LearnDatabase(url: nil)
        for _ in 0..<2 {
            let library = try database.loadContent(userDirectory: nil)
            #expect(library.issues.isEmpty, "\(library.issues)")
            for grade in [Grade.k2, .k3] {
                let id = "zhijing-literacy-\(grade.rawValue)"
                #expect(try database.packs(grade: grade, subject: .chinese).contains { $0.id == id })
                let items = try database.context.fetch(FetchDescriptor<StoredItem>()).filter { $0.packID == id }
                #expect(items.count == 111)
                #expect(items.allSatisfy { $0.grade == grade.rawValue && $0.kind == "character" })
                #expect(items.filter { $0.unitID == "u1" }.count == 15)
                #expect(items.filter { $0.unitID == "u2" }.count == 12)
                #expect(items.filter { $0.unitID == "u3" }.count == 20)
                #expect(items.filter { $0.unitID == "u4" }.count == 21)
                #expect(items.filter { $0.unitID == "u5" }.count == 20)
                #expect(items.filter { $0.unitID == "u6" }.count == 23)
            }
        }
    }
}
