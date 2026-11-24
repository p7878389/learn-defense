import Foundation
import LearnCore
import SpriteKit
import Testing
#if os(macOS)
import AppKit
import SwiftUI
#endif
@testable import LearnGame

@MainActor
@Suite("毁灭菇资源与场景", .serialized)
struct AdventureDoomSceneTests {
    private func battle() -> AdventureBattle {
        let level = AdventureLevel(id: 1, title: "爆破试炼", hint: "留意坑位", waves: [
            AdventureWave(enemies: [.init(kind: .boss, lane: 0, delay: 3600)])
        ])
        var state = AdventureBattle(level: level, deck: ["inkling", "frost", "wallnut", "doomShroom"])
        _ = state.plant("inkling", lane: 4, column: 0)
        _ = state.plant("doomShroom", lane: 2, column: 5)
        return state
    }

    @Test func cardPortraitAndIndependentArchivesLoad() throws {
        let kind = try #require(AdventureCatalog.defender("doomShroom"))
        #expect(UnitSprites.portrait(of: kind, skin: nil) != nil)
        let first = try #require(FXLibrary.effect(named: "DoomBody"))
        let second = try #require(FXLibrary.effect(named: "DoomBody"))
        first.removeAllChildren()
        #expect(!second.children.isEmpty)
        #expect(FXLibrary.effect(named: "DoomCrater") != nil)
    }

    @Test func chargeBecomesOneCraterAndRestoreDoesNotReplayBlast() throws {
        var state = battle()
        let scene = AdventureScene(loadout: Loadout())
        scene.render(state, events: [])
        #expect(scene.children.contains { $0.name?.hasPrefix("doom-charge-") == true })
        _ = state.start()
        let events = state.advance(by: 1)
        scene.render(state, events: events)
        #expect(!scene.children.contains { $0.name?.hasPrefix("doom-charge-") == true })
        #expect(scene.children.filter { $0.name?.hasPrefix("doom-crater-") == true }.count == 1)
        #expect(scene.childNode(withName: "DoomExplosion") != nil)
        let restored = AdventureScene(loadout: Loadout())
        restored.render(state, events: [])
        #expect(restored.childNode(withName: "DoomExplosion") == nil)
        #expect(restored.children.filter { $0.name?.hasPrefix("doom-crater-") == true }.count == 1)
        state.pause()
        restored.render(state, events: [])
        let before = state
        _ = state.advance(by: 30)
        #expect(state == before)
    }

    @Test func explosionPausesAndCleansWithoutChangingBattleState() throws {
        let clock = try ThemeClock()
        let effect = try #require(FXLibrary.playResource("DoomExplosion", at: CGPoint(x: 320, y: 100), in: clock.scene))
        try clock.advance(0.2)
        clock.scene.speed = 0
        FXLibrary.setPaused(true, in: clock.scene)
        try clock.advance(0.05)
        let before = clock.pixels()
        try clock.advance(0.4)
        #expect(before == clock.pixels())
        clock.scene.speed = 1
        FXLibrary.setPaused(false, in: clock.scene)
        try clock.advance(2)
        #expect(effect.parent == nil)
    }

    @Test func frostDecorationAndImpactSynchronizedDefeatInAdventureScene() throws {
        let level = AdventureLevel(id: 1, title: "同步试炼", hint: "", waves: [
            AdventureWave(enemies: [.init(kind: .runner, lane: 0, delay: 0)])
        ])
        var state = AdventureBattle(level: level, deck: ["frost", "inkling", "wallnut", "doomShroom"])
        #expect(state.plant("frost", lane: 1, column: 0) == true)
        #expect(state.plant("doomShroom", lane: 0, column: 8) == true)
        let scene = AdventureScene(loadout: Loadout())
        scene.render(state, events: [])
        let frost = try #require(scene.children.compactMap { $0 as? DefenderNode }.first)
        #expect(frost.childNode(withName: "iceAura") != nil)
        #expect(state.start() == true)
        let events = state.advance(by: 1)
        scene.render(state, events: events)
        let enemy = try #require(scene.children.compactMap { $0 as? EnemyNode }.first)
        #expect(enemy.rig?.current == "zombie-boom", "毁灭菇爆破在冒险中也应立即播放烧焦倒地")
    }

    @Test func bulletsTrackMovingEnemyAndNeverDefeatBeforeFinalBulletImpacts() throws {
        // 1. 远距离双发射手 + 近距离单发射手同路交火：
        // 疾跑怪（简单难度 11 血）在 x=1155 出生，第 0 列双发（8 伤，第二颗 0.92s 到达）与第 5 列单发（4 伤，0.46s 到达）同帧开火击杀。
        // 近处子弹在 0.46s 先到、甚至过 0.85s 旧兜底点时，远处第二颗子弹仍在空中，怪物绝不能提前倒地。
        let level = AdventureLevel(id: 1, title: "弹道同步试炼", hint: "", waves: [
            AdventureWave(enemies: [
                .init(kind: .runner, lane: 0, delay: 0),
                .init(kind: .armored, lane: 1, delay: 0),
            ])
        ])
        var state = AdventureBattle(level: level, difficulty: .easy, deck: ["twin", "inkling", "frost", "wallnut"])
        #expect(state.plant("twin", lane: 0, column: 0) == true)
        #expect(state.plant("inkling", lane: 0, column: 5) == true)
        #expect(state.plant("inkling", lane: 1, column: 0) == true)
        #expect(state.start() == true)

        let scene = AdventureScene(loadout: Loadout())
        let clock = try ThemeClock(scene: scene)
        let openEvents = state.advance(by: 0.05)
        scene.render(state, events: openEvents)

        let runner = try #require(scene.children.compactMap { $0 as? EnemyNode }.first { $0.lane == 0 })
        let armored = try #require(scene.children.compactMap { $0 as? EnemyNode }.first { $0.lane == 1 })
        let armoredSign = try #require(armored.sign.children.compactMap { $0 as? SKLabelNode }.first)
        #expect(armoredSign.text == "34 / 34", "子弹刚出膛未命中前，牌子血量不应提前扣减")

        // 推进 0.55 秒：第 5 列近处子弹已命中，但第 0 列双发的两颗子弹仍在飞行中；同时 1 路重甲怪向左移动。
        for _ in 0..<11 {
            let stepEvents = state.advance(by: 0.05)
            scene.render(state, events: stepEvents)
            try clock.advance(0.05)
        }
        #expect(runner.rig?.current != "zombie-dasher-die", "近处子弹先到时，远处致死连发仍在空中，怪物不能提前倒地")
        #expect(runner.position.x < 1155, "致死子弹飞行期间怪物仍自然前行，不在开火瞬间原地僵直")
        #expect(armoredSign.text == "34 / 34", "1 路子弹仍在途中时血量保持出膛前数值")

        // 推进到 0.86 秒（跨过旧的 0.85s 兜底时间，也跨过双发第一颗 0.80s 命中，但第二颗 0.92s 尚未到达）。
        for _ in 0..<6 {
            let stepEvents = state.advance(by: 0.05)
            scene.render(state, events: stepEvents)
            try clock.advance(0.05)
        }
        #expect(runner.rig?.current != "zombie-dasher-die", "0.86 秒时双发第二颗子弹尚未抵达，不能被 0.85 秒定时器提前判死")
        #expect(armoredSign.text == "30 / 34", "1 路单发子弹在 0.80 秒命中后，牌子血量才同步扣减")
        let splat = try #require(scene.childNode(withName: "impactSplat"))
        #expect(abs(splat.position.x - armored.position.x) < 6, "命中特效必须落在移动后怪物的当前位置，而不是出膛时的旧坐标")

        // 推进到 0.96 秒：双发第二颗子弹（0.92s）到达，此时所有在途子弹全部命中，怪物立即倒地。
        try clock.advance(0.10)
        #expect(runner.rig?.current == "zombie-dasher-die", "最后一颗在途子弹命中瞬间才播放倒地动画")
    }

    #if os(macOS)
    @Test func exportsActualBattleUIAndEffectStages() throws {
        guard let path = ProcessInfo.processInfo.environment["DOOM_PREVIEW"] else { return }
        let folder = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for (name, xp, coins, owned) in [("locked", 0, 600, false), ("for-sale", 220, 600, false), ("owned", 220, 0, true)] {
            let db = try LearnDatabase(url: nil)
            let child = Profile(name: "解锁预览", grade: .g3, avatar: "🌱")
            try db.saveProfiles([child])
            var state = GrowthState(); state.xp = xp; state.coins = coins
            if owned { state.owned.insert("defender.doomShroom") }
            try db.saveGrowthState(state, profileID: child.id)
            let previewModel = AppModel(database: db, library: .load(userDirectory: nil), speechLibrary: SpeechLibrary(database: db))
            for width: CGFloat in [375, 820, 1180] {
                let content = DoomShroomUnlockView(profileID: child.id, onClose: {}).environmentObject(previewModel)
                try captureStaticView(content, size: CGSize(width: width, height: 720),
                                      url: folder.appendingPathComponent("unlock-\(name)-\(Int(width)).png"))
                let embedded = DoomShroomUnlockView(profileID: child.id, onClose: {}, embedded: true, wideLayout: width >= 900).environmentObject(previewModel)
                try captureStaticView(embedded, size: CGSize(width: width, height: 600),
                                      url: folder.appendingPathComponent("unlock-tab-\(name)-\(Int(width)).png"))
                if name == "for-sale", width == 820 {
                    try captureStaticView(CollectionView(profileID: child.id, onClose: {}).environmentObject(previewModel),
                                          size: CGSize(width: 1180, height: 736), url: folder.appendingPathComponent("collection-tabs.png"))
                }
            }
            #expect(previewModel.growth(for: child.id).state == state, "只查看解锁页不能扣积分或改变拥有记录")
        }
        let database = try LearnDatabase(url: nil)
        let profile = Profile(name: "毁灭菇预览", grade: .g3, avatar: "🐯")
        try database.saveProfiles([profile])
        var growth = GrowthState(); growth.coins = 80
        growth.owned.insert("defender.doomShroom")
        try database.saveGrowthState(growth, profileID: profile.id)
        let model = AppModel(database: database, library: .load(userDirectory: nil), speechLibrary: SpeechLibrary(database: database))
        let session = AdventureSession(levelID: 1, model: model, profileID: profile.id, difficulty: .normal,
                                       deck: ["inkling", "frost", "wallnut", "doomShroom"])
        session.plant("inkling", lane: 4, column: 0)
        // 顶部实际卡栏、底部操作区及真实场景，非概念图替代。
        try captureUI(session, size: CGSize(width: 1180, height: 736), url: folder.appendingPathComponent("landscape-ready.png"))
        let background = try #require(BattleMapArtwork.image(.woodland))
        let placement = ZStack {
            Image(decorative: background, scale: 1).resizable().frame(width: 1200, height: 600)
            AdventurePlacementPreview(battle: session.battle, kindID: "doomShroom", cell: DefenderCell(lane: 2, column: 5))
        }.frame(width: 1200, height: 600)
        let placementImage = try #require(ImageRenderer(content: placement).cgImage)
        try #require(NSBitmapImageRep(cgImage: placementImage).representation(using: .png, properties: [:]))
            .write(to: folder.appendingPathComponent("placement-ready.png"))
        session.plant("doomShroom", lane: 2, column: 5)
        try captureUI(session, size: CGSize(width: 1180, height: 736), url: folder.appendingPathComponent("landscape-charge.png"))
        session.start()
        session.advance(by: 1)
        session.scene.onAdvance = nil
        let clock = try ThemeClock(scene: session.scene)
        try clock.advance(0.2)
        try clock.writePNG(to: folder.appendingPathComponent("engine-blast.png"))
        try clock.advance(1.6)
        try clock.writePNG(to: folder.appendingPathComponent("engine-crater.png"))
        try captureUI(session, size: CGSize(width: 1180, height: 736), url: folder.appendingPathComponent("landscape-crater.png"))
        try captureUI(session, size: CGSize(width: 820, height: 1100), url: folder.appendingPathComponent("portrait-crater.png"))
        let preview = AdventurePlacementPreview(battle: session.battle, kindID: "doomShroom", cell: DefenderCell(lane: 2, column: 5))
        let image = try #require(ImageRenderer(content: preview.frame(width: 1200, height: 600)).cgImage)
        try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
            .write(to: folder.appendingPathComponent("placement-blocked.png"))
    }

    private func captureUI(_ session: AdventureSession, size: CGSize, url: URL) throws {
        let host = NSHostingView(rootView: AdventureScreen(session: session, onClose: {}).frame(width: size.width, height: size.height))
        let window = NSWindow(contentRect: CGRect(origin: CGPoint(x: -5000, y: -5000), size: size),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = host
        defer { window.orderOut(nil) }
        host.frame = CGRect(origin: .zero, size: size)
        for _ in 0..<5 { host.layoutSubtreeIfNeeded(); window.displayIfNeeded(); RunLoop.current.run(until: Date().addingTimeInterval(0.06)) }
        let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        let image = try #require(bitmap.cgImage)
        let context = try #require(CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        func sprite(_ view: NSView) -> SKView? {
            if let view = view as? SKView { return view }
            return view.subviews.lazy.compactMap { sprite($0) }.first
        }
        let skView = try #require(sprite(host))
        let frame = skView.convert(skView.bounds, to: host)
        #expect(frame.width > 500 && frame.height > 240)
        let texture = try #require(skView.texture(from: session.scene, crop: CGRect(origin: .zero, size: session.scene.size)))
        let scale = CGFloat(image.width) / size.width
        let y = host.isFlipped ? size.height - frame.maxY : frame.minY
        context.draw(texture.cgImage(), in: CGRect(x: frame.minX * scale, y: y * scale, width: frame.width * scale, height: frame.height * scale))
        let result = try #require(context.makeImage())
        try #require(NSBitmapImageRep(cgImage: result).representation(using: .png, properties: [:])).write(to: url)
    }

    private func captureStaticView<V: View>(_ screen: V, size: CGSize, url: URL) throws {
        let host = NSHostingView(rootView: screen.frame(width: size.width, height: size.height))
        let window = NSWindow(contentRect: CGRect(origin: CGPoint(x: -5000, y: -5000), size: size),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = host
        defer { window.orderOut(nil) }
        host.frame = CGRect(origin: .zero, size: size)
        for _ in 0..<4 { host.layoutSubtreeIfNeeded(); window.displayIfNeeded(); RunLoop.current.run(until: Date().addingTimeInterval(0.04)) }
        let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        try #require(bitmap.representation(using: .png, properties: [:])).write(to: url)
    }
    #endif
}
