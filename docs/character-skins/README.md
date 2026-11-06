# 角色动画皮肤

当前范围：豌豆射手 `inkling`、普通僵尸 `blob`。两套原创装备主题：软糖派对、像素方块；另有三套整株重画的射手皮肤：竹筒小侠、方块工匠（方块体素风）、弹弹蛋（果冻蛋派对风）。每个角色在收藏馆中独立试穿、装备、恢复原版，首次进入即可免费使用。其他植物、带防具的僵尸保持原有外观。

## 设计约束

- 使用原角色序列帧作为底图，逐帧保留原始 alpha，包括半透明边缘。黑轮廓状态与原图逐像素一致。
- 豌豆射手保留绿色头部、炮嘴和叶子；以主题头盔或方块护额作为主要识别物。像素处理只限装备和衣服材质，不改变角色剪影。
- 僵尸保留头脸、牙齿、裤子与轮廓，以夹克材质和头部配件区分主题。
- 整株重画的皮肤不读取原图像素，共用 `scripts/character_skin_art.py` 的画笔与对齐约定，各自一个绘制模块，在 `generate-character-skins.py` 的 `REDRAWN` 中注册：
  - 竹筒小侠 `bamboo`（`character_skin_bamboo.py`）：竹筒身体、红头带、竹枝炮管；呼吸、叶片摆动。
  - 方块工匠 `voxel`（`character_skin_voxel.py`）：立体方块脑袋、阶梯叶子、方形炮管、砖陶花盆；脑袋按整格跳动。
  - 弹弹蛋 `egg`（`character_skin_egg.py`）：薄荷色果冻蛋、头顶豆苗、彩条喇叭炮口；挤压弹跳。
  - 三套都是 13 帧待机，第 9、10 帧眨眼；画布放大 3 倍（213×213）更清晰，crop、muzzle 按同倍数换算，战场占位和子弹出口与原版一致。只有射手，僵尸配它们时回退原版。
  - 方块、果冻蛋只借用画风，不使用其他游戏的角色、名称、标志或标志性造型。新增一套：写一个含 `draw_frame(index)` 与 `manifest()` 的模块，注册进 `REDRAWN`，再在 `CharacterSkin` 和 `cosmetics.json` 加对应项。
- 普通射击反馈保持绿色，皮肤不改变攻击属性；发射闪光在 0.16 秒后清理。
- 每个角色固定 6 片装饰，随父节点清理；僵尸冰冻时暂停，解冻时恢复。
- 沿用项目 SpriteKit 与原有序列帧资源；未引入 ParticleFX 依赖或外部图集。

## 查看

- `index.html`：自包含互动对比页，可离线打开，切换待机、发射/啃咬、掉头倒下、烧焦和暂停。
- `comparison.gif`：原版、两套装备与三套重画皮肤的资源动画对比。
- `runtime.gif` / `runtime.png`：实际 SpriteKit 渲染，包含题牌、角色缩放、装饰粒子和攻击动作。
- App：孩子主页 → 收藏馆 → 射手皮肤 / 僵尸皮肤。点卡片先试看，点装备后下局生效。

## 生成与验证

```bash
python3 scripts/generate-character-skins.py
python3 scripts/test_character_skins.py
```

脚本输出 235 张透明 PNG、15 段动画到 `Resources/Sprites/skin-*`（其中三套重画皮肤各 13 张），独立清单 `skins.json` 和 SHA-256 校验表 `skins-sha256.json`；原图与 `clips.json` 不变。装备类动画保留原始帧数、速度、crop、canvas、pivot 和 muzzle；重画皮肤保留帧数、速度，crop 与 muzzle 按 3 倍换算。缺失整套皮肤资源时回退原版。

```bash
cd Packages/LearnKit
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

设置 `LEARN_DEFENSE_SKIN_PREVIEW` 为本目录的绝对路径，再运行 `swift test --filter CharacterSkinAnimationTests`，即可重新导出 SpriteKit 动图。iOS 可用通用模拟器目标构建；本机没有安装 iOS 模拟器运行时，尚未执行 iPad 模拟器交互验收。

## 素材来源

原始植物与僵尸帧来自项目已有的 pypvz 素材，来源版本和使用范围见 `Packages/LearnKit/Sources/LearnGame/Resources/Sprites/SOURCE.md`。新装备由本项目脚本衍生绘制；三套重画皮肤为本项目原创绘制，不含原作像素；不将原始角色素材标记为 CC0。Stitch 项目 `3114158888309762861` 的生成请求遇到连接错误，本次交付不依赖其输出。
