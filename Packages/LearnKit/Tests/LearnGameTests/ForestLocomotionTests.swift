import Foundation
import ImageIO
@testable import LearnCore
import SwiftUI
import Testing
@testable import LearnGame

@MainActor
@Suite("森林怪物移动表现")
struct ForestLocomotionTests {
    @Test func ogreHasSixDistinctTransparentWalkingFrames() throws {
        var data: [Data] = []
        for index in 0..<6 {
            let image = try #require(ForestRosterArtwork.bitmap("ogre-walk-\(index)"))
            #expect(image.width == 512 && image.height == 512)
            data.append(try #require(image.dataProvider?.data) as Data)
        }
        #expect(Set(data).count == 6)
    }

    @Test func ogreFacingAndWalkFramesRespectMovementAndCasting() {
        var enemy = ForestEnemy(id: 0, kind: .ogre)
        #expect(ForestRosterArtwork.nativeFacing(.ogre) == -1)
        for frame in 0..<6 {
            enemy.distance = (Double(frame) + 0.1) / (6 * 18)
            let motion = ForestEnemyLocomotion(enemy: enemy, time: 0)
            #expect(ForestRosterArtwork.locomotionPose(enemy, progress: motion.progress) == "ogre-walk-\(frame)")
            #expect(motion.lift == 0 && motion.lean == 0)
            #expect(motion.scaleX == 1 && motion.scaleY == 1)
        }
        enemy.rooted = 2
        let held = ForestEnemyLocomotion(enemy: enemy, time: 10)
        #expect(ForestRosterArtwork.locomotionPose(enemy, progress: held.progress) == "ogre-walk-5")
        enemy.cast = ForestCast(target: 0, point: .init(x: 0.5, y: 0.5), windup: 0.8,
                                recovery: 0.65, effect: .smash, skill: true, count: 1)
        #expect(ForestRosterArtwork.locomotionPose(enemy, progress: held.progress) == "ogre")
        enemy.cast!.age = 0.81
        #expect(ForestRosterArtwork.locomotionPose(enemy, progress: held.progress) == "ogre-skill")
    }

    @Test func ogreWalkPreviewBothDirections() throws {
        guard let path = ProcessInfo.processInfo.environment["FOREST_MOTION_PREVIEW_DIR"] else { return }
        let directory = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let gif = try #require(CGImageDestinationCreateWithURL(
            directory.appendingPathComponent("ogre-walk-directions.gif") as CFURL, "com.compuserve.gif" as CFString, 24, nil))
        CGImageDestinationSetProperties(gif, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        for frame in 0..<24 {
            let phase = Double(frame) / 24
            let renderer = ImageRenderer(content: HStack(spacing: 0) {
                ForEach([-1.0, 1.0], id: \.self) { direction in
                    VStack {
                        Text(direction < 0 ? "向左行走" : "向右行走").font(.headline).foregroundStyle(.black)
                        ogrePreview(phase: phase, facing: direction)
                    }
                }
            }.padding(12).background(Color(red: 0.89, green: 0.92, blue: 0.86)))
            renderer.scale = 1
            let image = try #require(renderer.cgImage)
            CGImageDestinationAddImage(gif, image, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 0.07]] as CFDictionary)
            if frame == 8 {
                let png = try #require(CGImageDestinationCreateWithURL(
                    directory.appendingPathComponent("ogre-directions.png") as CFURL, "public.png" as CFString, 1, nil))
                CGImageDestinationAddImage(png, image, nil)
                #expect(CGImageDestinationFinalize(png))
            }
        }
        #expect(CGImageDestinationFinalize(gif))
    }

    private func ogrePreview(phase: Double, facing: Double) -> some View {
        var enemy = ForestEnemy(id: 0, kind: .ogre)
        enemy.distance = phase / 18
        enemy.facing = facing
        let point = ForestPath.forest.point(at: enemy.distance)
        return ForestRosterEnemyView(enemy: enemy, width: 1600, height: 900, time: phase)
            .offset(x: 180 - point.x * 1600, y: 270 - point.y * 900)
            .frame(width: 360, height: 320).clipped()
    }

    private func pixels(_ enemy: ForestEnemy, time: Double) throws -> Data {
        let renderer = ImageRenderer(content: ForestRosterEnemyView(
            enemy: enemy, width: 800, height: 450, time: time).frame(width: 800, height: 450))
        renderer.scale = 1
        let image = try #require(renderer.cgImage)
        return try #require(image.dataProvider?.data) as Data
    }

    @Test func floatingMonsterHoversWithoutAdvancingAlongPath() throws {
        var enemy = ForestEnemy(id: 3, kind: .reaper)
        enemy.distance = 0.4
        #expect(try pixels(enemy, time: 0) != pixels(enemy, time: 0.6))
        #expect(enemy.distance == 0.4)
    }

    @Test func turningBossShowsAPlantAndPivotPose() throws {
        var enemy = ForestEnemy(id: 4, kind: .ogre)
        enemy.distance = 0.4
        let walking = try pixels(enemy, time: 0)
        enemy.turnTimer = ForestEnemy.turnTime / 2
        #expect(try pixels(enemy, time: 0) != walking)
    }

    @Test func groundedPoseTracksDistanceRatherThanWallTime() throws {
        var enemy = ForestEnemy(id: 5, kind: .knight)
        enemy.distance = 0.4
        #expect(try pixels(enemy, time: 0) == pixels(enemy, time: 0.6))
        enemy.rooted = 2
        #expect(try pixels(enemy, time: 0) == pixels(enemy, time: 0.6))
    }

    @Test func stoppedBoarDoesNotKickUpDustOrResetItsWalkFrame() {
        var enemy = ForestEnemy(id: 0, kind: .boar)
        let walking = ForestEnemyLocomotion(enemy: enemy, time: 0)
        #expect(walking.dustOpacity > 0)
        enemy.rooted = 2
        let rooted = ForestEnemyLocomotion(enemy: enemy, time: 1)
        #expect(rooted.dustOpacity == 0)
        #expect(rooted.frameIndex(count: 6) == walking.frameIndex(count: 6))
        enemy.rooted = 0
        enemy.cast = ForestCast(target: 0, point: .init(x: 0, y: 0), windup: 1,
                                recovery: 0.5, effect: .smash, skill: false, count: 1)
        #expect(ForestEnemyLocomotion(enemy: enemy, time: 2).dustOpacity == 0)
    }

    @Test func cyclesStayBoundedAndReducedMotionKeepsTheBodySteady() {
        for kind in ForestEnemyKind.allCases {
            var enemy = ForestEnemy(id: 8, kind: kind)
            for step in 0..<120 {
                enemy.distance = Double(step) / 1000
                enemy.turnTimer = step % 2 == 0 ? ForestEnemy.turnTime / 2 : 0
                let motion = ForestEnemyLocomotion(enemy: enemy, time: Double(step) / 30)
                #expect((0..<6).contains(motion.frameIndex(count: 6)))
                #expect((0.88...1.12).contains(motion.scaleX))
                #expect((0.88...1.12).contains(motion.scaleY))
                let reduced = ForestEnemyLocomotion(enemy: enemy, time: Double(step) / 30, reduceMotion: true)
                #expect(reduced.scaleX == 1 && reduced.scaleY == 1 && reduced.lean == 0)
                #expect(reduced.dustOpacity == 0)
            }
        }
    }

    /// 用实际战场渲染移动序列；设置目录时导出 GIF 和关键帧，供人工检查。
    @Test func walkingRosterRendersThroughFullCycle() throws {
        var battle = ForestBattle()
        battle.phase = .fighting
        battle.enemies = [ForestEnemyKind.skeleton, .boar, .ogre, .slime, .reaper, .gargoyle].enumerated().map { index, kind in
            var enemy = ForestEnemy(id: index + 1, kind: kind)
            enemy.distance = 0.15 + Double(index) * 0.31
            enemy.attackCooldown = 100
            return enemy
        }
        let directory = ProcessInfo.processInfo.environment["FOREST_MOTION_PREVIEW_DIR"].map { URL(fileURLWithPath: $0) }
        var destination: CGImageDestination?
        if let directory {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            destination = try #require(CGImageDestinationCreateWithURL(
                directory.appendingPathComponent("forest-walk.gif") as CFURL, "com.compuserve.gif" as CFString, 32, nil))
            CGImageDestinationSetProperties(destination!, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        }
        for frame in 0..<32 {
            battle.tick(0.1)
            let renderer = ImageRenderer(content: ForestBattlefield(battle: battle, width: 1100, height: 614))
            renderer.scale = 1
            let image = try #require(renderer.cgImage)
            #expect(image.width == 1100 && image.height == 614)
            if let destination {
                CGImageDestinationAddImage(destination, image, [
                    kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 0.1]
                ] as CFDictionary)
            }
            if let directory, [0, 10, 20, 31].contains(frame) {
                let png = try #require(CGImageDestinationCreateWithURL(
                    directory.appendingPathComponent("walk-\(frame).png") as CFURL, "public.png" as CFString, 1, nil))
                CGImageDestinationAddImage(png, image, nil)
                #expect(CGImageDestinationFinalize(png))
            }
        }
        if let destination { #expect(CGImageDestinationFinalize(destination)) }
    }
}
