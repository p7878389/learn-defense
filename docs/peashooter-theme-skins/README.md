# 四款射手主题皮肤

沿用 codex/defender-theme-skins，在 5843c55 的资源皮肤链路上继续制作。设计依据：[概念档案](../skin-designs/peashooter-skin-design.json)。

## 游戏入口

收藏馆 → 射手皮肤 → 豌豆射手 → 翡翠星使 / 星轨术士 / 霜晶骑士 / 花火游侠 → 装备。四款等级 1 免费，装备后下局生效，可随时切回原版。卡牌、拖动预览和收藏头像使用同一组装造型，试穿播放真实战斗节点。

| 皮肤 | 本体与动作 | 弹体与特效 |
| --- | --- | --- |
| 翡翠星使 | 金边叶冠、琥珀种子、固定三颗种子光；头部轻浮与回弹 | 绿色实体豌豆、翡翠金色双尾、四瓣星核、月桂光冠 |
| 星轨术士 | 紫蓝星纹、弯月、金色轨道与叶披风；较慢聚能回落 | 带金环的紫色星珠、细双尾、旋转星门、星座碎光 |
| 霜晶骑士 | 冰蓝晶冠、透明冰叶；短促结晶脉冲与后坐 | 多面冰种、双短残影、六瓣霜纹、晶冠碎裂 |
| 花火游侠 | 红金花冠、流苏与叶片纹样；摆动与较大回弹 | 琥珀实体豌豆、红金双尾、花形礼花、双层花瓣退场 |

仅豌豆射手使用这些皮肤，其他角色/僵尸及缺少本体资源时回退原版。独立装备的子弹外观优先。皮肤不改变伤害、射速、奖励或附加效果；霜晶骑士不会增加减速。主题退场用于守卫被啃碎，怪物击败仍由玩家的击败外观槽决定。

## 美术与资源

采用内置 ImageGen，参考项目已有概念图；[完整提示词](prompts.json) 随原始 PNG 保留。没有导入 Pinterest 图片。每份图集包含独立头部、茎叶、弹体、出膛、命中和退场，避免用完整静态贴图拉伸模拟所有动作。

离线切片保留真实 alpha，最大边 384px；256px 头像按相同本体坐标合成，贴图 linear 过滤。花火图集头部超出等分网格，使用实测 550px 留白分界切片，避免切断嘴环并混入茎叶。头部、茎叶独立校准，muzzle 随头部动作换算位置。所有动作事件有绝对恢复终态，一次性特效自动移除。

运行资源使用 Emerald / Astral / Frost / Festival 前缀；每款 7 张 PNG 和 Body / Projectile / Muzzle / Impact / Defeat 五类 SKS。翡翠种子光复用已有 SpellbookStar 贴图。动作追加到 CombatActions.sks，保留已有皮肤命名动作。

## 复现

在本 worktree 根目录执行：

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift scripts/build-peashooter-skins.swift
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test --package-path Packages/LearnKit --filter 'ThemeSkinTests|ThemeSkinCatalogTests|PlantThemeSkinTests'
LEARN_THEME_PREVIEW="$PWD/docs/peashooter-theme-skins" DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test --package-path Packages/LearnKit --filter ThemeSkinTests.renderRuntime
```

生成脚本只在离线制作时使用，游戏与构建均不请求 ImageGen。主题测试还覆盖机甲、茶壶，因此运行导出命令会附带它们的回归画面。逐帧目录和预览 GIF/MP4 不纳入 Git。

## 验收

- 全套 Swift 测试通过：LearnGameTests 174 项、LearnCoreTests 143 项，共 317 项。原有参数化测试扩展至六款主题，另新增霜晶外观不减速回归。
- 先验证四款缺失时测试失败，再扩展注册与资源。装备与存档、恢复原版、其他角色回退、独立子弹外观优先、真实枪口位置、重复动作与受伤打断恢复、暂停像素稳定、命中/击败结算、预览四边界及特效清理均通过。
- 四款各导出 4 秒真实 GameScene 战斗和 3.5 秒收藏试穿，使用 Metal/SKRenderer 真实推进动画。目检后清理翡翠背景残影、校准花火切片与茎叶连接，最终全套测试及渲染重新通过。
- 28 张 PNG 的 alpha 与尺寸检查通过，20 个 SKS 经实际加载与渲染验证；48 个新资源共 3,678,295 字节，不含共享动作库。最终 iOS 模拟器 SDK 构建成功，逐一校验了 App 包内资源与清单 SHA-256 一致。
- GitNexus detect_changes(all)：26 个变更符号、1 条影响流程，medium，无 partial/truncated；覆盖 10 个已跟踪文件。新增生成脚本、测试及资源另用源码、透明度/打包检查与真实运行补查。索引流程枚举本身存在预算截断，因此图结果不代表全部运行路径。
- git diff --check 通过。未新增依赖，未提交、推送或合并。本机没有可用的 iPad 模拟器运行时，未做 iPad 真机性能验证。

## 运行预览

[收藏试穿对照](collection-preview.gif)：上排翡翠、星轨，下排霜晶、花火。

战斗录像：[翡翠](emerald.mp4)、[星轨](astral.mp4)、[霜晶](frost.mp4)、[花火](festival.mp4)。
