#if os(macOS)
import AppKit
import LearnCore
import SpriteKit
import Testing
@testable import LearnGame

@Suite("角色渲染")
@MainActor
struct SpriteRenderTests {
    /// 使用真正的 SpriteKit 渲染，检查透明素材、题牌和缩放组合；可导出预览用于目检。
    @Test func renderLineup() throws {
        let scene = SKScene(size: CGSize(width: 1200, height: 620))
        scene.backgroundColor = SKColor(red: 0.93, green: 0.96, blue: 0.87, alpha: 1)
        for (index, kind) in UnitCatalog.defenders.enumerated() {
            let x = CGFloat(index) * 220 + 150
            let node = DefenderNode(kind: kind, radius: 34)
            node.position = CGPoint(x: x, y: 465)
            scene.addChild(node)
            scene.addChild(label(kind.name, at: CGPoint(x: x, y: 395)))
            if let bullet = UnitSprites.projectile(kind.projectile) {
                bullet.position = CGPoint(x: x, y: 350)
                scene.addChild(bullet)
            }
        }
        for (index, kind) in UnitCatalog.enemies.enumerated() {
            let x = CGFloat(index) * 185 + 135
            let node = EnemyNode(id: index, kind: kind, sign: ["春", "花", "学", "书", "天", "好"][index], lane: 0, scale: 1)
            node.position = CGPoint(x: x, y: 190)
            if index == 0 { node.setTargeted(true) }
            if index == 4 { node.slow(factor: 0.5, seconds: 3) }
            scene.addChild(node)
            scene.addChild(label(kind.name, at: CGPoint(x: x, y: 100)))
        }
        scene.addChild(label("植物守卫 · 答对发射", at: CGPoint(x: 600, y: 565), size: 28))
        scene.addChild(label("僵尸题牌 · 保留答题与移动规则", at: CGPoint(x: 600, y: 295), size: 25))
        let view = SKView(frame: CGRect(origin: .zero, size: scene.size))
        let texture = try #require(view.texture(from: scene, crop: CGRect(origin: .zero, size: scene.size)))
        #expect(texture.size() == scene.size)
        if let path = ProcessInfo.processInfo.environment["LEARN_DEFENSE_PREVIEW"] {
            let bitmap = NSBitmapImageRep(cgImage: texture.cgImage())
            let data = try #require(bitmap.representation(using: .png, properties: [:]))
            try data.write(to: URL(fileURLWithPath: path))
        }
    }

    private func label(_ text: String, at point: CGPoint, size: CGFloat = 20) -> SKLabelNode {
        let label = SKLabelNode(fontNamed: "PingFangSC-Semibold")
        label.text = text
        label.fontSize = size
        label.fontColor = SKColor(red: 0.17, green: 0.25, blue: 0.17, alpha: 1)
        label.position = point
        return label
    }
}
#endif
