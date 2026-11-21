#if os(macOS)
import AppKit
import LearnCore
import SwiftUI
import Testing
@testable import LearnGame

@MainActor
@Suite("大量解锁奖励结算布局")
struct ResultRewardsLayoutTests {
    private func session(rewardCount: Int, includeMistake: Bool = false) throws -> GameSession {
        var catalog = GrowthCatalog.bundled
        catalog.badges = []
        for i in catalog.pacing.questions.indices { catalog.pacing.questions[i].count.easy = 1 }
        var unlocked = 0
        for i in catalog.cosmetics.indices where !catalog.cosmetics[i].isOriginal {
            catalog.cosmetics[i].unlockLevel = unlocked < rewardCount ? 2 : 99
            catalog.cosmetics[i].name = "这是一件有很长名称的奖励 · " + catalog.cosmetics[i].name
            unlocked += 1
        }
        let growth = GrowthStore(catalog: catalog)
        let pack = ContentPack(id: "rewards-layout", title: "奖励布局题库", subject: .chinese, grade: .g3,
            units: [ContentUnit(id: "u", title: "单元", lessons: [Lesson(id: "l", title: "课文",
                questions: [ChoiceItem(id: "q", prompt: "选出春", options: ["春", "夏"], answer: "春")])])])
        let session = GameSession(config: GameConfig(profileID: UUID(), grade: .g3, packIDs: [pack.id], selection: .all, difficulty: .easy),
                                  library: ContentLibrary(packs: [pack]), progress: ProgressStore(), speech: Speech(), growth: growth)
        _ = session.scene.plant(.inkling, in: DefenderCell(lane: 0, column: 0))
        session.startBattle()
        let enemy = try #require(session.nextEnemy())
        session.scene.spawn(enemy, lane: 0)
        session.selectQuestion(enemy.id)
        let question = try #require(session.current)
        if includeMistake { session.answer((question.answerIndex + 1) % question.options.count) }
        session.answer(question.answerIndex)
        session.enemyDefeated(enemy.id, at: .zero)
        session.finishGame()
        #expect(session.phase == .won)
        return session
    }

    @Test func manyUnlocksKeepReplayButtonsInsideLandscapeScreen() throws {
        let session = try session(rewardCount: 100)
        let result = try #require(session.growthResult)
        #expect(result.gifts.count + result.unlocked.count >= 12, "必须实际触发大量解锁，不能用空数据通过布局检查")
        for size in [CGSize(width: 1180, height: 736), CGSize(width: 1133, height: 690)] {
            let view = ResultView(session: session, onReplay: {}, onExit: {})
                .frame(width: size.width, height: size.height)
            let image = try #require(ImageRenderer(content: view).cgImage)
            #expect(hasReplayButtonNearBottom(image), "\(size)：大量奖励不能把重玩和回主页按钮挤出屏幕")
            if let folder = ProcessInfo.processInfo.environment["RESULT_REWARDS_PREVIEW"] {
                try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
                let data = try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
                try data.write(to: URL(fileURLWithPath: folder).appendingPathComponent("many-rewards-\(Int(size.width))x\(Int(size.height)).png"))
            }
        }
    }

    @Test func fewUnlocksKeepDialogCompact() throws {
        let session = try session(rewardCount: 2)
        let view = ResultView(session: session, onReplay: {}, onExit: {}).frame(width: 1180, height: 736)
        let image = try #require(ImageRenderer(content: view).cgImage)
        #expect(!hasReplayButtonNearBottom(image), "奖励少时保持自然高度，不必撑满屏幕")
    }

    @Test func manyUnlocksRemainVisibleInTheirOwnScrollableRegion() throws {
        let session = try session(rewardCount: 100, includeMistake: true)
        #expect(!session.mistakes.isEmpty, "奖励与记一记同时出现时也要保留全部内容")
        for size in [CGSize(width: 1180, height: 736), CGSize(width: 1133, height: 690)] {
            let host = NSHostingView(rootView: ResultView(session: session, onReplay: {}, onExit: {})
                .frame(width: size.width, height: size.height))
            let window = NSWindow(contentRect: CGRect(origin: CGPoint(x: -5000, y: -5000), size: size),
                                  styleMask: .borderless, backing: .buffered, defer: false)
            window.contentView = host
            host.frame = CGRect(origin: .zero, size: size)
            for _ in 0..<5 {
                host.layoutSubtreeIfNeeded()
                window.displayIfNeeded()
                RunLoop.current.run(until: Date().addingTimeInterval(0.04))
            }
            let scroll = try #require(scrollViews(host).first {
                ($0.documentView?.frame.height ?? 0) > $0.contentView.bounds.height + 1
            }, "大量奖励应保留在可滚动内容中，而不是隐藏或挤出屏幕")
            let frame = scroll.convert(scroll.bounds, to: host)
            #expect(frame.minX > size.width * 0.45 && frame.maxX <= size.width + 1)
            #expect(frame.minY >= -1 && frame.maxY <= size.height + 1 && frame.height >= 120)
            if let folder = ProcessInfo.processInfo.environment["RESULT_REWARDS_PREVIEW"] {
                try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
                let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                host.cacheDisplay(in: host.bounds, to: bitmap)
                let data = try #require(bitmap.representation(using: .png, properties: [:]))
                try data.write(to: URL(fileURLWithPath: folder).appendingPathComponent("scrolling-rewards-\(Int(size.width))x\(Int(size.height)).png"))
            }
            window.orderOut(nil)
        }
    }

    private func scrollViews(_ view: NSView) -> [NSScrollView] {
        var result = view.subviews.flatMap { scrollViews($0) }
        if let scroll = view as? NSScrollView { result.append(scroll) }
        return result
    }

    private func hasReplayButtonNearBottom(_ image: CGImage) -> Bool {
        var green = 0
        for offsetX in [200, 260, 320, 380] {
            for offsetY in [48, 64, 80] {
                var rgba = [UInt8](repeating: 0, count: 4)
                let context = CGContext(data: &rgba, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                let x = image.width / 2 + offsetX
                let y = image.height - offsetY
                context.draw(image, in: CGRect(x: -x, y: -(image.height - 1 - y), width: image.width, height: image.height))
                if rgba[0] < 140 && Double(rgba[1]) > Double(rgba[0]) * 1.4 && Double(rgba[1]) > Double(rgba[2]) * 1.1 { green += 1 }
            }
        }
        return green >= 4
    }
}
#endif
