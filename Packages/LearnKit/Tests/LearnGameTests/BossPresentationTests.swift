import AVFoundation
import LearnCore
import SpriteKit
import Testing
#if os(macOS)
import AppKit
#endif
@testable import LearnGame

@Suite("首领的血条、登场与音效")
@MainActor
struct BossPresentationTests {
    private let tuning = GameTuning.make(grade: .g3, difficulty: .normal)

    private func makeScene() -> GameScene {
        let scene = GameScene(tuning: tuning, theme: .academy)
        scene.didMove(to: SKView(frame: CGRect(origin: .zero, size: scene.size)))
        scene.update(0)
        return scene
    }

    private func bar(of node: EnemyNode) -> BossHealthBar? {
        node.children.compactMap { $0 as? BossHealthBar }.first
    }

    /// 红点是半径 7 的圆，数一数头顶有几个
    private func pipCount(of node: EnemyNode) -> Int {
        node.children.flatMap(\.children).filter { ($0 as? SKShapeNode)?.frame.width ?? 0 < 20 && $0 is SKShapeNode
            && ($0 as? SKShapeNode)?.lineWidth == 2 && $0.parent?.children.count == node.kind.hp }.count
    }

    @Test func bossShowsNamedBarInsteadOfPips() throws {
        for kind in [EnemyKind.king] + EnemyKind.forestBosses {
            let boss = EnemyNode(id: 1, kind: kind, sign: "学", lane: 0, scale: 1, boss: true)
            let bar = try #require(bar(of: boss), "\(kind.id) 应有血条")
            #expect(bar.ratio == 1)
            #expect((bar.childNode(withName: "bossName") as? SKLabelNode)?.text == kind.name)
            #expect(pipCount(of: boss) == 0, "\(kind.id) 不再显示红点")
            #expect(boss.childNode(withName: "bossAura") != nil)
        }
        // 不是首领的多血怪（铁桶僵尸）仍然是红点；同一种怪不当首领时也是红点
        for node in [EnemyNode(id: 2, kind: .armored, sign: "学", lane: 0, scale: 1),
                     EnemyNode(id: 3, kind: .king, sign: "学", lane: 0, scale: 1)] {
            #expect(bar(of: node) == nil)
            #expect(pipCount(of: node) == node.kind.hp)
            #expect(node.childNode(withName: "bossAura") == nil)
        }
    }

    @Test func barShrinksAndChangesColorAsBossIsHit() throws {
        let boss = EnemyNode(id: 1, kind: .knight, sign: "学", lane: 0, scale: 1, boss: true)
        let bar = try #require(bar(of: boss))
        boss.health.take(1)
        boss.showWound()
        #expect(abs(bar.ratio - 2.0 / 3) < 0.001)
        boss.health.take(1)
        boss.showWound()
        #expect(abs(bar.ratio - 1.0 / 3) < 0.001)

        #expect(BossHealthBar.color(for: 1) == Palette.jade)
        #expect(BossHealthBar.color(for: 0.5) == Palette.bullet)
        #expect(BossHealthBar.color(for: 0.2) == Palette.hurt)

        // 回满（不会发生，但不应留下残影动画）和归零都直接到位
        let plain = BossHealthBar(name: "测试", segments: 3)
        plain.set(current: 0, max: 3, animated: false)
        #expect(plain.ratio == 0)
    }

    /// 只记录暴走回调的场景代理
    private final class EnrageLog: GameSceneDelegate {
        var enraged: [Int] = []
        var defeated: [Int] = []
        func nextEnemy() -> EnemySpawn? { nil }
        func targetChanged(to id: Int?) {}
        func enemyReachedBase(_ id: Int) -> Bool { false }
        func enemyDefeated(_ id: Int, at point: CGPoint) { defeated.append(id) }
        func barricadeRemoved() {}
        func bossEnraged(_ id: Int) { enraged.append(id) }
        var speedFactor: Double { 1 }
    }

    @Test func bossEnragesOnceAtLastSegmentAndSpeedsUp() throws {
        let boss = EnemyNode(id: 1, kind: .knight, sign: "学", lane: 0, scale: 1, boss: true)
        let calm = boss.advance(dt: 1, speed: 40)
        boss.health.take(1)
        boss.showWound()
        #expect(!boss.isEnraged, "还剩两段血时不暴走")
        boss.health.take(1)
        boss.showWound()
        #expect(boss.isEnraged)
        #expect(boss.childNode(withName: "bossAnger") != nil)
        #expect(abs(boss.advance(dt: 1, speed: 40) - calm * EnemyNode.enragedSpeed) < 0.001, "暴走后快两成")
        boss.showWound()
        #expect(boss.children.filter { $0.name == "bossAnger" }.count == 1, "只暴走一次")

        // 不是首领的多血怪不会暴走
        let armored = EnemyNode(id: 2, kind: .armored, sign: "学", lane: 0, scale: 1)
        armored.health.take(1)
        armored.showWound()
        #expect(!armored.isEnraged)
    }

    /// 土豆雷对首领只扣 1 滴血：踩两次雷剩最后一段，场景恰好通知一次暴走
    @Test func sceneReportsEnrageExactlyOnce() throws {
        let scene = makeScene()
        let log = EnrageLog()
        scene.gameDelegate = log
        let lawn = Lawn(lanes: 5)
        for column in [3, 5] {
            let mine = try #require(tuning.guards.first { if case .mine = $0.guardStyle { true } else { false } })
            #expect(scene.plant(mine, in: DefenderCell(lane: 2, column: column)))
        }
        // 答对够多题，让两颗土豆雷都出土
        for _ in 0..<6 { _ = scene.noteCorrectAnswer() }
        let boss = scene.spawn(EnemySpawn(id: 1, sign: "学", kind: .ogre), lane: 2, x: lawn.columnX(5) + 20)
        var time = 0.0
        for _ in 0..<1200 where boss.health.current > 2 && log.defeated.isEmpty { time += 0.05; scene.update(time) }
        #expect(boss.health.current == 2)
        #expect(log.enraged.isEmpty, "第一颗雷后还剩两段血，不暴走")
        for _ in 0..<1200 where boss.health.current > 1 && log.defeated.isEmpty { time += 0.05; scene.update(time) }
        #expect(boss.health.current == 1)
        #expect(log.enraged == [1])
    }

    @Test func spawningBossPlaysWarningOnceAndCleansUp() throws {
        let scene = makeScene()
        let boss = scene.spawn(EnemySpawn(id: 1, sign: "学", kind: .ogre), lane: 2)
        #expect(boss.isBoss)
        #expect(scene.childNode(withName: BossWarningEffect.bannerName) != nil)
        #expect(scene.childNode(withName: BossWarningEffect.laneName) != nil)
        let banner = try #require(scene.childNode(withName: BossWarningEffect.bannerName))
        #expect(banner.children.contains { ($0 as? SKLabelNode)?.text == EnemyKind.ogre.name })

        // 小怪出场没有预警
        let other = makeScene()
        let minion = other.spawn(EnemySpawn(id: 1, sign: "学", kind: .goblin), lane: 2)
        #expect(!minion.isBoss)
        #expect(other.childNode(withName: BossWarningEffect.bannerName) == nil)
    }

    @Test func bossCuesAreValidDistinctAudio() throws {
        var seen: Set<Data> = []
        for cue in AnswerFeedback.Cue.allCases {
            let data = AnswerFeedback.wave(cue)
            #expect(seen.insert(data).inserted, "每种提示音都不一样")
            let player = try AVAudioPlayer(data: data)
            #expect(player.numberOfChannels == 1)
            #expect(player.duration > 0.2 && player.duration < 2)
        }
        // 登场号角约 1.4 秒，其余都在 1.2 秒以内；都不是静音，也没有削波
        let arrive = try AVAudioPlayer(data: AnswerFeedback.wave(.bossArrive))
        let defeated = try AVAudioPlayer(data: AnswerFeedback.wave(.bossDefeated))
        #expect(abs(arrive.duration - 1.39) < 0.02)
        #expect(abs(defeated.duration - 0.83) < 0.02)
        #expect(abs(try AVAudioPlayer(data: AnswerFeedback.wave(.bossEnrage)).duration - 0.94) < 0.02)
        #expect(abs(try AVAudioPlayer(data: AnswerFeedback.wave(.ultimateCast)).duration - 1.15) < 0.02)
        for cue in [AnswerFeedback.Cue.bossArrive, .bossEnrage, .bossDefeated, .ultimateCast] {
            let samples = AnswerFeedback.wave(cue).dropFirst(44)
            var peak = 0
            var index = samples.startIndex
            while index + 1 < samples.endIndex {
                let value = Int(Int16(bitPattern: UInt16(samples[index]) | UInt16(samples[index + 1]) << 8))
                peak = max(peak, abs(value))
                index += 2
            }
            #expect(peak > 6000, "\(cue) 太轻")
            #expect(peak < 26000, "\(cue) 混音后削波了")
        }
        // 想试听时导出成 WAV 文件
        if let folder = ProcessInfo.processInfo.environment["LEARN_DEFENSE_BOSS_AUDIO"] {
            for (cue, name) in [(AnswerFeedback.Cue.bossArrive, "boss-arrive"), (.bossEnrage, "boss-enrage"),
                                (.bossDefeated, "boss-defeated"), (.ultimateCast, "ultimate-cast")] {
                try AnswerFeedback.wave(cue).write(to: URL(fileURLWithPath: folder).appendingPathComponent("\(name).wav"))
            }
        }
        #expect(AnswerFeedback.wave(.correct) == AnswerFeedback.wave(correct: true))
        #expect(AnswerFeedback.wave(.wrong) == AnswerFeedback.wave(correct: false))
    }

    #if os(macOS)
    /// 首领登场瞬间的画面：横幅、警示带、血条；可导出预览目检
    @Test func renderBossEntrance() throws {
        let scene = makeScene()
        let boss = scene.spawn(EnemySpawn(id: 1, sign: "春天", kind: .frostKing), lane: 2, x: scene.size.width * 0.72)
        let hurt = scene.spawn(EnemySpawn(id: 2, sign: "学", kind: .ogre), lane: 0, x: scene.size.width * 0.5)
        hurt.health.take(2)
        hurt.showWound()
        // 离屏渲染不推进动作，血条直接摆到掉血后的长度
        bar(of: hurt)?.set(current: 1, max: 3, animated: false)
        _ = scene.spawn(EnemySpawn(id: 3, sign: "书", kind: .armored), lane: 4, x: scene.size.width * 0.6)
        _ = boss
        let view = SKView(frame: CGRect(origin: .zero, size: scene.size))
        // 离屏渲染不会推进动作，这里把各个动画直接摆到「登场半秒后」的样子：
        // 怪物淡入完成、首领落地、横幅滑到中间、警示带亮着
        for enemy in scene.children.compactMap({ $0 as? EnemyNode }) {
            enemy.removeAllActions()
            enemy.alpha = 1
            for part in enemy.children where part.action(forKey: "bossEntrance") != nil {
                part.removeAction(forKey: "bossEntrance")
                part.setScale(part.xScale / 1.7)
            }
        }
        for banner in scene.children where banner.name == BossWarningEffect.bannerName {
            banner.removeAllActions()
            banner.position.x = scene.size.width / 2
        }
        for strip in scene.children where strip.name == BossWarningEffect.laneName {
            strip.removeAllActions()
            strip.alpha = 0.28
        }
        let texture = try #require(view.texture(from: scene, crop: CGRect(origin: .zero, size: scene.size)))
        #expect(texture.size() == scene.size)
        if let path = ProcessInfo.processInfo.environment["LEARN_DEFENSE_BOSS_PREVIEW"] {
            let bitmap = NSBitmapImageRep(cgImage: texture.cgImage())
            let data = try #require(bitmap.representation(using: .png, properties: [:]))
            try data.write(to: URL(fileURLWithPath: path))
        }
    }
    #endif
}
