# 代码组织与后续优化

## 本次整理

按物理行数统计全部 Swift、Python、Shell 等代码文件，包含注释和空行，不包含 JSON、图片、`.sks` 等资源。
原有 12 个文件超过 400 行，已全部按现有职责拆分；当前最大文件为 394 行。

| 原文件 | 原行数 | 整理后职责 |
| --- | ---: | --- |
| `GameView.swift` | 840 | 入口、`BattleScreen`、战场布局、HUD、大招按钮、弹层 |
| `GameSession.swift` | 786 | 状态与准备、`+Answers`、`+Rounds`、`+SceneDelegate` |
| `GameScene.swift` | 778 | 主循环与布局、`+Defense`、`+Combat`、代理协议 |
| `CollectionView.swift` | 702 | 分类与预览、`+Cards` 购买和装备 |
| `EnemyNode.swift` | 488 | 状态与移动、`+Animation` |
| `AdventureView.swift` | 459 | 战斗界面、独立冒险大厅 |
| `HomeCarousel.swift` | 451 | 轮播卡片、独立主页草坪 |
| `UnitSprites.swift` | 443 | 资源加载、独立 `SpriteRig` 动画控制 |
| `Effects.swift` | 432 | 通用表现、单词卡、命中策略 |
| `CombatAnimationTests.swift` | 423 | 动画测试、独立 `SceneClock` 工具 |
| `LearnCoreTests.swift` | 402 | 逻辑测试、独立 `SeededRNG` 工具 |
| `GrowthTests.swift` | 401 | 成长测试、独立节奏配置测试 |

跨文件 extension 需要共享部分成员，因此将必要的 private 成员调整为模块内可见，保留其余私有成员。
公共产品接口、战斗算法、数值、存档格式、资源和调用顺序保持原样。
首轮只调整代码组织；后续优化的实现与测量结果见下文。

## 持续检查

在仓库根目录执行：

```bash
python3 scripts/check-source-lines.py
```

脚本检查 Git 跟踪文件及未忽略的新文件，超过 400 行返回退出码 1。
可直接接入后续 CI；新增功能优先新建职责明确的组件，不通过压缩空行或堆叠语句规避限制。

## 首轮拆分验证

- Xcode 工具链下完整 `swift test`：LearnGame 225 项、LearnCore 205 项通过，与拆分前一致。
- 恢复原动画套件标签后，额外执行 CombatAnimationTests：16 项通过。
- 改动涉及的测试保留 12 个套件标签、62 个测试方法、313 个 `#expect` 和 24 个 `#require`。
- 原代码与移动后的代码按行核对，无遗漏的非括号代码行；仅增加独立配置套件的文件私有 catalog 常量。
- iOS 模拟器 Debug 构建通过；未做真机操作验证。
- 行数检查与 `git diff --check` 通过。
- GitNexus `detect_changes(scope: all)` 已覆盖新增文件，报告 CRITICAL，涉及核心战斗调用链；结合完整测试、构建和代码一致性核对审查。

验证命令（本机默认 Command Line Tools 缺少 SwiftData 宏插件，因此指定 Xcode）：

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/LearnKit
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project LearnDefense.xcodeproj -scheme LearnDefense -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

## 后续建议处理进度

1. **并发隔离：已处理。** `BossWarningEffect` 明确为 MainActor；延迟回调弱引用场景，避免暂停退出后由动作持有整张场景。保持 SKAction 同步触发方式，没有增加 Task 延迟。原 MainActor 调用警告消除。
2. **共享状态：已收拢题目部分。** `SessionQuestions` 将题目、错选、首显时间和新题缓冲计时封装在私有状态中。替换、删除和回合重置统一更新，GameSession 扩展通过受控方法操作。SwiftUI 的 Published 通知方式不变；回合和结算状态暂保留原结构，后续有相关需求时再逐步抽取。
3. **资源缓存：已实施预算。** 动画按未压缩源画布估算成本，LRU 上限 64 MiB；头像按 bytesPerRow × height 计费，上限 8 MiB。两类缓存也限制条目数量。iOS 内存警告同步清理缓存持有，正在播放的节点和动作继续持有自身资源。逐帧解码使用局部 autoreleasepool，及时回收临时图片对象。
4. **战斗循环：已测量。** 当前压力场景耗时很低，保留现有遍历方式，以本轮数据作为后续回归基线，无需增加按路索引的维护成本。
5. **旧视觉特效：继续遵循按需迁移规则。** 本轮没有重做外观；后续确需调整视觉时，逐项迁移到 `.sks` 与 FXLibrary，并保持命中和伤害时机。

## 本轮性能测量

本机 Apple Silicon Mac，Xcode 工具链，Release 构建。压力场景为 30 只怪物、5 路共 40 个防御节点，推进 3000 帧，前 200 帧不计入样本。
测量 `GameScene.update` 的 CPU 耗时，**不包含 GPU 绘制，不能当作 iPad 实际帧率结论**。
资源场景依次读取内置及森林怪物的行走、其他动作和头像。驻留增量为同一进程加载前后差值，受系统与 ImageIO 缓存影响，存在波动。

| 指标 | 优化前 | 优化后 |
| --- | ---: | ---: |
| 资源场景缓存帧数 | 392 | 283 |
| 动画与头像估算缓存成本 | 无上限 | 实测 67.15 MiB，上限合计 72 MiB |
| 资源加载驻留增量中位数 | 114.17 MiB（5 次） | 107.91 MiB（4 次） |
| 资源加载驻留增量范围 | 113.55–157.02 MiB | 96.92–108.56 MiB |
| 主循环 P95 中位数 | 0.0512 ms | 0.0525 ms |

主循环没有可确认的性能变化，不宣称 CPU 加速。收益在于缓存持有有明确上限，并减少解码临时对象的堆积；实际进程总内存与 GPU 缓存不受该估算上限约束。

Instruments 使用 CPU Profiler 模板采样；含 LearnGameTests 栈的 2450 条样本中，564 条顶部为 ImageIO、298 条为 CoreGraphics。采样显示图像加载值得优先处理，不据样本条数直接推算 CPU 百分比或 GPU 耗时。

复现测量：

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer LEARN_OPTIMIZATION_PROFILE=1 swift test --package-path Packages/LearnKit -c release --filter ClassicOptimizationMeasurements
```

本轮新增回归覆盖题目替换与清理、首显时间、重复错选、战场缓冲时钟、LRU 淘汰与替换计费、超大/零成本资源、活动引用存活、纹理重载和首领预警暂停/退出。
通过临时恢复强场景捕获，确认暂停退出回归会失败；恢复弱引用后通过。

## 本轮最终验证

- 完整 Swift 测试：LearnGame 236 项、LearnCore 205 项，共 441 项通过。
- iOS 模拟器 Debug 构建通过；没有进行真机帧率测试。
- 236 个代码文件均不超过 400 行，最大 394 行；git diff --check 通过。
- GitNexus 已刷新，detect_changes(scope: all) 覆盖两轮累计 45 个文件；风险 CRITICAL，无 partial / truncated。已核对答题、结算重试、毁灭菇、皮肤、动画、暂停和退出相关完整回归。
- 原 Effects.swift 的 MainActor 调用警告已消除；第三方和旧 API 弃用等既有警告仍存在。
- 开发分支为 codex/split-large-code-files；提交、合并与设备安装状态以 Git 和实际执行结果为准。
