# 雷霆小机甲与云游茶壶接入计划

**Goal:** 在现有皮肤 worktree 中接入两款全造型皮肤，可收藏装备、存档、试穿并用于真实战斗。
**Architecture:** 保留魔导书适配器；新增共享资源皮肤适配器，使用独立 PNG 部件、SKS 本体与弹道资源。现有攻击策略仅按主题选择资源，伤害及效果仍由原角色负责。
**Tech Stack:** Swift / SpriteKit / Swift Testing / ImageGen。
**Spec:** docs/skin-designs/defender-concept-design.json。

## 约束与验证重点
- 仅豌豆射手使用；其他角色、僵尸和缺失资源回退原版。
- 两款等级 1 免费，沿用魔导书规则；独立装备的子弹外观优先。
- 不新增伤害、射速、减速、雷击等数值或效果。
- 枪口使用实际部件坐标；重复攻击、受伤打断后恢复；暂停冻结动画。
- 本体、部件、弹体、出膛、命中和退场视觉各自独立，有限时特效自动清理。

## 实施
- [x] 新增 ThemeSkinCatalogTests：两款装备、序列化、切换与原版恢复；先运行确认缺失失败。
- [x] 新增 ThemeSkinTests：真实节点、独立部件、发射坐标、主题弹与覆盖、伤害结算、暂停、试穿边界与清理；先确认失败。
- [x] 制作两款透明图集，保存来源与提示词；规范化部件，生成 SKS 与命名动作。
- [x] 修改 CharacterSkin.swift / cosmetics.json 增加 mecha、teapot；新增 ThemeSkin.swift 适配，接入 DefenderNode、UnitSprites、CharacterSkinPreview、ShotAttack。
- [x] 运行定向测试、完整 swift test、iOS SDK 构建；导出真实 SpriteKit 预览并目检。
- [x] GitNexus detect_changes(all) 与 git diff --check；更新设计状态与验收记录。

用户已授权执行本次续改；本轮不提交、不推送、不合并。
