import CoreGraphics
import SwiftUI
import Testing
@testable import LearnGame

/// 结算弹窗里的「记一记」：错题多时不能把弹窗撑高、把按钮挤出屏幕
@MainActor
@Suite("结算弹窗布局")
struct ResultLayoutTests {
    private func mistakes(_ count: Int) -> [GameSession.Mistake] {
        (0..<count).map { i in
            GameSession.Mistake(prompt: "题目\(i)", answer: "答案\(i)",
                                explanation: i % 2 == 0 ? "春眠不觉晓，处处闻啼鸟。出自唐代孟浩然《春晓》" : nil,
                                missed: i % 3 == 0)
        }
    }

    /// 上面一块红色（横幅、等级卡），中间记一记，下面一块蓝色（按钮），一起放进 600 高的框
    private func render(_ count: Int) throws -> (CGImage, height: Int) {
        let height = 600
        let harness = VStack(spacing: 0) {
            Color.red.frame(height: 150)
            MistakeNotebook(mistakes: mistakes(count))
            Color.blue.frame(height: 80)
        }
        .frame(width: 500, height: CGFloat(height))
        let renderer = ImageRenderer(content: harness)
        renderer.scale = 1
        return (try #require(renderer.cgImage), height)
    }

    private func pixel(_ image: CGImage, x: Int, y: Int) -> (r: UInt8, g: UInt8, b: UInt8) {
        var data = [UInt8](repeating: 0, count: 4)
        let context = CGContext(data: &data, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        // 把要读的像素挪到 1x1 画布的原点；CGImage 原点在左上，CGContext 在左下
        context.draw(image, in: CGRect(x: -x, y: -(image.height - 1 - y), width: image.width, height: image.height))
        return (data[0], data[1], data[2])
    }

    private func isBlue(_ p: (r: UInt8, g: UInt8, b: UInt8)) -> Bool { p.b > 200 && p.r < 60 && p.g < 140 }
    private func isRed(_ p: (r: UInt8, g: UInt8, b: UInt8)) -> Bool { p.r > 200 && p.g < 80 && p.b < 80 }

    @Test func manyMistakesScrollInsideInsteadOfGrowing() throws {
        let (image, height) = try render(20)
        #expect(isRed(pixel(image, x: 250, y: 4)), "上面的内容没被挤出框")
        #expect(isBlue(pixel(image, x: 250, y: height - 4)), "按钮还在框里，记一记在自己的框里滚动")
    }

    @Test func fewMistakesKeepNaturalHeight() throws {
        let (image, height) = try render(2)
        #expect(!isBlue(pixel(image, x: 250, y: height - 4)), "错题少时记一记不撑满，弹窗保持原来的高度")
    }
}
