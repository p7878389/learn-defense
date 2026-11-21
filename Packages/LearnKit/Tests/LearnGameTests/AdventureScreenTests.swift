#if os(macOS)
import AppKit
import LearnCore
import SpriteKit
import SwiftUI
import Testing
@testable import LearnGame

@MainActor
@Suite("冒险横竖屏界面")
struct AdventureScreenTests {
    @Test func homeAndMapFitViewportWithoutVerticalOverflow() throws {
        let database = try LearnDatabase(url: nil)
        let profile = Profile(name: "小小守卫", grade: .g3, avatar: "🐯")
        try database.saveProfiles([profile])
        var growth = GrowthState()
        growth.coins = 80
        try database.saveGrowthState(growth, profileID: profile.id)
        let model = AppModel(database: database, library: .load(userDirectory: nil),
                             speechLibrary: SpeechLibrary(database: database, settings: nil, premadeDirectories: []))
        for size in [CGSize(width: 1180, height: 736), CGSize(width: 1133, height: 690), CGSize(width: 820, height: 1100)] {
            try assertNoVerticalOverflow(ProfileHomeView(profileID: profile.id).environmentObject(model), size: size, name: "主页")
            try assertNoVerticalOverflow(AdventureLobbyView(profileID: profile.id, onClose: {}).environmentObject(model), size: size, name: "冒险地图")
            var battle = AdventureBattle(level: AdventureCatalog.levels[0])
            _ = battle.plant("inkling", lane: 0, column: 0)
            _ = battle.start()
            try model.growth(for: profile.id).startAdventure(battle)
            try assertNoVerticalOverflow(AdventureLobbyView(profileID: profile.id, onClose: {}).environmentObject(model), size: size, name: "有存档的冒险地图")
            try model.growth(for: profile.id).abandonAdventure()
        }
    }

    private func assertNoVerticalOverflow<V: View>(_ screen: V, size: CGSize, name: String) throws {
        let host = NSHostingView(rootView: screen.frame(width: size.width, height: size.height))
        let window = NSWindow(contentRect: CGRect(origin: CGPoint(x: -5000, y: -5000), size: size),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = host
        host.frame = CGRect(origin: .zero, size: size)
        defer { window.orderOut(nil) }
        for _ in 0..<4 {
            host.layoutSubtreeIfNeeded()
            RunLoop.current.run(until: Date().addingTimeInterval(0.04))
        }
        for scroll in verticalScrollViews(host) {
            let contentHeight = scroll.documentView?.frame.height ?? 0
            #expect(contentHeight <= scroll.contentView.bounds.height + 1,
                    "\(name) \(size)：内容高 \(contentHeight)，视口高 \(scroll.contentView.bounds.height)，不应靠禁用滚动裁切内容")
        }
        #expect(host.fittingSize.height <= size.height + 1, "\(name)不能超出屏幕可用高度")
    }

    private func verticalScrollViews(_ view: NSView) -> [NSScrollView] {
        var found = view.subviews.flatMap { verticalScrollViews($0) }
        if let scroll = view as? NSScrollView { found.append(scroll) }
        return found
    }

    /// 可选视觉验收：ADVENTURE_PREVIEW=/绝对路径 swift test --filter AdventureScreenTests
    @Test func rendersRealMapAndBattleAtBothOrientations() throws {
        guard let folder = ProcessInfo.processInfo.environment["ADVENTURE_PREVIEW"] else { return }
        try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        let database = try LearnDatabase(url: nil)
        let profile = Profile(name: "小小守卫", grade: .g3, avatar: "🐯")
        try database.saveProfiles([profile])
        var growth = GrowthState()
        growth.coins = 80
        try database.saveGrowthState(growth, profileID: profile.id)
        let library = ContentLibrary.load(userDirectory: nil)
        let model = AppModel(database: database, library: library, speechLibrary: SpeechLibrary(database: database))
        let pack = try #require(library.packs.first { $0.grade == .g3 })
        let config = GameConfig(profileID: profile.id, grade: .g3, packIDs: [pack.id], selection: .all, difficulty: .easy)
        try capture(QuestionBankPickerView(config: config, library: library, onConfirm: { _ in }, onCancel: {}),
                    size: CGSize(width: 900, height: 700), path: folder + "/question-bank.png")
        var partial = config
        let firstUnit = try #require(pack.units.first)
        partial.selection = .units([QuestionBankChoice.unitKey(pack: pack, unit: firstUnit)])
        try capture(QuestionBankPickerView(config: partial, library: library, onConfirm: { _ in }, onCancel: {}),
                    size: CGSize(width: 900, height: 700), path: folder + "/question-bank-partial.png")
        let domain = "start-review-preview-\(UUID())"
        let preferences = try #require(UserDefaults(suiteName: domain))
        defer { preferences.removePersistentDomain(forName: domain) }
        let preparation = GamePreparation(config: partial, model: model, preferences: preferences)
        #expect(preparation.confirm(partial))
        let ready = try #require(preparation.session)
        _ = ready.scene.plant(.inkling, in: DefenderCell(lane: 0, column: 0))
        #expect(preparation.requestStartConfirmation())
        try capture(GameStartConfirmationView(session: ready, library: library, onConfirm: {}, onCancel: {}),
                    size: CGSize(width: 760, height: 640), path: folder + "/start-confirmation.png")
        ready.end()
        for (orientation, size) in [("landscape", CGSize(width: 1180, height: 736)), ("portrait", CGSize(width: 820, height: 1100))] {
            try capture(ProfileHomeView(profileID: profile.id).environmentObject(model), size: size, path: folder + "/\(orientation)-home.png")
            try capture(AdventureLobbyView(profileID: profile.id, onClose: {}).environmentObject(model),
                        size: size, path: folder + "/\(orientation)-map.png")
            for playing in [false, true] {
                let session = AdventureSession(levelID: 1, model: model, profileID: profile.id, difficulty: .normal)
                for lane in 0..<5 { session.plant("inkling", lane: lane, column: 0) }
                if playing { session.start(); session.advance(by: 14) }
                for enemy in session.scene.children.compactMap({ $0 as? EnemyNode }) {
                    if enemy.doomed { enemy.removeFromParent(); continue }
                    enemy.removeAllActions()
                    enemy.alpha = 1
                }
                session.scene.setPaused(true)
                try capture(AdventureScreen(session: session, onClose: {}), size: size,
                            path: folder + "/\(orientation)-\(playing ? "battle" : "preparing").png", scene: session.scene)
                if playing {
                    session.suspend()
                    try capture(AdventureLobbyView(profileID: profile.id, onClose: {}).environmentObject(model), size: size,
                                path: folder + "/\(orientation)-saved-map.png")
                    #expect(session.abandon())
                }
            }
        }
    }

    @Test func selectedAndUnselectedLongUnitCardsKeepTheSameLayout() throws {
        func render(_ selected: Bool) throws -> CGImage {
            let view = QuestionUnitTile(title: "第八单元 · 在生活中学习语言并探索美好品质", lessonCount: 4,
                                        selected: selected, action: {}).frame(width: 260).padding(8)
            return try #require(ImageRenderer(content: view).cgImage)
        }
        let selected = try render(true)
        let unselected = try render(false)
        #expect(selected.width == unselected.width && selected.height == unselected.height)
        let selectedPixels = try #require(selected.dataProvider?.data) as Data
        let unselectedPixels = try #require(unselected.dataProvider?.data) as Data
        #expect(selectedPixels != unselectedPixels, "选中必须有可见差异，同时保持尺寸与文字位置稳定")
    }

    private func capture<V: View>(_ screen: V, size: CGSize, path: String, scene: AdventureScene? = nil) throws {
        let host = NSHostingView(rootView: screen.frame(width: size.width, height: size.height))
        let window = NSWindow(contentRect: CGRect(origin: CGPoint(x: -5000, y: -5000), size: size),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = host
        host.frame = CGRect(origin: .zero, size: size)
        for _ in 0..<5 {
            host.layoutSubtreeIfNeeded()
            window.displayIfNeeded()
            RunLoop.current.run(until: Date().addingTimeInterval(0.06))
        }
        let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        let snapshot = try #require(bitmap.cgImage)
        let context = try #require(CGContext(data: nil, width: snapshot.width, height: snapshot.height,
                                             bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(snapshot, in: CGRect(x: 0, y: 0, width: snapshot.width, height: snapshot.height))
        if let scene {
            let skView = try #require(spriteView(host))
            let frame = skView.convert(skView.bounds, to: host)
            #expect(frame.width > 500 && frame.height > 240, "卡牌和操作栏不能挤掉可操作的战场")
            #expect(frame.minX >= -1 && frame.maxX <= size.width + 1)
            #expect(frame.minY >= -1 && frame.maxY <= size.height + 1)
            let texture = try #require(skView.texture(from: scene, crop: CGRect(origin: .zero, size: scene.size)))
            let scale = CGFloat(snapshot.width) / size.width
            let y = host.isFlipped ? size.height - frame.maxY : frame.minY
            context.draw(texture.cgImage(), in: CGRect(x: frame.minX * scale, y: y * scale,
                                                       width: frame.width * scale, height: frame.height * scale))
        }
        let image = try #require(context.makeImage())
        let data = try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
        try data.write(to: URL(fileURLWithPath: path))
        window.orderOut(nil)
    }

    private func spriteView(_ view: NSView) -> SKView? {
        if let sprite = view as? SKView { return sprite }
        return view.subviews.lazy.compactMap { spriteView($0) }.first
    }
}
#endif
