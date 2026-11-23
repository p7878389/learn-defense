#if os(macOS)
import AppKit
import LearnCore
import SpriteKit
import SwiftUI
import Testing
@testable import LearnGame

@MainActor
@Suite("结算返回主页")
struct ResultNavigationTests {
    private struct Context {
        let database: LearnDatabase
        let profile: Profile
        let model: AppModel
        let config: GameConfig
        let preferenceKey: String
    }

    private final class Presentation: ObservableObject {
        @Published var game: GameConfig?
        var exitRequested = false
        init(_ config: GameConfig) { game = config }
    }

    private struct DeferredExitHost: View {
        @ObservedObject var presentation: Presentation
        let model: AppModel

        var body: some View {
            Color.clear.frame(width: 1194, height: 834)
                .gameCover(item: $presentation.game) { config in
                    GameView(config: config, model: model, onReplay: { presentation.game = $0 },
                             onExit: { presentation.exitRequested = true })
                }
        }
    }

    @Test(arguments: [false, true])
    func homeButtonClosesFinishedGame(won: Bool) throws {
        let c = try context()
        defer { UserDefaults.standard.removeObject(forKey: c.preferenceKey) }
        let window = host(ProfileHomeView(profileID: c.profile.id).environmentObject(c.model))
        defer { window.orderOut(nil) }
        update(window)
        // 固定窗口内“经典闯关”的中心；真实鼠标事件覆盖完整页面回调。
        try click(window, in: #require(window.contentView), at: CGPoint(x: 280, y: 470))
        update(window)
        let sheet = try #require(window.attachedSheet)
        let session = try session(in: sheet)
        finish(session, won: won)
        update(sheet)
        try clickHome(in: sheet)
        update(window)
        #expect(window.attachedSheet == nil, "回主页必须关闭整个游戏页")
        #expect(try c.database.games(profileID: c.profile.id).count == 1)
    }

    @Test(arguments: [false, true])
    func homeDismissesGameWithoutWaitingForHostToHandleExit(won: Bool) throws {
        let c = try context()
        defer { UserDefaults.standard.removeObject(forKey: c.preferenceKey) }
        let presentation = Presentation(c.config)
        let window = host(DeferredExitHost(presentation: presentation, model: c.model))
        defer { window.orderOut(nil) }
        update(window)
        let sheet = try #require(window.attachedSheet)
        let session = try session(in: sheet)
        finish(session, won: won)
        update(sheet)
        try clickHome(in: sheet)
        update(window)
        #expect(presentation.exitRequested, "主页仍须收到退出通知")
        #expect(window.attachedSheet == nil, "即使主页尚未处理退出通知，也应关闭游戏页")
        #expect(presentation.game == nil)
        #expect(session.phase == (won ? .won : .lost))
        #expect(try c.database.games(profileID: c.profile.id).count == 1)
    }

    private func context() throws -> Context {
        let database = try LearnDatabase(url: nil)
        let profile = Profile(name: "返回测试", grade: .g3, avatar: "🐯")
        try database.saveProfiles([profile])
        try database.saveSetting(true, named: "legacy-disabled")
        let pack = ContentPack(id: "return-home", title: "返回测试题库", subject: .chinese, grade: .g3,
            units: [ContentUnit(id: "u", title: "单元", lessons: [Lesson(id: "l", title: "课文",
                questions: [ChoiceItem(id: "q", prompt: "选出春", options: ["春", "夏"], answer: "春")])])])
        let model = AppModel(database: database, library: ContentLibrary(packs: [pack]),
                             speechLibrary: SpeechLibrary(database: database, settings: nil, premadeDirectories: []))
        let key = "question-bank.\(profile.id.uuidString).classic"
        UserDefaults.standard.set(try JSONSerialization.data(withJSONObject: [
            "grade": Grade.g3.rawValue, "packIDs": [pack.id]
        ]), forKey: key)
        let config = GameConfig(profileID: profile.id, grade: .g3, packIDs: [pack.id], selection: .all, difficulty: .easy)
        return Context(database: database, profile: profile, model: model, config: config, preferenceKey: key)
    }

    private func host<Content: View>(_ content: Content) -> NSWindow {
        let size = CGSize(width: 1194, height: 834)
        let window = NSWindow(contentRect: CGRect(origin: CGPoint(x: -5000, y: -5000), size: size),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.contentView = NSHostingView(rootView: content.frame(width: size.width, height: size.height))
        window.orderBack(nil)
        return window
    }

    private func session(in window: NSWindow) throws -> GameSession {
        let content = try #require(window.contentView)
        let scene = try #require(spriteView(in: content)?.scene as? GameScene)
        return try #require(scene.gameDelegate as? GameSession)
    }

    private func finish(_ session: GameSession, won: Bool) {
        #expect(session.scene.plant(.inkling, in: DefenderCell(lane: 0, column: 0)))
        session.startBattle()
        #expect(session.phase == .playing)
        if won {
            while let enemy = session.nextEnemy() { session.enemyDefeated(enemy.id, at: .zero) }
        }
        session.finishGame()
        #expect(session.phase == (won ? .won : .lost))
        #expect(session.settlementError == nil)
    }

    private func clickHome(in window: NSWindow) throws {
        // 固定测试窗口中，成功与失败结算页左下角均为“回主页”。
        let content = try #require(window.contentView)
        #expect(content.bounds.size == CGSize(width: 642, height: 724))
        try click(window, in: content, at: CGPoint(x: 125, y: 624))
    }

    private func click(_ window: NSWindow, in view: NSView, at point: CGPoint) throws {
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            let event = try #require(NSEvent.mouseEvent(with: type, location: view.convert(point, to: nil),
                modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                context: nil, eventNumber: 1, clickCount: 1, pressure: 1))
            window.sendEvent(event)
        }
    }

    private func update(_ window: NSWindow) {
        for _ in 0..<12 {
            window.contentView?.layoutSubtreeIfNeeded()
            window.displayIfNeeded()
            RunLoop.current.run(until: Date().addingTimeInterval(0.04))
        }
    }

    private func spriteView(in view: NSView) -> SKView? {
        if let sprite = view as? SKView { return sprite }
        return view.subviews.lazy.compactMap { spriteView(in: $0) }.first
    }
}
#endif
