# 字灵守卫 · UI 风格优化（B 档）总结与前后对照

优化分支：`fix/fresh-game-fullscreen-map`（代码基线：`2c8ad5f`）。

## 一、设计原则与 Token 收口

在保留既有绘本瓷釉胶囊按钮、SF Rounded 圆体、翡翠绿主行动与战斗纹章种植卡（62×64 pt）的前提下，补齐结构层级与语义约束：

1. **四层表面体系（`Support/DesignSystem.swift`）**
   - **L0 背景层**：`GrowthPageBackground`（纯 SwiftUI 纸面径向高光与浅草色晕）。
   - **L1 面板层**：`.appPanel(radius:tint:)`（暖白渐变、细描边与 `AppShadow.panel`，无厚底，用于大区块容器与未解锁状态卡）。
   - **L1 内嵌层**：`.appInset(radius:tint:)`（平面浅底、1pt 细描边、无阴影，用于面板内部信息格与列表行，消除“卡套卡”）。
   - **L2 交互层**：`.candyCard(...)` 与 `AppButton`（保留物理厚底与按压反馈，**仅用于可点击元素**）。
2. **色彩语义单一化**
   - **翡翠绿（`AppColor.jade`）**：每屏唯一满色 `.primary` 主按钮及选项/推荐选中态。
   - **琥珀金（`AppColor.gold`）**：仅用于积分、阳光与经验等资源数值。
   - **活力橙（`AppColor.accent`）**：仅用于大招、能量与升级/可买提示，不再用作分段控件选中态（`GrowthSegmentedPicker` 改为白色凸起滑块 + 深墨文字）。
   - **浅色入口卡**：主页「冒险闯关 / 收藏馆 / 徽章墙」改为浅底 + 语义柔边 + 角标，不再与主行动按钮抢夺视觉中心。
3. **新增统一 Token**
   - **间距 `AppSpacing`**：`xxs(4)`、`xs(8)`、`sm(12)`、`md(16)`、`lg(24)`、`xl(32)`、`xxl(48)`。
   - **阴影 `AppShadow`**：`panel`、`raised`、`floating`。
   - **动效 `AppMotion`**：`press`、`appear`、`celebrate`、`stagger(_:)` 与尊重 `accessibilityReduceMotion` 的 `View.appAppear(index:)`。
   - **弹窗脚手架 `AppModalScaffold`**：统一标题区、自适应内容区（支持 `scrollable: false` 内嵌独立滚动列表）与等宽固定底部操作栏。

## 二、模块改动清单

- **底座与样板**：`DesignSystem.swift`、`Theme.swift`、`GrowthComponents.swift`、`CandyModals.swift`、`ProfileHomeView.swift`、`GrowthHomeSection.swift`、`GameStartConfirmationView.swift`。
- **战斗外框（W1）**：`BattleChrome.swift`、`BattleScreen.swift`、`GameHUD.swift`、`BattleOverlays.swift`、`AnswerPanel.swift`、`TileAnswerView.swift`、`UltimateButton.swift`、`SeedPacketStrip.swift`、`GameView.swift`、`BattlefieldView.swift`、`AdventureView.swift`。
- **冒险地图与解锁（W2）**：`AdventureLobbyView.swift`、`AdventurePlacementPreview.swift`、`DoomShroomUnlockView.swift`。
- **成长、收藏与结算（W3）**：`CollectionView.swift`、`CollectionView+Cards.swift`、`CollectionCardMaterial.swift`、`BadgeWallView.swift`、`GrowthBadges.swift`、`ResultView.swift`。
- **档案、设置与弹窗（W4）**：`ProfilesView.swift`、`ProfileEditor.swift`、`HomeCarousel.swift`、`HomeCarousel+Cards.swift`、`HomeLawn.swift`、`ParentSettingsView.swift`、`ParentDataPane.swift`、`ParentPacksPane.swift`、`ParentVoicePane.swift`、`VoiceSettingsView.swift`、`QuestionBankPickerView.swift`、`CandyDropdown.swift`、`BattleMapPicker.swift`、`CharacterSkinPreview.swift`。

## 三、前后画面对照

| 页面 | 改前（`before/`） | 改后（`after/`） | 主要改善 |
|---|---|---|---|
| 横屏主页 | [landscape-home.png](before/landscape-home.png) | [landscape-home.png](after/landscape-home.png) | 左 60% 主战卡 + 右侧竖排浅色入口卡 + 底部草坪地景，消除底部空白与色彩冲突 |
| 竖屏主页 | [portrait-home.png](before/portrait-home.png) | [portrait-home.png](after/portrait-home.png) | 底部 200pt 森林草坪与守卫/僵尸精灵填满下半屏空白，「暂无错题」降为次级禁用态 |
| 冒险地图 | [landscape-map.png](before/landscape-map.png) | [landscape-map.png](after/landscape-map.png) | 白色滑块难度器、未解锁关卡清晰可读且无厚底、推荐关翡翠绿描边与「推荐」角标、卡片留白收紧 |
| 冒险横屏战斗 | [landscape-battle.png](before/landscape-battle.png) | [landscape-battle.png](after/landscape-battle.png) | 顶部关卡/生命/计时/暂停合为一条 `.appPanel` 状态栏，全屏铺满战场无黑边 |
| 冒险竖屏战斗 | [portrait-battle.png](before/portrait-battle.png) | [portrait-battle.png](after/portrait-battle.png) | 单条顶栏 + 紧凑底栏，最大化草坪展示空间 |
| 开战核对弹窗 | [start-confirmation.png](before/start-confirmation.png) | [start-confirmation.png](after/start-confirmation.png) | 统一 `AppModalScaffold`、2 列 `.appInset` 信息格消除卡套卡、底栏左右边缘与上方严格对齐 |
| 题库选择弹窗 | [question-bank.png](before/question-bank.png) | [question-bank.png](after/question-bank.png) | 迁移至 `AppModalScaffold(scrollable: false)`、`.appPanel` 筛选面板、翡翠绿下拉展开态 |
