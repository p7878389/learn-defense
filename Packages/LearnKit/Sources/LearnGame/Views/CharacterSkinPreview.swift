import LearnCore
import SpriteKit
import SwiftUI

/// 使用同一套 SpriteRig 试穿；试看不写入孩子的装备。
struct CharacterSkinPreview: View {
    var kind: DefenderKind = .inkling
    let skin: CharacterSkin?
    let enemy: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 试穿舞台的身份：换皮肤或换角色时整块舞台重建
    static func stageID(kind: DefenderKind = .inkling, skin: CharacterSkin?, enemy: Bool) -> String {
        "\(enemy ? "enemy" : kind.id)-\(skin?.rawValue ?? "original")"
    }

    var body: some View {
        HStack(spacing: 12) {
            // SpriteView 只展示创建时拿到的场景，之后换参数不会重新展示；
            // 所以按皮肤给舞台独立身份，切换时连同场景一起重建。
            CharacterSkinStage(kind: kind, skin: skin, enemy: enemy, paused: reduceMotion)
                .id(Self.stageID(kind: kind, skin: skin, enemy: enemy))
                .frame(width: 280, height: 130)
                .accessibilityLabel("\(enemy ? "普通僵尸" : kind.name)\(skin == nil ? "原版" : "动画皮肤")试穿")
            VStack(alignment: .leading, spacing: 8) {
                Text(enemy ? "普通僵尸 · 行走 / 啃咬" : "\(kind.name) · 待机 / 发射")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                Text("点选试看，装备后下局生效")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
            }
            .foregroundStyle(Theme.ink)
        }
    }
}

/// 每个身份只建一次场景；出现时才建，父视图刷新不会白建场景
private struct CharacterSkinStage: View {
    let kind: DefenderKind
    let skin: CharacterSkin?
    let enemy: Bool
    let paused: Bool
    @State private var scene: CharacterSkinPreviewScene?

    var body: some View {
        ZStack {
            if let scene {
                SpriteView(scene: scene, isPaused: paused, options: [.allowsTransparency])
            }
        }
        .onAppear {
            if scene == nil { scene = CharacterSkinPreviewScene(kind: kind, skin: skin, enemy: enemy) }
        }
    }
}

@MainActor
final class CharacterSkinPreviewScene: SKScene {
    init(kind: DefenderKind = .inkling, skin: CharacterSkin?, enemy: Bool) {
        super.init(size: CGSize(width: 280, height: 130))
        scaleMode = .aspectFit
        backgroundColor = .clear
        let node: SKNode
        if enemy {
            let zombie = EnemyNode(id: 0, kind: .blob, sign: "春", lane: 0, scale: 1.25, skin: skin)
            zombie.run(.repeatForever(.sequence([
                .wait(forDuration: 2), .run { [weak zombie] in zombie?.lunge() },
                .wait(forDuration: 0.8), .moveBy(x: 36, y: 0, duration: 0.7),
            ])))
            node = zombie
        } else {
            let shooter = DefenderNode(kind: kind, radius: 44, skin: skin)
            shooter.run(.repeatForever(.sequence([
                .wait(forDuration: 2), .run { [weak shooter] in shooter?.shoot() },
            ])))
            node = shooter
        }
        node.position = CGPoint(x: 140, y: 56)
        addChild(node)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
