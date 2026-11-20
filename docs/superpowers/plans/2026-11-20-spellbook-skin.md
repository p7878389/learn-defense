# 星轨魔导书皮肤 Implementation Plan

**Goal:** 完成用户选定的星轨魔导书，包含收藏装备、分层本体、翻页动作、星珠弹道、命中与实际预览。

**Architecture:** 复用已有装备位 `defenderSkin` 和 FXLibrary。新增场景型 SpellbookSkin，根节点/书身/左右书页/星轨/发射点由 `.sks` 定义；命名动作继续放 CombatActions.sks，代码只绑定事件与生命周期。仅豌豆射手 inkling 可用。

**Tech Stack:** Swift、SpriteKit、Swift Testing、Metal；无新增依赖。

**Spec:** 本会话已确认的三款概念图和魔导书六阶段分镜；用户明确本轮只完成魔导书。

## 设计与边界

- 沿用靛紫封面、金色包角、奶油书页、青蓝宝石和星轨。约 80pt 高度仍需可读。
- 用分层图和 `.sks` 部件动画实现翻页/后坐/回落，不把整个背景概念图放入游戏。
- 身体、左右活动书页、星珠和星门等纹理来自内置 ImageGen，复制原图与提示词，规范切片和 alpha 后导入。
- 皮肤免费、等级 1 可装备，沿用已有整株重画皮肤的可用策略；不增加属性收益。
- 默认普通弹使用星珠主题；装备独立子弹外观时优先保留其外观和效果。伤害、飞行时间、连发间隔和回调不变。
- 换回原版后本体、头像和默认弹体恢复；冰射手、杨桃、防御道具和僵尸不受影响。
- 默认击败演出维持已有战斗逻辑，星珠主题覆盖本体、发射、飞行、命中。机甲和茶壶不在本轮范围。
- 不自动提交、推送、合并；主仓库及旧任务保持原状。

## 资源结构

`Resources/Effects/SpellbookBody.sks`：effect 根节点包含 caster，caster 下有 body、左右页片、muzzle。根 userData.referenceRadius 用于尺寸适配。闲置动作在节点 action 元数据，发射/受击动作在 shootAction/hurtAction。

`SpellbookProjectile.sks`、`SpellbookMuzzle.sks`、`SpellbookImpact.sks`：星珠与金环、薄尾迹、出膛星芒、空心星门。一次性效果不超过现有清理窗口，飞行节点随弹体一起销毁。

`Spellbook*.png`：规范化透明纹理；`SpellbookPortrait.png` 提供收藏卡/种植卡第一帧。

## 实施任务

- [x] 先写可编译的失败测试：catalog 中能装备/持久化/复原；游戏出现新本体而非原版回退。
- [x] 制作分层素材与清单，写入资源型动作和布局；核对锚点、比例与实际发射位置。
- [x] 新增 `CharacterSkin.spellbook` 与目录条目，使用独立场景型标识；旧序列帧测试继续覆盖原皮肤，新的场景型行为由专门测试覆盖。
- [x] 扩展 FXLibrary 的通用资源挂载/事件动作方法，新增 `SpellbookSkin`；接入 DefenderNode、头像和攻击策略。
- [x] 收藏馆试穿舞台播放真实翻页、星珠与命中，装备仍下局生效。
- [x] 测试重复发射回正、不同实例隔离、暂停恢复、独立子弹优先、其他单位回退、一次答对一次扣血/结算。
- [x] 导出真实战斗/收藏预览，目检并调资源；完整 swift test、iOS SDK 构建、detect_changes 和 diff 检查。

## Review Focus

- 新枚举值不能导致旧存档/目录整体解码失败；原有装备保持有效。
- 场景型皮肤不能把全量枚举假定为序列帧皮肤；预览标签避免固定数组越界。
- 使用真实节点坐标换算发射点，不能遗留豌豆嘴坐标。
- 本体资源不可用时回退原版，攻击策略也相应回退。
- 高频发射的部件动作必须取消旧动作并恢复同一待机姿态，暂停时不提前完成或泄露节点。

## 验证命令

`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test`（Packages/LearnKit）。

`xcodebuild -project LearnDefense.xcodeproj -scheme LearnDefense -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`（带相同 DEVELOPER_DIR）。

已有基线：父分支 301 项测试及 iOS SDK 构建通过。本机未安装可用 iPad 模拟器运行时，因此 SDK 构建、macOS 实际 SpriteKit 渲染与真机验证分开报告。
