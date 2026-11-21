// 从透明 ImageGen 图集构建运行资源；在仓库根目录用 Xcode Swift 运行。
import AppKit
import ImageIO
import SpriteKit

let repo = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let output = repo.appendingPathComponent("Packages/LearnKit/Sources/LearnGame/Resources/Effects")
let docs = repo.appendingPathComponent("docs/peashooter-theme-skins")
let actionURL = output.appendingPathComponent("CombatActions.sks")
let decoder = try NSKeyedUnarchiver(forReadingFrom: Data(contentsOf: actionURL))
decoder.requiresSecureCoding = false
let archive = decoder.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as! [String: Any]
decoder.finishDecoding()
var actions = archive["actions"] as! [String: SKAction]
var report: [[String: Any]] = []

func writePNG(_ image: CGImage, _ name: String) {
    let url = output.appendingPathComponent(name + ".png")
    let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    precondition(CGImageDestinationFinalize(dest))
}

// 仅执行确定性的网格切片、透明边界裁切与等比缩放，不重绘生成素材。
func slice(_ source: CGImage, index: Int, name: String) -> CGImage {
    let cellWidth = source.width / 3, h = source.height / 2
    // 花火头部的流苏与嘴环稍宽，按实测留白分界切片，避免等分网格截断嘴环。
    let isFestivalTop = name.hasPrefix("Festival") && index < 2
    let boundary = Int(CGFloat(source.width) * 550 / 1536)
    let x = isFestivalTop ? (index == 0 ? 0 : boundary) : index % 3 * cellWidth
    let w = isFestivalTop ? (index == 0 ? boundary : cellWidth * 2 - boundary) : cellWidth
    let cell = source.cropping(to: CGRect(x: x, y: index / 3 * h, width: w, height: h))!
    let ctx = CGContext(data: nil,width: w,height: h,bitsPerComponent: 8,bytesPerRow: w*4,
                        space: CGColorSpaceCreateDeviceRGB(),bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.draw(cell,in: CGRect(x: 0,y: 0,width: w,height: h))
    let data = ctx.data!.assumingMemoryBound(to: UInt8.self)
    var x0 = w, y0 = h, x1 = 0, y1 = 0, transparent = 0
    for y in 0..<h { for x in 0..<w {
        let a = data[(y*w+x)*4+3]
        if a < 8 { transparent += 1 }
        if a > 16 { x0 = min(x0,x);y0 = min(y0,y);x1 = max(x1,x);y1 = max(y1,y) }
    } }
    precondition(transparent > w*h/10 && x1>x0 && y1>y0, "需要真实透明素材")
    // CGContext 数据的第零行与生成 CGImage 裁切坐标一致。
    let rect = CGRect(x: max(0,x0-4),y: max(0,y0-4),width: min(w-1,x1+4)-max(0,x0-4)+1,
                      height: min(h-1,y1+4)-max(0,y0-4)+1)
    let cropped = ctx.makeImage()!.cropping(to: rect)!
    let scale = min(1,384/CGFloat(max(cropped.width,cropped.height)))
    let cw = Int((CGFloat(cropped.width)*scale).rounded()), ch = Int((CGFloat(cropped.height)*scale).rounded())
    let resized = CGContext(data: nil,width: cw,height: ch,bitsPerComponent: 8,bytesPerRow: 0,
                           space: CGColorSpaceCreateDeviceRGB(),bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    resized.interpolationQuality = .high
    resized.draw(cropped,in: CGRect(x: 0,y: 0,width: cw,height: ch))
    let image = resized.makeImage()!
    writePNG(image,name)
    report.append(["name": name,"width": cw,"height": ch,"sourceCell": index,"sourceRect": [x,index/3*h,w,h],"transparentPixels": transparent])
    return image
}

func save(_ node: SKNode, name: String) throws {
    try NSKeyedArchiver.archivedData(withRootObject: node,requiringSecureCoding: false)
        .write(to: output.appendingPathComponent(name + ".sks"))
}
func metadata(_ node: SKNode, _ values: [String: Any]) { node.userData = NSMutableDictionary(dictionary: values) }
func sprite(_ texture: String, _ image: CGImage, width: CGFloat, name: String) -> SKSpriteNode {
    let node = SKSpriteNode(color: .white,size: CGSize(width: width,height: width*CGFloat(image.height)/CGFloat(image.width)))
    node.name = name
    metadata(node,["texture": texture])
    return node
}
func sequence(_ actions: SKAction...) -> SKAction { .sequence(actions) }

// 头部绕同一连接点摆动；所有事件使用绝对终态，重复发射和受伤打断不会累积漂移。
actions["PlantRestore"] = .group([.scale(to: 1,duration: 0.16),.rotate(toAngle: 0,duration: 0.16)])
let themes: [(String,String,CGFloat,Double)] = [
    ("emerald","Emerald",4,0.30), ("astral","Astral",5,0.38),
    ("frost","Frost",2.5,0.24), ("festival","Festival",5,0.34)
]
for (id,prefix,recoil,recover) in themes {
    let sourceURL = docs.appendingPathComponent(id + "-source.png")
    guard FileManager.default.fileExists(atPath: sourceURL.path) else { continue }
    let source = CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithURL(sourceURL as CFURL,nil)!,0,nil)!
    let suffixes = ["Head","Base","Bolt","Puff","Ring","Bloom"]
    let images = suffixes.enumerated().map { slice(source,index: $0.offset,name: prefix + $0.element) }
    let idle: SKAction
    switch id {
    case "frost": idle = .repeatForever(sequence(.scaleY(to: 1.025,duration: 1.1),.scaleY(to: 1,duration: 1.1)))
    case "festival": idle = .repeatForever(sequence(.rotate(toAngle: 0.025,duration: 0.65),.rotate(toAngle: -0.025,duration: 0.65)))
    case "astral": idle = .repeatForever(sequence(.moveTo(y: 15.5,duration: 1.25),.moveTo(y: 14,duration: 1.25)))
    default: idle = .repeatForever(sequence(.moveTo(y: 15,duration: 0.9),.moveTo(y: 14,duration: 0.9)))
    }
    actions[prefix+"HeadIdle"] = idle
    actions[prefix+"HeadShoot"] = sequence(
        .group([.moveTo(x: -recoil,duration: 0.06),.rotate(toAngle: id == "frost" ? 0.025 : 0.07,duration: 0.06)]),
        .group([.moveTo(x: 0,duration: recover),.moveTo(y: 14,duration: recover),
                .rotate(toAngle: 0,duration: recover),.scale(to: 1,duration: recover)]))
    actions[prefix+"Flight"] = .repeatForever(sequence(.scaleY(to: id == "frost" ? 1.04 : 1.10,duration: 0.18),.scaleY(to: 1,duration: 0.18)))
    actions[prefix+"MuzzleLife"] = sequence(.group([.scale(to: 1.35,duration: 0.2),.fadeOut(withDuration: 0.2)]),.removeFromParent())
    actions[prefix+"ImpactLife"] = sequence(.scale(to: 0.45,duration: 0),
        .group([.scale(to: 1.15,duration: id == "frost" ? 0.30 : 0.42),.fadeOut(withDuration: 0.42),
                .rotate(byAngle: id == "astral" ? 0.45 : 0,duration: 0.42)]),.removeFromParent())
    actions[prefix+"DefeatLife"] = sequence(.scale(to: 0.4,duration: 0),
        .group([.scale(to: 1.15,duration: 0.65),.fadeOut(withDuration: 0.65),.moveBy(x: 0,y: 6,duration: 0.65)]),.removeFromParent())
    let root = SKNode();metadata(root,["referenceRadius": 34])
    let caster = SKNode();caster.name = "caster";root.addChild(caster)
    metadata(caster,["shootAction": "PlantRestore","hurtAction": "ThemeHurt"])
    let base = sprite(prefix+"Base",images[1],width: 51,name: "rootedLeaves")
    base.position = CGPoint(x: id == "festival" ? 6 : -4,y: id == "festival" ? -17 : -19);caster.addChild(base)
    let head = SKNode();head.name = "movingPart";head.position = CGPoint(x: 0,y: 14);caster.addChild(head)
    metadata(head,["action": prefix+"HeadIdle","shootAction": prefix+"HeadShoot"])
    let artwork = sprite(prefix+"Head",images[0],width: 64,name: "headArtwork");head.addChild(artwork)
    let muzzle = SKNode();muzzle.name = "muzzle";muzzle.position = CGPoint(x: 30,y: -6);head.addChild(muzzle)
    // 翡翠的三颗种子光使用已归档金色星点，数量固定，不持续生成节点。
    if id == "emerald" {
        actions["EmeraldSeedDrift"] = .repeatForever(sequence(.moveBy(x: 1,y: 3,duration: 0.8),.moveBy(x: -1,y: -3,duration: 0.8)))
        for (i,y) in [CGFloat(22),7,-8].enumerated() {
            let seed = SKSpriteNode(color: .white,size: CGSize(width: 5,height: 5))
            seed.name = "seedLight";seed.position = CGPoint(x: -29-CGFloat(i%2)*3,y: y);seed.zPosition = -0.1
            metadata(seed,["texture": "SpellbookStar","action": "EmeraldSeedDrift"]);caster.addChild(seed)
        }
    }
    try save(root,name: prefix+"Body")
    for (suffix,index,width,action) in [("Projectile",2,CGFloat(47),prefix+"Flight"),("Muzzle",3,CGFloat(28),prefix+"MuzzleLife"),
                                      ("Impact",4,CGFloat(60),prefix+"ImpactLife"),("Defeat",5,CGFloat(70),prefix+"DefeatLife")] {
        let effect = SKNode();metadata(effect,["action": action]);effect.zPosition = 52
        let art = sprite(prefix+suffixes[index],images[index],width: width,name: "artwork")
        if suffix == "Projectile" { art.position.x = -width*0.27 }
        effect.addChild(art);try save(effect,name: prefix+suffix)
    }
    let portrait = CGContext(data: nil,width: 256,height: 256,bitsPerComponent: 8,bytesPerRow: 0,
                             space: CGColorSpaceCreateDeviceRGB(),bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    portrait.translateBy(x: 128,y: 118);portrait.scaleBy(x: 2.5,y: 2.5)
    for (node,image,position) in [(base,images[1],base.position),(artwork,images[0],head.position)] {
        portrait.draw(image,in: CGRect(x: position.x-node.size.width/2,y: position.y-node.size.height/2,width: node.size.width,height: node.size.height))
    }
    writePNG(portrait.makeImage()!,prefix+"Portrait")
}
var updated = archive;updated["actions"] = actions
try NSKeyedArchiver.archivedData(withRootObject: updated,requiringSecureCoding: false).write(to: actionURL)
try JSONSerialization.data(withJSONObject: report,options: [.prettyPrinted,.sortedKeys]).write(to: docs.appendingPathComponent("asset-report.json"))
print("Built \(report.count) textures; named actions: \(actions.count)")
