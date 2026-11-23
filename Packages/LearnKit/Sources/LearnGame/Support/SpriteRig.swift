import LearnCore
import SpriteKit

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
