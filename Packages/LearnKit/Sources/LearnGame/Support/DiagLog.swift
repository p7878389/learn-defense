import Foundation

/// 排查战斗画面闪退用的打点日志（仅 Debug 构建）。
/// 每条立即写进 Library/Caches/diag.log，闪退后可用 devicectl 从设备拷出最后发生了什么；
/// 同时 print 到控制台。启动时超过 1MB 就把旧日志挪到 diag.prev.log。
enum DiagLog {
    #if DEBUG
    private static let start = Date()
    /// 只在主线程写（场景 deinit 也在主线程）；static let 的初始化本身是线程安全的
    nonisolated(unsafe) private static let handle: FileHandle? = {
        let fm = FileManager.default
        guard let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let url = caches.appendingPathComponent("diag.log")
        if let size = (try? fm.attributesOfItem(atPath: url.path)[.size] as? Int) ?? nil, size > 1_000_000 {
            let previous = caches.appendingPathComponent("diag.prev.log")
            try? fm.removeItem(at: previous)
            try? fm.moveItem(at: url, to: previous)
        }
        if !fm.fileExists(atPath: url.path) {
            fm.createFile(atPath: url.path, contents: nil)
        }
        let handle = try? FileHandle(forWritingTo: url)
        _ = try? handle?.seekToEnd()
        let stamp = ISO8601DateFormatter().string(from: Date())
        try? handle?.write(contentsOf: Data("==== 启动 \(stamp) ====\n".utf8))
        return handle
    }()
    #endif

    static func log(_ message: @autoclosure () -> String) {
        #if DEBUG
        let line = String(format: "%9.3f ", Date().timeIntervalSince(start)) + message()
        print("[diag]", line)
        try? handle?.write(contentsOf: Data((line + "\n").utf8))
        #endif
    }

    /// 节点地址，方便把同一个节点的创建、挪动、移除串起来
    static func id(_ object: AnyObject) -> String {
        "\(Unmanaged.passUnretained(object).toOpaque())"
    }
}
