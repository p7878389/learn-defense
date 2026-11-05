import Foundation
import Testing
@testable import LearnCore

/// 固定种子的随机数，保证测试可重复
struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

@Suite("拼音")
struct PinyinTests {
    @Test func parseAndMark() {
        let s = Pinyin.parse("zhuāng")
        #expect(s.base == "zhuang")
        #expect(s.tone == 1)
        #expect(Pinyin.mark("zhuang", tone: 1) == "zhuāng")
        #expect(Pinyin.mark("hou", tone: 2) == "hóu")
        #expect(Pinyin.mark("liu", tone: 2) == "liú")
        #expect(Pinyin.mark("gui", tone: 4) == "guì")
        #expect(Pinyin.mark("lü", tone: 4) == "lǜ")
        #expect(Pinyin.parse("chen").tone == 5)
    }

    @Test func splitInitial() {
        for (text, initial, final) in [("zhuang", "zh", "uang"), ("ou", "", "ou"), ("shi", "sh", "i")] {
            let parts = Pinyin.split(text)
            #expect(parts.initial == initial)
            #expect(parts.final == final)
        }
    }

    @Test func variants() {
        #expect(Set(Pinyin.toneVariants(of: "chén")) == ["chēn", "chěn", "chèn"])
        #expect(Set(Pinyin.confusableVariants(of: "chén")) == ["cén", "chéng"])
        #expect(Set(Pinyin.confusableVariants(of: "qíng")) == ["qín"])
        #expect(Pinyin.confusableVariants(of: "juān").isEmpty)
    }

    @Test func distractorsExcludeCorrect() {
        var rng = SeededRNG(state: 1)
        for strategy in [DistractorStrategy.easy, .normal, .hard] {
            let d = Pinyin.distractors(for: "chén", count: 3, strategy: strategy, pool: ["qiú", "chén", "hàn"], using: &rng)
            #expect(d.count == 3)
            #expect(!d.contains("chén"))
            #expect(Set(d).count == 3)
        }
    }
}

@Suite("题库与出题")
struct GeneratorTests {
    static let library = ContentLibrary.load(userDirectory: nil)

    @Test func bundledPacksLoadWithoutIssues() {
        #expect(Self.library.issues.isEmpty, "\(Self.library.issues)")
        #expect(Self.library.pack(id: "chinese-g3-sample") != nil)
        #expect(Self.library.pack(id: "chinese-k2-sample") != nil)
    }

    @Test(arguments: Difficulty.allCases)
    func everyItemProducesValidQuestion(difficulty: Difficulty) throws {
        for grade in [Grade.g3, .k2] {
            let packs = Self.library.packs(grade: grade, subject: .chinese)
            let pool = ItemPool(packs: packs, selection: .all)
            #expect(!pool.isEmpty)
            let tuning = GameTuning.make(grade: grade, difficulty: difficulty)
            let generator = QuestionGenerator(pool: pool, settings: tuning.generator)
            var rng = SeededRNG(state: 42)
            for item in pool.items {
                // 每个知识点多出几次，覆盖随机到的不同题型
                for _ in 0..<5 {
                    let q = try #require(generator.makeQuestion(for: item, using: &rng), "\(item.key)")
                    #expect(q.options.count >= 2)
                    #expect(q.options.count <= max(tuning.generator.optionCount, 3))
                    #expect(Set(q.options).count == q.options.count, "选项重复：\(q.options)")
                    #expect(q.itemKey == item.key)
                    let card = try #require(q.card, "答对后要有单词卡：\(item.key)")
                    #expect(!card.text.isEmpty)
                    if case .picture(let p) = item {
                        #expect(card.picture == p.emoji)
                    }
                    if grade.isPreschool {
                        #expect(q.promptSpeech != nil, "幼儿园题目必须能朗读")
                    }
                }
            }
        }
    }

    @Test func unitSelectionAndReview() {
        let packs = Self.library.packs(grade: .g3, subject: .chinese)
        let all = ItemPool(packs: packs, selection: .all)
        let unit1 = ItemPool(packs: packs, selection: .units(["chinese-g3-sample/u1"]))
        #expect(unit1.items.count < all.items.count)
        #expect(unit1.items.contains { $0.key == "char:晨" })
        #expect(!unit1.items.contains { $0.key == "char:霜" })

        let review = ItemPool(packs: packs, selection: .review(["char:霜", "poem:山行#0"]))
        #expect(Set(review.items.map(\.key)) == ["char:霜", "poem:山行#0"])
    }

    @Test func invalidPackReported() throws {
        let json = #"{"schemaVersion":1,"id":"x","title":"x","subject":"chinese","grade":"g3","units":[{"id":"u","title":"u","lessons":[{"id":"l","title":"l","questions":[{"prompt":"p","options":["a","b"],"answer":"c"}]}]}]}"#
        let pack = try ContentLibrary.decode(Data(json.utf8))
        #expect(ContentLibrary.validate(pack).count == 1)
    }
}

@Suite("学习记录")
struct ProgressTests {
    @Test func reviewAfterWrongUntilTwoCorrect() {
        let store = ProgressStore(url: nil)
        let item = LearningItem.character(CharacterItem(char: "晨", pinyin: "chén"))
        store.record(item, correct: false)
        #expect(store.reviewKeys == ["char:晨"])
        store.record(item, correct: true)
        #expect(store.reviewKeys == ["char:晨"])
        store.record(item, correct: true)
        #expect(store.reviewKeys.isEmpty)
    }

    @Test func persistsToFile() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("progress-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let item = LearningItem.idiom(IdiomItem(text: "手舞足蹈"))
        let store = ProgressStore(url: url)
        store.record(item, correct: false)
        store.save()
        let reloaded = ProgressStore(url: url)
        #expect(reloaded.stats["idiom:手舞足蹈"]?.wrong == 1)
    }

    @Test func schedulerPrefersWrongItemsAndAvoidsRepeats() {
        let items = (0..<6).map { LearningItem.character(CharacterItem(char: String(UnicodeScalar(0x4E00 + $0)!), pinyin: "yī")) }
        var stats: [String: ItemStats] = [:]
        for item in items { var s = ItemStats(); s.seen = 3; s.correct = 3; s.streak = 3; stats[item.key] = s }
        var wrong = ItemStats(); wrong.seen = 3; wrong.wrong = 3
        stats[items[0].key] = wrong

        var scheduler = ItemScheduler()
        var rng = SeededRNG(state: 7)
        var picks: [String] = []
        for _ in 0..<300 { picks.append(scheduler.next(from: items, stats: stats, using: &rng)!.key) }

        let counts = Dictionary(grouping: picks, by: { $0 }).mapValues(\.count)
        #expect(counts[items[0].key]! > counts[items[1].key]!)
        for i in 1..<picks.count { #expect(picks[i] != picks[i - 1]) }
    }
}

@Suite("怪物与字灵")
struct UnitTests {
    @Test func catalogIDsUnique() {
        #expect(Set(UnitCatalog.enemies.map(\.id)).count == UnitCatalog.enemies.count)
        #expect(Set(UnitCatalog.defenders.map(\.id)).count == UnitCatalog.defenders.count)
        #expect(UnitCatalog.enemy(id: "king") == .king)
        #expect(UnitCatalog.defender(id: "frost") == .frost)
    }

    /// 不管哪种走法，平均速度都要等于设定值，否则「多少秒走到书架」的难度就不准了
    @Test func movementKeepsAverageSpeed() {
        var rng = SeededRNG(state: 7)
        for kind in UnitCatalog.enemies {
            var strategy = kind.movement.makeStrategy()
            var distance = 0.0
            var time = 0.0
            while time < 30 {
                let dt = Double.random(in: 0.004...0.05, using: &rng)
                let motion = strategy.step(dt: dt, speed: 40)
                #expect(motion.dx >= 0, "\(kind.id) 倒着走了")
                #expect(motion.lift >= 0)
                distance += motion.dx
                time += dt
            }
            #expect(abs(distance - 40 * time) / (40 * time) < 0.05, "\(kind.id) 平均速度不对：\(distance / time)")
        }
    }

    @Test func hopStaysOnGroundDuringPause() {
        var hop = HopMovement(pause: 0.5, airTime: 0.5, height: 20)
        let first = hop.step(dt: 0.25, speed: 10)
        #expect(first.dx == 0 && first.lift == 0)
        // 再过 0.5 秒：停顿剩 0.25 秒，然后在空中 0.25 秒（跳到最高点），空中速度是平均的 2 倍
        let mid = hop.step(dt: 0.5, speed: 10)
        #expect(mid.lift > 19)
        #expect(abs(mid.dx - 5) < 1e-9)
    }

    @Test func damageAndHealth() {
        #expect(AttackStyle.single(damage: 1).totalDamage == 1)
        #expect(AttackStyle.volley(count: 2, damage: 1).totalDamage == 2)
        var health = Health(max: EnemyKind.armored.hp)
        let firstHit = health.take(DefenderKind.inkling.attack.totalDamage)
        #expect(!firstHit && health.current == 1)
        let secondHit = health.take(1)
        #expect(secondHit && health.isDefeated)
        // 连珠灵一次打两下，铁头墨一题就倒
        var tough = Health(max: EnemyKind.armored.hp)
        let volley = tough.take(DefenderKind.twin.attack.totalDamage)
        #expect(volley)
    }

    @Test func wavePlan() {
        var rng = SeededRNG(state: 3)
        for grade in Grade.allCases {
            for difficulty in Difficulty.allCases {
                let tuning = GameTuning.make(grade: grade, difficulty: difficulty)
                #expect(tuning.lineup.count == tuning.lanes)
                let kinds = tuning.waves.kinds(count: tuning.enemyCount, using: &rng)
                #expect(kinds.count == tuning.enemyCount)
                #expect(kinds.prefix(tuning.waves.warmup).allSatisfy { $0 == tuning.waves.basic })
                if let boss = tuning.waves.boss {
                    #expect(kinds.last == boss)
                }
                if grade.isPreschool {
                    #expect(kinds.allSatisfy { $0.hp == 1 }, "幼儿园不出要打好几下的怪")
                }
            }
        }
        // 权重为 0 的怪物不会出现
        let plan = WavePlan(warmup: 0, mix: [WavePlan.Entry(.hopper, weight: 1), WavePlan.Entry(.king, weight: 0)])
        #expect(plan.kinds(count: 50, using: &rng).allSatisfy { $0 == .hopper })
    }
}

@Suite("道具")
struct ItemTests {
    @Test func inventoryCapacity() {
        var inventory = Inventory(capacity: 2)
        let added = [inventory.add(.frostCharm), inventory.add(.luckyStar), inventory.add(.heartLeaf)]
        #expect(added == [true, true, false], "装满后不再收")
        let first = inventory.take(at: 0)
        let missing = inventory.take(at: 5)
        #expect(first == .frostCharm)
        #expect(missing == nil)
        #expect(inventory.items == [.luckyStar])
    }

    @Test func dropsAndCatalog() {
        var rng = SeededRNG(state: 11)
        #expect(ItemDrop(.luckyStar, chance: 1).roll(using: &rng) == .luckyStar)
        #expect(ItemDrop(.luckyStar, chance: 0).roll(using: &rng) == nil)
        #expect(ItemKind.heartLeaf.onlyHeals)
        #expect(!ItemKind.frostCharm.onlyHeals)
        #expect(Set(UnitCatalog.items.map(\.id)).count == UnitCatalog.items.count)
        for kind in UnitCatalog.enemies {
            if let drop = kind.drop {
                #expect(UnitCatalog.item(id: drop.item.id) == drop.item, "\(kind.id) 掉落的道具不在目录里")
            }
        }
        for grade in Grade.allCases {
            for difficulty in Difficulty.allCases {
                #expect(GameTuning.make(grade: grade, difficulty: difficulty).ultimate.effects.contains(.clearField))
            }
        }
    }
}

@Suite("画面主题")
struct SceneThemeTests {
    static let library = ContentLibrary.load(userDirectory: nil)

    @Test func idsUniqueAndComplete() {
        #expect(Set(SceneTheme.all.map(\.id)).count == SceneTheme.all.count)
        for theme in SceneTheme.all {
            #expect(!theme.lanes.isEmpty)
            #expect(!theme.horizon.isEmpty)
            #expect(!theme.base.isEmpty)
        }
    }

    @Test func chooseByUnitThenGrade() {
        let k2 = Self.library.packs(grade: .k2, subject: .chinese)
        #expect(SceneTheme.choose(packs: k2, selection: .units(["chinese-k2-sample/u2"]), grade: .k2) == .orchard)
        #expect(SceneTheme.choose(packs: k2, selection: .units(["chinese-k2-sample/u3"]), grade: .k2) == .starry)
        // 选了好几个单元：用得最多的主题，一样多时取靠前的
        #expect(SceneTheme.choose(packs: k2, selection: .units(["chinese-k2-sample/u1", "chinese-k2-sample/u2"]), grade: .k2) == .meadow)
        // 单元没写主题：按年级
        #expect(SceneTheme.choose(packs: k2, selection: .units(["chinese-k2-sample/u4"]), grade: .k2) == .meadow)
        #expect(SceneTheme.choose(packs: [], selection: .all, grade: .g3) == .academy)

        let g3 = Self.library.packs(grade: .g3, subject: .chinese)
        #expect(SceneTheme.choose(packs: g3, selection: .all, grade: .g3) == .academy)
        #expect(SceneTheme.choose(packs: g3, selection: .units(["chinese-g3-sample/u2"]), grade: .g3) == .orchard)
    }

    @Test func unknownThemeIgnored() throws {
        let json = """
        {"schemaVersion":1,"id":"t","title":"t","subject":"chinese","grade":"g1",
         "units":[{"id":"u1","title":"u","theme":"moon-base","lessons":[]}]}
        """
        let pack = try ContentLibrary.decode(Data(json.utf8))
        #expect(pack.units[0].theme == "moon-base")
        #expect(SceneTheme.choose(packs: [pack], selection: .all, grade: .g1) == .academy)
    }
}
