// 从透明 ImageGen 图集构建运行资源；在仓库根目录用 Xcode Swift 运行。
import AppKit
import ImageIO
import SpriteKit

let repo = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let output = repo.appendingPathComponent("Packages/LearnKit/Sources/LearnGame/Resources/Effects")
let docs = repo.appendingPathComponent("docs/defender-theme-skins")
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
    let w = source.width / 3, h = source.height / 2
    let cell = source.cropping(to: CGRect(x: index % 3 * w, y: index / 3 * h, width: w, height: h))!
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
    report.append(["name": name,"width": cw,"height": ch,"sourceCell": index,"transparentPixels": transparent])
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

// 名称稳定；动作结束显式恢复姿态，允许 hurt/shoot 互相打断。
actions["ThemeHurt"] = sequence(.scale(to: 0.9,duration: 0.06),.scale(to: 1,duration: 0.18))
actions["ThemeRecoil"] = sequence(.group([.moveTo(x: -3,duration: 0.06),.rotate(toAngle: 0.05,duration: 0.06)]),
                                  .group([.moveTo(x: 0,duration: 0.24),.rotate(toAngle: 0,duration: 0.24),.scale(to: 1,duration: 0.24)]))
actions["TeaTilt"] = sequence(.rotate(toAngle: -0.09,duration: 0.1),
                               .group([.rotate(toAngle: 0,duration: 0.3),.scale(to: 1,duration: 0.3)]))
actions["MechaArm"] = sequence(.moveTo(x: 16,duration: 0.06),.moveTo(x: 23,duration: 0.23))
actions["TeaLid"] = sequence(.moveTo(y: 37,duration: 0.1),.moveTo(y: 32,duration: 0.3))
actions["TeaFloat"] = .repeatForever(sequence(.moveTo(y: 2,duration: 0.9),.moveTo(y: -1,duration: 0.9)))
actions["ThemePulse"] = .repeatForever(sequence(.fadeAlpha(to: 0.7,duration: 0.3),.fadeAlpha(to: 1,duration: 0.3)))
actions["ThemeMuzzle"] = sequence(.group([.scale(to: 1.4,duration: 0.22),.fadeOut(withDuration: 0.22)]),.removeFromParent())
actions["ThemeImpact"] = sequence(.scale(to: 0.45,duration: 0),.group([.scale(to: 1.25,duration: 0.38),.fadeOut(withDuration: 0.38)]),.removeFromParent())
actions["ThemeDefeat"] = sequence(.scale(to: 0.4,duration: 0),.group([.scale(to: 1.3,duration: 0.6),.fadeOut(withDuration: 0.6),.rotate(byAngle: 0.2,duration: 0.6)]),.removeFromParent())

for (id,prefix) in [("mecha","Mecha"),("teapot","Teapot")] {
    let sourceURL = docs.appendingPathComponent(id + "-source.png")
    guard FileManager.default.fileExists(atPath: sourceURL.path) else { continue }
    let source = CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithURL(sourceURL as CFURL,nil)!,0,nil)!
    let suffixes = ["Shell","Part","Bolt","Puff","Ring","Bloom"]
    let images = suffixes.enumerated().map { slice(source,index: $0.offset,name: prefix + $0.element) }
    let root = SKNode();metadata(root,["referenceRadius": 34])
    let float = SKNode();root.addChild(float)
    if id == "teapot" { metadata(float,["action": "TeaFloat"]) }
    let caster = SKNode();caster.name = "caster";float.addChild(caster)
    metadata(caster,["shootAction": id == "mecha" ? "ThemeRecoil" : "TeaTilt","hurtAction": "ThemeHurt"])
    let shell = sprite(prefix+"Shell",images[0],width: id == "mecha" ? 57 : 75,name: "shell")
    shell.position = CGPoint(x: id == "mecha" ? -8 : 0,y: id == "mecha" ? 0 : -3)
    caster.addChild(shell)
    let part = SKNode();part.name = "movingPart";caster.addChild(part)
    part.position = id == "mecha" ? CGPoint(x: 23,y: 4) : CGPoint(x: 0,y: 32)
    metadata(part,["shootAction": id == "mecha" ? "MechaArm" : "TeaLid"])
    let artwork = sprite(prefix+"Part",images[1],width: 32,name: "partArtwork")
    part.addChild(artwork)
    let muzzle = SKNode();muzzle.name = "muzzle"
    if id == "mecha" { muzzle.position = CGPoint(x: 15,y: 0);part.addChild(muzzle) }
    else { muzzle.position = CGPoint(x: 34,y: 10);caster.addChild(muzzle) }
    try save(root,name: prefix+"Body")
    for (suffix,index,width,action) in [("Projectile",2,CGFloat(47),"ThemePulse"),("Muzzle",3,CGFloat(30),"ThemeMuzzle"),
                                      ("Impact",4,CGFloat(63),"ThemeImpact"),("Defeat",5,CGFloat(76),"ThemeDefeat")] {
        let effect = SKNode();metadata(effect,["action": action]);effect.zPosition = 52
        let art = sprite(prefix+suffixes[index],images[index],width: width,name: "artwork")
        // 发射坐标/碰撞点对应弹体亮核，而不是尾迹中心。
        if suffix == "Projectile" { art.position.x = -width*0.27 }
        effect.addChild(art);try save(effect,name: prefix+suffix)
    }
    // 卡牌头像按本体相同坐标组装；256px 只影响静态预览，不作为战斗贴图。
    let portrait = CGContext(data: nil,width: 256,height: 256,bitsPerComponent: 8,bytesPerRow: 0,
                             space: CGColorSpaceCreateDeviceRGB(),bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    portrait.translateBy(x: 128,y: 128);portrait.scaleBy(x: 2.6,y: 2.6)
    for (node,image,position) in [(shell,images[0],shell.position),(artwork,images[1],part.position)] {
        portrait.draw(image,in: CGRect(x: position.x-node.size.width/2,y: position.y-node.size.height/2,
                                       width: node.size.width,height: node.size.height))
    }
    writePNG(portrait.makeImage()!,prefix+"Portrait")
}
var updated = archive;updated["actions"] = actions
try NSKeyedArchiver.archivedData(withRootObject: updated,requiringSecureCoding: false).write(to: actionURL)
try JSONSerialization.data(withJSONObject: report,options: [.prettyPrinted,.sortedKeys])
    .write(to: docs.appendingPathComponent("asset-report.json"))
print("Built \(report.count) textures; named actions: \(actions.count)")
