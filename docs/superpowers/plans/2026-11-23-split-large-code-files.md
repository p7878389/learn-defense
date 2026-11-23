# 代码文件职责拆分 Implementation Plan

**Goal:** 将全部手写代码文件控制在 400 行以内，保持游戏行为、资源和测试断言。

**Architecture:** 保留现有类型与接口；完整类型单独成文件，大类型按职责拆成 extension。只对跨文件所需的成员调整模块内访问权限。

**Tech Stack:** Swift、SwiftUI、SpriteKit、Swift Testing、Python 标准库。

**Spec:** 本次用户要求：优化代码文件，单文件约 400 行，并给出剩余优化建议。

## 约束与风险

- 不改战斗数值、伤害时机、存档格式和特效资源。
- 不引入依赖，不提交、推送或合并。
- GitNexus 将核心战斗类型标为 CRITICAL；通过原有完整测试套件与 iOS 构建验证。
- 测试类型由 Swift Testing 动态发现，空调用图不代表未使用。

## 实施与验证

- [x] 建立代码行数检查，先确认现有 12 个超限文件可被检出。
- [x] `GameSession.swift` 保留状态、初始化、准备与道具；新增 `+Answers`、`+SceneDelegate`、`+Rounds`。
- [x] `GameScene.swift` 保留状态、布局、主循环和目标选择；新增 `GameSceneDelegate.swift`、`+Defense`、`+Combat`。
- [x] `EnemyNode+Animation.swift` 收拢角色表现；`SpriteRig.swift` 独立管理序列帧。
- [x] `GameView.swift` 拆出 `BattleScreen`、`BattlefieldView`、`GameHUD`、`UltimateButton`、`BattleOverlays`。
- [x] `CollectionView+Cards.swift` 收拢外观卡片和购买装备；冒险大厅与主页草坪独立成文件。
- [x] `WordCardEffect.swift`、`HitEffects.swift` 分离学习卡片与命中策略。
- [x] 测试按原套件边界拆分，共用工具独立，保持所有断言。
- [x] 运行行数检查、Python 脚本测试、Swift 完整测试和 iOS 模拟器构建。
- [x] GitNexus detect_changes、Git diff 与代码块一致性检查；记录剩余优化建议。

## Review Focus

- 暂停/恢复与回合休息仍按原顺序修改状态。
- 结算失败重试保持幂等。
- 毁灭菇伤害、焦坑、冷却保持原规则。
- 敌人皮肤、防具脱落和动画清理保持原行为。
- 测试套件与测试方法数量不因移动而减少。
