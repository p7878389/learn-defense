#if os(macOS)
import AppKit
import LearnCore
import SwiftUI
import Testing
@testable import LearnGame

@MainActor
@Suite("题库弹窗单元完整展示")
struct QuestionBankLayoutTests {
    @Test func allBuiltInUnitsFitCompactLandscapeAndPortraitSheets() throws {
        let library = ContentLibrary.load(userDirectory: nil)
        let pack = try #require(library.packs.first { $0.grade == .g3 && $0.subject == .chinese })
        #expect(pack.units.count >= 8)
        let config = GameConfig(profileID: UUID(), grade: .g3, packIDs: [pack.id], selection: .all, difficulty: .normal)
        for size in [CGSize(width: 900, height: 600), CGSize(width: 680, height: 540), CGSize(width: 680, height: 940)] {
            let view = QuestionBankPickerView(config: config, library: library, onConfirm: { _ in }, onCancel: {})
                .frame(width: size.width, height: size.height)
            let host = NSHostingView(rootView: view)
            let window = NSWindow(contentRect: CGRect(origin: CGPoint(x: -5000, y: -5000), size: size),
                                  styleMask: .borderless, backing: .buffered, defer: false)
            window.contentView = host
            host.frame = CGRect(origin: .zero, size: size)
            for _ in 0..<5 {
                host.layoutSubtreeIfNeeded()
                window.displayIfNeeded()
                RunLoop.current.run(until: Date().addingTimeInterval(0.04))
            }
            let lists = scrollViews(host)
            #expect(!lists.isEmpty, "单元列表需要支持更多单元的独立滚动")
            for list in lists {
                let frame = list.convert(list.bounds, to: host)
                #expect(frame.minX >= -1 && frame.maxX <= size.width + 1, "\(size)：列表不能伸出弹窗左右边界")
                #expect(frame.minY >= -1 && frame.maxY <= size.height + 1, "\(size)：列表不能被底部操作区裁掉")
                let content = list.documentView?.frame.height ?? 0
                #expect(content <= list.contentView.bounds.height + 1,
                        "\(size)：内置八个单元应完整展示，内容高 \(content)，可用高 \(list.contentView.bounds.height)")
            }
            if let folder = ProcessInfo.processInfo.environment["QUESTION_BANK_PREVIEW"] {
                try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
                let image = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                host.cacheDisplay(in: host.bounds, to: image)
                let data = try #require(image.representation(using: .png, properties: [:]))
                try data.write(to: URL(fileURLWithPath: folder).appendingPathComponent("units-\(Int(size.width))x\(Int(size.height)).png"))
            }
            window.orderOut(nil)
        }
    }

    @Test func longUnitTitleExpandsInsteadOfBeingTruncatedToTwoLines() throws {
        func height(_ title: String) throws -> Int {
            let view = QuestionUnitTile(title: title, lessonCount: 4, selected: true, action: {}).frame(width: 220).padding(8)
            return try #require(ImageRenderer(content: view).cgImage).height
        }
        let short = try height("第一单元 · 校园生活")
        let long = try height("第八单元 · 在生活中学习语言并探索美好品质、观察自然与社会、阅读文学作品并分享自己的收获与发现")
        #expect(long > short, "完整长标题需要更多行，不能固定两行截断或被固定卡片高度裁切")
    }

    private func scrollViews(_ view: NSView) -> [NSScrollView] {
        var result = view.subviews.flatMap { scrollViews($0) }
        if let scroll = view as? NSScrollView { result.append(scroll) }
        return result
    }
}
#endif
