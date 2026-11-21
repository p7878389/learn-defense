import ImageIO
import LearnCore
import SpriteKit

/// 机甲与茶壶的资源适配；部件、枪口和动作均在 SKS 中维护。
@MainActor
final class ThemeSkin {
    let root: SKNode
    let muzzle: SKNode
    let prefix: String

    init?(kind: DefenderKind, skin: CharacterSkin?, radius: CGFloat) {
        guard kind.id == DefenderKind.inkling.id,
              skin == .mecha || skin == .teapot,
              let prefix = Self.resourcePrefix(skin),
              let root = FXLibrary.effect(named: prefix + "Body"),
              let muzzle = root.childNode(withName: "//muzzle"),
              let reference = root.userData?["referenceRadius"] as? NSNumber,
              reference.doubleValue > 0 else { return nil }
        self.root = root
        self.muzzle = muzzle
        self.prefix = prefix
        root.name = "themeSkin"
        root.setScale(radius / CGFloat(reference.doubleValue))
        for suffix in ["Projectile", "Muzzle", "Impact", "Defeat"] {
            _ = FXLibrary.effect(named: prefix + suffix)
        }
    }

    func shoot() { FXLibrary.runEvent("shoot", on: root) }
    func hurt() { FXLibrary.runEvent("hurt", on: root) }

    static func resourcePrefix(_ skin: CharacterSkin?) -> String? {
        switch skin {
        case .spellbook: "Spellbook"
        case .mecha: "Mecha"
        case .teapot: "Teapot"
        default: nil
        }
    }

    private static var portraits: [String: CGImage] = [:]

    static func portrait(for skin: CharacterSkin?) -> CGImage? {
        guard skin == .mecha || skin == .teapot, let prefix = resourcePrefix(skin) else { return nil }
        if let cached = portraits[prefix] { return cached }
        guard let url = Bundle.module.url(forResource: prefix + "Portrait", withExtension: "png", subdirectory: "Effects"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        portraits[prefix] = image
        return image
    }
}
