import ImageIO
import LearnCore
import SpriteKit

/// 星轨魔导书的表现适配器；布局、发射点和全部动作参数由资源提供。
@MainActor
final class SpellbookSkin {
    let root: SKNode
    let muzzle: SKNode

    init?(kind: DefenderKind, skin: CharacterSkin?, radius: CGFloat) {
        guard kind.id == DefenderKind.inkling.id, skin == .spellbook,
              let root = FXLibrary.effect(named: "SpellbookBody"),
              let muzzle = root.childNode(withName: "//muzzle"),
              let reference = root.userData?["referenceRadius"] as? NSNumber,
              reference.doubleValue > 0 else { return nil }
        self.root = root
        self.muzzle = muzzle
        root.name = "spellbookSkin"
        root.setScale(radius / CGFloat(reference.doubleValue))
        // 栽种/试看时预热首次发射所需资源；之后复用 FXLibrary 缓存。
        for name in ["SpellbookProjectile", "SpellbookMuzzle", "SpellbookImpact"] {
            _ = FXLibrary.effect(named: name)
        }
    }

    func shoot() { FXLibrary.runEvent("shoot", on: root) }
    func hurt() { FXLibrary.runEvent("hurt", on: root) }

    static let portrait: CGImage? = {
        guard let url = Bundle.module.url(forResource: "SpellbookPortrait", withExtension: "png", subdirectory: "Effects"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }()
}
