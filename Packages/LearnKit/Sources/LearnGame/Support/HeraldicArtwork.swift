import LearnCore
import SpriteKit
import ImageIO

/// 品质边框是静态 UI 素材；收藏馆与战斗题牌共用图片和纹理缓存。
@MainActor
enum HeraldicArtwork {
    private static var images: [String: CGImage] = [:]
    private static var textures: [String: SKTexture] = [:]

    static func assetName(for rarity: CosmeticRarity, lightInterior: Bool = false) -> String {
        "frame-\(rarity.rawValue)\(lightInterior ? "-light" : "")"
    }

    static func image(for rarity: CosmeticRarity, lightInterior: Bool = false) -> CGImage? {
        let name = assetName(for: rarity, lightInterior: lightInterior)
        if let image = images[name] { return image }
        guard let url = Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "Pictures/CollectionFrames"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        images[name] = image
        return image
    }

    static func texture(for rarity: CosmeticRarity) -> SKTexture? {
        let name = assetName(for: rarity)
        if let texture = textures[name] { return texture }
        guard let image = image(for: rarity) else { return nil }
        let texture = SKTexture(cgImage: image)
        texture.filteringMode = .linear
        textures[name] = texture
        return texture
    }

    /// 选择卡和拖动浮层共用实际装备名称；原版和不匹配的配置回退植物名称。
    static func defenderName(kind: DefenderKind, skin: CharacterSkin?) -> String {
        guard let skin else { return kind.name }
        return GrowthCatalog.bundled.shooterSkins(for: kind.id)
            .first { $0.characterSkin == skin }?.name ?? kind.name
    }

    static func defenderRarity(kind: DefenderKind, skin: CharacterSkin?) -> CosmeticRarity {
        GrowthCatalog.bundled.shooterSkins(for: kind.id).first { $0.characterSkin == skin }?.rarity ?? .common
    }

    static func monsterRarity(appearance: String) -> CosmeticRarity? {
        GrowthCatalog.bundled.cosmetics(in: .enemySkin).first { $0.enemyAppearance == appearance }?.rarity
    }
}
