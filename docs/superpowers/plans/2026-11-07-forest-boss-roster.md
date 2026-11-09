# 森林 Boss 与守卫战斗 Implementation Plan

**Goal:** 接入 10 Boss、2 小怪、2 英雄及攻击/技能特效，守卫与塔有耐久并可修复。
**Architecture:** LearnCore 目录增加 ForestRoster（单位与招式配置）、ForestCombat（状态机/命中/耐久），ForestBattle 保留路径和炮塔射击。SwiftUI 增加独立单位/特效绘制和战前首领选择，读取 Stitch 原始素材。
**Tech Stack:** Swift 5.9+ / SwiftUI / Foundation / CoreGraphics；不添加依赖。
**Spec:** docs/forest-roster/design.md；用户已授权开发并选择攻击守卫、炮塔及耐久修复。本会话直接实施，不提交、不推送。

## Global Constraints
- 基线 origin/main 58bd52f；与另一会话 worktree 隔离。
- 保留六塔位、三连发0.09s/0.75s、冰塔1.2s及55%减速2s。
- 飞行外观沿路；技能前摇不能提前伤害；wave question 暂停敌方攻击。
- 白底原型来源保留，加载时按背景色遮罩；不得以整张评审图替代游戏资源。
- 所有10 Boss通过战前选择在最终波出现，前两波教学基础怪/远程怪。
- 数值初版集中配置：塔耐久30、英雄36，修复15阳光补20耐久，英雄部署50；战斗中可修复，失败/答题期不可修复；废墟保留可修复。
- Boss普攻与每第三次强化技共用明确前摇/释放/收招；英雄主动盾垒/缠绕，冷却12秒。

## Review Focus
- 死亡或目标毁坏：取消未释放攻击，不重复奖励。
- 波间暂停/终局：不再扣血；无效dt不污染状态。
- 毁坏防线：停火，可修复，不能重复建造重叠单位。
- 定点陨石与追踪魂弹：落点锁定与跟踪分别处理。
- 全部Boss可选且最终波不提前结束；资源丢失测试失败。

### Task 1: 单位与攻击状态机
Files: ForestRoster.swift, ForestCombat.swift, ForestDefense.swift, ForestCombatTests.swift.
- [x] 测试前摇无伤害、释放只结算一次、每种Boss攻击事件、目标失效与暂停。
- [x] 运行swift test --filter ForestCombatTests，确认新能力缺失。
- [x] 实现单位目录、施法计时、敌方攻击目标、弹道与范围效果；保留旧init兼容。
- [x] 运行新增逻辑测试与ForestDefenseTests。

### Task 2: 英雄、耐久、修复与波次
Files: 同上。
- [x] 测试修复付费/上限/废墟、敌方对塔/英雄伤害、盾吸收、缠绕暂停移动、首领最终波。
- [x] 实现结构耐久、英雄部署/自动攻击/主动技能、首领选择波次。
- [x] 测试通过，模拟全部首领完整战斗，检查胜负可达。

### Task 3: 素材与画面
Files: ForestRosterArtwork.swift, ForestCombatViews.swift, ForestDefenseView.swift, Resources/Sprites/ForestRoster/*, ForestRosterRenderTests.swift.
- [x] 资源加载与战斗阶段截图测试先失败。
- [x] 从Stitch下载保留原型/前摇/技能原图及来源清单；使用缓存背景遮罩与统一脚底基准。
- [x] 行进/蓄力/释放/收招、弹道/预警/命中、毁坏/修复/盾垒/藤蔓；更新控制区。
- [x] 渲染截图人工核对：角色识别、白底处理、特效时机、文字与点击区域。

### Task 4: 验证与交付
- [x] swift test 完整套件；记录既有失败，不削弱断言。
- [x] GitNexus refresh + detect_changes(scope:all,worktree:本目录)，处理partial/truncated。
- [x] git diff --check；核对自己的改动、测试和限制，保留未提交供用户审查。

## Verification

- `swift test`: 24 XCTest + 86 LearnGame Swift Testing + 130 LearnCore Swift Testing passed.
- 十种 Boss 均完成三波长跑并到达胜利；防线毁坏场景仍可失守。
- iOS Simulator 与签名 iOS Device Debug 构建成功。
- 十张 Boss/防御控制快照全部生成并核对，白底遮罩、角色识别与技能标签正常。
- GitNexus detect_changes 未返回 partial/truncated；涉及 Tick → FlightTime、Tick → Point 两条流程。
- 新增 roster 文件仍未跟踪，因此 GitNexus 的差异统计只覆盖两个已跟踪的改动文件；新增文件由完整编译和测试覆盖。
