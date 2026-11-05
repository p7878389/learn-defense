# 冰晶攻击与皮肤 Implementation Plan

**Goal:** 在现有 SpriteKit 战斗中加入可装备的冰晶视觉样板。
**Architecture:** 独立 IceCombatEffects 生成并共享透明纹理、一次性爆点序列帧、粒子和常驻光环。ShotAttack 按最终子弹外观挂接视觉，GameScene 种植时使用同一 Loadout 挂接光环。
**Tech Stack:** Swift、SpriteKit、CoreGraphics；不新增依赖。
**Spec:** 本会话已授权的推荐方案：冰系攻击、配套皮肤、保持战斗结算。

## 约束与检查重点
- 不改变伤害、减速、飞行时间、连发间隔和命中回调次数。
- 冰蓝宝石皮肤不产生减速；原版和其他皮肤不增加冰晶光环。
- 粒子有数量上限；延迟连发未发射前不产生拖尾；一次性效果结束后清理。
- 常驻光环跟随守卫销毁；资源共享，不为每次攻击生成纹理。
- 验证真实 SpriteKit 动画回调与最终节点清理，导出预览检查外观。

## 实施
- [x] 新增测试：收藏馆冰晶皮肤可装备，原版可恢复；种植读取最终外观；连发保持两次命中且只有最后一次 final；瞬态节点最终清理。
- [x] 运行测试确认缺失功能导致失败。
- [x] 新增 IceCombatEffects.swift；接入 ShotAttack 和 GameScene.plant；配置免费一级冰晶弹供直接体验，不调整既有外观数值。
- [x] 运行 swift test 全套、iOS 模拟器构建（环境支持时），导出效果预览目检。
- [x] 刷新索引并 detect_changes，检查 git diff；不提交、不合并。
