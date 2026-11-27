import Foundation
import SwiftData
import Testing
@testable import LearnCore

@Suite("幼儿园看图识词与直映识字题库")
struct KindergartenPackTests {
    static let forbiddenRiddleChars = CharacterSet(charactersIn: "刂攵廿敕昷甬孚寅隹")

    @Test func legacySampleRemovedAndPicturePacksUseWordOptions() throws {
        let library = ContentLibrary.load(userDirectory: nil)
        #expect(library.issues.isEmpty, "\(library.issues)")
        #expect(library.pack(id: "chinese-k2-sample") == nil)

        let picturesDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/LearnGame/Resources/Pictures")

        for grade in [Grade.k2, .k3] {
            let id = "chinese-pictures-\(grade.rawValue)"
            let pack = try #require(library.pack(id: id), "缺少 \(id)")
            #expect(pack.grade == grade && pack.subject == .chinese)
            #expect(pack.units.count == 4)
            #expect(Set(pack.units.compactMap(\.theme)) == ["meadow", "orchard", "starry", "academy"])
            let pool = ItemPool(packs: [pack], selection: .all)
            #expect(pool.pictures.count >= 36)
            for p in pool.pictures {
                let code = p.emoji.unicodeScalars.filter { $0.value != 0xFE0F }.map { String($0.value, radix: 16) }.joined(separator: "-")
                let png = picturesDir.appendingPathComponent("\(code).png")
                #expect(FileManager.default.fileExists(atPath: png.path), "\(id) 图片词「\(p.text) \(p.emoji)」缺少本地 PNG：\(code).png")
            }
            let gen = QuestionGenerator(pool: pool, settings: GameTuning.make(grade: grade, difficulty: .hard).generator)
            var rng = SeededRNG(state: 23)
            for item in pool.items {
                for rung in 0...3 {
                    let q = try #require(gen.makeQuestion(for: item, rung: rung, using: &rng))
                    #expect(q.kind != .listenPickPicture)
                    #expect(q.optionStyle == .text)
                    if rung <= 1 {
                        #expect(q.kind == .pictureToWord)
                    } else {
                        #expect(q.input != nil)
                    }
                }
            }
        }
    }

    @Test func zhijingPacksAreStratifiedWithValidRiddlesAndCleanWords() throws {
        let library = ContentLibrary.load(userDirectory: nil)
        #expect(library.issues.isEmpty, "\(library.issues)")
        let k2Pack = try #require(library.pack(id: "zhijing-literacy-k2"))
        let k3Pack = try #require(library.pack(id: "zhijing-literacy-k3"))

        let k2Pool = ItemPool(packs: [k2Pack], selection: .all)
        let k3Pool = ItemPool(packs: [k3Pack], selection: .all)
        let k2Chars = Set(k2Pool.characters.map(\.char))
        let k3Chars = Set(k3Pool.characters.map(\.char))
        #expect(k2Chars.count == 90)
        #expect(k3Chars.count == 96)
        #expect(k2Chars.isDisjoint(with: k3Chars), "中班与大班直映识字不应重复选字：\(k2Chars.intersection(k3Chars))")

        for (grade, pack) in [(Grade.k2, k2Pack), (.k3, k3Pack)] {
            #expect(pack.units.count == 6)
            #expect(Set(pack.units.compactMap(\.theme)) == ["meadow", "orchard", "starry", "academy"])
            for unit in pack.units {
                #expect(unit.lessons.count >= 3, "\(pack.id)/\(unit.id) 应拆分为至少 3 课")
            }

            let pool = ItemPool(packs: [pack], selection: .all)
            let gen = QuestionGenerator(pool: pool, settings: GameTuning.make(grade: grade, difficulty: .hard).generator)
            var rng = SeededRNG(state: 42)
            for c in pool.characters {
                let riddle = try #require(QuestionGenerator.shapeRiddleText(c), "\(pack.id)「\(c.char)」字谜为空或包含答案字")
                #expect(riddle.rangeOfCharacter(from: Self.forbiddenRiddleChars) == nil, "\(c.char) 字谜含生僻构件：\(riddle)")

                let words = c.words ?? []
                #expect(words.count >= 2, "\(c.char) 组词不足 2 个")
                #expect(Set(words).count == words.count, "\(c.char) 存在重复组词：\(words)")
                for w in words {
                    #expect(w.count >= 2 && w.count <= 3, "\(c.char) 组词长度异常：\(w)")
                    #expect(w.components(separatedBy: c.char).count == 2, "\(c.char) 组词未恰好出现一次本字：\(w)")
                }

                let item = LearningItem.character(c)
                let r1 = try #require(gen.makeQuestion(for: item, rung: 1, using: &rng))
                #expect(r1.kind == .listenFillChar)
                let r2 = try #require(gen.makeQuestion(for: item, rung: 2, using: &rng))
                #expect(r2.kind == .shapeRiddle, "\(c.char) 第 2 阶应生成字谜题而非降级")
            }
        }
    }

    @Test func databaseLoadsBothGradesAndKeepsThemOnReload() throws {
        let database = try LearnDatabase(url: nil)
        for _ in 0..<2 {
            let library = try database.loadContent(userDirectory: nil)
            #expect(library.issues.isEmpty, "\(library.issues)")
            for (grade, expectedCount) in [(Grade.k2, 90), (.k3, 96)] {
                let id = "zhijing-literacy-\(grade.rawValue)"
                #expect(try database.packs(grade: grade, subject: .chinese).contains { $0.id == id })
                let items = try database.context.fetch(FetchDescriptor<StoredItem>()).filter { $0.packID == id }
                #expect(items.count == expectedCount)
                #expect(items.allSatisfy { $0.grade == grade.rawValue && $0.kind == "character" })
            }
        }
    }
}
