# 雷霆小机甲与云游茶壶

续改分支：`codex/defender-theme-skins`。设计依据：`../skin-designs/defender-concept-design.json`。

## 使用

收藏馆 → 射手皮肤 → 豌豆射手 → 雷霆小机甲 / 云游茶壶 → 装备，下局生效。两款均等级 1 免费；原版射手可随时恢复。试穿使用真实战斗节点，不写入装备。

- 雷霆小机甲：乳白钴蓝装甲、铜线圈、独立炮臂后坐、青白电浆、六边电弧命中。
- 云游茶壶：青瓷金边、独立壶盖跳动、壶身倾斜、茶叶水珠、水环命中及莲花退场。
- 仅替换豌豆射手外观；不会增加雷击、减速、伤害或射速。其他角色或本体资源加载失败沿用原版。
- 独立选择的子弹外观优先于主题弹；原版豌豆使用完整主题弹道。僵尸击败效果沿用玩家的击败外观槽；莲花/电弧退场用于守卫被啃碎。

## 素材与复现

原图由内置 ImageGen 参照已确认的概念图生成；不直接使用 Pinterest 图片。`*-source.png` 为原始透明图集，[prompts.json](prompts.json) 保存生成与透明背景修正提示词。每份图集按 3×2 切出本体、活动部件、弹体、出膛、命中、退场。透明边界裁切和等比缩放保留 alpha。运行 PNG 最大边 384，头像 256；贴图使用现有 FXLibrary 的 linear 过滤。

在 worktree 根目录执行：

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift scripts/build-theme-skins.swift
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test --package-path Packages/LearnKit --filter 'ThemeSkinTests|ThemeSkinCatalogTests|SpellbookSkinTests'
LEARN_THEME_PREVIEW="$PWD/docs/defender-theme-skins" DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test --package-path Packages/LearnKit --filter ThemeSkinTests
```

生成脚本只负责离线导入；构建和运行不需要 ImageGen。SKS 使用 metadata 引用外部 PNG 与 CombatActions 命名动作。两款各自 referenceRadius=34，muzzle 独立节点跟随炮臂或壶身，逻辑坐标不随动画移动。

## 验证记录

- 完整 Swift 测试通过：LearnGameTests 173 项、LearnCoreTests 143 项，共 316 项。新增 4 项参数化游戏测试与 1 项装备测试。
- 装备序列化、切回原版、其他角色/僵尸回退、独立子弹优先、枪口坐标、受伤后射击姿态恢复、伤害与击败单次结算、暂停像素稳定、试穿四边界及节点清理均通过。
- 两款各导出 4 秒真实 GameScene 战斗与 3.5 秒真实收藏试穿，由 Metal/SKRenderer 推进动作。目检后调整茶壶壶盖位置，最终完整测试和渲染再次通过。
- 14 张 PNG 通过尺寸和透明度检查，10 个 SKS 通过实际加载及渲染；运行素材共 1,909,225 字节（不含共享动作库）。茶壶第一版因半透明背景未通过，使用内置 ImageGen 修正后才入库。
- iOS 模拟器 SDK 最终构建成功，确认资源进入打包目录。本机没有可用模拟器设备，尚未验证 iPad 真机性能。
- GitNexus detect_changes(all)：39 个变更符号、19 条影响流程，风险 critical，主要来自共享 DefenderNode / ShotAttack / 收藏预览。图分析只覆盖已跟踪差异；新增适配器、测试、生成脚本与 PNG/SKS 另以代码审查、资源检查及真实运行测试补充。
- git diff --check 通过；未新增依赖、未提交、未推送、未合并。主检出已有修改保持原样；项目无 .trellis。

## 本地预览

- [收藏试穿对照](collection-preview.gif)：左机甲，右茶壶。
- [机甲战斗](mecha.mp4)、[茶壶战斗](teapot.mp4)。
- mecha/、teapot/ 为真实引擎 PNG 帧；预览录像与逐帧目录不纳入 Git，可通过上述测试重新生成。
