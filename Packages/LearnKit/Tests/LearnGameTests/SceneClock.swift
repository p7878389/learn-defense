import ImageIO
import LearnCore
import Metal
import SpriteKit
import Testing
#if os(macOS)
import AppKit
#endif
@testable import LearnGame

final class WeakBox<T: AnyObject> {
    weak var value: T?
    init(_ value: T?) { self.value = value }
}

/// 用 SKRenderer 真正推进 SpriteKit 动作，按 60 帧/秒走时间
@MainActor
final class SceneClock {
    let scene: SKScene
    private let renderer: SKRenderer
    private let queue: MTLCommandQueue
    private let pass = MTLRenderPassDescriptor()
    private let start = CACurrentMediaTime()
    private(set) var frame = 0
    let texture: MTLTexture

    init(size: CGSize = CGSize(width: 900, height: 360), scene: SKScene? = nil) throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        self.scene = scene ?? SKScene(size: size)
        self.scene.isPaused = false
        renderer = SKRenderer(device: device)
        renderer.scene = self.scene
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm, width: Int(self.scene.size.width), height: Int(self.scene.size.height), mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead]
        texture = try #require(device.makeTexture(descriptor: descriptor))
        queue = try #require(device.makeCommandQueue())
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        try advance(seconds: 0)
    }

    func advance(_ seconds: Double) throws {
        try advance(seconds: seconds)
    }

    func advance(seconds: Double) throws {
        let frames = max(1, Int((seconds * 60).rounded()))
        for _ in 0..<frames {
            renderer.update(atTime: start + Double(frame) / 60)
            let command = try #require(queue.makeCommandBuffer())
            renderer.render(withViewport: CGRect(origin: .zero, size: scene.size), commandBuffer: command,
                            renderPassDescriptor: pass)
            command.commit()
            command.waitUntilCompleted()
            frame += 1
        }
    }

    func setBackground(red: Double, green: Double, blue: Double) {
        scene.backgroundColor = SKColor(red: red, green: green, blue: blue, alpha: 1)
        pass.colorAttachments[0].clearColor = MTLClearColor(red: red, green: green, blue: blue, alpha: 1)
    }

    /// 跳过中间帧，复现主线程卡住后下一帧带着较大的时间间隔恢复。
    func advanceWithFrameGap(seconds: Double) throws {
        frame += max(0, Int((seconds * 60).rounded()) - 1)
        try advance(seconds: 0)
    }

    func pixels() -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: texture.width * texture.height * 4)
        bytes.withUnsafeMutableBytes {
            texture.getBytes($0.baseAddress!, bytesPerRow: texture.width * 4,
                             from: MTLRegionMake2D(0, 0, texture.width, texture.height), mipmapLevel: 0)
        }
        return bytes
    }

    func snapshot() throws -> CGImage {
        let row = texture.width * 4
        let provider = try #require(CGDataProvider(data: Data(pixels()) as CFData))
        return try #require(CGImage(width: texture.width, height: texture.height, bitsPerComponent: 8,
            bitsPerPixel: 32, bytesPerRow: row, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue).union(.byteOrder32Little),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
    }

    func writePNG(to url: URL) throws {
        let image = try snapshot()
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
    }
}
