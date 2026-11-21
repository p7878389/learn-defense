# 冒险模式第一版 Implementation Plan

> **For agentic workers:** 按任务逐项实施和验证。本会话由主代理原生执行；用户已授权实现，不额外设置计划审批。

**Goal:** 增加「现有经典答题游戏赚积分 → 15 积分入场 → 无题目塔防 → 关卡星级」闭环，完整保留经典模式。

**Architecture:** LearnCore 提供可编码、可确定性推进的冒险战斗状态；LearnGame 独立场景复用现有地图、角色、卡牌、攻击和 `.sks` 资源。新增进度和战斗快照随 GrowthState 存储，积分扣除与快照创建一次保存，不新增数据库表。

**Tech Stack:** Swift、Swift Testing、SwiftData、SwiftUI、SpriteKit；不新增依赖。

**Spec:** 本会话已确认的第一版方案；下列规则作为实施规格。

## Global Constraints

- 一章 6 关、每关 5 波；4 种射手、2 种防御单位；普通、快速、重甲怪和 1 类首领。
- 复用五行九列战场；自动索敌射击；定时阳光、击杀奖励、波次奖励；铲除单位；战斗充能大招。
- 每次正式开始扣 15 积分，准备退出免费；失败和主动放弃不退款；恢复已付费对局不重复扣费。
- 积分沿用现有经典答题游戏的获取方式；不新增独立答题页、奖励来源或学习入口。
- 冒险通关只增加星级、关卡进度和纪念成就；不调用经典成长结算，不产出积分、经验或积分徽章。
- 经典答题、错题复习和学习记录保持原行为；冒险积分不足时引导返回主页进行经典闯关。
- 旧 GrowthState 缺少新字段时使用空进度；数据库备份、还原、档案删除沿用原成长数据路径。
- 所有新特效复用已有 `.sks`，不新增运行时粒子或形状特效。
- UI 使用中文、现有糖果卡片风格；适配 iPad 横竖屏；后台暂停，明确点击继续；持久化已扣费战斗供重启恢复。
- 经典游戏进场不自动弹窗，按孩子与模式恢复上次有效题库；首次手动选库后才能开战。准备完成时核对配置，确认才出怪，取消保留准备状态。
- 不提交、不推送、不集成 main。

## Review Focus

- 双击开始、重复恢复、保存失败不可重复扣费或丢失积分。
- 冒险消费不能恢复经典每日奖励额度；切换档案不能串用余额和对局。
- 暂停、进入后台和恢复不能推动出怪、阳光、攻击时钟。
- 最后一只敌人漏过、飞行子弹、波次切换和大招不能重复击杀或卡住结算。
- 旧存档及备份导入不得丢失经典积分、皮肤、每日额度；纯冒险不得触发经典奖励。

## Task 1: 可恢复塔防规则

**Files:**
- Create: `Packages/LearnKit/Sources/LearnCore/Adventure/AdventureCatalog.swift`
- Create: `Packages/LearnKit/Sources/LearnCore/Adventure/AdventureBattle.swift`
- Test: `Packages/LearnKit/Tests/LearnCoreTests/AdventureBattleTests.swift`

**Interfaces:** `AdventureCatalog.levels`、`AdventureBattle(level:difficulty:deck:)`、`plant(_:lane:column:)`、`shovel(lane:column:)`、`start()`、`advance(by:) -> [AdventureEvent]`、`unleash() -> [AdventureEvent]`、`pause()`、`resume()`。

- [x] 先写自动射击、射程/同路目标、漏怪损失、暂停、阳光、五波结束、充能、快照恢复的失败测试。
- [x] 执行 `swift test --filter AdventureBattleTests`，确认因缺少功能失败。
- [x] 实现 Codable 战斗状态和关卡数据，伤害由引擎一次结算，场景只负责动画。
- [x] 重跑测试，检查有布阵可通关、漏怪会失败以及小步/大步时间推进一致。

## Task 2: 现有积分消费与持久化

**Files:**
- Create: `Packages/LearnKit/Sources/LearnCore/Adventure/AdventureProgress.swift`
- Create: `Packages/LearnKit/Sources/LearnCore/Adventure/GrowthStore+Adventure.swift`
- Modify: `Packages/LearnKit/Sources/LearnCore/Growth/GrowthState.swift`
- Modify: `Packages/LearnKit/Sources/LearnCore/Growth/GrowthRules.swift`
- Test: `Packages/LearnKit/Tests/LearnCoreTests/AdventureProgressTests.swift`

**Interfaces:** `GrowthStore.startAdventure(_:) throws`、`saveAdventure(_:) throws`、`finishAdventure(_:) throws`、`abandonAdventure() throws`；`GrowthState.adventure`。

- [x] 先写余额不足、重复扣费、档案隔离、旧档解码和数据库重开测试；补充经典收益用于冒险、消费保留每日额度和备份恢复测试。
- [x] 执行 `swift test --filter AdventureProgressTests`，确认失败。
- [x] 增加兼容字段和先保存后发布状态的事务接口，纯战斗不修改经典统计和奖励。
- [x] 验证新测试及 `DailyRewardTests`、`GrowthStoreTests`、`ParentSettingsTests`。

## Task 3: 冒险场景与会话

**Files:**
- Create: `Packages/LearnKit/Sources/LearnGame/Adventure/AdventureSession.swift`
- Create: `Packages/LearnKit/Sources/LearnGame/Adventure/AdventureScene.swift`
- Test: `Packages/LearnKit/Tests/LearnGameTests/AdventureSessionTests.swift`

**Interfaces:** `AdventureSession(levelID:model:profileID:difficulty:deck:)`，发布 HUD 状态，复用 SeedPacketStrip。

- [x] 先写后台暂停、恢复不重扣、结束不发成长奖励测试；补充连续场景帧推进回归测试。
- [x] 执行 `swift test --filter AdventureSessionTests`，确认失败。
- [x] 实现场景事件渲染；所有战斗规则由 LearnCore 驱动。
- [x] 验证会话测试和经典 `GameSessionExitTests`、`UltimateStatisticsTests`。

## Task 4: 页面、集成与最终验证

**Files:**
- Create: `Packages/LearnKit/Sources/LearnGame/Views/AdventureView.swift`
- Modify: `Packages/LearnKit/Sources/LearnGame/Views/ProfileHomeView.swift`
- Modify: `README.md`

- [x] 接入六关地图、卡组选择、准备/暂停/结算覆盖层、积分不足返回经典模式和恢复入口。
- [x] 运行完整 `swift test`：191 + 189 = 380 项全部通过，包含 21 项冒险规则、积分、会话与可选界面测试。
- [x] 使用 Xcode 的 DEVELOPER_DIR 构建 iOS Simulator，结果 BUILD SUCCEEDED；使用真实 SwiftUI/SpriteKit 组件导出六张横竖屏截图检查。机器没有模拟器运行时，模拟器/真机触控与系统后台切换保留为人工验收项。
- [x] 执行 GitNexus `detect_changes(scope:all, worktree:...)`：包含新文件的全部 16 个文件，423 个符号、71 条受影响流程；无 partial/truncated。风险 critical 来自共享成长存储及角色/场景依赖，已回归经典结算、皮肤、每日积分、备份等现有测试。
- [x] 检查 `git diff --check`、改动范围和存档兼容性；未提交、未推送、未集成 main。

## 验证产物

- 全量测试：`/tmp/learn-defense-adventure-final-tests.log`
- iOS 构建：`/tmp/learn-defense-adventure-ios-final.log`
- 界面截图：`/tmp/learn-defense-adventure-preview-v1/`（实际 macOS SwiftUI/SpriteKit 渲染，尺寸参照 iPad 横竖屏；不替代 iOS 设备验收）。
- 首次默认命令行工具链缺少 SwiftData 宏插件；所有有效验证均显式使用 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`，未修改系统工具链配置。

## Task 5: 真机反馈后的界面与选库续改

**Goal:** 统一冒险糖果风格，主页及六关地图无需纵向滚动；题库选择移入经典游戏弹窗。

**Files:** `GrowthHomeSection.swift`、`ProfileHomeView.swift`、`AdventureView.swift`、`GameView.swift`、新增 `GamePreparation.swift`、`QuestionBankPickerView.swift`；对应 `AdventureScreenTests` 和 `QuestionBankPreparationTests`。

- [x] 先增加真实布局回归测试，复现 1180×736 下主页高 815、地图高 1045、有存档地图高 1187 的溢出。
- [x] 冒险与收藏、徽章入口共用一行；移除主页选题区；地图改为横屏左右分栏、竖屏上下布局，复用现有糖果组件。
- [x] 先运行失败测试，再实现 `QuestionBankDraft` 与 `GamePreparation`：切换范围重置单元，未确认题库无法开战，取消不产生对局记录，开战后禁止改库。
- [x] 新增弹窗及准备阶段「切换题库」；重选只废弃原准备状态，再来一局使用已确认的题库配置。
- [x] 定向六项测试通过；导出真实主页、地图、战斗和选题弹窗截图，检查横竖屏及已付费存档状态。
- [x] 全量回归 196 + 189 = 385 项全部通过（含经典战场与冒险横竖屏真实渲染）；iOS 真机构建成功。
- [x] GitNexus 全范围变更检查覆盖 22 个文件、548 个符号和 121 条受影响流程，无 partial/truncated；已检查 Git diff。
- [x] 已更新安装至「peng的iPad」（iPad Air 11-inch M4），启动成功并确认进程运行。未提交、未推送、未合入 main。

续改验证产物：`/tmp/learn-defense-adventure-ui-full.log`、`/tmp/learn-defense-adventure-ui-device-build.log`、`/tmp/learn-defense-adventure-ui-final/`、`/tmp/learn-defense-classic-ui-final/`。

## Task 6: 默认配置、单元复选与开战核对

- [x] 先验证新行为的失败测试：首次进场无弹窗且不能开战；上次配置重开可恢复并按孩子隔离；准备后取消/确认启动；单元全选、部分与清空。
- [x] UserDefaults 按孩子及经典/复习模式存储选题范围；旧版从最近对应对局恢复；失效范围需人工重选。难度沿用档案默认，确认修改后更新默认难度。
- [x] GameSession 增加题库确认门槛；准备界面显示范围并可手动选库/调整难度；配置未变时保留布阵。
- [x] 单元改为固定行高复选卡片，选中与未选中不移动文字，长标题支持两行；全不选禁用确认。
- [x] 新增 GameStartConfirmationView，展示难度、年级学科、课本、单元、地图、题量和布阵；取消可修改，确认后才启动。
- [x] 完整回归 203 + 189 = 392 项全部通过；真机构建成功；图检查覆盖全部 24 文件、673 符号，无 partial/truncated；更新安装至已连接 iPad。

本轮产物：`/tmp/learn-defense-ready-review-full.log`、`/tmp/learn-defense-ready-review-device.log`、`/tmp/learn-defense-ready-review-final/`（含单元部分选择与开战确认截图）。

## Task 7: 单元完整展示与弹窗空间优化

- [x] 先用真实 SwiftUI 复现小弹窗边界溢出和长标题固定两行截断的失败测试。
- [x] 横屏左侧筛选、右侧单元；竖屏两行筛选，确认区固定底部，去掉重复说明占位。
- [x] 复用 CandyDropdownButton 统一筛选控件；单元卡片按内容增长，完整换行；数量较多可在单元区独立滚动。
- [x] 680×540、900×600、680×940 三种弹窗尺寸下，内置八个单元均不超出列表视口；13 项定向测试通过，已查看横竖屏真实截图。
- [x] 全量 205 + 189 = 394 项测试通过；真机构建成功；图检查覆盖 25 文件、700 符号，无 partial/truncated；已更新安装至 iPad。

本轮产物：`/tmp/learn-defense-unit-layout-full.log`、`/tmp/learn-defense-unit-layout-device.log`、`/tmp/learn-defense-unit-layout-final/`（三种弹窗尺寸的真实截图）。

本轮安装成功；自动启动被真机锁屏拒绝（Locked），需解锁后手动打开，不将此项视为真机交互已验证。
