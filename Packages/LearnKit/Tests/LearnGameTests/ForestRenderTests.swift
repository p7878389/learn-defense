import Foundation
import LearnCore
import SwiftUI
import Testing
@testable import LearnGame

/// 森林塔防画面：素材都能从资源包加载，战斗各阶段能完整渲染出来
@MainActor
@Suite("森林塔防渲染")
struct ForestRenderTests {
    @Test func allArtworkLoadsFromBundle() {
        let missing = ForestArtwork.names.filter { ForestArtwork.images[$0] == nil }
        #expect(missing.isEmpty, "缺少素材：\(missing)")
    }

    /// 准备阶段：空塔位统一画地图专用底座并发光提示可建造，已建的塔立在底座上。
    @Test func preparingFieldShowsSlotPads() throws {
        var battle = ForestBattle()
        let built = battle.build(.rapid, at: 2) && battle.build(.frost, at: 3)
        #expect(built)
        for _ in 0..<20 { battle.tick(1.0 / 30) }
        let renderer = ImageRenderer(content: ForestBattlefield(battle: battle, width: 1100, height: 1100 * 768 / 1376))
        renderer.scale = 1
        let image = try #require(renderer.cgImage)
        if let directory = ProcessInfo.processInfo.environment["FOREST_SNAPSHOT_DIR"] {
            try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
            let url = URL(fileURLWithPath: directory).appendingPathComponent("prepare.png") as CFURL
            let destination = try #require(CGImageDestinationCreateWithURL(url, "public.png" as CFString, 1, nil))
            CGImageDestinationAddImage(destination, image, nil)
            #expect(CGImageDestinationFinalize(destination))
        }
    }

    /// 单塔打完一整波：行走、开火、弹道、命中、击败每一帧都能渲染。
    /// 设置环境变量 FOREST_SNAPSHOT_DIR 时把有弹道或击败特效的帧存成 PNG，便于人工核对动画效果。
    @Test(arguments: [(ForestTower.rapid, 2), (ForestTower.frost, 3)])
    func battleFramesRender(tower: ForestTower, slot: Int) throws {
        var battle = ForestBattle()
        let built = battle.build(tower, at: slot)
        #expect(built)
        battle.startWave()
        let directory = ProcessInfo.processInfo.environment["FOREST_SNAPSHOT_DIR"].map { URL(fileURLWithPath: $0) }
        var rendered = 0, saved = 0, sawShot = false, sawDefeat = false
        for frame in 0..<3000 where battle.phase == .fighting {
            battle.tick(1.0 / 30)
            sawShot = sawShot || !battle.shots.isEmpty
            sawDefeat = sawDefeat || !battle.defeats.isEmpty
            guard frame % 30 == 0 || !battle.defeats.isEmpty || !battle.shots.isEmpty else { continue }
            let renderer = ImageRenderer(content: ForestBattlefield(battle: battle, width: 1100, height: 1100 * 768 / 1376))
            renderer.scale = 1
            let image = try #require(renderer.cgImage)
            rendered += 1
            if let directory, saved < 150 || !battle.defeats.isEmpty {
                saved += 1
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let name = String(format: "%@-%04d.png", tower == .rapid ? "rapid" : "frost", frame)
                let destination = try #require(CGImageDestinationCreateWithURL(directory.appendingPathComponent(name) as CFURL, "public.png" as CFString, 1, nil))
                CGImageDestinationAddImage(destination, image, nil)
                #expect(CGImageDestinationFinalize(destination))
            }
        }
        #expect(sawShot && sawDefeat)
        #expect(rendered > 10)
    }
}
