# 幼儿园闯关进阶 实施方案

**目标：** 幼儿园（中班 k2 / 大班 k3）题目不再只是「听音选图 / 听音选字」，按孩子对每个知识点的掌握度逐级升阶，并让干扰项、年级、难度、怪物血量真正拉开差距。

**架构：** 新增「幼儿园题阶（PreschoolLadder）」：知识点的连续答对数决定题阶，难度决定可用题阶区间；生成器按题阶出题，题阶出不了时逐级降级。小学出题逻辑保持不变。

**技术栈：** Swift 6 / SwiftPM（LearnCore 纯逻辑 + LearnGame SwiftUI），swift-testing。

**开发位置：** worktree 分支 `feature/preschool-challenge`。

---

## 1. 题阶设计（核心）

题阶 = `min(3, ItemStats.streak)`；没见过为 0；答错时 streak 清零，因此回到 0 阶。最后的题阶会限制在难度给的区间内。

| 题阶 | 生字（直映识字等） | 图片词（启蒙示例） | 作答方式 |
|---|---|---|---|
| 0 听 | 听音选字 `listenPickChar`（原有） | 听音选图 `listenPickPicture`（原有） | 选择 |
| 1 语境 | **听词填字** `listenFillChar`：听「头发」，题面「□发」，选「头」 | **看图选词** `pictureToWord`：题面是图片，不朗读，从文字里选「苹果」 | 选择 |
| 2 回忆 | **听字谜选字** `shapeRiddle`：朗读 `image_association`（如「像张开五指的小手」）；没有字谜时改为听音选声母字块 | 选拼音首字母字块（原有 `firstLetter`） | 选择 / 单空 |
| 3 拼读 | 听音拼「声母+韵母」字块（原有 `listenPinyin` 多空） | 同 2 阶 | 多空 |

**降级链：** 3 → 2 → 1 → 0。例如组词里这个字出现两次、字谜里含有答案字本身、或者没有声母，都会降一级。最后一定落在原有的 0 阶题。

**难度对应的题阶区间：**

| | 入门 | 标准 | 挑战 |
|---|---|---|---|
| 中班 k2 | 0…1 | 0…2 | 1…3 |
| 大班 k3 | 0…1 | 1…2 | 1…3 |

- 入门最高只到 1 阶，所以仍然全是选择题；标准最多单空，挑战才有多空。这和现有 `AnswerMix`（choiceOnly / standard / challenge）的语义一致，准备阶段 `layoutSample` 预留的答题区高度也保持正确。
- 标准（大班）和挑战难度的下限是 1 阶，新知识点也不再出「听音选简单图片」。

## 2. 干扰项与年级区分

| 参数 | k2 入门 / 标准 / 挑战 | k3 入门 / 标准 / 挑战 |
|---|---|---|
| 选项数 `optionCount` | 3 / 3 / 4 | 3 / 4 / 4 |
| 干扰策略 `strategy` | easy / normal / normal | normal / normal / hard |
| 提示 `showHint` | 开 / 开 / 开 | 开 / 开 / 关 |

幼儿园挑字干扰项（`preschoolCharDistractors`）按以下规则：
- **easy**：随机，即现状。
- **normal**：同部首字和近音字交替排在前面。
- **hard**：同部首字优先，其次近音字，最后随机。

部首用关键字表从 `image_association` 里识别，如「提手旁、三点水、虫字旁、言字旁、宝盖头……」。识别不到就退回近音字。

## 3. 题量与怪物

- `pacing.json` 和 `PacingConfig.defaults` 同步修改：k2 改为 **8/10/12**（原 6/7/8），k3 改为 **10/12/14**（原 8/9/10）。修改后仍在测试要求的 6~18 范围内，且难度越高题量越多。
- 大班标准、挑战难度的波次里加入 2 血的铁桶僵尸（权重分别为 1、2）。中班和大班入门仍然只出 1 血怪。
- 幼儿园仍然不会失败（`hearts = nil`）。

## 4. 文件结构

| 文件 | 改动 |
|---|---|
| `LearnCore/Models/ContentPack.swift` | `CharacterItem` 增加 `imageHint: String?`，JSON 键为 `image_association` |
| `LearnCore/Questions/Question.swift` | `QuestionKind` 增加 `listenFillChar`、`shapeRiddle`、`pictureToWord` |
| `LearnCore/Questions/PreschoolLadder.swift`（新） | `PreschoolLadder.level(_:) -> Int`、`Radical.of(_ hint:) -> String?` |
| `LearnCore/Questions/QuestionGenerator.swift` | `GeneratorSettings.ladder: ClosedRange<Int>?`；`speechTexts` 增加可用的字谜 |
| `LearnCore/Questions/QuestionGenerator+Preschool.swift`（新） | `makeQuestion(for:stats:using:)`，以及各阶出题、幼儿园干扰项 |
| `LearnCore/Questions/QuestionGenerator+Input.swift` | `listenPinyin` 和 `firstLetter` 改为 internal 供题阶复用，逻辑不变 |
| `LearnCore/Game/Difficulty.swift` | 幼儿园参数按年级分开，加入 `ladder`，大班波次加入铁桶 |
| `LearnCore/Growth/PacingConfig.swift`、`Resources/Config/pacing.json` | 幼儿园题量 |
| `LearnGame/Game/GameSession+SceneDelegate.swift` | 出题时传入 `progress.stats[item.key]` |
| `LearnGame/Views/AnswerPanel.swift` | 有朗读的题，只要题面不是 🔊 也显示出来（「□发」要能看到） |
| `README.md`、`docs/题库格式.md` | 说明题阶，说明 `image_association` 已被使用，以及需要重新生成语音 |

## 5. 接口

```swift
// GeneratorSettings
public var ladder: ClosedRange<Int>?          // nil = 不分题阶（小学，以及旧的调用方式）

// QuestionGenerator
public func makeQuestion<R: RandomNumberGenerator>(for item: LearningItem, stats: ItemStats?, using rng: inout R) -> Question?
func makeQuestion<R>(for item: LearningItem, rung: Int, using rng: inout R) -> Question?   // 测试用，按指定题阶出题，带降级

// PreschoolLadder
public enum PreschoolLadder { public static func level(_ stats: ItemStats?) -> Int }   // 0…3
enum Radical { static func of(_ hint: String?) -> String? }
```

旧接口 `makeQuestion(for:using:)` 和 `makeQuestion(for:mode:using:)` 行为不变（大招题、样题、导入预检、现有测试都依赖它们）。

## 6. 测试（新文件 `Tests/LearnCoreTests/PreschoolLadderTests.swift`）

1. `levelFollowsStreak`：nil→0；streak 1/2/5→1/2/3；答错（streak 0）→0。
2. `rungsProduceExpectedKinds`：用直映识字 k3 的「水」测试：rung0→`listenPickChar`；rung1→`listenFillChar`，题面是挖去「水」的组词，`promptSpeech` 是组词，没有 input；rung2→`shapeRiddle`，`promptSpeech == imageHint`；rung3→有 input 且 `isMulti`。「手」的原始提示包含答案字，按防泄题规则用于降级测试。
3. `fallsBackWhenRungUnavailable`：
   - 字谜里含有答案字（如「交」）时，rung2 退回声母单空。
   - 只有叠字组词的字，rung1 退回 0 阶。
   - 没有声母的「耳」，rung3 退到不需要声母的题。
4. `difficultyClampsRung`：k3 入门，即使 streak 是 5 也没有 input；k3 标准，新知识点出 1 阶；k2 入门，新知识点出 0 阶。
5. `pictureRungs`：启蒙示例的图片词：rung1→`pictureToWord`，题面是 emoji，选项是文字，`promptSpeech == nil`；rung2→首字母字块。
6. `hardPrefersSameRadical`：k3 挑战难度下，「捕」的干扰项里至少有一个提手旁的字（捞/挖/扶/批/搭/抱）。
7. `everyLadderLineIsListed`：所有幼儿园题库、所有难度、0~3 阶出的题，朗读文本都在 `SpeechText.texts` 里。
8. `optionsAreUniqueAndAnswerable`：所有题阶都满足：选项不重复、答案在选项里、选项数不超过 `optionCount`。

同时修改的已有测试：
- `PacingTests` 与 `LearnCoreTests` 中「幼儿园只出 1 血怪」的断言，改为只对中班和大班入门要求 1 血。
- `PacingTests` 的题量断言按新值更新。

## 7. 重点核查项

- 字谜文本里出现答案字，或者组词里这个字出现两次时，必须降级，不能出送分题或无效题。
- `layoutSample` 预留的高度要和题阶区间一致：入门不能出字块题。
- 新题型的朗读要能命中预生成语音清单；字谜要在 `speech-pack --bundled` 重新生成后才有高质量语音，之前用系统语音。
- 新的 `QuestionKind` 写入对局记录和备份后，旧版 App 恢复会失败（属于正常的向前兼容限制，在文档中说明）。
- 错题复习局、大招题仍然走原有路径，不受题阶影响。

## 8. 不在本次范围

暂不做的有：找不同、归类、数感这类全新认知题型（需要新的 UI 和素材）；小学题阶；家长侧可调的题阶开关。

## 9. 实施与验证（2026-11-24）

- 已实现题阶、缺少素材时降级、同部首和近音干扰项，以及按年级区分的难度和题量。
- 普通闯关读取最新 `ItemStats`；复习局显式沿用旧接口，大招和布局样题保持原路径。
- 听词填字的可见题面和语音重播按钮可同时显示；字谜语音加入清单，尚未生成新的预录音频。
- TDD：先验证字段往返、题量和选项参数的失败，再验证题阶及会话接入的失败，实施后全部转绿；新增 9 项核心测试和 3 项对局测试。
- 基线：209 项 LearnCore 测试通过。最终 `swift test`：218 项 LearnCore、245 项 LearnGame，共 463 项通过。
- 本机 CommandLineTools 缺少 SwiftData 宏，验证命令使用 `env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/xcrun swift test`。
- `xcodebuild -project LearnDefense.xcodeproj -scheme LearnDefense -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/learn-defense-preschool-build CODE_SIGNING_ALLOWED=NO build`（同样指定 Xcode 的 `DEVELOPER_DIR`）成功。未做真机交互或视觉验收。
- GitNexus 独立索引 `learn-defense@wt-feature-preschool-challenge-953b6466e3c1` 已刷新；`detect_changes(scope: all)` 覆盖 18 个变更文件、165 个符号、48 条受影响流程。共享生成器和配置涉及多条调用链，风险评级为 critical；结合源码差异、全量测试和构建核查，不以图中缺失的调用关系作为安全证明。

## 10. 续改：答错换题防排除

- 普通闯关、复习局和大招答错后，优先从当前允许范围生成知识点、答案均不同的题；题库不足时重生成原知识点，并保证完整选项或字块顺序变化。
- 不保留已排除的错误选项，不再在多次答错后提示或高亮正确字块。重新朗读新题、重置输入与展示计时，怪物血量和当前目标保持不变；重试不给新的停怪宽限时间。
- 每张新题的实际作答独立记录到学习进度、错题及对局明细；同一次攻击换题后答对仍只得 2 分且不充能。大招一旦答错，之后答对或取消都清空能量且不释放大招。
- UI 回调携带展示题目的 ID，旧题连点、延迟输入不得答到新题。
- 验证：优先换题、小题库换序、复习范围、选择/字块/大招旧回调、错误与正确记录对应、重试奖励限制及暂停/切目标回归；最后运行全量测试和 iOS 构建。
- 验证结果：新增防排除测试先失败再通过；全量 469 项测试通过（LearnCore 218 项、LearnGame 251 项）。最后简化重试状态为由当前题目派生后，复跑相关 15 项测试通过，iOS Simulator 构建成功。
- 最终 `detect_changes(scope: all)` 覆盖 16 个变更文件、102 个符号、38 条流程，未报告 partial/truncated；共享判题调用链评级 critical，已通过记录、计分、大招、输入、切目标、暂停及全量回归核对。未做真机交互验收。
