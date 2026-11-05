// swift-tools-version: 5.9
import PackageDescription

// LearnCore：题库、出题、学习记录等纯逻辑（不依赖界面，可在 macOS 上直接跑测试）
// LearnGame：SwiftUI 界面 + SpriteKit 游戏场景，iOS App 只引用这一个产品
let package = Package(
    name: "LearnKit",
    defaultLocalization: "zh-Hans",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "LearnCore", targets: ["LearnCore"]),
        .library(name: "LearnGame", targets: ["LearnGame"]),
    ],
    targets: [
        .target(
            name: "LearnCore",
            resources: [.copy("Resources/Packs")]
        ),
        .target(
            name: "LearnGame",
            dependencies: ["LearnCore"],
            // 3D 图片与植物/僵尸序列帧分别保存；来源及使用范围见各资源目录
            resources: [.copy("Resources/Pictures"), .copy("Resources/Sprites")]
        ),
        .testTarget(
            name: "LearnCoreTests",
            dependencies: ["LearnCore"]
        ),
        .testTarget(
            name: "LearnGameTests",
            dependencies: ["LearnGame"]
        ),
    ]
)
