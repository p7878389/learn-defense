# 翡翠彗星弹 · SKS V2

先完成 [动画设计方案](../superpowers/specs/2026-11-20-sks-emerald-comet-v2.md)，再制作透明素材并编排资源。使用 `game-feel` 的分层冲击/缓动/强度分级，`create-game-assets` 的素材规范与原比例验收，以及 `imagegen` 内置工具制作同风格透明素材。

## 与 V1 的差异

| 环节 | V1 | V2 |
| --- | --- | --- |
| 发射 | 原有弹体直接出现 | 真正出膛时播放金白撞击星与能量弧 |
| 飞行 | 小圆弹 | 保留弹体，附着有体积与呼吸变化的彗星尾焰 |
| 命中 | 细绿环、小白闪 | 撞击星、双斩痕、错峰断裂环与尖角碎屑，分段收束 |
| 受击 | 轻后仰 | 后仰、短停、轻微过冲回正 |
| 击败 | 墨点和原倒地 | 专用光冠、外环、放射碎片叠加原退场 |

视觉层次、尺寸、透明度、散射与时间线都保存在 `.sks` / `CombatActions.sks`；Swift 只增加实际发射和击败时的资源绑定。普通命中在 0.48 秒内结束，不改变攻击时长、连发间隔、伤害或奖励。

## 维护入口

- `Resources/Effects/PeaMuzzle.sks`：枪口组合。
- `Resources/Effects/PeaFlight.sks`：弹体子节点，随弹体移除。
- `Resources/Effects/PeaImpact.sks`：普通命中组合。
- `Resources/Effects/DefeatBloom.sks`：仅在普通击败时调用，烧焦路径保持原有演出。
- `Resources/Effects/CombatActions.sks`：12 个命名动作，包含循环 CometPulse 与有限生命期。
- 节点 `userData.texture` 和 `userData.action` 分别绑定包内 PNG 与命名动作。固定多色纹理不设置 tint，避免把金白/青绿材质染成单色。

素材来源、切片与验证见 `../spritekit-fx-mvp/design-v2/asset-manifest.json`；原图为 `emerald-comet-source.png`，完整提示词在同目录 `imagegen-prompt.txt`。六张纹理有真实透明通道，采用统一轮廓、光照和颜色；裁切后留出透明边界。

## 实际引擎预览

从 worktree 的 `Packages/LearnKit` 运行：

```sh
LEARN_FX_PREVIEW="$PWD/../../docs/spritekit-fx-v2" \
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun swift test --filter FXResourceTests
```

输出来自原有真实 `GameScene.fire` 与 SpriteKit/Metal 渲染，不使用概念图替代运行画面。V1/V2 使用相同角色位置、攻击时间和镜头，比较素材与动画效果；粒子的随机位置不保证逐帧一致。

- `runtime.mp4` / `runtime.gif`：7 秒完整战斗。
- `comparison-slow.gif`：V1/V2 相同片段的并排慢放。
- `frames/`：210 张渲染原帧。

## 验收

- 完整 Swift 测试：LearnGameTests 160 项 + LearnCoreTests 141 项，共 301 项通过。V2 新增三个测试覆盖连发资源出现时机、击败清理、飞行暂停与不提前命中。
- 带预览环境变量的真实引擎测试通过，导出 210 帧、7 秒完整战斗；两只敌人各结算一次，有限特效无残留。
- iOS Simulator 通用目标 Debug 构建通过；没有可用的 iPad 模拟器运行时，未进行 iPad 真机观感/性能验收。
- 六张纹理通过 skill 的 `asset_report.py`：尺寸、真实 alpha、边界留白均通过。正常比例下目检了飞行、命中与击败阶段。
- GitNexus `detect_changes(scope: all)` 报 12 个变更符号、40 条影响流程、critical。原因是攻击/击败/暂停属于共享主流程；结合真实调用链和全套回归核对，未更改结算逻辑。未跟踪的新资源/加载器不计入这 5 个已跟踪文件的图差异，另由资源检查和运行测试覆盖。
- `git diff --check` 通过。工作仍保留在 `codex/spritekit-fx-mvp`，未提交、推送或合并。

本次完成的是普通圆弹的视觉升级和通用击败光冠；雷霆、冰晶、其他弹种维持原路径。素材、布局与命名动作可以继续在资源层调节，代码不负责配置这些视觉数值。
