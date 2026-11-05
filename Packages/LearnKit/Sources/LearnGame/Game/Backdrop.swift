import LearnCore
import SpriteKit

extension RGB {
    var color: SKColor {
        SKColor(red: r, green: g, blue: b, alpha: 1)
    }

    func scaled(_ k: Double) -> SKColor {
        SKColor(red: min(1, r * k), green: min(1, g * k), blue: min(1, b * k), alpha: 1)
    }
}

/// 把背景主题画成场景：天空、远景、路面、路边装饰、飘动的云和蝴蝶、左边的基地。
/// 每一层只看主题配置，新增主题不用改这里
@MainActor
struct Backdrop {
    let theme: SceneTheme
    let size: CGSize
    /// 顶部天空的高度，下面是路
    let skyHeight: CGFloat
    let lanes: Int
    /// 基地那一列的宽度
    let baseWidth: CGFloat

    private var fieldHeight: CGFloat { size.height - skyHeight }
    private var laneHeight: CGFloat { fieldHeight / CGFloat(lanes) }

    func build(in scene: SKNode) {
        if let url = Bundle.module.url(forResource: "courtyard", withExtension: "jpg", subdirectory: "Sprites"),
           let image = PlatformImage(contentsOfFile: url.path) {
            let full = SKTexture(image: image)
            let texture = SKTexture(rect: CGRect(x: 100.0 / 1400, y: 0, width: 1200.0 / 1400, height: 1), in: full)
            let courtyard = SKSpriteNode(texture: texture, size: size)
            courtyard.name = "courtyard"
            courtyard.anchorPoint = .zero
            courtyard.zPosition = -30
            scene.addChild(courtyard)
            return
        }
        addSky(to: scene)
        addHorizon(to: scene)
        addLanes(to: scene)
        addScenery(to: scene)
        addDrifters(to: scene)
        addFlutter(to: scene)
        addBase(to: scene)
    }

    // MARK: - 天空

    private func addSky(to scene: SKNode) {
        let sky = SKSpriteNode(texture: Self.gradient(top: theme.skyTop, bottom: theme.skyBottom))
        sky.size = CGSize(width: size.width, height: skyHeight)
        sky.anchorPoint = .zero
        sky.position = CGPoint(x: 0, y: fieldHeight)
        sky.zPosition = -30
        scene.addChild(sky)

        if let celestial = theme.celestial {
            let node = Pictures.node(celestial, size: skyHeight * 0.8)
            node.position = CGPoint(x: size.width - 70, y: fieldHeight + skyHeight * 0.52)
            node.zPosition = -29
            scene.addChild(node)
            node.run(.repeatForever(.sequence([
                .group([.scale(to: 1.08, duration: 2), .rotate(byAngle: 0.08, duration: 2)]),
                .group([.scale(to: 1.0, duration: 2), .rotate(byAngle: -0.08, duration: 2)]),
            ])))
        }
    }

    /// 地平线上一排远景，底部压在路的上沿
    private func addHorizon(to scene: SKNode) {
        let items = theme.horizon
        guard !items.isEmpty else { return }
        let left = baseWidth + 40
        let right = size.width - (theme.celestial == nil ? 40 : 140)
        let step = (right - left) / CGFloat(max(1, items.count - 1))
        for (i, emoji) in items.enumerated() {
            let s = skyHeight * CGFloat([0.95, 0.75, 0.85, 0.7][i % 4])
            let node = Pictures.node(emoji, size: s)
            node.position = CGPoint(x: left + step * CGFloat(i) + CGFloat.random(in: -14...14),
                                    y: fieldHeight + s * 0.42)
            node.zPosition = -27
            node.alpha = 0.92
            scene.addChild(node)
        }
    }

    /// 慢慢飘过天空的云、星星、风筝
    private func addDrifters(to scene: SKNode) {
        for (i, emoji) in theme.drifters.enumerated() {
            let s = skyHeight * CGFloat.random(in: 0.5...0.7)
            let node = Pictures.node(emoji, size: s)
            let y = fieldHeight + skyHeight * CGFloat.random(in: 0.45...0.75)
            let startX = size.width * CGFloat(i + 1) / CGFloat(theme.drifters.count + 1)
            node.position = CGPoint(x: startX, y: y)
            node.zPosition = -28
            node.alpha = 0.95
            scene.addChild(node)
            // 从当前位置飘到左边，再从右边重新进来
            let speed = CGFloat.random(in: 9...16)
            let offLeft = -s
            let offRight = size.width + s
            let first = SKAction.moveTo(x: offLeft, duration: Double((startX - offLeft) / speed))
            let loop = SKAction.sequence([
                .moveTo(x: offRight, duration: 0),
                .moveTo(x: offLeft, duration: Double((offRight - offLeft) / speed)),
            ])
            node.run(.sequence([first, .repeatForever(loop)]))
            node.run(.repeatForever(.sequence([
                .moveBy(x: 0, y: 3, duration: 1.6),
                .moveBy(x: 0, y: -3, duration: 1.6),
            ])))
        }
    }

    // MARK: - 路面

    private func addLanes(to scene: SKNode) {
        for lane in 0..<lanes {
            let rgb = theme.lanes[lane % theme.lanes.count]
            let y = laneHeight * CGFloat(lane)
            let strip = SKSpriteNode(color: rgb.color, size: CGSize(width: size.width, height: laneHeight))
            strip.anchorPoint = .zero
            strip.position = CGPoint(x: 0, y: y)
            strip.zPosition = -20
            scene.addChild(strip)

            // 路的上沿一条浅色描边，让每条路分开
            let edge = SKSpriteNode(color: rgb.scaled(0.85), size: CGSize(width: size.width, height: 3))
            edge.anchorPoint = .zero
            edge.position = CGPoint(x: 0, y: y + laneHeight - 3)
            edge.zPosition = -19
            scene.addChild(edge)

            switch theme.ground {
            case .grass: addGrass(to: scene, laneY: y, color: rgb.scaled(0.78))
            case .stone: addStones(to: scene, laneY: y, lane: lane, color: rgb.scaled(0.94))
            }
        }
    }

    private func addGrass(to scene: SKNode, laneY: CGFloat, color: SKColor) {
        let count = Int(size.width / 70)
        for _ in 0..<count {
            let x = CGFloat.random(in: baseWidth...size.width)
            let y = laneY + CGFloat.random(in: 8...(laneHeight - 14))
            let h = CGFloat.random(in: 7...12)
            let path = CGMutablePath()
            for dx in [-5.0, 0, 5] as [CGFloat] {
                path.move(to: CGPoint(x: dx * 0.4, y: 0))
                path.addLine(to: CGPoint(x: dx, y: dx == 0 ? h : h * 0.75))
            }
            let tuft = SKShapeNode(path: path)
            tuft.strokeColor = color
            tuft.lineWidth = 2
            tuft.lineCap = .round
            tuft.position = CGPoint(x: x, y: y)
            tuft.zPosition = -18
            scene.addChild(tuft)
        }
    }

    private func addStones(to scene: SKNode, laneY: CGFloat, lane: Int, color: SKColor) {
        let brick: CGFloat = 96
        let offset = lane.isMultiple(of: 2) ? 0 : brick / 2
        var x = baseWidth + offset
        while x < size.width {
            let seam = SKSpriteNode(color: color, size: CGSize(width: 3, height: laneHeight * 0.5))
            seam.position = CGPoint(x: x, y: laneY + laneHeight / 2)
            seam.zPosition = -18
            scene.addChild(seam)
            x += brick
        }
        let middle = SKSpriteNode(color: color, size: CGSize(width: size.width - baseWidth, height: 2))
        middle.anchorPoint = CGPoint(x: 0, y: 0.5)
        middle.position = CGPoint(x: baseWidth, y: laneY + laneHeight * 0.25)
        middle.zPosition = -18
        scene.addChild(middle)
    }

    /// 路和路之间、最下沿零星的小花小草
    private func addScenery(to scene: SKNode) {
        guard !theme.scenery.isEmpty else { return }
        let s = min(30, laneHeight * 0.3)
        for border in 0..<lanes {
            let y = laneHeight * CGFloat(border) + (border == 0 ? s * 0.45 : 0)
            for _ in 0..<4 {
                let node = Pictures.node(theme.scenery.randomElement()!, size: s * CGFloat.random(in: 0.8...1.1))
                node.position = CGPoint(x: CGFloat.random(in: (baseWidth + 140)...(size.width - 20)), y: y)
                node.zPosition = -15
                scene.addChild(node)
            }
        }
    }

    /// 在路上飞来飞去的蝴蝶、蜜蜂，在怪物下面一层，不挡牌子
    private func addFlutter(to scene: SKNode) {
        for emoji in theme.flutter {
            let node = Pictures.node(emoji, size: min(34, laneHeight * 0.32))
            let point = { CGPoint(x: CGFloat.random(in: (self.baseWidth + 120)...(self.size.width - 40)),
                                  y: CGFloat.random(in: 20...(self.fieldHeight - 20))) }
            node.position = point()
            node.zPosition = -12
            node.alpha = 0.9
            scene.addChild(node)
            var path: [SKAction] = []
            for _ in 0..<6 {
                let move = SKAction.move(to: point(), duration: Double.random(in: 3...5))
                move.timingMode = .easeInEaseOut
                path.append(move)
            }
            node.run(.repeatForever(.sequence(path)))
            // 一扇一扇
            node.run(.repeatForever(.sequence([
                .scaleX(to: 0.75, duration: 0.18),
                .scaleX(to: 1.0, duration: 0.18),
            ])))
        }
    }

    // MARK: - 基地

    private func addBase(to scene: SKNode) {
        let wall = SKShapeNode(rect: CGRect(x: -20, y: 0, width: baseWidth + 20, height: fieldHeight), cornerRadius: 14)
        wall.fillColor = theme.baseColor.color
        wall.strokeColor = theme.baseColor.scaled(0.7)
        wall.lineWidth = 3
        wall.zPosition = -9
        scene.addChild(wall)
        for lane in 0..<lanes {
            let node = Pictures.node(theme.base, size: min(56, laneHeight * 0.55))
            node.position = CGPoint(x: baseWidth / 2, y: laneHeight * (CGFloat(lane) + 0.5))
            node.zPosition = -8
            scene.addChild(node)
        }
    }

    // MARK: - 工具

    /// 竖直方向的渐变贴图
    static func gradient(top: RGB, bottom: RGB) -> SKTexture {
        let width = 4, height = 64
        let space = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let gradient = CGGradient(colorsSpace: space, colors: [
                  CGColor(red: bottom.r, green: bottom.g, blue: bottom.b, alpha: 1),
                  CGColor(red: top.r, green: top.g, blue: top.b, alpha: 1),
              ] as CFArray, locations: [0, 1])
        else { return SKTexture() }
        // CGContext 的原点在左下，和 SpriteKit 一致：y=0 是底部
        context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: height), options: [])
        guard let image = context.makeImage() else { return SKTexture() }
        return SKTexture(cgImage: image)
    }
}
