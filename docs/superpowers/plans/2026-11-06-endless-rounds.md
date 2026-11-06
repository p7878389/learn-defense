# 无限回合与积分结算实施计划

**目标：** 无限递增回合、按题量难度休息、不揭晓答案、点击切题、结束整局才结算积分。
**架构：** 保留 GameSession / GameScene 分工；回合独立计数，整局累计成长报告；每日积分账本持久化在 GrowthStats，兼容旧档案。
**技术：** Swift、SwiftUI、SpriteKit、SwiftData、Swift Testing。
**需求来源：** 本次用户消息；“不同通知”已确认指不同积分来源。

## 约束与规则
- 不提交、不推送；保留现有植物、阳光与道具跨回合状态。
- 每回合题量在首回合基础上增加 easy 2 / normal 3 / hard 4；回合数无上限。
- 回合间休息 = 题量 × 难度权重（1/2/3）秒，最少 10 秒、最多 90 秒；倒计时后手动继续，允许结束结算。
- 每日积分上限：答题 100、过关评分 100、每日首胜 10、升级 90、徽章 100；耗尽不补发。
- 无作答不得领取奖励；答题积分按有效作答量折算（至少 6 题才享全额正确率奖励），防止单题退出刷奖励。
- 保留每日第六局起经验和基础奖励减半，额外硬上限覆盖所有重复来源。
- 仅结束整局写成长与对局；回合页仅显示本回合评分，不调用成长结算。
- 点击题号或战场僵尸切换，保留各题错误选项，暂停/大招/休息禁止切换。

## 实施与验证
- [x] 新增积分与会话回归测试，先验证旧行为失败。
- [x] 修改 GrowthRules / GrowthState：各来源额度、跨天重置、旧档读取、零题奖励拦截；验证持久化后仍限额。
- [x] 修改 GameSession / GameScene：回合与休息状态、重启出怪、幂等击杀发阳光、手动选目标、主动结束一次结算。
- [x] 修改 AnswerPanel / GameView / ResultView：移除答案提示，切题栏、回合评分页、结算与限额说明。
- [x] 运行 swift test 全套测试及 iOS 构建（环境可用时），检查 diff 与 detect_changes。

## 重点边界
- 最后一只僵尸动画回调、重复击杀不能重复加阳光或结算。
- 连续回合出怪必须恢复；休息期间不出怪、不作答。
- 错题切换回来不能清除首答错误状态；大招暂停不能恢复游戏。
- 主动结束/离开页面/失败不能重复结算。
- 跨日、重启、旧存档、超额升级和徽章积分均受限制。

## 实际验证结果
- 使用完整 Xcode 工具链（DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer）；系统 CommandLineTools 缺少 SwiftData 宏插件，首次尝试未能编译，切换后解决。
- swift test：LearnCore 89 项、LearnGame 46 项，共 135 项通过。
- xcodebuild：LearnDefense，generic/platform=iOS Simulator，arm64 / x86_64，构建成功。
- git diff --check 通过。
- GitNexus detect_changes(scope: all)：92 个变更符号、64 个受影响流程，partial=false、truncated=false，风险 critical（核心战斗状态链路）；结合实际 diff、完整测试检查。新测试及本计划为未跟踪文件，另行检查，不以图结果证明覆盖它们。
- 保留既有 DiagLog nonisolated(unsafe) 警告；Xcode 另提示未使用 AppIntents，元数据提取跳过。
- 未进行真机交互验证；未提交、推送或合并。

## 后续调整（以此节覆盖原休息规则）
- 前 3 回合各休息 10 秒，第 4 回合 15 秒，其后每回合加 5 秒，最多 90 秒。
- 同一局选定的知识点中，每 3 题穿插一次 needsReview 错题；没有错题/没有新题时回退到可用题目；连对两次后退出待复习集合。
- 正误均使用本地生成的短提示音，不再播报正误语音，也不请求 TTS。
- StoredConfigFile 的 game-rules.json 保存独立运行配置；首次初始化默认值，syncConfig 只覆盖原有内置配置，不删除运行配置。
- 配置键：initialRestRounds、initialRestSeconds、restIncrementSeconds、maxRestSeconds、questionIncrement（easy/normal/hard）、reviewEvery、coinLimits（answers/completion/firstWin/level/badge）。
- 通过 LearnDatabase.saveGameRules 保存，AppModel 启动时读取；重新启动应用后生效。缺失/无效字段回退到默认值，积分上限允许设为 0；数据库不可用时回退默认值。
- 本次全套 swift test：LearnCore 92 项 + LearnGame 47 项 = 139 项通过；真机 Debug 构建成功。
- detect_changes(scope: all)：116 个符号、91 个影响流程，partial=false、truncated=false，risk=critical；新建文件另行阅读和测试检查。
