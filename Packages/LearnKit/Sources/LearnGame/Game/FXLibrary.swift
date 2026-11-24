import ImageIO
import SpriteKit

/// `.sks` 是外观和固定动作的来源；这里只处理资源包、实例隔离和运行时绑定。
@MainActor
enum FXLibrary {
    private static var archives: [String: SKNode] = [:]
    private static var textures: [String: SKTexture] = [:]
    private static var actions: [String: SKAction] = [:]

    static var cachedArchiveCount: Int { archives.count }
    static var cachedTextureCount: Int { textures.count }

    static func releaseCachedResources() {
        archives.removeAll()
        textures.removeAll()
        actions.removeAll()
    }

    static func effect(named name: String) -> SKNode? {
        guard let archive = archive(named: name) else { return nil }
        let source = archive is SKScene ? archive.childNode(withName: "effect") : archive
        guard let instance = source?.copy() as? SKNode else {
            DiagLog.log("fx missing effect root: \(name)")
            return nil
        }
        instance.position = .zero
        guard bindActions(in: instance) else { return nil }
        return instance
    }

    static func reaction() -> SKAction? {
        action(named: "HitReaction")
    }

    static func react(on node: SKNode) {
        guard let action = reaction() else { return }
        node.run(action, withKey: "fxHitReaction")
    }

    /// 在实际出膛时绑定资源；等待连发的子弹不提前创建枪口和飞行效果。
    static func launchOrb(on bullet: SKNode, towards target: CGPoint, in layer: SKNode) {
        let direction = atan2(target.y - bullet.position.y, target.x - bullet.position.x)
        if let muzzle = effect(named: "PeaMuzzle") {
            muzzle.name = "peaMuzzle"
            muzzle.position = bullet.position
            muzzle.zRotation = direction
            attach(muzzle, to: layer)
        }
        if let flight = effect(named: "PeaFlight") {
            flight.name = "peaFlight"
            flight.zRotation = direction
            attach(flight, to: bullet)
        }
    }

    static func playDefeat(at point: CGPoint, in layer: SKNode) {
        guard let effect = effect(named: "DefeatBloom") else { return }
        effect.name = "defeatBloom"
        effect.position = point
        attach(effect, to: layer)
    }

    static func playInk(at point: CGPoint, in layer: SKNode, color: SKColor, scale: CGFloat, count: Int) {
        guard count > 0, scale > 0,
              let emitter = effect(named: "InkBurst") as? SKEmitterNode,
              emitter.particleBirthRate > 0, emitter.particleLifetime > 0 else { return }
        emitter.position = point
        emitter.setScale(scale)
        emitter.numParticlesToEmit = count
        emitter.particleColorSequence = nil
        emitter.particleColor = color
        // 数量是调用方的动态输入，其他参数来自资源。清理期限随资源寿命自动变化。
        let lifetime = Double(count) / Double(emitter.particleBirthRate)
            + Double(emitter.particleLifetime + emitter.particleLifetimeRange / 2)
        emitter.run(.sequence([.wait(forDuration: lifetime), .removeFromParent()]), withKey: "lifetime")
        attach(emitter, to: layer)
    }

    @discardableResult
    static func playImpact(at point: CGPoint, in layer: SKNode, color: SKColor) -> Bool {
        guard let effect = effect(named: "PeaImpact"), effect.action(forKey: "fxResourceAction") != nil else { return false }
        effect.name = "impactSplat"
        effect.position = point
        tint(effect, color: color)
        attach(effect, to: layer)
        return true
    }

    static func setPaused(_ paused: Bool, in layer: SKNode) {
        layer.enumerateChildNodes(withName: ".//*") { node, _ in
            if node.userData?["fxResource"] as? Bool == true {
                applyPause(paused, to: node)
            }
        }
    }

    static func attach(_ effect: SKNode, to layer: SKNode) {
        if effect.userData == nil { effect.userData = NSMutableDictionary() }
        effect.userData?["fxResource"] = true
        layer.addChild(effect)
        let scene = (layer as? SKScene) ?? layer.scene
        applyPause(scene?.speed == 0 || layer.isPaused, to: effect)
    }

    @discardableResult
    static func playResource(_ name: String, at point: CGPoint, in layer: SKNode) -> SKNode? {
        guard let node = effect(named: name) else { return nil }
        node.name = name
        node.position = point
        attach(node, to: layer)
        return node
    }

    /// 部件事件动作与待机循环都由 SKS 元数据指定，重复触发只保留最新一次。
    static func runEvent(_ event: String, on root: SKNode) {
        if let name = root.userData?[event + "Action"] as? String, let eventAction = action(named: name) {
            root.removeAction(forKey: "fxResourceAction")
            root.run(.sequence([eventAction, .run { [weak root] in
                guard let root, let idleName = root.userData?["action"] as? String,
                      let idle = action(named: idleName) else { return }
                root.run(idle, withKey: "fxResourceAction")
            }]), withKey: "fxEvent")
        }
        for child in root.children { runEvent(event, on: child) }
    }

    private static func applyPause(_ paused: Bool, to effect: SKNode) {
        effect.removeAction(forKey: "fxInitialPause")
        effect.isPaused = paused
        if paused {
            // SpriteKit 首帧接入渲染树会重置新节点的暂停标志，首帧再同步一次。
            effect.run(.run { [weak effect] in effect?.isPaused = true }, withKey: "fxInitialPause")
        }
    }

    private static func tint(_ node: SKNode, color: SKColor) {
        if node.userData?["tint"] as? Bool == true {
            if let emitter = node as? SKEmitterNode {
                emitter.particleColorSequence = nil
                emitter.particleColor = color
            } else if let sprite = node as? SKSpriteNode {
                sprite.color = color
            }
        }
        for child in node.children { tint(child, color: color) }
    }

    private static func archive(named name: String) -> SKNode? {
        if let cached = archives[name] { return cached }
        guard let url = Bundle.module.url(forResource: name, withExtension: "sks", subdirectory: "Effects") else {
            DiagLog.log("fx missing archive: \(name)")
            return nil
        }
        do {
            // 仅读取本应用打包的归档，不接收下载或用户导入的 SKS。
            let decoder = try NSKeyedUnarchiver(forReadingFrom: Data(contentsOf: url))
            decoder.requiresSecureCoding = false
            defer { decoder.finishDecoding() }
            guard let root = decoder.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? SKNode,
                  bindTextures(in: root) else {
                DiagLog.log("fx invalid archive or texture: \(name)")
                return nil
            }
            archives[name] = root
            return root
        } catch {
            DiagLog.log("fx load failed: \(name) \(error)")
            return nil
        }
    }

    private static func bindTextures(in node: SKNode) -> Bool {
        if let name = node.userData?["texture"] as? String {
            guard let texture = texture(named: name) else { return false }
            if let emitter = node as? SKEmitterNode { emitter.particleTexture = texture }
            if let sprite = node as? SKSpriteNode { sprite.texture = texture }
        }
        return node.children.allSatisfy { bindTextures(in: $0) }
    }

    private static func bindActions(in node: SKNode) -> Bool {
        if let name = node.userData?["action"] as? String {
            guard let action = action(named: name) else { return false }
            // Xcode 保存场景会重写运行时 action 的键；用原生动作库和稳定的资源引用恢复。
            node.removeAllActions()
            node.run(action, withKey: "fxResourceAction")
        }
        return node.children.allSatisfy { bindActions(in: $0) }
    }

    private static func action(named name: String) -> SKAction? {
        if let cached = actions[name] { return cached.copy() as? SKAction }
        guard let url = Bundle.module.url(forResource: "CombatActions", withExtension: "sks", subdirectory: "Effects"),
              let action = SKAction(named: name, from: url) else {
            DiagLog.log("fx missing action: \(name)")
            return nil
        }
        actions[name] = action
        return action.copy() as? SKAction
    }

    private static func texture(named name: String) -> SKTexture? {
        if let cached = textures[name] { return cached }
        guard let url = Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "Effects"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        let texture = SKTexture(cgImage: image)
        texture.filteringMode = .linear
        textures[name] = texture
        return texture
    }
}
