import Foundation
import SwiftUI
import ImageIO
import Testing
@testable import LearnCore
@testable import LearnGame

@MainActor
@Suite("森林全体动作帧")
struct ForestActionTests {
    @Test func everyAuthoredRosterKindHasNineDistinctFrames() throws {
        for kind in ForestRosterArtwork.actionKinds {
            var hashes: [Data] = []
            for index in 0..<9 {
                let name = ForestRosterArtwork.actionFrame(kind, index)
                let image = try #require(ForestRosterArtwork.bitmap(name), "\(name)")
                #expect(image.width == 320 && image.height == 320)
                hashes.append(try #require(image.dataProvider?.data) as Data)
            }
            #expect(Set(hashes).count == 9, "\(kind)")
        }
        #expect(ForestRosterArtwork.actionNames.count == 99)
    }

    @Test func knightWalkAndAttackSelectSeparateFrames() {
        var enemy = ForestEnemy(id: 0, kind: .knight)
        #expect(ForestRosterArtwork.locomotionPose(enemy, progress: 0.4) == "knight-action-2")
        enemy.rooted = 2
        #expect(ForestRosterArtwork.locomotionPose(enemy, progress: 0.4) == "knight-action-2")
        enemy.cast = ForestCast(target: 0, point: .init(x: 0.5, y: 0.5),
                                windup: 0.6, recovery: 0.4, effect: .slash, skill: false, count: 1)
        #expect(ForestRosterArtwork.locomotionPose(enemy, progress: 0.4) == "knight-action-6")
        enemy.cast!.age = 0.6
        #expect(ForestRosterArtwork.locomotionPose(enemy, progress: 0.4) == "knight-action-7")
        enemy.cast!.age = 0.8
        #expect(ForestRosterArtwork.locomotionPose(enemy, progress: 0.4) == "knight-action-8")
    }

    @Test func authoredMovesUseWalkForGroundAndWingFramesForFlyingUnits() {
        for kind in ForestRosterArtwork.actionKinds {
            var enemy = ForestEnemy(id: 0, kind: kind)
            for frame in 0..<6 {
                enemy.distance = Double(frame) / 6
                #expect(ForestRosterArtwork.locomotionPose(enemy, progress: (Double(frame) + 0.1) / 6)
                    == ForestRosterArtwork.actionFrame(kind, frame), "\(kind) \(frame)")
            }
            enemy.rooted = 1
            #expect(ForestRosterArtwork.locomotionPose(enemy, progress: 5.1 / 6)
                == ForestRosterArtwork.actionFrame(kind, 5), "\(kind)")
        }
    }

    @Test func everyAuthoredKindRendersWalkChargeReleaseAndRecovery() throws {
        for kind in ForestRosterArtwork.actionKinds {
            for (index, stage) in [0, 6, 7, 8].enumerated() {
                var enemy = ForestEnemy(id: index, kind: kind)
                enemy.distance = 0.4
                if stage >= 6 {
                    enemy.cast = ForestCast(target: 1, point: ForestPoint(x: 0.7, y: 0.5),
                                            windup: 0.6, recovery: 0.4, effect: kind.effect,
                                            skill: stage == 7, count: 1)
                    enemy.cast!.age = stage == 6 ? 0.2 : (stage == 7 ? 0.61 : 0.85)
                }
                let renderer = ImageRenderer(content: ForestRosterEnemyView(
                    enemy: enemy, width: 900, height: 500, time: 1).frame(width: 900, height: 500))
                renderer.scale = 1
                let image = try #require(renderer.cgImage)
                #expect(image.width == 900 && image.height == 500, "\(kind) \(stage)")
            }
        }
    }

    @Test func impactEffectMovesThroughSixStagesAndFades() {
        #expect((0..<6).map { ForestCombatOverlay.impactStage(Double($0) / 6 + 0.02) }
            == [0, 1, 2, 3, 4, 5])
        #expect((0..<6).map(ForestCombatOverlay.impactParticleCount) == [4, 8, 12, 10, 6, 2])
    }

    @Test func shieldAndSpreadAttacksRenderOnTheirPhaseFrames() throws {
        @MainActor func render(_ effect: ForestCombatEffect) throws -> Data {
            var battle = ForestBattle()
            battle.phase = .fighting
            let point = ForestPoint(x: 0.5, y: 0.5)
            var shot = ForestCombatShot(id: 1, side: .enemy, source: 1, target: 2,
                                        origin: point, point: point, effect: effect,
                                        damage: 1, flight: 0.2, radius: effect == .soul ? 0.02 : 0.12,
                                        skill: effect == .soul)
            shot.age = 0.2 + 0.45 * 0.35
            battle.combatShots = [shot]
            let renderer = ImageRenderer(content: ForestCombatOverlay(battle: battle, width: 800, height: 450)
                .frame(width: 800, height: 450))
            renderer.scale = 1
            return try #require(renderer.cgImage?.dataProvider?.data) as Data
        }
        #expect(try render(.soul) != render(.fire))
        #expect(try render(.frost) != render(.acid))
    }
}

@Suite("森林动作帧缓存")
struct ForestActionCacheTests {
    @Test func recentlyUsedFramesOutliveOlderOnes() {
        var order = ForestFrameRecency(limit: 3)
        #expect(order.touch("a").isEmpty)
        #expect(order.touch("b").isEmpty)
        #expect(order.touch("c").isEmpty)
        // a 刚被再次用到，超出上限时该淘汰的是最久没用的 b。
        #expect(order.touch("a").isEmpty)
        #expect(order.touch("d") == ["b"])
        #expect(order.touch("e") == ["c"])
        #expect(order.touch("a").isEmpty)
    }

    @Test func limitLeavesRoomForEveryKindOfOneWave() {
        let battle = ForestBattle(boss: .reaper)
        for wave in 1...battle.rules.economy.waves {
            let frames = battle.rosterKinds(inWave: wave).filter(ForestRosterArtwork.hasActionSheet).count * 9
            #expect(frames <= ForestRosterArtwork.actionCacheLimit, "第 \(wave) 波")
        }
    }
}
