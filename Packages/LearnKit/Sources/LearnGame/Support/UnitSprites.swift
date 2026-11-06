import LearnCore
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

        var duration: TimeInterval { Double(frameCount) * frameTime }
    }

    private static let clips: [String: Clip] = {
        guard let url = Bundle.module.url(forResource: "clips", withExtension: "json", subdirectory: "Sprites"),
              let data = try? Data(contentsOf: url),
              let clips = try? JSONDecoder().decode([String: Clip].self, from: data) else { return [:] }
        guard let skinURL = Bundle.module.url(forResource: "skins", withExtension: "json", subdirectory: "Sprites"),
              let skinData = try? Data(contentsOf: skinURL),
              let skins = try? JSONDecoder().decode([String: Clip].self, from: skinData) else { return clips }
        return clips.merging(skins) { original, _ in original }
    }()
    private static var cachedFrames: [String: [SKTexture]] = [:]

    static func frames(named name: String) -> [SKTexture] {
        if let cached = cachedFrames[name] { return cached }
        guard let clip = clips[name], clip.frameCount > 0, clip.crop.count == 4 else { return [] }
        var frames: [SKTexture] = []
        for index in 0..<clip.frameCount {
            guard let url = Bundle.module.url(forResource: String(index), withExtension: "png", subdirectory: "Sprites/\(name)"),
                  let image = PlatformImage(contentsOfFile: url.path) else {
                cachedFrames[name] = []
                return []
            }
            // PNG 的 DPI 元数据会改变 NSImage 的点尺寸，裁切必须统一使用像素尺寸。
            #if canImport(UIKit)
            guard let bitmap = image.cgImage else { return [] }
            #else
            guard let bitmap = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return [] }
            #endif
            let source: CGImage
            if let key = clip.colorKey, key.count == 3 {
                // Core Graphics 的色键遮罩不接受带 alpha 的源图；先以 RGB 解码白底帧。
                guard let context = CGContext(data: nil, width: bitmap.width, height: bitmap.height,
                                              bitsPerComponent: 8, bytesPerRow: bitmap.width * 4,
                                              space: CGColorSpaceCreateDeviceRGB(),
                                              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return [] }
                context.draw(bitmap, in: CGRect(x: 0, y: 0, width: bitmap.width, height: bitmap.height))
                guard let rgb = context.makeImage(),
                      let masked = rgb.copy(maskingColorComponents: key.flatMap { [$0, $0] }) else { return [] }
                source = masked
            } else {
                source = bitmap
            }
            let full = SKTexture(cgImage: source)
            let size = full.size()
            let c = clip.crop
            guard size.width > 0, size.height > 0,
                  c[0] >= 0, c[1] >= 0, c[2] > 0, c[3] > 0,
                  c[0] + c[2] <= size.width, c[1] + c[3] <= size.height else { return [] }
            // 清单采用左上角像素坐标；SpriteKit 纹理坐标从左下角开始。
            let rect = CGRect(x: c[0] / size.width, y: 1 - (c[1] + c[3]) / size.height,
                              width: c[2] / size.width, height: c[3] / size.height)
            let texture = SKTexture(rect: rect, in: full)
            texture.filteringMode = name.hasPrefix("skin-pixel-") ? .nearest : .linear
            frames.append(texture)
        }
        cachedFrames[name] = frames
        return frames
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
        frames(named: characterName("plant-\(kind.id)", skin: skin)).first?.cgImage()
    }

    static func portrait(of kind: EnemyKind, skin: CharacterSkin?) -> CGImage? {
        frames(named: characterName("zombie-\(kind.id)", skin: kind.id == "blob" ? skin : nil)).first?.cgImage()
    }

    static func enemy(_ kind: EnemyKind, skin: CharacterSkin? = nil) -> SpriteRig? {
        SpriteRig(named: characterName("zombie-\(kind.id)", skin: kind.id == "blob" ? skin : nil),
                  fitting: CGSize(width: 88, height: 80))
    }

    /// 整套状态完整才换皮，避免行走穿着皮肤，攻击或倒下却突然变回原版。
    static func characterName(_ base: String, skin: CharacterSkin?) -> String {
        guard let skin else { return base }
        let name = "skin-\(skin.rawValue)-\(base)"
        guard let clip = clips[name], !frames(named: name).isEmpty,
              (clip.states ?? [:]).values.allSatisfy({ !frames(named: $0).isEmpty }) else { return base }
        return name
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

/// 一个角色的序列帧外观：同一个精灵节点在走路、啃咬、倒下等动画之间切换，
/// 切换时按 clips.json 里的 pivot 和画布底边对齐，换动画不会让角色跳位置
@MainActor
final class SpriteRig {
    static let loopKey = "idle"
    static let onceKey = "once"

    let sprite: SKSpriteNode
    let base: String
    /// 每像素多少点，同一角色所有动画共用
    let scale: CGFloat
    /// 正在循环播放的动画（走路，或掉了防具后的走路）
    private(set) var looping: String
    private(set) var current: String

    /// 动画播放速度：减速时变慢，冻住时为 0。
    /// SKAction 的 speed 在 run 之后不起作用，所以按新速度换帧间隔、从当前帧接着循环
    var tempo: CGFloat = 1 {
        didSet {
            guard tempo != oldValue, current == looping else { return }
            startLoop(looping, from: sprite.texture)
        }
    }

    init?(named name: String, fitting bounds: CGSize) {
        let frames = UnitSprites.frames(named: name)
        guard let first = frames.first else { return nil }
        let size = first.size()
        scale = min(bounds.width / size.width, bounds.height / size.height)
        sprite = SKSpriteNode(texture: first, size: CGSize(width: size.width * scale, height: size.height * scale))
        sprite.name = "unitSprite"
        base = name
        looping = name
        current = name
        startLoop(name)
    }

    func clip(for state: String) -> String? {
        UnitSprites.state(state, of: base)
    }

    /// 子弹出口，以 base 第一帧中心为原点
    var muzzle: CGPoint? {
        UnitSprites.clip(named: base)?.muzzle.flatMap { UnitSprites.point($0, in: base, scale: scale) }
    }

    /// 换一段循环动画（比如掉了防具改用普通走路）
    func loop(_ name: String) {
        guard show(name) else { return }
        looping = name
        sprite.removeAction(forKey: Self.onceKey)
        startLoop(name)
    }

    /// 播一遍 name，播完回到循环动画；hold 为 true 时停在最后一帧（倒下）。返回播放时长
    @discardableResult
    func playOnce(_ name: String, hold: Bool = false) -> TimeInterval {
        guard let clip = UnitSprites.clip(named: name), show(name) else { return 0 }
        sprite.removeAction(forKey: Self.loopKey)
        let animate = SKAction.animate(with: UnitSprites.frames(named: name), timePerFrame: clip.frameTime,
                                       resize: false, restore: false)
        if hold {
            sprite.run(animate, withKey: Self.onceKey)
        } else {
            let back = looping
            sprite.run(.sequence([animate, .run { [weak self] in self?.resume(back) }]), withKey: Self.onceKey)
        }
        return clip.duration
    }

    /// 单次动画播完后回到循环。此时还在 onceKey 那条动作里面执行，
    /// 不能像 loop 那样 removeAction(forKey: onceKey) 把正在跑的自己删掉——
    /// SpriteKit 会接着访问已释放的动作，偶发 EXC_BAD_ACCESS 闪退；这条动作播完会自己结束
    private func resume(_ name: String) {
        guard show(name) else { return }
        looping = name
        startLoop(name)
    }

    /// 在同一坐标里另起一个精灵播一遍 name（比如掉下来的头），播完自己移除
    func spawn(_ name: String) -> SKSpriteNode? {
        guard let clip = UnitSprites.clip(named: name),
              let rect = UnitSprites.placement(of: name, in: base, scale: scale),
              let parent = sprite.parent else { return nil }
        let frames = UnitSprites.frames(named: name)
        guard let first = frames.first else { return nil }
        let node = SKSpriteNode(texture: first, size: rect.size)
        node.position = CGPoint(x: rect.midX, y: rect.midY)
        node.zPosition = sprite.zPosition + 1
        parent.addChild(node)
        node.run(.sequence([
            .animate(with: frames, timePerFrame: clip.frameTime, resize: false, restore: false),
            .wait(forDuration: 0.3),
            .fadeOut(withDuration: 0.25),
            .removeFromParent(),
        ]))
        return node
    }

    /// 把精灵换成 name 的第一帧，并按对齐规则摆好位置和大小
    @discardableResult
    private func show(_ name: String) -> Bool {
        let frames = UnitSprites.frames(named: name)
        guard let first = frames.first else { return false }
        if name == base {
            sprite.position = .zero
            sprite.size = CGSize(width: first.size().width * scale, height: first.size().height * scale)
        } else {
            guard let rect = UnitSprites.placement(of: name, in: base, scale: scale) else { return false }
            sprite.position = CGPoint(x: rect.midX, y: rect.midY)
            sprite.size = rect.size
        }
        sprite.texture = first
        current = name
        return true
    }

    private func startLoop(_ name: String, from texture: SKTexture? = nil) {
        var frames = UnitSprites.frames(named: name)
        // 冻住时停在当前帧
        guard frames.count > 1, let clip = UnitSprites.clip(named: name), tempo > 0 else {
            sprite.removeAction(forKey: Self.loopKey)
            return
        }
        if let texture, let index = frames.firstIndex(where: { $0 === texture }) {
            frames = Array(frames[index...] + frames[..<index])
        }
        let frameTime = clip.frameTime / Double(tempo)
        sprite.run(.repeatForever(.animate(with: frames, timePerFrame: frameTime, resize: false, restore: false)),
                   withKey: Self.loopKey)
    }
}
