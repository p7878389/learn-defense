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
            for width: CGFloat in [375, 820] {
                let content = DoomShroomUnlockView(profileID: child.id, onClose: {}).environmentObject(previewModel)
                try captureStaticView(content, size: CGSize(width: width, height: 720),
                                      url: folder.appendingPathComponent("unlock-\(name)-\(Int(width)).png"))
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
