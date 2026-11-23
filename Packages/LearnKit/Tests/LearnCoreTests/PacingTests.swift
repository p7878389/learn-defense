import Foundation
import Testing
@testable import LearnCore

private let catalog = GrowthCatalog.bundled

@Suite("节奏配置")
struct PacingTests {
    @Test func bundledConfigLoadsCleanly() {
        #expect(catalog.issues.isEmpty, "\(catalog.issues)")
        #expect(catalog.pacing == .defaults, "内置 JSON 和代码里的默认值应保持一致")
        #expect(catalog.badges.count == 12)
        #expect(Set([CosmeticSlot.defenderSkin, .enemySkin]) == Set(catalog.cosmetics.map(\.slot)))
    }

    @Test func questionBudgetPerGradeAndDifficulty() {
        for grade in Grade.allCases {
            let counts = Difficulty.allCases.map { catalog.pacing.questionBudget(grade: grade, difficulty: $0) }
            #expect(counts == counts.sorted(), "\(grade) 难度越高题量不应减少")
            #expect(counts.allSatisfy { (6...18).contains($0) }, "\(grade) 题量 \(counts) 超出 6~18")
        }
        #expect(catalog.pacing.questionBudget(grade: .g1, difficulty: .normal) == 12)
        #expect(catalog.pacing.questionBudget(grade: .g6, difficulty: .hard) == 18)
    }

    @Test func wavePlanMatchesQuestionBudgetExactly() {
        var rng = SeededRNG(state: 11)
        for grade in Grade.allCases {
            for difficulty in Difficulty.allCases {
                let tuning = GameTuning.make(grade: grade, difficulty: difficulty)
                for _ in 0..<50 {
                    let kinds = tuning.waves.kinds(questions: tuning.questions, using: &rng)
                    #expect(kinds.reduce(0) { $0 + $1.hp } == tuning.questions)
                    #expect(kinds.prefix(tuning.waves.warmup).allSatisfy { $0 == tuning.waves.basic })
                    if !tuning.waves.bosses.isEmpty { #expect(kinds.last.map(tuning.waves.isBoss) == true) }
                }
            }
        }
        // 题量太少放不下首领时就不出首领
        let plan = WavePlan(mix: [WavePlan.Entry(.armored, weight: 1)], boss: .king)
        let small = plan.kinds(questions: 4, using: &rng)
        #expect(small.reduce(0) { $0 + $1.hp } == 4 && !small.contains(.king))
    }

    @Test func forestEnemiesJoinClassicWaves() throws {
        let names = [
            "goblin": "掷石斥候", "acolyte": "暗影学徒", "knight": "骷髅死亡骑士", "ogre": "巨魔酋长",
            "berserker": "双斧狂战士", "frostKing": "寒霜魔王", "infernal": "炎狱领主", "reaper": "冥魂收割者",
            "pharaoh": "古墓法老", "slime": "剧毒史莱姆王", "gargoyle": "暗翼石像鬼王", "shaman": "炼金萨满王"
        ]
        let all = UnitCatalog.enemies + UnitCatalog.forestEnemies
        #expect(Set(all.map(\.id)).count == all.count, "森林怪物和原版僵尸不能重名")
        #expect(Set(UnitCatalog.forestEnemies.map(\.id)) == Set(names.keys))
        for kind in UnitCatalog.forestEnemies {
            #expect(UnitCatalog.enemy(id: kind.id) == kind)
            #expect(names[kind.id] == kind.name)
            #expect(kind.sunReward == kind.hp * 25)
        }
        // 首领血量和铁门僵尸一样，抽到哪个都不改变一局的题量
        #expect(EnemyKind.forestBosses.count == 10)
        #expect(EnemyKind.forestBosses.allSatisfy { $0.hp == EnemyKind.king.hp })
        #expect(Set(EnemyKind.forestBosses.map(\.id)) == Set(names.keys).subtracting(["goblin", "acolyte"]))
        // 飘着的首领能越过矮墙
        #expect(EnemyKind.reaper.canVault && EnemyKind.gargoyle.canVault && !EnemyKind.knight.canVault)

        // 小学标准、挑战难度：每个首领都会轮到，最后一只一定是首领
        var rng = SeededRNG(state: 7)
        for difficulty in [Difficulty.normal, .hard] {
            let tuning = GameTuning.make(grade: .g3, difficulty: difficulty)
            #expect(Set(tuning.waves.bosses) == Set([EnemyKind.king] + EnemyKind.forestBosses))
            var seen: Set<String> = []
            var minions: Set<String> = []
            for _ in 0..<400 {
                let kinds = tuning.waves.kinds(questions: tuning.questions, using: &rng)
                seen.insert(try #require(kinds.last).id)
                #expect(kinds.dropLast().allSatisfy { !tuning.waves.isBoss($0) }, "首领只在最后出一个")
                minions.formUnion(kinds.dropLast().map(\.id))
            }
            #expect(seen == Set(tuning.waves.bosses.map(\.id)))
            #expect(minions.isSuperset(of: ["goblin", "acolyte"]))
        }
        // 入门和幼儿园不出首领；幼儿园只加 1 滴血的小怪
        #expect(GameTuning.make(grade: .g3, difficulty: .easy).waves.bosses.isEmpty)
        for grade in Grade.allCases where grade.isPreschool {
            for difficulty in Difficulty.allCases {
                let waves = GameTuning.make(grade: grade, difficulty: difficulty).waves
                #expect(waves.bosses.isEmpty && waves.mix.allSatisfy { $0.kind.hp == 1 })
            }
        }
        // 只有一个候选时和以前一样，不多消耗随机数
        var a = SeededRNG(state: 5), b = SeededRNG(state: 5)
        let single = WavePlan(mix: [WavePlan.Entry(.hopper, weight: 1)], boss: .king)
        _ = single.kinds(questions: 10, using: &a)
        _ = WavePlan(mix: [WavePlan.Entry(.hopper, weight: 1)]).kinds(questions: 7, using: &b)
        #expect(a.next() == b.next())
    }

    @Test func reviewBudget() {
        let pacing = catalog.pacing
        #expect(pacing.reviewBudget(itemCount: 1, cap: 12) == 6, "错题少时至少 6 题")
        #expect(pacing.reviewBudget(itemCount: 5, cap: 12) == 10)
        #expect(pacing.reviewBudget(itemCount: 30, cap: 12) == 12, "最多不超过本档题量")
    }

    @Test func invalidValuesFallBackToDefaults() {
        let json = """
        { "questions": [ { "grades": ["g1", "g2"], "easy": 0, "normal": 12, "hard": 14 },
                         { "grades": ["k2", "k3", "g3", "g4", "g5", "g6"], "easy": 9, "normal": 9, "hard": 9 } ],
          "daily": { "fullRewardGames": 0, "extraGameRewardRate": 0.5, "firstWinXP": 30, "firstWinCoins": 10 },
          "levels": { "perLevel": 100, "offset": -200, "maxPerLevel": 1500 } }
        """
        let (config, issues) = PacingConfig.parse(Data(json.utf8))
        #expect(config.questionBudget(grade: .g1, difficulty: .easy) == 10, "一二年级那条无效，用默认题量")
        #expect(config.questionBudget(grade: .g3, difficulty: .hard) == 9)
        #expect(config.daily.fullRewardGames == 5)
        #expect(config.levels == PacingConfig.defaults.levels)
        #expect(config.review == PacingConfig.defaults.review)
        #expect(issues.contains { $0.contains("questions[0]") })
        #expect(issues.contains { $0.contains("一年级") })
        #expect(issues.contains { $0.contains("daily.fullRewardGames") })
        #expect(issues.contains { $0.contains("levels") })
        #expect(issues.contains { $0.contains("review") }, "缺少的项也要提示")
        #expect(PacingConfig.parse(Data("oops".utf8)).0 == .defaults)
    }
}
