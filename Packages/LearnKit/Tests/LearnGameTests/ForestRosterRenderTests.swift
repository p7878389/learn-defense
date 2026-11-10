import Foundation
import SwiftUI
import ImageIO
import Testing
@testable import LearnCore
@testable import LearnGame

@MainActor
@Suite("森林单位与技能渲染")
struct ForestRosterRenderTests {
    /// 预警圈画出的范围必须与伤害判定一致：圈内的塔位会受伤，圈外的不会。
    @Test func warningFootprintMatchesDamageArea() {
        let width = 1100.0, height = 614.0
        let rules = ForestRules.defaults
        for kind in ForestEnemyKind.bosses {
            let stats = rules.enemy(kind)
            var enemy = ForestEnemy(id: 1, kind: kind)
            enemy.cast = ForestCast(target: 4, point: ForestBattle.slots[4], windup: stats.windup,
                                    recovery: stats.recovery, effect: kind.skillEffect, skill: true, count: 1)
            #expect(ForestCombatOverlay.warningRadius(of: enemy, rules: rules) == stats.skillRadius)
            enemy.cast = ForestCast(target: 4, point: ForestBattle.slots[4], windup: stats.windup,
                                    recovery: stats.recovery, effect: kind.effect, skill: false, count: 1)
            #expect(ForestCombatOverlay.warningRadius(of: enemy, rules: rules) == 0)
        }
        let radius = rules.enemy(.gargoyle).skillRadius
        for a in ForestBattle.slots.indices {
            let rect = ForestCombatOverlay.footprint(at: ForestBattle.slots[a], radius: radius, width: width, height: height)
            for b in ForestBattle.slots.indices {
                let x = (ForestBattle.slots[b].x * width - rect.midX) / (rect.width / 2)
                let y = (ForestBattle.slots[b].y * height - rect.midY) / (rect.height / 2)
                let drawnInside = x * x + y * y <= 1 + 1e-9
                let damaged = ForestBattle.slots[a].distance(to: ForestBattle.slots[b]) <= radius
                #expect(drawnInside == damaged, "塔位 \(a) → \(b)")
            }
        }
    }

    /// 把位图画进已知格式的画布，读出每个像素的透明度。
    private func alpha(of image: CGImage) throws -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        try pixels.withUnsafeMutableBytes { buffer in
            let context = try #require(CGContext(data: buffer.baseAddress, width: image.width, height: image.height,
                                                 bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                                 space: CGColorSpaceCreateDeviceRGB(),
                                                 bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return stride(from: 3, to: pixels.count, by: 4).map { pixels[$0] }
    }

    @Test func allRosterArtworkIsPreBakedWithTransparentBackground() throws {
        var bytes = 0
        for name in ForestRosterArtwork.names {
            let url = try #require(ForestRosterArtwork.files[name], "缺少素材 \(name)")
            bytes += try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
            let image = try #require(ForestRosterArtwork.bitmap(name), "\(name) 无法解码")
            #expect(image.width == 512 && image.height == 512, "\(name) 应为 512 见方的整张画布")
            let alpha = try alpha(of: image)
            let corners = [0, image.width - 1, alpha.count - image.width, alpha.count - 1]
            #expect(corners.allSatisfy { alpha[$0] == 0 }, "\(name) 四角应是透明背景")
            let opaque = alpha.filter { $0 > 250 }.count
            #expect(opaque > alpha.count / 20, "\(name) 主体不应被挖空")
        }
        // 成品图整套约 1.8MB；原始白底 JPG（13MB）不应再进应用包。
        #expect(bytes < 3_000_000)
        let folder = try #require(ForestRosterArtwork.files.values.first).deletingLastPathComponent()
        let shipped = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        #expect(shipped.allSatisfy { $0.hasSuffix(".webp") }, "包里只放成品图：\(shipped.filter { !$0.hasSuffix(".webp") })")
        #expect(shipped.count == ForestRosterArtwork.names.count)
    }

    @Test func artworkIsDecodedOnceAndPosesFallBackToTheBaseImage() throws {
        let first = try #require(ForestRosterArtwork.bitmap("knight"))
        #expect(ForestRosterArtwork.bitmap("knight") === first)
        #expect(ForestRosterArtwork.bitmap("no-such-unit") == nil)
        let charging = ForestCast(target: 0, point: ForestBattle.slots[0], windup: 1, recovery: 0.5,
                                  effect: .meteor, skill: true, count: 1)
        var releasing = charging
        releasing.age = 1.05
        var recovering = charging
        recovering.age = 1.4
        #expect(ForestRosterArtwork.pose(.gargoyle, cast: nil) == "gargoyle")
        #expect(ForestRosterArtwork.pose(.gargoyle, cast: charging) == "gargoyle-windup")
        #expect(ForestRosterArtwork.pose(.gargoyle, cast: releasing) == "gargoyle-skill")
        #expect(ForestRosterArtwork.pose(.gargoyle, cast: recovering) == "gargoyle")
        // 骑士没有专门的蓄力图，回到主体图。
        #expect(ForestRosterArtwork.pose(.knight, cast: charging) == "knight")
    }

    @Test func allBossStatesAndDefenseControlsRender() throws {
        for (i, kind) in ForestEnemyKind.bosses.enumerated() {
            var battle = ForestBattle(boss: kind)
            let built = battle.build(.rapid, at: 2)
            let deployed = battle.deploy(.paladin, at: 3)
            #expect(built && deployed)
            battle.phase = .fighting
            let stats = battle.rules.enemy(kind)
            var enemy = ForestEnemy(id: 100, kind: kind)
            enemy.distance = 0.55
            enemy.cast = ForestCast(target: 2, point: ForestBattle.slots[2], windup: stats.windup,
                                    recovery: stats.recovery, effect: kind.skillEffect, skill: true, count: 1)
            battle.enemies = [enemy]
            for age in [0.0, stats.windup * 0.7, stats.windup + 0.03, stats.windup + 0.3] {
                battle.enemies[0].cast!.age = age
                let renderer = ImageRenderer(content: ForestBattlefield(battle: battle, width: 1100, height: 614))
                renderer.scale = 1
                let image = try #require(renderer.cgImage)
                #expect(image.width == 1100 && image.height == 614)
                if let directory = ProcessInfo.processInfo.environment["FOREST_ROSTER_SNAPSHOT_DIR"], age == stats.windup * 0.7 {
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
