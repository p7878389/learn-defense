# 星轨魔导书 · 实装与验收

## 使用入口

收藏馆 → 射手皮肤 → 豌豆射手 → **星轨魔导书** → 装备。等级 1 免费可用，装备后下局生效；选择原版射手即可恢复。只替换 inkling 的表现，不改变其战斗数值。

收藏卡、种植卡、拖动预览使用新的书本头像。试穿舞台会自动展示真实翻页、星珠发射和命中；试穿不会写入装备。

单独装备冰晶弹、金星弹、花瓣弹等子弹外观时，优先保留这些外观。选择“原版豌豆”时，魔导书自动使用完整星珠主题。

## 资源与实现

- `SpellbookBody.sks`：悬浮根节点、caster、书身、左右独立页片、星轨与 muzzle 发射点。
- `SpellbookProjectile.sks`：星珠和双尾迹，随弹体生命周期结束。
- `SpellbookMuzzle.sks`、`SpellbookImpact.sks`：局部出膛弧和星门命中。
- `CombatActions.sks`：追加魔导书命名动作，布局、角度、缩放和节奏由资源维护。
- `SpellbookSkin` 只负责皮肤适配；FXLibrary 根据 action / shootAction / hurtAction 元数据播放，事件结束恢复待机。
- 发射点使用实际节点坐标换算，书本发射时后坐但不移动逻辑位置。
- 本体资源不可用则保持原角色和攻击策略；其他射手及僵尸使用这项皮肤时回退原版。

图片来源：内置 ImageGen，使用已确认的魔导书概念为参考，生成书身/页片/星珠及六件特效素材。原始图、提示词、规范化尺寸和 alpha 检查记录在本目录。资源路径在 `Sources/LearnGame/Resources/Effects/`，不会在构建时重新生成。

## 复现测试和录像

在 worktree 的 `Packages/LearnKit` 下执行：

```sh
LEARN_SPELLBOOK_PREVIEW="$PWD/../../docs/spellbook-skin" \
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun swift test --filter 'SpellbookSkinTests|SpellbookCatalogTests'
```

完整测试使用同一 Xcode 环境运行 `xcrun swift test`。`frames/` 来自真实 `GameScene.fire`，`preview-frames/` 来自真实收藏馆试穿场景；均由 Metal / SKRenderer 实际推进动画，不使用网页替身。

## 验收记录

- 全套 Swift 测试通过：LearnGameTests 169 项、LearnCoreTests 142 项，共 311 项。包含本次新增的 9 项游戏测试和 1 项装备存档测试。
- 真引擎导出通过：7 秒战斗、4 秒收藏试穿；两次答对各扣 1 血、击败只结算一次，星珠与命中节点正常清理。
- 独立子弹外观、原版恢复、其他角色回退、部件重复动作、真实发射点和暂停像素稳定性通过。
- 目检发现收藏舞台左侧裁切，先通过动态边界测试复现再调整；独立审查发现 hurt→shoot 打断造成缩放残留，先复现再仅修改 BookRecoil 资源收尾恢复 scale 1，复审确认关闭。
- iOS SDK 构建首次遇到 CGPoint/CGRect 的 `.zero` 重载歧义，已明确为 `CGPoint.zero`；最终构建成功。类型修正后的 9 项游戏定向测试再次通过。
- 10 张透明纹理通过尺寸和 alpha 检查，原比例/试看放大画面已目检。没有新增依赖。
- `git diff --check` 通过。GitNexus detect_changes(all) 报 36 个变更符号、13 条影响流程、high；覆盖 10 个已跟踪文件。未跟踪的新适配器、测试和 SKS/PNG 资源另由源码审查、资源解档和运行测试覆盖，不将图结果视作完整运行证明。
- 本机无可用 iPad 模拟器运行时，因此 iOS SDK 构建和 macOS 实际渲染不等同于 iPad 真机性能验证。
- 开发分支 `codex/defender-theme-skins`，基于 `e07ca11`，本轮未提交、推送或合并。

## 本地运行产物

- `runtime.gif` / `runtime.mp4`：真实战斗。
- `collection-preview.gif`：真实收藏馆试穿场景。
- `frames/` / `preview-frames/`：原始引擎渲染帧，可由上述命令重新生成，不纳入版本控制。
