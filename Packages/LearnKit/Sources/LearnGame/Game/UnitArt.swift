import LearnCore
import SpriteKit

/// 把外观配置画成 SpriteKit 节点。每个部件单独画，组合在一起就是一个角色
extension UnitColor {
    private var rgb: (CGFloat, CGFloat, CGFloat) {
        switch self {
        case .ink: (0.17, 0.17, 0.22)
        case .indigo: (0.29, 0.31, 0.62)
        case .crimson: (0.76, 0.25, 0.27)
        case .plum: (0.49, 0.30, 0.52)
        case .moss: (0.45, 0.64, 0.30)
        case .sky: (0.40, 0.66, 0.86)
        case .gold: (1.00, 0.80, 0.25)
        case .coral: (0.96, 0.50, 0.42)
        case .jade: (0.24, 0.66, 0.52)
        }
    }

    var fill: SKColor {
        let (r, g, b) = rgb
        return SKColor(red: r, green: g, blue: b, alpha: 1)
    }

    /// 描边用的深色
    var dark: SKColor {
        let (r, g, b) = rgb
        return SKColor(red: r * 0.6, green: g * 0.6, blue: b * 0.6, alpha: 1)
    }
}

enum Shapes {
    /// 绕中心一圈的形状，radius(θ) 返回该方向上的半径倍数
    static func radial(rx: CGFloat, ry: CGFloat, points: Int = 48, radius: (CGFloat) -> CGFloat) -> CGPath {
        let path = CGMutablePath()
        for i in 0..<points {
            let angle = CGFloat(i) / CGFloat(points) * .pi * 2
            let r = radius(angle)
            let point = CGPoint(x: cos(angle) * rx * r, y: sin(angle) * ry * r)
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }

    static func star(points: Int, outer: CGFloat, inner: CGFloat) -> CGPath {
        let path = CGMutablePath()
        for i in 0..<(points * 2) {
            let angle = CGFloat(i) / CGFloat(points * 2) * .pi * 2 + .pi / 2
            let r = i.isMultiple(of: 2) ? outer : inner
            let point = CGPoint(x: cos(angle) * r, y: sin(angle) * r)
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }

    static func triangle(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> CGPath {
        let path = CGMutablePath()
        path.addLines(between: [a, b, c])
        path.closeSubpath()
        return path
    }

    static func filled(_ path: CGPath, _ color: SKColor, stroke: SKColor = .clear, width: CGFloat = 0) -> SKShapeNode {
        let node = SKShapeNode(path: path)
        node.fillColor = color
        node.strokeColor = stroke
        node.lineWidth = width
        return node
    }

    static func circle(_ radius: CGFloat, _ color: SKColor, at point: CGPoint = .zero) -> SKShapeNode {
        let node = SKShapeNode(circleOfRadius: radius)
        node.fillColor = color
        node.strokeColor = .clear
        node.position = point
        return node
    }
}

// MARK: - 怪物

enum EnemyArt {
    /// 身体的半宽、半高（缩放前）
    static func extent(of body: EnemyLook.Body) -> CGSize {
        switch body {
        case .blob: CGSize(width: 36, height: 32)
        case .ball: CGSize(width: 32, height: 32)
        case .tall: CGSize(width: 28, height: 40)
        case .cloud: CGSize(width: 40, height: 30)
        case .spiky: CGSize(width: 36, height: 36)
        }
    }

    static func body(_ look: EnemyLook) -> SKShapeNode {
        let e = extent(of: look.body)
        let path: CGPath = switch look.body {
        case .blob, .ball, .tall:
            CGPath(ellipseIn: CGRect(x: -e.width, y: -e.height, width: e.width * 2, height: e.height * 2), transform: nil)
        case .cloud:
            // 上半边鼓起几个包
            Shapes.radial(rx: e.width, ry: e.height) { a in sin(a) > 0 ? 0.92 + 0.12 * abs(sin(a * 3)) : 0.95 }
        case .spiky:
            Shapes.star(points: 9, outer: e.width, inner: e.width * 0.78)
        }
        return Shapes.filled(path, look.color.fill, stroke: look.color == .ink ? .clear : look.color.dark, width: 3)
    }

    static func eyes(_ look: EnemyLook) -> SKNode {
        let e = extent(of: look.body)
        let node = SKNode()
        let y = e.height * 0.38
        switch look.eyes {
        case .pair:
            for x in [-e.width * 0.38, e.width * 0.34] {
                node.addChild(eyeball(radius: 9, at: CGPoint(x: x, y: y), pupil: Palette.ink))
            }
        case .single:
            node.addChild(eyeball(radius: 14, at: CGPoint(x: -2, y: y), pupil: Palette.hurt))
        case .sleepy:
            for x in [-e.width * 0.35, e.width * 0.3] {
                let lid = CGMutablePath()
                lid.addArc(center: .zero, radius: 7, startAngle: .pi, endAngle: 0, clockwise: true)
                let shape = SKShapeNode(path: lid)
                shape.strokeColor = Palette.ink
                shape.lineWidth = 3
                shape.lineCap = .round
                shape.position = CGPoint(x: x, y: y)
                node.addChild(shape)
            }
        }
        return node
    }

    private static func eyeball(radius: CGFloat, at point: CGPoint, pupil: SKColor) -> SKNode {
        let eye = Shapes.circle(radius, .white, at: point)
        // 瞳孔往左看，盯着书
        eye.addChild(Shapes.circle(radius * 0.45, pupil, at: CGPoint(x: -radius * 0.33, y: 0)))
        return eye
    }

    static func accessory(_ look: EnemyLook) -> SKNode? {
        let e = extent(of: look.body)
        let top = e.height
        switch look.accessory {
        case .none:
            return nil
        case .sprout:
            let node = SKNode()
            let stem = SKShapeNode(rect: CGRect(x: -1.5, y: top - 4, width: 3, height: 14))
            stem.fillColor = UnitColor.moss.dark
            stem.strokeColor = .clear
            node.addChild(stem)
            for side in [-1.0, 1.0] {
                let leaf = SKShapeNode(ellipseOf: CGSize(width: 14, height: 7))
                leaf.fillColor = UnitColor.moss.fill
                leaf.strokeColor = .clear
                leaf.position = CGPoint(x: side * 7, y: top + 10)
                leaf.zRotation = side * 0.4
                node.addChild(leaf)
            }
            return node
        case .horns:
            let node = SKNode()
            for side in [-1.0, 1.0] {
                let x = side * e.width * 0.5
                node.addChild(Shapes.filled(
                    Shapes.triangle(CGPoint(x: x - 7, y: top - 8), CGPoint(x: x + 7, y: top - 8), CGPoint(x: x + side * 5, y: top + 12)),
                    look.color.dark))
            }
            return node
        case .helmet:
            let path = CGMutablePath()
            path.addArc(center: CGPoint(x: 0, y: top * 0.45), radius: e.width * 0.95, startAngle: 0.2, endAngle: .pi - 0.2, clockwise: false)
            path.closeSubpath()
            let helmet = Shapes.filled(path, SKColor(white: 0.62, alpha: 1), stroke: SKColor(white: 0.4, alpha: 1), width: 3)
            helmet.addChild(Shapes.circle(4, SKColor(white: 0.85, alpha: 1), at: CGPoint(x: 0, y: top * 0.45 + e.width * 0.75)))
            return helmet
        case .crown:
            let w = e.width * 0.75
            let path = CGMutablePath()
            path.addLines(between: [
                CGPoint(x: -w, y: top - 6), CGPoint(x: -w, y: top + 14), CGPoint(x: -w / 2, y: top + 4),
                CGPoint(x: 0, y: top + 20), CGPoint(x: w / 2, y: top + 4), CGPoint(x: w, y: top + 14), CGPoint(x: w, y: top - 6),
            ])
            path.closeSubpath()
            return Shapes.filled(path, Palette.bullet, stroke: Palette.target, width: 2)
        }
    }
}

// MARK: - 字灵

enum DefenderArt {
    static func body(_ look: DefenderLook, radius r: CGFloat) -> SKShapeNode {
        let path: CGPath = switch look.body {
        case .round:
            CGPath(ellipseIn: CGRect(x: -r, y: -r, width: r * 2, height: r * 2), transform: nil)
        case .drop:
            // 尖头朝上的水滴
            Shapes.radial(rx: r, ry: r) { a in
                let up = max(0, sin(a))
                return 1 + 0.45 * pow(up, 8)
            }
        case .seal:
            CGPath(roundedRect: CGRect(x: -r * 0.9, y: -r * 0.9, width: r * 1.8, height: r * 1.8),
                   cornerWidth: r * 0.35, cornerHeight: r * 0.35, transform: nil)
        }
        return Shapes.filled(path, look.color.fill, stroke: look.color.dark, width: 3)
    }

    static func eyes(radius r: CGFloat) -> SKNode {
        let node = SKNode()
        for x in [-r * 0.05, r * 0.38] {
            let eye = Shapes.circle(r * 0.16, .white, at: CGPoint(x: x, y: r * 0.25))
            // 往右看，盯着怪物
            eye.addChild(Shapes.circle(r * 0.08, Palette.ink, at: CGPoint(x: r * 0.05, y: 0)))
            node.addChild(eye)
        }
        return node
    }

    static func accessory(_ look: DefenderLook, radius r: CGFloat) -> SKNode? {
        switch look.accessory {
        case .none:
            return nil
        case .brush:
            let brush = SKShapeNode(rect: CGRect(x: r * 0.6, y: -r * 0.12, width: r * 0.8, height: r * 0.24), cornerRadius: 4)
            brush.fillColor = Palette.shelf
            brush.strokeColor = .clear
            let tip = Shapes.filled(
                Shapes.triangle(CGPoint(x: r * 1.4, y: -r * 0.14), CGPoint(x: r * 1.4, y: r * 0.14), CGPoint(x: r * 1.7, y: 0)),
                Palette.ink)
            brush.addChild(tip)
            return brush
        case .scholarHat:
            let hat = SKShapeNode(rect: CGRect(x: -r * 0.7, y: r * 0.75, width: r * 1.4, height: r * 0.4), cornerRadius: 3)
            hat.fillColor = Palette.ink
            hat.strokeColor = .clear
            let brim = SKShapeNode(rect: CGRect(x: -r * 0.95, y: r * 0.7, width: r * 1.9, height: r * 0.12))
            brim.fillColor = Palette.ink
            brim.strokeColor = .clear
            hat.addChild(brim)
            return hat
        case .bow:
            let node = SKNode()
            for side in [-1.0, 1.0] {
                node.addChild(Shapes.filled(
                    Shapes.triangle(CGPoint(x: 0, y: r * 0.95), CGPoint(x: side * r * 0.5, y: r * 1.2), CGPoint(x: side * r * 0.5, y: r * 0.7)),
                    Palette.hurt))
            }
            node.addChild(Shapes.circle(r * 0.1, Palette.hurt, at: CGPoint(x: 0, y: r * 0.95)))
            return node
        case .leaf:
            let leaf = SKShapeNode(ellipseOf: CGSize(width: r * 0.8, height: r * 0.35))
            leaf.fillColor = UnitColor.moss.dark
            leaf.strokeColor = .clear
            leaf.position = CGPoint(x: r * 0.2, y: r * 1.05)
            leaf.zRotation = 0.5
            return leaf
        }
    }
}

// MARK: - 子弹

enum ProjectileArt {
    static func make(_ look: ProjectileLook) -> SKShapeNode {
        let r = CGFloat(look.size)
        let node: SKShapeNode
        switch look.shape {
        case .orb:
            node = Shapes.filled(CGPath(ellipseIn: CGRect(x: -r, y: -r, width: r * 2, height: r * 2), transform: nil),
                                 look.color.fill, stroke: look.color.dark, width: 3)
            node.glowWidth = 4
        case .star:
            node = Shapes.filled(Shapes.star(points: 5, outer: r, inner: r * 0.45), look.color.fill, stroke: Palette.target, width: 2)
            node.run(.repeatForever(.rotate(byAngle: -.pi * 2, duration: 0.5)))
        case .snowflake:
            node = Shapes.filled(Shapes.star(points: 6, outer: r, inner: r * 0.35), .white, stroke: look.color.fill, width: 3)
            node.glowWidth = 3
            node.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 0.8)))
        case .petal:
            node = Shapes.filled(CGPath(ellipseIn: CGRect(x: -r * 1.4, y: -r * 0.5, width: r * 2.8, height: r), transform: nil),
                                 look.color.fill, stroke: look.color.dark, width: 2)
        case .heart:
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: -r))
            path.addCurve(to: CGPoint(x: 0, y: r * 0.45), control1: CGPoint(x: r * 1.5, y: -r * 0.1), control2: CGPoint(x: r * 0.6, y: r * 1.2))
            path.addCurve(to: CGPoint(x: 0, y: -r), control1: CGPoint(x: -r * 0.6, y: r * 1.2), control2: CGPoint(x: -r * 1.5, y: -r * 0.1))
            node = Shapes.filled(path, look.color.fill, stroke: .white, width: 2)
            node.glowWidth = 3
            node.run(.repeatForever(.sequence([.scale(to: 1.2, duration: 0.15), .scale(to: 1, duration: 0.15)])))
        case .gem:
            let path = CGMutablePath()
            path.addLines(between: [CGPoint(x: 0, y: r), CGPoint(x: r * 0.8, y: 0), CGPoint(x: 0, y: -r), CGPoint(x: -r * 0.8, y: 0)])
            path.closeSubpath()
            node = Shapes.filled(path, look.color.fill, stroke: .white, width: 2)
            node.glowWidth = 5
            node.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 0.6)))
        }
        return node
    }
}
