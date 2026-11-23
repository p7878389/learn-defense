import LearnCore
import Metal
import SpriteKit
import Testing
#if os(macOS)
import AppKit
#endif
@testable import LearnGame

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
}
