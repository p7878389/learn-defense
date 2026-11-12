#if os(macOS)
import AppKit
import LearnCore
import SpriteKit
import SwiftUI
import Testing
@testable import LearnGame

@Suite("完整经典战场界面")
@MainActor
struct BattleScreenTests {
    @Test func renderFullItemShelf() throws {
        guard let folder = ProcessInfo.processInfo.environment["BATTLE_SCREEN_PREVIEW"] else { return }
        var inventory = Inventory(capacity: 3)
        inventory.add(.frostCharm)
        inventory.add(.heartLeaf)
        inventory.add(.luckyStar)
        let shelf = ItemBar(inventory: inventory, enabled: true, onUse: { _ in }, horizontal: true)
            .padding(12).background(Theme.paper)
        let renderer = ImageRenderer(content: shelf)
        renderer.scale = 2
        let image = try #require(renderer.cgImage)
        #expect(image.width <= 440, "三个横向道具占位不超过 220pt，给大招和地图名留出空间")
        try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        let data = try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
        try data.write(to: URL(fileURLWithPath: folder).appendingPathComponent("items-full.png"))
    }

    /// 使用生产 BattleScreen；Metal 场景按实际 SKView 的 frame 补入窗口位图。
    /// 不另造 HUD，也不使用概念图代替真实游戏组件。
    @Test func renderFullScreens() throws {
        guard let folder = ProcessInfo.processInfo.environment["BATTLE_SCREEN_PREVIEW"] else { return }
        try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        let library = ContentLibrary.load(userDirectory: nil)
        let pack = try #require(library.packs.first { $0.grade == .g3 })
        for (name, size) in [("landscape", CGSize(width: 1194, height: 834)),
                             ("portrait", CGSize(width: 834, height: 1194))] {
            for (state, playing, casting) in [("preparing", false, false), ("playing", true, false), ("casting", true, true)] {
                let session = GameSession(config: GameConfig(profileID: UUID(), grade: .g3, packIDs: [pack.id],
                                                              selection: .all, difficulty: .normal),
                                          library: library, progress: ProgressStore(), speech: Speech(), map: .woodland)
                session.scene.didMove(to: SKView(frame: CGRect(origin: .zero, size: session.scene.size)))
                _ = session.scene.plant(.inkling, in: DefenderCell(lane: 2, column: 0))
                if playing {
                    session.startBattle()
                    session.scene.update(10)
                    for index in 1...12 { session.scene.update(10 + Double(index) * 0.1) }
                    session.energy = session.tuning.ultimateEnergy
                    session.scene.setGamePaused(true)
                }
                for defender in session.scene.children.compactMap({ $0 as? DefenderNode }) {
                    defender.removeAllActions()
                    defender.setScale(1)
                }
                for enemy in session.scene.children.compactMap({ $0 as? EnemyNode }) {
                    enemy.removeAllActions()
                    enemy.alpha = 1
                }
                let screen = BattleScreen(session: session, onReplay: {}, onExit: {}, onOpenCollection: {})
                    .frame(width: size.width, height: size.height)
                let host = NSHostingView(rootView: screen)
                let window = NSWindow(contentRect: CGRect(origin: CGPoint(x: -5000, y: -5000), size: size),
                                      styleMask: .borderless, backing: .buffered, defer: false)
                window.contentView = host
                host.frame = CGRect(origin: .zero, size: size)
                for _ in 0..<5 {
                    host.layoutSubtreeIfNeeded()
                    window.displayIfNeeded()
                    RunLoop.current.run(until: Date().addingTimeInterval(0.06))
                }
                if casting {
                    session.energy = 0
                    session.scene.setGamePaused(false)
                    session.scene.unleash()
                    session.scene.update(1000)
                    for index in 1...25 { session.scene.update(1000 + Double(index) / 60) }
                    session.scene.setGamePaused(true)
                    #expect(session.isUnleashing)
                    for _ in 0..<3 {
                        host.layoutSubtreeIfNeeded()
                        window.displayIfNeeded()
                        RunLoop.current.run(until: Date().addingTimeInterval(0.04))
                    }
                }
                let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                host.cacheDisplay(in: host.bounds, to: bitmap)
                let snapshot = try #require(bitmap.cgImage)
                let context = try #require(CGContext(data: nil, width: snapshot.width, height: snapshot.height,
                                                      bitsPerComponent: 8, bytesPerRow: 0,
                                                      space: CGColorSpaceCreateDeviceRGB(),
                                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                context.draw(snapshot, in: CGRect(x: 0, y: 0, width: snapshot.width, height: snapshot.height))
                let skView = try #require(findSpriteView(host))
                let frame = skView.convert(skView.bounds, to: host)
                #expect(frame.width > 0 && frame.height >= 240, "完整工具栏下仍有可操作的地图空间")
                #expect(frame.minX >= -1 && frame.maxX <= size.width + 1)
                #expect(frame.minY >= -1 && frame.maxY <= size.height + 1)
                let texture = try #require(skView.texture(from: session.scene, crop: CGRect(origin: .zero, size: session.scene.size)))
                let fit = min(frame.width / 1200, frame.height / 600)
                let rect = CGRect(x: frame.midX - 600 * fit, y: frame.midY - 300 * fit, width: 1200 * fit, height: 600 * fit)
                let scale = CGFloat(snapshot.width) / size.width
                let y = host.isFlipped ? size.height - rect.maxY : rect.minY
                context.draw(texture.cgImage(), in: CGRect(x: rect.minX * scale, y: y * scale, width: rect.width * scale, height: rect.height * scale))
                let image = try #require(context.makeImage())
                let data = try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
                try data.write(to: URL(fileURLWithPath: folder).appendingPathComponent("\(name)-\(state).png"))
                window.orderOut(nil)
                session.end()
            }
        }
    }

    private func findSpriteView(_ view: NSView) -> SKView? {
        if let sprite = view as? SKView { return sprite }
        return view.subviews.lazy.compactMap { findSpriteView($0) }.first
    }
}
#endif
