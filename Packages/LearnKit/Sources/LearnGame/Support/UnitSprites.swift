import LearnCore
import ImageIO
import SpriteKit

/// 内置植物与僵尸的透明序列帧。动画共享纹理，节点独立；缺图时交回原有矢量绘制。
@MainActor
enum UnitSprites {
    struct Clip: Decodable {
        let frameCount: Int
        let frameTime: Double
        /// 裁切框（左、上、宽、高，画布像素，左上角为原点）
        let crop: [Double]
        let colorKey: [CGFloat]?
        /// 原始画布宽高
        let canvas: [Double]?
        /// 同一角色切换动画时用来对齐的横向基准（画布像素），和画布底边一起对齐
        let pivot: Double?
        /// 子弹出口（画布像素）
        let muzzle: [Double]?
        /// 这个角色的其他动画：attack 啃咬 / 发射、die 倒下、head 掉头、boom 烧焦、bare 掉了防具…
        let states: [String: String]?
        /// 每一帧的图片（相对 Sprites 目录、不带扩展名的透明 WebP）。
        /// 有它就不读「动画名/序号.png」，森林怪物借此加载独立的动作素材
        let files: [String]?
        /// 加载时水平翻转：经典模式的怪物朝左走，朝右画的素材要翻过来。crop 按翻转后的坐标写
        let mirrored: Bool?

        var duration: TimeInterval { Double(frameCount) * frameTime }
    }

    private static let clips: [String: Clip] = {
        guard let url = Bundle.module.url(forResource: "clips", withExtension: "json", subdirectory: "Sprites"),
              let data = try? Data(contentsOf: url),
              let clips = try? JSONDecoder().decode([String: Clip].self, from: data) else { return [:] }
        // 森林怪物清单由素材脚本生成；重名时以 clips.json 为准
        return ["forest-classic"].reduce(clips) { merged, manifest in
            guard let url = Bundle.module.url(forResource: manifest, withExtension: "json", subdirectory: "Sprites"),
                  let data = try? Data(contentsOf: url),
                  let extra = try? JSONDecoder().decode([String: Clip].self, from: data) else { return merged }
            return merged.merging(extra) { original, _ in original }
        }
    }()
    private static let cache = SpriteResourceCache()
    static var cachedAnimationFrameCount: Int { cache.frames.values.reduce(0) { $0 + $1.count } }
    static var cachedResourceBytes: Int { cache.frames.totalCost + cache.portraits.totalCost }

    static func releaseCachedResources() { cache.removeAll() }

    static func frames(named name: String) -> [SKTexture] {
        if let cached = cache.frames.value(for: name) { return cached }
        guard let clip = clips[name], clip.frameCount > 0, clip.crop.count == 4 else { return [] }
        var textures: [SKTexture] = []
        for index in 0..<clip.frameCount {
            // 每帧完成后及时释放 ImageIO / 平台图片的临时对象，避免批量加载堆积到下一次主循环。
            guard let texture = autoreleasepool(invoking: { frame(named: name, index: index, clip: clip) }) else {
                cache.frames.insert([], for: name, cost: 0)
                return []
            }
            textures.append(texture)
        }
        cache.frames.insert(textures, for: name, cost: SpriteResourceCache.estimatedCost(of: textures))
        return textures
    }

    /// 头像与完整动画共用像素解码、透明色键和裁切，静态预览只读取第零帧。
    private static func frame(named name: String, index: Int, clip: Clip) -> SKTexture? {
        let bitmap: CGImage
        if let files = clip.files {
            guard files.indices.contains(index),
                  let image = Self.webp(files[index], mirrored: clip.mirrored == true) else {
                return nil
            }
            bitmap = image
        } else {
            guard let url = Bundle.module.url(forResource: String(index), withExtension: "png", subdirectory: "Sprites/\(name)"),
                  let image = PlatformImage(contentsOfFile: url.path) else {
                return nil
            }
            // PNG 的 DPI 元数据会改变 NSImage 的点尺寸，裁切必须统一使用像素尺寸。
            #if canImport(UIKit)
            guard let decoded = image.cgImage else { return nil }
            #else
            guard let decoded = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
            #endif
            bitmap = decoded
        }
        let source: CGImage
        if let key = clip.colorKey, key.count == 3 {
            // Core Graphics 的色键遮罩不接受带 alpha 的源图；先以 RGB 解码白底帧。
            guard let context = CGContext(data: nil, width: bitmap.width, height: bitmap.height,
                                          bitsPerComponent: 8, bytesPerRow: bitmap.width * 4,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
            context.draw(bitmap, in: CGRect(x: 0, y: 0, width: bitmap.width, height: bitmap.height))
            guard let rgb = context.makeImage(),
                  let masked = rgb.copy(maskingColorComponents: key.flatMap { [$0, $0] }) else { return nil }
            source = masked
        } else {
            source = bitmap
        }
        let full = SKTexture(cgImage: source)
        let size = full.size()
        let c = clip.crop
        guard size.width > 0, size.height > 0,
              c[0] >= 0, c[1] >= 0, c[2] > 0, c[3] > 0,
              c[0] + c[2] <= size.width, c[1] + c[3] <= size.height else { return nil }
        // 清单采用左上角像素坐标；SpriteKit 纹理坐标从左下角开始。
        let rect = CGRect(x: c[0] / size.width, y: 1 - (c[1] + c[3]) / size.height,
                          width: c[2] / size.width, height: c[3] / size.height)
        let texture = SKTexture(rect: rect, in: full)
        texture.filteringMode = .linear
        return texture
    }

    /// 准备阶段预热本回合的角色状态、子弹和命中图，战斗中直接复用同一份纹理。
    @discardableResult
    static func preloadCombat(defenders: [DefenderKind], enemies: [EnemyKind], loadout: Loadout) -> [String: [SKTexture]] {
        var names: Set<String> = []
        func addCharacter(_ name: String) {
            names.insert(name)
            names.formUnion(clips[name]?.states?.values.map { $0 } ?? [])
        }
        for kind in defenders {
            addCharacter(characterName("plant-\(kind.id)", skin: loadout.defenderSkins[kind.id]))
            let projectile = loadout.projectile(for: kind)
            if let name = projectileName(projectile) {
                names.insert(name)
                if let hit = clips[name]?.states?["hit"] { names.insert(hit) }
            }
            if projectile.shape == .petal { names.insert("fume") }
        }
        for kind in enemies {
            if loadout.enemyAppearances.isEmpty {
                addCharacter(enemyName(kind, skin: loadout.enemySkin, appearance: loadout.enemyAppearance))
            } else {
                for appearance in loadout.enemyAppearances {
                    addCharacter(enemyName(kind, appearance: appearance))
                }
            }
        }
        var warmed: [String: [SKTexture]] = [:]
        for name in names.sorted() {
            let textures = frames(named: name)
            if !textures.isEmpty { warmed[name] = textures }
        }
        let textures = warmed.values.flatMap { $0 }
        if !textures.isEmpty { SKTexture.preload(textures) {} }
        DiagLog.log("combat textures preloaded clips=\(warmed.count) frames=\(textures.count) cached=\(cachedAnimationFrameCount)")
        return warmed
    }

    /// 读 Sprites 目录下的一张透明 WebP（file 不带扩展名），需要时水平翻转
    static func webp(_ file: String, mirrored: Bool) -> CGImage? {
        guard let folder = Bundle.module.url(forResource: "Sprites", withExtension: nil),
              let source = CGImageSourceCreateWithURL(
                folder.appendingPathComponent(file).appendingPathExtension("webp") as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        guard mirrored else { return image }
        guard let context = CGContext(data: nil, width: image.width, height: image.height,
                                      bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.translateBy(x: CGFloat(image.width), y: 0)
        context.scaleBy(x: -1, y: 1)
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return context.makeImage()
    }

    static func clip(named name: String) -> Clip? {
        clips[name]
    }

    /// base 角色的某个动画状态对应的资源名；没有这个状态或资源缺帧时为 nil
    static func state(_ state: String, of base: String) -> String? {
        guard let name = clips[base]?.states?[state], !frames(named: name).isEmpty else { return nil }
        return name
    }

    /// 把 clip 放进 base 角色的坐标里：base 的第一帧以 (0, 0) 为中心，scale 是每像素多少点。
    /// 两段动画按「pivot + 画布底边」对齐（和上游切换动画时保持底边、中线的做法一致），返回 clip 的显示区域
    static func placement(of clip: String, in base: String, scale: CGFloat) -> CGRect? {
        guard let b = clips[base], let s = clips[clip],
              let bc = b.canvas, bc.count == 2, let sc = s.canvas, sc.count == 2 else { return nil }
        let baseCenter = CGPoint(x: b.crop[0] + b.crop[2] / 2, y: b.crop[1] + b.crop[3] / 2)
        let clipCenter = CGPoint(x: s.crop[0] + s.crop[2] / 2, y: s.crop[1] + s.crop[3] / 2)
        let basePivot = b.pivot ?? bc[0] / 2, clipPivot = s.pivot ?? sc[0] / 2
        // 画布像素的 y 向下，SpriteKit 的 y 向上
        let foot = CGPoint(x: (basePivot - baseCenter.x) * scale, y: (baseCenter.y - bc[1]) * scale)
        let center = CGPoint(x: foot.x + (clipCenter.x - clipPivot) * scale, y: foot.y + (sc[1] - clipCenter.y) * scale)
        let size = CGSize(width: s.crop[2] * scale, height: s.crop[3] * scale)
        return CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height)
    }

    /// base 画布上的一个像素点，换成以 base 第一帧中心为原点的坐标
    static func point(_ pixel: [Double], in base: String, scale: CGFloat) -> CGPoint? {
        guard pixel.count == 2, let b = clips[base], b.crop.count == 4 else { return nil }
        return CGPoint(x: (pixel[0] - b.crop[0] - b.crop[2] / 2) * scale,
                       y: (b.crop[1] + b.crop[3] / 2 - pixel[1]) * scale)
    }

    static func node(named name: String, fitting bounds: CGSize) -> SKSpriteNode? {
        let frames = frames(named: name)
        guard let first = frames.first else { return nil }
        let size = first.size()
        let scale = min(bounds.width / size.width, bounds.height / size.height)
        let node = SKSpriteNode(texture: first, size: CGSize(width: size.width * scale, height: size.height * scale))
        node.name = "unitSprite"
        if frames.count > 1, let clip = clips[name] {
            node.run(.repeatForever(.animate(with: frames, timePerFrame: clip.frameTime, resize: false, restore: false)), withKey: "idle")
        }
        return node
    }

    static func defender(_ kind: DefenderKind, radius: CGFloat, skin: CharacterSkin? = nil) -> SpriteRig? {
        // 哪种射手有哪套皮肤由素材决定；没有整套素材的回退原版
        SpriteRig(named: characterName("plant-\(kind.id)", skin: skin),
                  fitting: CGSize(width: radius * 2.3, height: radius * 2.3))
    }

    /// 植物卡、拖动预览、收藏馆卡片用的静态形象：穿着皮肤的第一帧，缺素材时是原版
    static func portrait(of kind: DefenderKind, skin: CharacterSkin?) -> CGImage? {
        if kind.id == AdventureDoom.id { return AdventureDoomArtwork.portrait }
        if skin == .spellbook, kind.id == DefenderKind.inkling.id, let image = SpellbookSkin.portrait { return image }
        if kind.id == DefenderKind.inkling.id, let image = ThemeSkin.portrait(for: skin) { return image }
        return portrait(named: characterName("plant-\(kind.id)", skin: skin, preload: false))
    }

    static func portrait(of kind: EnemyKind, skin: CharacterSkin?) -> CGImage? {
        portrait(named: characterName("zombie-\(kind.id)", skin: kind.id == "blob" ? skin : nil, preload: false))
    }

    /// 裁切纹理每次 cgImage() 都会重新绘制一张图；头像按资源名缓存在独立预算内。
    private static func portrait(named name: String) -> CGImage? {
        if let cached = cache.portraits.value(for: name) { return cached }
        guard let clip = clips[name], clip.frameCount > 0, clip.crop.count == 4 else { return nil }
        let decoded: CGImage? = autoreleasepool {
            guard let texture = cache.frames.value(for: name)?.first ?? frame(named: name, index: 0, clip: clip) else { return nil }
            return texture.cgImage()
        }
        guard let image = decoded else { return nil }
        cache.portraits.insert(image, for: name, cost: image.bytesPerRow * image.height)
        return image
    }

    static func enemy(_ kind: EnemyKind, skin: CharacterSkin? = nil, appearance: String? = nil) -> SpriteRig? {
        SpriteRig(named: enemyName(kind, skin: skin, appearance: appearance),
                  fitting: CGSize(width: 88, height: 80))
    }

    /// 只选择渲染素材，不修改 EnemyKind。不存在或缺帧时回退原怪物。
    static func enemyName(_ kind: EnemyKind, skin: CharacterSkin? = nil, appearance: String? = nil) -> String {
        if let appearance, UnitCatalog.enemy(id: appearance) != nil {
            let name = "zombie-\(appearance)"
            if !frames(named: name).isEmpty,
               (clips[name]?.states ?? [:]).values.allSatisfy({ !frames(named: $0).isEmpty }) {
                return name
            }
        }
        return characterName("zombie-\(kind.id)", skin: kind.id == "blob" ? skin : nil)
    }

    /// 整套状态完整才换皮，避免行走穿着皮肤，攻击或倒下却突然变回原版。
    static func characterName(_ base: String, skin: CharacterSkin?, preload: Bool = true) -> String {
        guard let skin else { return base }
        let name = "skin-\(skin.rawValue)-\(base)"
        guard let clip = clips[name] else { return base }
        let resources = [name] + Array((clip.states ?? [:]).values)
        let complete = resources.allSatisfy { preload ? !frames(named: $0).isEmpty : hasFrameFiles(named: $0) }
        guard complete else { return base }
        return name
    }

    private static func hasFrameFiles(named name: String) -> Bool {
        guard let clip = clips[name], clip.frameCount > 0, clip.crop.count == 4 else { return false }
        return (0..<clip.frameCount).allSatisfy { index in
            if let files = clip.files {
                guard files.indices.contains(index) else { return false }
                return Bundle.module.url(forResource: files[index], withExtension: "webp", subdirectory: "Sprites") != nil
            }
            return Bundle.module.url(forResource: String(index), withExtension: "png", subdirectory: "Sprites/\(name)") != nil
        }
    }

    private static func projectileName(_ look: ProjectileLook) -> String? {
        switch look.shape {
        case .orb: "pea"
        case .snowflake: "ice-pea"
        case .star: "star"
        case .petal, .heart, .gem: nil
        }
    }

    static func projectile(_ look: ProjectileLook) -> SKSpriteNode? {
        guard let name = projectileName(look) else { return nil }
        let diameter = CGFloat(look.size) * 2
        return node(named: name, fitting: CGSize(width: diameter, height: diameter))
    }

    /// 子弹打中时溅开的图案（豌豆、星星）；没有对应素材时为 nil
    static func impact(_ look: ProjectileLook) -> SKSpriteNode? {
        guard let base = projectileName(look), let name = state("hit", of: base) else { return nil }
        // 上游溅开图约是子弹的两倍大
        let diameter = CGFloat(look.size) * 4.4
        let node = node(named: name, fitting: CGSize(width: diameter, height: diameter))
        node?.name = "impactSplat"
        return node
    }

    /// 光束攻击的烟雾序列帧（大喷菇的孢子烟）；没有对应素材时为 nil
    static func beam(_ look: ProjectileLook) -> (frames: [SKTexture], frameTime: TimeInterval)? {
        guard look.shape == .petal, let clip = clips["fume"] else { return nil }
        let frames = frames(named: "fume")
        return frames.isEmpty ? nil : (frames, clip.frameTime)
    }
}
