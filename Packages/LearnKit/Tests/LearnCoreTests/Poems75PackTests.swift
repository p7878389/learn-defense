import Foundation
import Testing
@testable import LearnCore

@Suite("小学生必背古诗词75首题库")
struct Poems75PackTests {
    static let library = ContentLibrary.load(userDirectory: nil)
    static let punctuation = CharacterSet(charactersIn: "，。？！；：、“”‘’（）《》,.?!;:")

    @Test func sixBooksContainExactly75UniquePoemsWithoutPunctuation() throws {
        #expect(Self.library.issues.isEmpty, "\(Self.library.issues)")
        let grades: [Grade] = [.g1, .g2, .g3, .g4, .g5, .g6]
        var titles = Set<String>()
        var firstLines = Set<String>()
        var totalPoems = 0

        for grade in grades {
            let id = "poems-75-\(grade.rawValue)"
            let pack = try #require(Self.library.pack(id: id), "缺少 \(id)")
            #expect(pack.grade == grade && pack.subject == .chinese)
            #expect(pack.edition == "小学生必背古诗词75首")
            #expect(pack.units.count == 3)

            for unit in pack.units {
                for lesson in unit.lessons {
                    for poem in lesson.poems {
                        #expect(titles.insert(poem.title).inserted, "重复诗题：\(poem.title)")
                        #expect(poem.lines.count >= 4, "诗句不足 4 句：\(poem.title)")
                        #expect(firstLines.insert(poem.lines[0]).inserted, "重复首句：\(poem.lines[0])")
                        for line in poem.lines {
                            #expect(line.rangeOfCharacter(from: Self.punctuation) == nil, "诗句包含标点：\(poem.title) - \(line)")
                            #expect(line.trimmingCharacters(in: .whitespacesAndNewlines) == line)
                        }
                        totalPoems += 1
                    }
                }
            }
        }
        #expect(totalPoems == 75, "必背古诗词总数应精确为 75 首，实际为 \(totalPoems)")
    }

    @Test func everySingleUnitGeneratesValidChoiceAndTileQuestions() throws {
        let grades: [Grade] = [.g1, .g2, .g3, .g4, .g5, .g6]
        var rng = SeededRNG(state: 99)
        for grade in grades {
            let pack = try #require(Self.library.pack(id: "poems-75-\(grade.rawValue)"))
            for unit in pack.units {
                let unitPool = ItemPool(packs: [pack], selection: .units(["\(pack.id)/\(unit.id)"]))
                #expect(!unitPool.isEmpty)
                for difficulty in Difficulty.allCases {
                    let gen = QuestionGenerator(pool: unitPool, settings: GameTuning.make(grade: grade, difficulty: difficulty).generator)
                    for item in unitPool.items {
                        let q = try #require(gen.makeQuestion(for: item, using: &rng), "\(pack.id)/\(unit.id) \(item.key) 生成失败")
                        if let spec = q.input {
                            #expect(!spec.blanks.isEmpty)
                            #expect(spec.accepts(spec.blanks.map(\.answer)))
                        } else {
                            #expect(q.options.count >= 2 && Set(q.options).count == q.options.count)
                        }
                    }
                }
            }
        }
    }
}
