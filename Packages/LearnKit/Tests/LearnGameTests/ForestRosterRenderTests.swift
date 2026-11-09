import Foundation
import SwiftUI
import ImageIO
import Testing
@testable import LearnCore
@testable import LearnGame

@MainActor
@Suite("森林单位与技能渲染")
struct ForestRosterRenderTests {
    @Test func allRosterArtworkHasTransparentBackground() throws {
        for name in ForestRosterArtwork.names {
            let image = try #require(ForestRosterArtwork.bitmaps[name], "缺少素材 \(name)")
            #expect(image.width > 64 && image.height > 64)
            #expect(image.alphaInfo == .premultipliedLast)
            let data = try #require(image.dataProvider?.data)
            let bytes = try #require(CFDataGetBytePtr(data))
            #expect(bytes[3] == 0, "\(name) 白底应透明")
        }
    }

    @Test func allBossStatesAndDefenseControlsRender() throws {
        for (i, kind) in ForestEnemyKind.bosses.enumerated() {
            var battle = ForestBattle(boss: kind)
            let built = battle.build(.rapid, at: 2)
            let deployed = battle.deploy(.paladin, at: 3)
            #expect(built && deployed)
            battle.phase = .fighting
            var enemy = ForestEnemy(id: 100, kind: kind)
            enemy.distance = 0.55
            enemy.cast = ForestCast(target: 2, point: ForestBattle.slots[2], windup: kind.windup,
                                    recovery: kind.recovery, effect: kind.skillEffect, skill: true, count: 1)
            battle.enemies = [enemy]
            for age in [0.0, kind.windup * 0.7, kind.windup + 0.03, kind.windup + 0.3] {
                battle.enemies[0].cast!.age = age
                let renderer = ImageRenderer(content: ForestBattlefield(battle: battle, width: 1100, height: 614))
                renderer.scale = 1
                let image = try #require(renderer.cgImage)
                #expect(image.width == 1100 && image.height == 614)
                if let directory = ProcessInfo.processInfo.environment["FOREST_ROSTER_SNAPSHOT_DIR"], age == kind.windup * 0.7 {
                    try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
                    let url = URL(fileURLWithPath: directory).appendingPathComponent("\(i)-\(kind.rawValue).png")
                    let dest = try #require(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
                    CGImageDestinationAddImage(dest, image, nil)
                    #expect(CGImageDestinationFinalize(dest))
                }
            }
        }
    }
}
