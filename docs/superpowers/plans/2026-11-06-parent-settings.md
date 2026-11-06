# 家长设置页实施计划
**目标：** 按主检出 docs/ui-settings 的六组设计稿落地家长专区。
**架构：** SwiftUI 设置容器及确认面板；LearnCore 负责家长验证、偏好、题库文件管理、数据库快照；复用现有语音账号页、档案编辑器、StoredConfigFile。
**约束：** 不引入依赖；所有危险操作由应用内确认；不操作用户真实数据进行验证；不提交、推送。主检出的设计稿只读引用，不搬走。
**范围：** 系统/豆包语音真实能力；讯飞不展示可用状态。声音与游戏只暴露现有可工作的休息、增题、复习、积分参数。

- [x] 测试先行：验证家长锁三错冷却及重新进入、课本校验/覆盖/删除、数据库快照往返、单个孩子重置和非法备份不改原数据。
- [x] LearnCore 新增 ParentSettings / PackManager / LearnDatabase+Backup；备份包含档案、学习与成长、对局和作答、运行设置及导入课本，不含钥匙串账号和语音缓存。恢复先完整校验，再事务替换数据库及可回滚的课本目录交换。
- [x] AppModel 接入设置状态、导入、备份、重置及清空内存缓存；Speech 应用实际朗读源/速度/音调/音量/静音策略和自动朗读开关。
- [x] 首页入口替换为家长专区，每次重新验证；设置六个导航分区；导入确认、备份恢复确认、重置输入与长按确认。
- [x] Swift 测试全套、iOS 构建；原生离屏截图检查横屏布局；Git diff / detect_changes 检查。

## 验证结果
- swift test：LearnCore 102 项、LearnGame 50 项，共 152 项通过。
- generic/platform=iOS Simulator：LearnDefense 构建成功。
- 使用 NSHostingView 渲染 1194×834 页面截图，已查看语音、数据页；截图位于 /tmp/learn-defense-settings-preview。
- 环境未安装可启动的 iOS Simulator runtime，未做 iOS 点击交互及真机操作验证。没有对用户实际数据执行恢复或重置。
- 备份包括导入课本自带 Audio/*.mp3；不包括钥匙串账号、运行时语音缓存和已迁移的旧 JSON 备份。
- 旧 JSON 迁移在恢复/全量重置后通过数据库标记禁用；单孩子学习重置也保存独立标记，防止旧文件重新导入。
- 未引入依赖；语音仅展示真实支持的系统/豆包，不提供尚未实现的讯飞与混合权重。背景音乐/左手模式等设计占位功能未展示。

- detect_changes(scope: all)：49 个已跟踪变更符号、118 个影响流程；partial=false、truncated=false，risk=critical。该命令不统计未跟踪文件，新设置/备份文件已另外阅读、执行测试并纳入 iOS 构建验证。
