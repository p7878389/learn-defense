import ImageIO
import LearnCore
import SpriteKit

/// 资源负责外观和动作；场景只同步玩法状态，所有倒计时来自战斗快照。
@MainActor
final class AdventureDoomArtwork {
    static let portrait: CGImage? = {
        guard let url = Bundle.module.url(forResource: "DoomBody", withExtension: "png", subdirectory: "Effects"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }()

    private var charges: [Int: SKNode] = [:]
    private var craters: [Int: SKNode] = [:]

    func render(_ battle: AdventureBattle, in scene: SKNode) {
        render(charges: battle.doomCharges, craters: battle.doomCraters, playing: battle.phase == .playing, in: scene)
    }

    func render(charges sites: [AdventureDoomSite], craters holes: [AdventureDoomSite], playing: Bool,
                in scene: SKNode, laneOffset: Int = 0) {
        let chargeIDs = Set(sites.map(\.id))
        for id in Array(charges.keys) where !chargeIDs.contains(id) { charges.removeValue(forKey: id)?.removeFromParent() }
        for site in sites {
            if charges[site.id] == nil,
               let node = FXLibrary.playResource("DoomBody", at: point(site, laneOffset: laneOffset), in: scene) {
                node.name = "doom-charge-\(site.id)"
                node.zPosition = 8
                charges[site.id] = node
            }
            if let node = charges[site.id], playing, node.userData?["armed"] as? Bool != true {
                if node.userData == nil { node.userData = NSMutableDictionary() }
                node.userData?["armed"] = true
                node.speed = AdventureDoom.fuse / max(0.05, site.remaining)
                FXLibrary.runEvent("arm", on: node)
            }
        }
        let craterIDs = Set(holes.map(\.id))
        for id in Array(craters.keys) where !craterIDs.contains(id) { craters.removeValue(forKey: id)?.removeFromParent() }
        for site in holes {
            if craters[site.id] == nil,
               let node = FXLibrary.playResource("DoomCrater", at: point(site, laneOffset: laneOffset), in: scene) {
                node.name = "doom-crater-\(site.id)"
                node.zPosition = 7
                let label = SKLabelNode(fontNamed: "PingFangSC-Semibold")
                label.name = "countdown"
                label.fontSize = 16
                label.fontColor = .white
                label.position.y = -52
                node.addChild(label)
                craters[site.id] = node
            }
            let seconds = max(0, Int(ceil(site.remaining)))
            (craters[site.id]?.childNode(withName: "countdown") as? SKLabelNode)?.text = String(format: "🔒 %02d:%02d", seconds / 60, seconds % 60)
        }
    }

    func explode(_ site: AdventureDoomSite, in scene: SKNode, laneOffset: Int = 0) {
        FXLibrary.playResource("DoomExplosion", at: point(site, laneOffset: laneOffset), in: scene)
    }

    private func point(_ site: AdventureDoomSite, laneOffset: Int) -> CGPoint {
        CGPoint(x: AdventureDoom.x(site.column), y: AdventureDoom.y(site.lane + laneOffset))
    }
}
