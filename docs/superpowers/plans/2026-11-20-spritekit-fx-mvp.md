# SpriteKit 特效资源化 MVP Implementation Plan

> **For agentic workers:** 本会话按用户授权直接执行，采用原生逐项实施与测试。步骤使用复选框记录；不自动提交、推送或合并。

**Goal:** 用三份实际 `.sks` 资源驱动命中、墨点、受击，并交付真实引擎动态预览。

**Architecture:** `FXLibrary` 从 Swift Package 加载可信归档，缓存模板、绑定包内纹理并按调用复制。现有表现入口调用资源，业务结算继续留在原流程。

**Tech Stack:** Swift、SpriteKit、Swift Testing、Metal SKRenderer；不新增依赖。

**Spec:** `docs/superpowers/specs/2026-11-20-spritekit-fx-resources.md`

## Global Constraints

- iOS 17 / macOS 14；Swift Package `LearnKit`。
- 只在 `codex/spritekit-fx-mvp` worktree 开发；不触碰主仓库未提交文档和两个旧任务。
- `.sks` 为外观与固定动作的维护来源；不在构建时生成覆盖。
- 不改伤害、奖励、能量、弹速与命中回调；不引入依赖。
- 资源失败记录诊断，不能阻断攻击结算；保留原调用接口和 `impactSplat` 节点名。

## Review Focus

- 包内贴图绑定、错误资源与缺少动作：加载测试需要观察实际资源失败。
- 粒子循环与结束推导：有限发射，暂停恢复后清空。
- 多实例可变状态：不同颜色/数量互不污染。
- 重复受击与冻色：不累计旋转，不改变逻辑位置或冻色。
- 连发/击杀：回调顺序与次数保持不变，清理完整。

## Task 1：三份资源与最小加载器

**Files:** 新增 `Game/FXLibrary.swift`、`Resources/Effects/*`、`Tests/LearnGameTests/FXResourceTests.swift`；修改 `Package.swift`。

**Interfaces:** `FXLibrary.effect(named: String) -> SKNode?`；`FXLibrary.reaction() -> SKAction?`；内部从固定资源目录解析。粒子实例可由入口覆盖业务颜色、count 和 scale，其余沿用归档。

- [x] 写能编译的缺失资源测试，通过 `Bundle.module` 可达的 `LearnGame` 资源包验证三个 `.sks` 尚不存在；观察预期失败。
- [x] 添加 `.copy("Resources/Effects")`，制作真实归档和透明纹理。
- [x] 实现加载、纹理绑定、模板复制和原资源动作读取。
- [x] 验证归档可解码、节点/动作有效、多实例隔离、缺失资源与错误根类型安全失败。

## Task 2：接入生产战斗入口

**Files:** 修改 `Game/Effects.swift`、`Game/AttackStrategy.swift`、`Game/EnemyNode.swift`；扩展 `FXResourceTests.swift`。

**Interfaces:** `FXLibrary.playInk(at:in:color:scale:count:)`；`FXLibrary.playImpact(at:in:color:) -> Bool`；`FXLibrary.react(on:)`。不修改调用方公共接口。

- [x] 写 InkBurst 会真实创建资源粒子、普通命中含组合层并能清理的失败测试。
- [x] 写反复受击动作可见且回正、冻色不变的失败测试。
- [x] 按已完成 impact 分析修改三个表现入口。
- [x] 验证颜色/数量绑定、暂停恢复、批量播放清理，以及连发命中回调。

## Task 3：动态预览、编辑说明与验收

**Files:** 新增 `Resources/Effects/README.md`、`docs/spritekit-fx-mvp/README.md`；测试内添加受环境变量控制的真实渲染导出。

- [x] 复用已有测试的 Metal / SKRenderer 方法，在真实角色和场景下触发生产入口，按固定帧率导出。
- [x] 输出正常速度与慢放预览以及代表帧；目检实际效果并按需调整资源。
- [x] 用 Xcode 打开并保存粒子/场景资源；原生动作库 API 加载及播放通过。iOS SDK 构建通过；无可用模拟器运行时，iPad 运行和 Action 编辑器保存往返仍列为未覆盖项。
- [x] 执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test` 完整套件，记录既有失败与新失败。
- [x] 刷新 worktree 索引，执行 `detect_changes(scope: all, worktree: ...)`，结合 Git diff 补查新资源与图遗漏。
- [x] 更新任务勾选与验收记录，交付路径和测试结果；保留未提交状态供审阅。

## 执行记录

- 基线首次直接 `swift test` 因系统选择 CommandLineTools，找不到 SwiftData 宏失败；改用本进程 `DEVELOPER_DIR` 指向已安装 Xcode，不修改系统设置。

- 最终结果：298 项测试通过、iOS Simulator 通用目标构建通过、真实 7 秒预览已导出。详细边界与回归记录见 `docs/spritekit-fx-mvp/README.md`。
