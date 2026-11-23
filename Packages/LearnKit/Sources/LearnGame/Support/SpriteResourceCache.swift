import SpriteKit
#if canImport(UIKit)
import UIKit
#endif

/// 成本按未压缩源画布 RGBA 估算，不等同 SpriteKit 的实际 CPU/GPU 驻留量。
@MainActor
final class SpriteResourceCache {
    var frames = ResourceCache<[SKTexture]>(costLimit: 64 * 1024 * 1024)
    var portraits = ResourceCache<CGImage>(costLimit: 8 * 1024 * 1024)
    private var memoryWarning: NSObjectProtocol?

    init() {
        #if canImport(UIKit)
        memoryWarning = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main
        ) { [weak self] _ in
            // 通知显式交给主队列；同步释放引用，避免排队等待下一轮 Task。
            MainActor.assumeIsolated { self?.removeAll() }
        }
        #endif
    }

    deinit {
        if let memoryWarning { NotificationCenter.default.removeObserver(memoryWarning) }
    }

    func removeAll() {
        frames.removeAll()
        portraits.removeAll()
    }

    static func estimatedCost(of textures: [SKTexture]) -> Int {
        textures.reduce(0) { total, texture in
            let rect = texture.textureRect(), size = texture.size()
            guard rect.width > 0, rect.height > 0 else { return total }
            // 裁切纹理仍持有整张源图，不能只按显示区域的面积计算。
            let width = Int((size.width / rect.width).rounded(.up))
            let height = Int((size.height / rect.height).rounded(.up))
            return total + width * height * 4
        }
    }
}
