# 后续优化 Implementation Plan

**Goal:** 处理并发隔离、题目共享状态和资源缓存，并测量经典战斗循环。

**Architecture:** 保留 SwiftUI 的状态通知机制；以受控题目集合替代跨文件字典写入。
资源缓存按估算像素成本设置上限，淘汰缓存引用而保留正在播放的节点引用。

**Tech Stack:** Swift、SpriteKit、Swift Testing、Instruments。

**Spec:** 用户“按建议优化”，延续 docs/code-organization.md 的前四项建议。

## 约束

- 所有代码文件不超过 400 行。
- 保持伤害、答题统计、暂停、结算重试和动画时序。
- 不引入依赖，不提交、推送或合并。
- 不重做视觉资源；本次只修复原效果回调的线程与生命周期约束。

## 实施

- [x] 新增可选 Release 测量，记录全角色资源加载与 30 怪物、40 防御节点的主循环基线。
- [x] 尝试 Instruments 采样，按实测结果决定是否增加战斗索引。
- [x] `Effects.swift` 明确首领预警主线程入口，回调弱引用场景，保持同步时序。
- [x] 新增 `SessionQuestions.swift` 受控维护题目、首显时间与错选集合，修改三个 GameSession 扩展复用它。
- [x] 先补题目替换、删除、重复错选和回合清空回归，再实施状态封装。
- [x] 新增带成本上限的资源缓存，覆盖 LRU、重复插入、超大资源、清理后活动引用和重新加载。
- [x] 接入 `UnitSprites`，为 iOS 内存警告释放缓存持有；统计说明采用估算缓存成本，不等同 GPU 实际占用。
- [x] 复测缓存与战斗场景，完整 Swift 测试、iOS 构建、行数和差异检查。
- [x] 刷新 GitNexus，执行 detect_changes，更新报告。
