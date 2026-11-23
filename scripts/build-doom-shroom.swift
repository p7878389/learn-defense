// 离线资源导入：只切片、规范化与归档；运行时直接读取可维护的 .sks。
import AppKit
import ImageIO
import SpriteKit

let repo = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let docs = repo.appendingPathComponent("docs/doom-shroom")
let output = repo.appendingPathComponent("Packages/LearnKit/Sources/LearnGame/Resources/Effects")
let source = CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithURL(docs.appendingPathComponent("asset-source.png") as CFURL, nil)!, 0, nil)!
let boundaries = [0, 704, 1504, source.width]
var report: [[String: Any]] = []

func slice(_ index: Int, name: String, maxSize: CGFloat) -> CGSize {
    let w = boundaries[index + 1] - boundaries[index], h = source.height
    let crop = source.cropping(to: CGRect(x: boundaries[index], y: 0, width: w, height: h))!
    let context = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.draw(crop, in: CGRect(x: 0, y: 0, width: w, height: h))
    let pixels = context.data!.assumingMemoryBound(to: UInt8.self)
    var x0 = w, y0 = h, x1 = 0, y1 = 0, transparent = 0
    for y in 0..<h { for x in 0..<w {
        let alpha = pixels[(y * w + x) * 4 + 3]
        if alpha < 8 { transparent += 1 }
        if alpha > 16 { x0 = min(x0, x); y0 = min(y0, y); x1 = max(x1, x); y1 = max(y1, y) }
    } }
    precondition(transparent > w * h / 10 && x1 > x0 && y1 > y0)
    let left = max(0, x0 - 8), top = max(0, y0 - 8)
    let image = context.makeImage()!.cropping(to: CGRect(x: left, y: top,
        width: min(w - 1, x1 + 8) - left + 1, height: min(h - 1, y1 + 8) - top + 1))!
    let scale = min(1, maxSize / CGFloat(max(image.width, image.height)))
    let width = Int((CGFloat(image.width) * scale).rounded()), height = Int((CGFloat(image.height) * scale).rounded())
    let target = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                           space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    target.interpolationQuality = .high
    target.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    let destination = CGImageDestinationCreateWithURL(output.appendingPathComponent(name + ".png") as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, target.makeImage()!, nil)
    precondition(CGImageDestinationFinalize(destination))
    report.append(["name": name, "size": [width, height], "sourceRect": [boundaries[index], 0, w, h], "transparentPixels": transparent])
    return CGSize(width: width, height: height)
}

let bodySize = slice(0, name: "DoomBody", maxSize: 512)
let cloudSize = slice(1, name: "DoomCloud", maxSize: 768)
let craterSize = slice(2, name: "DoomCrater", maxSize: 256)
func metadata(_ node: SKNode, _ data: [String: Any]) { node.userData = NSMutableDictionary(dictionary: data) }
func sprite(_ name: String, size: CGSize, width: CGFloat) -> SKSpriteNode {
    let node = SKSpriteNode(color: .white, size: CGSize(width: width, height: width * size.height / size.width))
    node.name = name
    metadata(node, ["texture": name])
    return node
}
func save(_ node: SKNode, _ name: String) throws {
    try NSKeyedArchiver.archivedData(withRootObject: node, requiringSecureCoding: false)
        .write(to: output.appendingPathComponent(name + ".sks"))
}
let actionURL = output.appendingPathComponent("CombatActions.sks")
let decoder = try NSKeyedUnarchiver(forReadingFrom: Data(contentsOf: actionURL))
decoder.requiresSecureCoding = false
var archive = decoder.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as! [String: Any]
decoder.finishDecoding()
var actions = archive["actions"] as! [String: SKAction]
actions["DoomCharge"] = .sequence([.scale(to: 1, duration: 0), .scale(to: 1.25, duration: 1)])
actions["DoomBlastLife"] = .sequence([.wait(forDuration: 1.25), .removeFromParent()])
actions["DoomCloudPop"] = .sequence([.scale(to: 0.25, duration: 0), .fadeAlpha(to: 0.4, duration: 0),
    .group([.scale(to: 1, duration: 0.25), .fadeIn(withDuration: 0.15)]),
    .group([.scale(to: 1.15, duration: 0.9), .fadeOut(withDuration: 0.9)])])
actions["DoomWave"] = .sequence([.scale(to: 0.1, duration: 0),
    .group([.scale(to: 1, duration: 0.65), .fadeOut(withDuration: 0.75)])])

let body = SKNode()
let mushroom = sprite("DoomBody", size: bodySize, width: 82)
mushroom.position.y = -28
mushroom.anchorPoint = CGPoint(x: 0.5, y: 0)
metadata(mushroom, ["texture": "DoomBody", "armAction": "DoomCharge"])
body.addChild(mushroom)
try save(body, "DoomBody")

let crater = SKNode()
let hole = sprite("DoomCrater", size: craterSize, width: 78)
hole.position.y = -25
crater.addChild(hole)
try save(crater, "DoomCrater")

let blast = SKNode()
blast.zPosition = 60
metadata(blast, ["action": "DoomBlastLife"])
let cloud = sprite("DoomCloud", size: cloudSize, width: 310)
cloud.anchorPoint = CGPoint(x: 0.5, y: 0)
cloud.position.y = -30
metadata(cloud, ["texture": "DoomCloud", "action": "DoomCloudPop"])
blast.addChild(cloud)
let ring = SKSpriteNode(color: .systemPurple, size: CGSize(width: 583, height: 350))
ring.name = "shockwave"
ring.colorBlendFactor = 1
ring.zPosition = -1
metadata(ring, ["texture": "ShockRing", "action": "DoomWave"])
blast.addChild(ring)
try save(blast, "DoomExplosion")
archive["actions"] = actions
try NSKeyedArchiver.archivedData(withRootObject: archive, requiringSecureCoding: false).write(to: actionURL)
try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: docs.appendingPathComponent("asset-report.json"))
print("已导入毁灭菇三张透明纹理、三份 SKS 和四个命名动作")
