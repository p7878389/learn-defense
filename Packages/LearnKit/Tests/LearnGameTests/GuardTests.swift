import Foundation
import LearnCore
import SpriteKit
import Testing
#if os(macOS)
import AppKit
#endif
@testable import LearnGame

/// 只记录场景回调，不出新怪物
@MainActor
private final class FieldLog: GameSceneDelegate {
    var defeated: [Int] = []
    var barricadesRemoved = 0
    func nextEnemy() -> EnemySpawn? { nil }
    func targetChanged(to id: Int?) {}
    func enemyReachedBase(_ id: Int) -> Bool { false }
    func enemyDefeated(_ id: Int, at point: CGPoint) { defeated.append(id) }
    func barricadeRemoved() { barricadesRemoved += 1 }
    var speedFactor: Double { 1 }
}

@Suite("防御道具")
@MainActor
struct GuardTests {
    private let tuning = GameTuning.make(grade: .g3, difficulty: .normal)
    /// 第 4 列的中线，在草坪中间
    private let column = 4
    private var columnX: CGFloat { Lawn(lanes: 5).columnX(column) }
    private var contact: CGFloat { Lawn(lanes: 5).columnWidth * 0.45 }

    private func makeScene(_ log: FieldLog) -> GameScene {
        let scene = GameScene(tuning: tuning, theme: .academy)
        scene.didMove(to: SKView(frame: CGRect(origin: .zero, size: scene.size)))
        scene.gameDelegate = log
        scene.update(0)
        return scene
    }

    private func guardKind(_ id: String) throws -> DefenderKind {
        try #require(tuning.guards.first { $0.id == id })
    }

    /// 按 0.05 秒一帧推进场景
    private func run(_ scene: GameScene, seconds: Double, clock: inout Double) {
        let end = clock + seconds
        while clock < end {
            clock += 0.05
            scene.update(clock)
        }
    }

    private func spawn(_ scene: GameScene, id: Int, kind: EnemyKind = .blob, x: CGFloat) -> EnemyNode {
        scene.spawn(EnemySpawn(id: id, sign: "学", kind: kind), lane: 0, x: x)
    }

    @Test func wallStopsZombieUntilChewedThrough() throws {
        let log = FieldLog()
        let scene = makeScene(log)
        var clock = 0.0
        let wallnut = try guardKind("wallnut")
        #expect(scene.plant(wallnut, in: DefenderCell(lane: 0, column: column)))
        let enemy = spawn(scene, id: 1, x: columnX + 120)

        run(scene, seconds: 6, clock: &clock)
        #expect(enemy.isChewing, "走到坚果墙面前停下来啃")
        #expect(abs(enemy.position.x - (columnX + contact)) < 0.01)

        // 正常难度坚果墙能啃 15 秒
        run(scene, seconds: 8, clock: &clock)
        #expect(scene.plantedCellCount == 1, "还没啃完")
        run(scene, seconds: 9, clock: &clock)
        #expect(scene.plantedCellCount == 0, "啃碎后空出格子")
        #expect(!enemy.isChewing)
        #expect(enemy.position.x < columnX + contact, "啃碎后接着往前走")
    }

    @Test func frozenZombiesDoNotChewAndCrowdsChewFaster() throws {
        let wall = DefenderKind.wallnut.guarding(.wall(seconds: 4, tall: false))

        let frozenLog = FieldLog()
        let frozen = makeScene(frozenLog)
        var clock = 0.0
        #expect(frozen.plant(wall, in: DefenderCell(lane: 0, column: column)))
        _ = spawn(frozen, id: 1, x: columnX + contact + 1)
        run(frozen, seconds: 0.2, clock: &clock)
        frozen.freeze(seconds: 30)
        run(frozen, seconds: 6, clock: &clock)
        #expect(frozen.plantedCellCount == 1, "冻住的僵尸不啃")

        let soloLog = FieldLog(), crowdLog = FieldLog()
        let solo = makeScene(soloLog), crowd = makeScene(crowdLog)
        var soloClock = 0.0, crowdClock = 0.0
        #expect(solo.plant(wall, in: DefenderCell(lane: 0, column: column)))
        #expect(crowd.plant(wall, in: DefenderCell(lane: 0, column: column)))
        _ = spawn(solo, id: 1, x: columnX + contact + 1)
        _ = spawn(crowd, id: 1, x: columnX + contact + 1)
        _ = spawn(crowd, id: 2, x: columnX + contact + 2)
        run(solo, seconds: 2.6, clock: &soloClock)
        run(crowd, seconds: 2.6, clock: &crowdClock)
        #expect(solo.plantedCellCount == 1)
        #expect(crowd.plantedCellCount == 0, "两只一起啃，耐久消耗翻倍")
    }

    @Test func hoppersVaultShortWallsOnlyWhereAllowed() {
        let hopper = EnemyNode(id: 1, kind: .hopper, sign: "学", lane: 0, scale: 1)
        let blob = EnemyNode(id: 2, kind: .blob, sign: "学", lane: 0, scale: 1)
        let short = WallGuard(seconds: 10, tall: false), tall = WallGuard(seconds: 10, tall: true)
        #expect(!short.blocks(hopper, vaulting: true), "路障僵尸跳过坚果墙")
        #expect(tall.blocks(hopper, vaulting: true), "跳不过高坚果")
        #expect(short.blocks(hopper, vaulting: false), "幼儿园不跳墙")
        #expect(short.blocks(blob, vaulting: true))
        #expect(tuning.wallsCanBeVaulted)
        #expect(!GameTuning.make(grade: .k2, difficulty: .hard).wallsCanBeVaulted)
    }

    @Test func guardsNeverShoot() throws {
        let scene = makeScene(FieldLog())
        #expect(scene.plant(try guardKind("wallnut"), in: DefenderCell(lane: 0, column: column)))
        _ = spawn(scene, id: 1, x: 1000)
        #expect(scene.plantedLaneCount == 0, "只种坚果墙不算布阵")
        #expect(!scene.canAttack(1))
        #expect(scene.fire(at: 1) == nil)
        #expect(scene.plant(.inkling, in: DefenderCell(lane: 0, column: 0)))
        #expect(scene.canAttack(1))
        #expect(scene.fire(at: 1) != nil)
    }

    @Test func potatoMineArmsAfterCorrectAnswers() throws {
        let potato = try guardKind("potato")
        guard case let .mine(armAfter, _) = potato.guardStyle else {
            Issue.record("土豆雷应该是地雷")
            return
        }
        #expect(armAfter == 2)

        // 没出土：僵尸直接踩过去
        let buriedLog = FieldLog()
        let buried = makeScene(buriedLog)
        var clock = 0.0
        #expect(buried.plant(potato, in: DefenderCell(lane: 0, column: column)))
        #expect(!buried.noteCorrectAnswer())
        let walker = spawn(buried, id: 1, x: columnX + 60)
        run(buried, seconds: 3, clock: &clock)
        #expect(buriedLog.defeated.isEmpty)
        #expect(walker.position.x < columnX - contact, "没出土的土豆雷不挡路")
        #expect(buried.plantedCellCount == 1)

        // 出土后：踩上去的僵尸直接倒下，土豆雷用掉
        let log = FieldLog()
        let scene = makeScene(log)
        clock = 0
        #expect(scene.plant(potato, in: DefenderCell(lane: 0, column: column)))
        #expect(!scene.noteCorrectAnswer())
        #expect(scene.noteCorrectAnswer(), "答对第 2 题时出土")
        _ = spawn(scene, id: 7, kind: .armored, x: columnX + 60)
        run(scene, seconds: 3, clock: &clock)
        #expect(log.defeated == [7], "两滴血的铁桶僵尸也一下倒下")
        #expect(scene.plantedCellCount == 0)
    }

    @Test func potatoMineOnlyWoundsTheBoss() throws {
        let log = FieldLog()
        let scene = makeScene(log)
        var clock = 0.0
        #expect(scene.plant(try guardKind("potato"), in: DefenderCell(lane: 0, column: column)))
        scene.noteCorrectAnswer()
        scene.noteCorrectAnswer()
        let boss = spawn(scene, id: 3, kind: .king, x: columnX + 60)
        run(scene, seconds: 2.5, clock: &clock)
        #expect(log.defeated.isEmpty, "首领不会被土豆雷一下炸倒")
        #expect(boss.health.current == EnemyKind.king.hp - 1)
        #expect(!boss.doomed)
    }

    @Test func wrongAnswerBitesTheWallInsteadOfLunging() throws {
        // 场景只弱引用代理，要自己留着，否则场景不会推进
        let log = FieldLog()
        let scene = makeScene(log)
        var clock = 0.0
        #expect(scene.plant(DefenderKind.wallnut.guarding(.wall(seconds: 4, tall: false)),
                            in: DefenderCell(lane: 0, column: column)))
        let enemy = spawn(scene, id: 1, x: columnX + contact + 1)
        run(scene, seconds: 0.2, clock: &clock)
        #expect(enemy.isChewing)
        let x = enemy.position.x
        scene.penalize(1)
        #expect(enemy.position.x == x, "被挡住时答错不往前冲")
        #expect(scene.plantedCellCount == 1)
        scene.penalize(1)
        #expect(scene.plantedCellCount == 0, "每次答错狠咬掉 2 秒耐久")
    }

    @Test func ironGateDropsInFrontOfTheTarget() throws {
        let log = FieldLog()
        let scene = makeScene(log)
        var clock = 0.0
        let gate = try #require(tuning.barricade)
        let enemy = spawn(scene, id: 5, x: 700)
        #expect(!scene.dropBarricade(gate, before: 99), "怪物不在场上时不放")
        #expect(scene.dropBarricade(gate, before: 5))
        #expect(scene.barricadeCount == 1)
        #expect(scene.plantedCellCount == 0, "铁栅门不占种植格")

        run(scene, seconds: 1, clock: &clock)
        #expect(enemy.isChewing, "门落在面前，马上被挡住")
        #expect(enemy.position.x > 600)
        // 正常难度挡 10 秒
        run(scene, seconds: 10.5, clock: &clock)
        #expect(scene.barricadeCount == 0)
        #expect(log.barricadesRemoved == 1)
        #expect(!enemy.isChewing)
    }

    @Test func spritesFollowDurabilityAndArming() throws {
        let wallnut = DefenderNode(kind: .wallnut, radius: 34)
        let sprite = try #require(wallnut.childNode(withName: "//unitSprite") as? SKSpriteNode)
        let fresh = sprite.texture
        wallnut.showDurability(0.5)
        #expect(sprite.texture !== fresh, "耐久过半换裂纹帧")

        let potato = DefenderNode(kind: .potato, radius: 34)
        let potatoSprite = try #require(potato.childNode(withName: "//unitSprite") as? SKSpriteNode)
        #expect(potatoSprite.action(forKey: SpriteRig.loopKey) == nil, "埋着的土豆雷不动")
        potato.arm()
        #expect(potatoSprite.action(forKey: SpriteRig.loopKey) != nil, "出土后播放待机动画")

        let gate = DefenderNode(kind: .ironGate, radius: 34)
        #expect(gate.childNode(withName: "//unitSprite") == nil, "铁栅门没有序列帧，用矢量画")
        #expect(!gate.canShoot)
    }

    #if os(macOS)
    /// 设置 GUARD_PREVIEW=<png 路径> 时导出一张布阵截图，用来目检防御道具和僵尸啃咬
    @Test func exportGuardPreview() throws {
        guard let path = ProcessInfo.processInfo.environment["GUARD_PREVIEW"] else { return }
        let log = FieldLog()
        let scene = makeScene(log)
        let view = SKView(frame: CGRect(origin: .zero, size: scene.size))
        scene.didMove(to: view)
        var clock = 0.0
        let lawn = Lawn(lanes: 5)
        for lane in 0..<5 { _ = scene.plant(.inkling, in: DefenderCell(lane: lane, column: 0)) }
        _ = scene.plant(try guardKind("wallnut"), in: DefenderCell(lane: 0, column: 4))
        _ = scene.plant(try guardKind("tallnut"), in: DefenderCell(lane: 1, column: 4))
        _ = scene.plant(try guardKind("potato"), in: DefenderCell(lane: 2, column: 4))
        _ = scene.plant(try guardKind("potato"), in: DefenderCell(lane: 3, column: 3))
        scene.noteCorrectAnswer()
        scene.noteCorrectAnswer()
        _ = scene.plant(try guardKind("potato"), in: DefenderCell(lane: 3, column: 5))
        for (lane, kind) in [(0, EnemyKind.blob), (1, .armored), (4, .king)] {
            _ = scene.spawn(EnemySpawn(id: lane + 1, sign: "学", kind: kind), lane: lane, x: lawn.columnX(4) + 80)
        }
        _ = scene.dropBarricade(try #require(tuning.barricade), before: 5)
        run(scene, seconds: 9, clock: &clock)
        // 测试里不跑 SKAction，种下的放大、出场的淡入、铁栅门落下都直接摆到结束状态
        for node in scene.children {
            if node is DefenderNode {
                node.setScale(1)
                node.alpha = 1
                node.position.y = lawn.laneY((node as? DefenderNode)?.lane ?? 0)
            } else if node is EnemyNode {
                node.alpha = 1
            }
        }
        let texture = try #require(view.texture(from: scene, crop: CGRect(origin: .zero, size: scene.size)))
        let bitmap = NSBitmapImageRep(cgImage: texture.cgImage())
        try #require(bitmap.representation(using: .png, properties: [:])).write(to: URL(fileURLWithPath: path))
    }
    #endif
}

@Suite("防御道具 · 对局")
@MainActor
struct GuardSessionTests {
    private func session(grade: Grade = .g3) -> GameSession {
        let library = ContentLibrary.load(userDirectory: nil)
        let pack = library.packs.first { $0.grade == grade } ?? library.packs[0]
        return GameSession(config: GameConfig(profileID: UUID(), grade: grade, packIDs: [pack.id],
                                              selection: .all, difficulty: .normal),
                           library: library, progress: ProgressStore(), speech: Speech(),
                           growth: GrowthStore(catalog: .bundled))
    }

    @Test func guardCardsCanBePlanted() {
        let s = session()
        let before = s.sun
        let point = CGPoint(x: Lawn(lanes: 5).columnX(5), y: Lawn(lanes: 5).laneY(2))
        #expect(s.dropSeed(id: "wallnut", at: point))
        #expect(s.sun == before - DefenderKind.wallnut.sunCost)
        #expect(!s.canStartBattle, "只有防御道具还不能开战")
        #expect(!s.dropSeed(id: "ironGate", at: point), "铁栅门不能拖到草坪上")
    }

    @Test func ironGateCostsSunAndOnlyOneAtATime() throws {
        let s = session()
        _ = s.scene.plant(.inkling, in: DefenderCell(lane: 0, column: 0))
        s.startBattle()
        #expect(!s.dropBarricade(), "没有僵尸时不放")
        let spec = try #require(s.nextEnemy())
        s.scene.spawn(spec, lane: 0, x: 800)
        s.targetChanged(to: spec.id)
        #expect(s.canDropBarricade)
        let before = s.sun
        #expect(s.dropBarricade())
        #expect(s.sun == before - DefenderKind.ironGate.sunCost)
        #expect(s.barricadeDown)
        #expect(!s.canDropBarricade)
        #expect(!s.dropBarricade(), "场上已经有一道门")
        s.barricadeRemoved()
        #expect(s.canDropBarricade)
    }

    @Test func preschoolHasNoIronGate() {
        let tuning = GameTuning.make(grade: .k2, difficulty: .normal)
        #expect(tuning.barricade == nil)
        #expect(!tuning.guards.contains { $0.id == "tallnut" })
        #expect(session(grade: .k2).canDropBarricade == false)
    }
}
