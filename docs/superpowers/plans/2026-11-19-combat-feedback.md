# 战斗反馈修复实施计划

**目标：** 答题后子弹可见，首次死亡不再现场加载素材，回合结束时退场动画能够完成并清理。

**架构：** 复用 SpriteKit 攻击策略和 UnitSprites 纹理缓存，在对局准备及换回合时预热本回合的素材。回合休息冻结玩法时钟，同时允许现有退场动作完成；普通暂停沿用现有行为。

**技术栈：** Swift、SwiftUI、SpriteKit、Swift Testing；iOS 17 / macOS 14 起。

**需求来源：** 本会话确认的子弹不可见、僵尸死亡卡顿问题，以及落实到 `fix/横屏留白与栽种优化` 分支的指示。

## 约束与复查重点

- 不引入依赖，保留已合入的横屏和栽种优化，仅提交本次修复。
- 一次正确作答仍只推进一次伤害；连发仍按顺序回调，最后一发标记不变。
- 覆盖首帧可见、200 毫秒帧间隔、连发等待期间隐藏、纹理缓存共享、已装备皮肤及缺失皮肤回退。
- 回合休息时不再出怪或推进玩法时钟，死亡节点能够移除；普通暂停和大招暂停仍冻结动画。
- 预热只选择本回合敌人和可种植单位，不加载未遇到的所有首领。

## 任务一：子弹可见过程

**文件：** `Game/AttackStrategy.swift`、`Tests/LearnGameTests/CombatAnimationTests.swift`。

- [x] 补充真实离屏渲染回归：第一发首帧可见，200 毫秒帧间隔后仍在飞行，命中一次并清理；连发后续子弹仍等待各自发射时间。
- [x] 在现有实现上运行测试，确认因透明首帧或提前消失失败。
- [x] 修改 `ShotAttack.perform`：飞行时间为距离 / 1200，限制在 0.35～0.8 秒；第一发立即可见，其余发到发射时再显示。
- [x] 重跑战斗动画测试，检查命中顺序、光束时序和清理。

## 任务二：预热战斗纹理

**文件：** `Support/UnitSprites.swift`、`Game/GameSession.swift`、`Tests/LearnGameTests/UnitSpriteTests.swift`。

**接口：** `UnitSprites.preloadCombat(defenders: [DefenderKind], enemies: [EnemyKind], loadout: Loadout) -> [String: [SKTexture]]`。

- [x] 测试返回的纹理覆盖角色动作、子弹和命中图，并与随后实际使用的缓存纹理共享；覆盖皮肤及回退。
- [x] 确认测试在未实现预热时失败。
- [x] 复用 `frames(named:)` 和 `SKTexture.preload`，在准备阶段及下一回合开始前预热本回合资源。
- [x] 重跑纹理和战斗测试；用独立探针比较预热后的首次死亡调用耗时。

## 任务三：回合休息期间完成退场

**文件：** `Game/GameScene.swift`、`Game/GameSession.swift`、`Tests/LearnGameTests/CombatAnimationTests.swift`。

**接口：** `GameScene.setGamePaused(_:keepingAnimations:)`，`keepingAnimations` 默认 `false`。

- [x] 补充最后击杀回归：进入休息，玩法时钟不动，死亡节点和特效能够清理。
- [x] 确认原实现因全场动画暂停而失败。
- [x] 仅在 `GameSession.checkFinished` 的回合休息路径保留动画。
- [x] 运行完整包测试及 iOS 构建，执行 GitNexus `detect_changes(scope: "all")` 和 Git diff 复查。

## 验证结果

- `LearnGameTests` 145 项、`LearnCoreTests` 141 项，共 286 项测试通过。
- iOS Simulator Release 构建成功；没有安装到真机。
- 新回归先复现首帧透明、200 毫秒帧间隔吞掉子弹、休息期间死亡节点无法清理，再验证修复。
- Mac 离屏探针中，200 毫秒帧间隔后子弹仍有 9 个可见帧；预热后普通僵尸首次退场调用约 0.33 毫秒，原约 17～22 毫秒。数据不等同于 iPad 整帧耗时。
- 素材准备发生在进入准备阶段和换回合，探针预热 196 帧约 174 毫秒，战斗中复用缓存。
- 图变更检查识别了全部 6 个代码/测试文件和 15 条相关执行流程；结合 Git diff 与完整测试复查。静态图仍有动态接收者解析限制。
