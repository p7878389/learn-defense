# 交互容错、学习闭环与代码门禁优化实施计划

**目标：** 在保留全部既有奖励数值、存档兼容与布局基线契约的前提下，消除儿童/家长高频误操作断点、打通跨年级错题与结算学习闭环、加固同音干扰项与语音恢复体验，并恢复全仓代码行数门禁（≤ 400 行）。

**工作区与影响面基线：**
- Repository: `learn-defense` (`/Users/martin/ideawork/learn-defense`)
- Worktree: `/Users/martin/ideawork/learn-defense/.claude/worktrees/feature-ux-and-code-polish` (`feature/ux-and-code-polish`, base `main` @ `1d7378b`)
- GitNexus Impact:
  - `QuestionGenerator` (`+Input` / `+Preschool`): `CRITICAL`（153 关联符号，修改需完整运行 `LearnCoreTests` 与 `LearnGameTests`）
  - `AdventureBattle`: `LOW`（直接上游 `AdventureSession.init`）
  - `GameSession` / `SpeechLibrary`: 核心交互链路，修改保持原有同步判题契约与 API 兼容

## 约束与不改动边界

- 不改变成长经验/积分公式、`AdventureBattle.shovel` 单格铲除不返阳光契约、`GameSession.answer` 同步换题测试契约，以及 `AdventureScreenTests` 横竖屏无黑边/无溢出一屏契约。
- 不新增数据库表、外部依赖或破坏旧存档 `Codable` 兼容。
- 所有业务与测试源码单文件严格不超过 400 行。

## 实施清单（TDD）

### 1. 代码行数门禁与设计系统收尾
- [x] `scripts/check-source-lines.py` 排除顶层隐藏配置目录（`.claude/`、`.cursor/`、`.gemini/`、`.trellis/`、`.agents/` 等），仅检查项目源码。
- [x] 拆分 `DesignSystem.swift`（609 行）为令牌表面层 `DesignSystem.swift` 与按钮脚手架层 `AppButtons.swift`，消除裸 `Color(red:)` 违例。
- [x] 拆分 `AdventureView.swift`（406 行）弹层至 `AdventureOverlays.swift`，清理未引用的 `Chip`、重复 `rarityColor` 及废弃 `adventure.active` 判断。

### 2. 种植容错、冒险退出防误触与家长后台防丢草稿
- [x] 经典闯关支持“轻点选卡 → 点击草坪空位放置”（兼容原有拖拽放置），与引导飘字一致。
- [x] 经典与冒险模式在 `.preparing` 准备阶段均提供「重摆 / 重置布阵」能力（全额恢复初始阳光并清空预摆单位与预放毁灭菇），不改动局内 `shovel` 规则。
- [x] 冒险准备阶段点「返回」直接退回地图；战斗暂停弹窗合并冗余退出按钮并统一走二次确认；冒险大厅积分不足 15 分点击关卡弹引导提示而非静默关页。
- [x] `ParentSettingsView` 切后台改为顶层覆盖验证锁屏而非卸载子视图树，保留 `VoiceSettingsView` 等页面的未保存密钥草稿；锁定时动态展示剩余秒数。

### 3. 答错防连点、错题跨年级闭环与结算补全
- [x] `AnswerPanel` 增加换题瞬间防连点冷却锁，避免双击连点误触新题；满血点治疗道具或空场点冰冻道具拦截防浪费。
- [x] 修复跨年级选库错题孤儿化：主页待复习统计与复习范围覆盖全库待复习项，`QuestionBankDraft` 在复习模式下保留全学科/跨年级待复习题库；`WrongBookView` 迁移 `AppModalScaffold`、补齐子筛选空态、点读发音与「立即复习」入口。
- [x] 结算页 `MistakeNotebook` 补齐正确答案与听音题文案；第 6 局衰减时总积分砖补齐 `fullCoins` 划线对照，并在开战核对弹窗给出护眼休息提示。

### 4. 同音干扰过滤、语音恢复与场景特效比例适配
- [x] `QuestionGenerator` 在 `pinyinToWord`、`listenPickChar` 与 `preschoolCharDistractors` 中优先排除完全同音词/同音字干扰项（极小题库不足时安全回退）。
- [x] `Speech.apply` 保留 `.spokenAudio` 模式；`SpeechLibrary` 新增 `resumePending()` 并在 `VoiceSettingsView` 提供中断后继续生成入口、1.0 模型与 2.0 音色冲突提示及密钥掩码切换。
- [x] `AdventureScene` 将视口纵横比补偿扩展至弹丸与毁灭菇圆环特效，消除竖屏椭圆拉伸；`BadgeWallView` 补齐窄屏/竖屏滚动兜底。

## 验证结果

- 全量 Swift 测试：`LearnGameTests` 271 项、`LearnCoreTests` 231 项，共 **502 项测试全部通过**。
- iOS Simulator 构建：`xcodebuild -project LearnDefense.xcodeproj -scheme LearnDefense -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build` 通过（`BUILD SUCCEEDED`）。
- 行数与格式门禁：`python3 scripts/check-source-lines.py` 已检查 258 个代码文件、**超限 0 个**；`git diff --check` 无空白或冲突问题。
- GitNexus 图谱变更检查：`detect_changes(scope: "all")` 完整扫描本次工作树全部变更符号（无 `partial` / `truncated`），高风险调用链均已由全套单元测试与界面布局测试覆盖。
- 工作树状态：所有变更隔离保存在 `/Users/martin/ideawork/learn-defense/.claude/worktrees/feature-ux-and-code-polish`（分支 `feature/ux-and-code-polish`），主检出 `main` 保持原状。
