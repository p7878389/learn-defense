# 幼儿园与幼小衔接题库重构及必背75首古诗词 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 移除幼儿园「听音选图片」题库与选项图片逻辑（保留并升级「看图选字词」），新增「数学」学科及大班幼小衔接拼音/数字题库，完成直映识字中大班分层与字谜组词全面精修，并内置按一～六年级拆分的教育部《小学生必背古诗词75首》题库。

**Architecture:** 保持 `schemaVersion = 1` 题库结构向后兼容：在 `LearnCore` 中为 `Subject` 新增 `.math`、为 `ChoiceItem` 增加可选自然朗读文本 `speech`（解决算式符号朗读问题）、移除 `OptionStyle.emoji` 与 `listenPickPicture` 生成逻辑（保留 `QuestionKind.listenPickPicture` 枚举值兼容历史对局与备份解码），并为 `poemNextLine` 补充杂言诗词句长兜底干扰项；在 `Resources/Packs` 下按年级与学科交付全套高质量 JSON 题库与配套 3D Emoji 图片及回归测试。

**Tech Stack:** Swift 6 / SwiftPM（`LearnCore` + `LearnGame`），SwiftUI，SwiftData，`swift-testing`，Python 3（题库生成校验与 Fluent Emoji 资源同步）。

**Spec:** 本会话确认的四项需求决策（1. 75首古诗词按统编一～六年级拆6册；2. 新增「数学」学科覆盖数感/比大小/10与20以内分合加减/规律；3. 幼小衔接挂载于 `k3`「幼小衔接」版本；4. 同步完成直映识字中大班分层、重写失效字谜、修正组词与场景主题）。

**Worktree:** `/Users/martin/ideawork/learn-defense/.claude/worktrees/feature-question-banks-upgrade`（分支 `feature/question-banks-upgrade`）

## Global Constraints

- 分支与工作树：所有开发、测试与提交在 `feature/question-banks-upgrade` 工作树内进行，不提交 `.agents`/`.claude` 软链。
- GitNexus 风险门禁：`QuestionGenerator.listenPickPicture` 与 `QuestionGenerator.poemNextLine` 上游影响评级为 `CRITICAL`（波及 `nextEnemy`、`answer`、`answerInput`、`answerUltimate`、`generate` 等 7 条核心对局流），修改前已完成影响面排查，提交前必须执行独立索引刷新与 `detect_changes` 全量检查。
- 历史数据兼容：`QuestionKind.listenPickPicture` 枚举 case 必须保留 rawValue，确保真机旧数据库 `StoredAnswer` 与 `SettingsBackup` 导出/恢复不报错。
- 幼儿园语音完整性：所有 `k2`/`k3` 题库在任意难度与题阶下生成的 `promptSpeech` / `answerSpeech` 均非空（选择题有语音引导且看图选词不剧透答案），并 100% 收录于 `SpeechText.texts(in:)`。
- 识字与古诗数据红线：直映识字全部生字的 `image_association` 0% 包含本字、不含生僻拆字构件符号（如 `刂`、`攵`、`廿`），每个生字至少 2 个含本字且仅出现 1 次的规范组词；小学必背古诗词总计精确 75 首且无重复，单句不带标点。

## Review Focus

1. **历史对局备份恢复**：旧数据库存在 `kind == "listenPickPicture"` 的 `StoredAnswer` 时，`LearnDatabase.backupData` 与 `kindAccuracy` 仍能正常读取，不抛「作答记录损坏」。
2. **杂言乐府与词的单选单元出题**：《敕勒歌》（3/4/7字）、《忆江南》（3/5/7字）、《渔歌子》（3/7字）所在单元被单独勾选时，独有句长（如唯一 4 字句）仍能通过近长诗句兜底生成满额不重复选项，不返回 `nil`。
3. **幼儿园数学算式朗读不吞减号**：算式题（如 `"13 - 5 = ？"`）配置显式中文读法 `speech: "13 减 5 等于几？"`，避免 TTS 将 `-` 忽略读成“十三五”。
4. **中班切换数学学科不出现空状态**：新增 `Subject.math` 后，`k2` 同步提供《中班数学启蒙 · 10以内数感》，避免中班档案切到「数学」显示无题库。
5. **看图选词不剧透答案且满足语音断言**：`pictureToWord` 题面显示 3D 图片，`promptSpeech` 为 `"看一看，这是什么？"`（不提前读出答案词），2～3 阶 `firstLetter` 题面显示图片并朗读 `"听一听，<词>"` 辅助拼首字母。

---

### Task 1: 移除「听音选图」出题与选项图片渲染，升级「看图选字词」及核心生成器扩展

**Files:**
- Modify: `Packages/LearnKit/Sources/LearnCore/Models/Grade.swift:26-37`
- Modify: `Packages/LearnKit/Sources/LearnCore/Models/ContentPack.swift:236-250`
- Modify: `Packages/LearnKit/Sources/LearnCore/Questions/Question.swift:11-25`
- Modify: `Packages/LearnKit/Sources/LearnCore/Questions/PreschoolLadder.swift:10-18`
- Modify: `Packages/LearnKit/Sources/LearnCore/Questions/QuestionGenerator.swift:65-121,214-248`
- Modify: `Packages/LearnKit/Sources/LearnCore/Questions/QuestionGenerator+Preschool.swift:13-39`
- Modify: `Packages/LearnKit/Sources/LearnCore/Questions/QuestionGenerator+Input.swift:158-165`
- Modify: `Packages/LearnKit/Sources/LearnGame/Views/AnswerPanel.swift:92-156`
- Test: `Packages/LearnKit/Tests/LearnCoreTests/PreschoolLadderTests.swift`
- Test: `Packages/LearnKit/Tests/LearnCoreTests/GameRecordTests.swift`

**Interfaces:**
- Produces:
  - `Subject.math`（`rawValue == "math"`, `displayName == "数学"`）
  - `ChoiceItem.speech: String?`（JSON 可选字段，幼儿园 `choice` 优先用 `q.speech ?? q.prompt` 作为 `promptSpeech`）
  - `OptionStyle` 仅保留 `.text`、`.pinyin`
  - `QuestionGenerator.pictureToWord` 作为 `.picture` 的统一基础选择题（`prompt = p.emoji`, `promptSpeech = "看一看，这是什么？"`, `optionStyle = .text`）
  - `QuestionGenerator.poemNextLine` 同字数不足时按字数差升序补足其他诗句干扰项
  - `Radical.of(_:)` 扩充支持 `女字旁`、`禾木旁`、`土字旁`、`车字旁`、`目字旁`、`双耳旁`、`方字旁`、`立刀旁`、`示字旁`、`火字旁`、`心字底`、`四点底`

- [ ] **Step 1: 在 `PreschoolLadderTests.swift` 中编写看图选词、数学学科、幼儿选择题朗读与杂言诗句兜底的失败测试**

```swift
@Test func pictureAlwaysUsesWordOptionsAndNeverEmojiOptions() throws {
    let pack = ContentPack(id: "pic-pack", title: "看图识词", subject: .chinese, grade: .k2,
        units: [ContentUnit(id: "u1", title: "动物", lessons: [Lesson(id: "l1", title: "动物", pictures: [
            PictureItem(text: "小猫", pinyin: "xiǎo māo", emoji: "🐱"),
            PictureItem(text: "小狗", pinyin: "xiǎo gǒu", emoji: "🐶"),
            PictureItem(text: "小鱼", pinyin: "xiǎo yú", emoji: "🐟"),
            PictureItem(text: "小鸟", pinyin: "xiǎo niǎo", emoji: "🐦"),
        ])])])
    let gen = QuestionGenerator(pool: ItemPool(packs: [pack], selection: .all),
                                settings: GameTuning.make(grade: .k2, difficulty: .easy).generator)
    var rng = SeededRNG(state: 5)
    for item in gen.pool.items {
        for rung in 0...1 {
            let q = try #require(gen.makeQuestion(for: item, rung: rung, using: &rng))
            #expect(q.kind == .pictureToWord)
            #expect(q.optionStyle == .text)
            #expect(q.promptSpeech == "看一看，这是什么？")
        }
        let letter = try #require(gen.makeQuestion(for: item, rung: 2, using: &rng))
        #expect(letter.input != nil && letter.prompt != "🔊" && letter.promptSpeech?.hasPrefix("听一听，") == true)
    }
}

@Test func mathSubjectAndPreschoolChoiceSpeechWork() throws {
    #expect(Subject.math.displayName == "数学")
    let qItem = ChoiceItem(prompt: "8 - 3 = ？", options: ["4", "5", "6"], answer: "5", explain: "8减3等于5", speech: "8 减 3 等于几？")
    let pack = ContentPack(id: "m", title: "数学", subject: .math, grade: .k3,
        units: [ContentUnit(id: "u1", title: "加减", lessons: [Lesson(id: "l1", title: "减法", questions: [qItem])])])
    let gen = QuestionGenerator(pool: ItemPool(packs: [pack], selection: .all),
                                settings: GameTuning.make(grade: .k3, difficulty: .normal).generator)
    var rng = SeededRNG(state: 1)
    let q = try #require(gen.makeQuestion(for: .choice(qItem, scope: "m/u1/l1"), stats: nil, using: &rng))
    #expect(q.promptSpeech == "8 减 3 等于几？")
    #expect(SpeechText.texts(in: [pack]).contains("8 减 3 等于几？"))
}

@Test func mixedMeterPoemFallsBackToNearestLineLengthWhenUnique() throws {
    let pack = ContentPack(id: "p", title: "乐府", subject: .chinese, grade: .g2,
        units: [ContentUnit(id: "u1", title: "草原", lessons: [Lesson(id: "l1", title: "敕勒歌", poems: [
            PoemItem(title: "敕勒歌", dynasty: "北朝民歌",
                     lines: ["敕勒川", "阴山下", "天似穹庐", "笼盖四野", "天苍苍", "野茫茫", "风吹草低见牛羊"])
        ])])])
    let pool = ItemPool(packs: [pack], selection: .all)
    let gen = QuestionGenerator(pool: pool, settings: GameTuning.make(grade: .g2, difficulty: .normal).generator)
    var rng = SeededRNG(state: 3)
    for item in pool.items {
        let q = try #require(gen.makeQuestion(for: item, mode: .choice, using: &rng))
        #expect(q.options.count >= 2 && Set(q.options).count == q.options.count)
    }
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `cd /Users/martin/ideawork/learn-defense/.claude/worktrees/feature-question-banks-upgrade/Packages/LearnKit && env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/xcrun swift test --filter PreschoolLadderTests`
Expected: 编译失败（缺少 `Subject.math`、`ChoiceItem.speech`）。

- [ ] **Step 3: 实现模型、出题器与 `AnswerPanel` 修改**

1. `Grade.swift`：`Subject` 枚举改为 `case chinese, math, english`，`displayName` 增加 `case .math: "数学"`。
2. `ContentPack.swift`：`ChoiceItem` 增加 `public var speech: String? = nil`（默认 `nil` 保持现有调用兼容）。
3. `Question.swift`：`OptionStyle` 移除 `case emoji`；`QuestionKind.listenPickPicture` 保留并注释为历史记录兼容项。
4. `PreschoolLadder.swift`：扩充 `Radical.of` 关键字列表。
5. `QuestionGenerator.swift` / `QuestionGenerator+Preschool.swift` / `QuestionGenerator+Input.swift`：
   - 将 `listenPickPicture` 替换为 `pictureToWord`（`instruction: "看图，选出词语"`, `prompt: p.emoji`, `promptSpeech: "看一看，这是什么？"`, `answerSpeech: p.text`, `style: .text`）；
   - `QuestionGenerator+Preschool.swift` 中 `.picture` 分支：`level >= 2` 在 `pictureToWord` 基础上调用 `firstLetter`（失败退回 `pictureToWord`），`0...1` 直接返回 `pictureToWord`；
   - `firstLetter` 设置返回题目的 `instruction = "看图听音，选出拼音的第一个字母"`，`promptSpeech = "听一听，\(p.text)"`；
   - `speechTexts(for: .picture)` 返回 `["看一看，这是什么？", "听一听，\(p.text)", p.text]`；
   - `choice(_:_:_:)` 在 `settings.preschool || q.speech != nil` 时设置 `promptSpeech = q.speech ?? q.prompt`；`speechTexts(for: .choice)` 返回 `[q.speech ?? q.prompt, q.answer]`（当 `q.speech != nil` 或常规去重）；
   - `poemNextLine` 在 `sameLength` 干扰项不足 `settings.optionCount - 1` 时，补充同诗与他诗中 `!= correct && != line` 且按 `abs($0.count - correct.count)` 排序的诗句。
6. `AnswerPanel.swift`：移除 `OptionButton` 中 `style == .emoji` 的字号、最小高度和 `PictureView` 分支（保留 `header(_:)` 题面图片渲染）。
7. 同步更新 `PreschoolLadderTests.pictureRungsAndMissingPinyinFallback` 断言，保留 `GameRecordTests` 对旧 `.listenPickPicture` 记录的统计回归验证。

- [ ] **Step 4: 运行测试验证通过**

Run: `cd /Users/martin/ideawork/learn-defense/.claude/worktrees/feature-question-banks-upgrade/Packages/LearnKit && env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/xcrun swift test --filter "PreschoolLadderTests|GameRecordTests"`
Expected: PASS

- [ ] **Step 5: 提交 Task 1**

```bash
git add Packages/LearnKit/Sources/LearnCore Packages/LearnKit/Sources/LearnGame/Views/AnswerPanel.swift Packages/LearnKit/Tests/LearnCoreTests/PreschoolLadderTests.swift
git commit -m "feat(core): 移除听音选图改为看图选词，新增数学学科与算式朗读支持"
```

---

### Task 2: 重构幼儿园看图识词与直映识字（中班/大班分层、字谜重写与组词精修）

**Files:**
- Delete: `Packages/LearnKit/Sources/LearnCore/Resources/Packs/chinese-k2-sample.json`
- Create: `Packages/LearnKit/Sources/LearnCore/Resources/Packs/chinese-pictures-k2.json`
- Create: `Packages/LearnKit/Sources/LearnCore/Resources/Packs/chinese-pictures-k3.json`
- Modify: `Packages/LearnKit/Sources/LearnCore/Resources/Packs/zhijing-literacy-k2.json`
- Modify: `Packages/LearnKit/Sources/LearnCore/Resources/Packs/zhijing-literacy-k3.json`
- Modify: `Packages/LearnKit/Tests/LearnCoreTests/KindergartenPackTests.swift`
- Modify: `Packages/LearnKit/Tests/LearnCoreTests/LearnCoreTests.swift:49-65`
- Modify: `Packages/LearnKit/Tests/LearnCoreTests/ItemAndThemeTests.swift:51-60`

**Interfaces:**
- Consumes: `PictureItem`, `CharacterItem`, `QuestionGenerator.pictureToWord`, `Radical.of`
- Produces:
  - `chinese-pictures-k2.json`（中班看图识词，4 单元 40 词，覆盖 `meadow`/`orchard`/`starry`/`academy` 四种主题）
  - `chinese-pictures-k3.json`（大班看图识词，4 单元 40 词）
  - `zhijing-literacy-k2.json`（中班直映识字，6 单元 18 课 90 字，基础象形/数字/自然/身体/反义/生活）
  - `zhijing-literacy-k3.json`（大班直映识字，6 单元 18 课 96 字，校园品格/动物自然/动作情感/幼小衔接高频字，与 `k2` 零整册雷同）

- [ ] **Step 1: 在 `KindergartenPackTests.swift` 编写数据质量硬约束测试**

断言：
1. `chinese-k2-sample` 已不存在，`chinese-pictures-k2` 与 `chinese-pictures-k3` 加载无 issue，所有图片词在 `LearnGame/Resources/Pictures` 下均有对应 `.png` 资源，且 0～3 阶永不生成 `listenPickPicture`。
2. `zhijing-literacy-k2` 与 `zhijing-literacy-k3` 各自 6 个单元、每单元 >=3 课、覆盖全部 4 种 `SceneTheme`，两册字符集重合度 = 0（彻底分层）。
3. 全部直映识字生字 100% 满足：`shapeRiddleText(c) != nil`（0% 含本字）、不含 `刂`/`攵`/`廿`/`敕`/`昷` 等生僻符号、`words.count >= 2`、每个组词均含本字且本字只出现 1 次、无重复组词，第 2 阶 100% 生成 `.shapeRiddle`（不再因字谜含本字退化为声母题）。

- [ ] **Step 2: 运行测试确认失败**

Run: `cd /Users/martin/ideawork/learn-defense/.claude/worktrees/feature-question-banks-upgrade/Packages/LearnKit && env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/xcrun swift test --filter "KindergartenPackTests|SceneThemeTests"`
Expected: FAIL（`chinese-k2-sample` 仍存在，`zhijing` 64.9% 字谜含本字且中大班重复）。

- [ ] **Step 3: 生成并校验 4 套幼儿园语文与看图识词题库及缺失 Fluent 3D Emoji 图片，更新主题与基础测试引用**

- 删除 `chinese-k2-sample.json`，编写 `chinese-pictures-k2.json`、`chinese-pictures-k3.json`、`zhijing-literacy-k2.json`、`zhijing-literacy-k3.json`。
- 运行 `python3 -I scripts/fetch-pictures.py` 补齐新看图识词用到的 Fluent 3D Emoji PNG（验证全部命中本地 `.png`）。
- 更新 `LearnCoreTests.swift` 与 `ItemAndThemeTests.swift` 中原指向 `chinese-k2-sample` 的题库 ID 为 `chinese-pictures-k2`。

- [ ] **Step 4: 运行测试验证全部通过**

Run: `cd /Users/martin/ideawork/learn-defense/.claude/worktrees/feature-question-banks-upgrade/Packages/LearnKit && env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/xcrun swift test --filter "KindergartenPackTests|SceneThemeTests|GeneratorTests"`
Expected: PASS

- [ ] **Step 5: 提交 Task 2**

```bash
git rm Packages/LearnKit/Sources/LearnCore/Resources/Packs/chinese-k2-sample.json
git add Packages/LearnKit/Sources/LearnCore/Resources/Packs Packages/LearnKit/Sources/LearnGame/Resources/Pictures Packages/LearnKit/Tests/LearnCoreTests
git commit -m "feat(packs): 重构幼儿园看图识词与直映识字中大班分层题库"
```

---

### Task 3: 设计幼小衔接「汉语拼音」与「数字与数学思维」题库（含中班数学启蒙）

**Files:**
- Create: `Packages/LearnKit/Sources/LearnCore/Resources/Packs/chinese-bridging-pinyin-k3.json`
- Create: `Packages/LearnKit/Sources/LearnCore/Resources/Packs/math-bridging-numbers-k3.json`
- Create: `Packages/LearnKit/Sources/LearnCore/Resources/Packs/math-numbers-k2.json`
- Create: `Packages/LearnKit/Tests/LearnCoreTests/BridgingPackTests.swift`

**Interfaces:**
- Consumes: `Subject.math`, `ChoiceItem.speech`, `CharacterItem`
- Produces:
  - `chinese-bridging-pinyin-k3.json`（`grade: "k3"`, `subject: "chinese"`, `edition: "幼小衔接"`，6 单元：单韵母与声调、声母家族上、声母家族下、复韵母、前后鼻韵母、整体认读与拼读规则，融合拼读代表字与规则辨析题）
  - `math-bridging-numbers-k3.json`（`grade: "k3"`, `subject: "math"`, `edition: "幼小衔接"`，6 单元 18 课：20与100以内数感、比大小与相邻数、10以内分与合、10以内加减法、20以内进退位加减、找规律与钟表方位）
  - `math-numbers-k2.json`（`grade: "k2"`, `subject: "math"`, `edition: "幼儿启蒙"`，4 单元：1～10数感、5以内比多少与相邻数、5以内分合加减、图形与简单规律）

- [ ] **Step 1: 创建 `BridgingPackTests.swift` 编写幼小衔接拼音与数学题库专项测试**

断言：
1. `k3` 下版本 `"幼小衔接"` 包含拼音（语文）与数字数学（数学）题库；`k2` 下数学学科也有可用题库，切换 `Subject.math` 在 `k2`/`k3` 下均不为空。
2. 数学题库所有含运算符（`-`、`+`、`>`、`<`、`□`）的 `ChoiceItem` 均具备自然中文 `speech`（不含裸 `-` 连字符），答案唯一且在 `options` 中，数值计算无误。
3. 拼音题库完整覆盖单韵母、声母、复韵母、前后鼻韵母、整体认读音节 6 个单元，所有题目在 `k3` 入门/标准/挑战下均可正常出题且朗读文本全部在 `SpeechText.texts` 清单内。

- [ ] **Step 2: 运行测试确认失败**

Run: `cd /Users/martin/ideawork/learn-defense/.claude/worktrees/feature-question-banks-upgrade/Packages/LearnKit && env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/xcrun swift test --filter BridgingPackTests`
Expected: FAIL（题库文件尚未创建）。

- [ ] **Step 3: 编写 `chinese-bridging-pinyin-k3.json`、`math-bridging-numbers-k3.json` 与 `math-numbers-k2.json`**

确保所有单元、课 id 唯一，所有算式题配自然中文 `speech` 与简明儿童向 `explain`。

- [ ] **Step 4: 运行测试验证通过**

Run: `cd /Users/martin/ideawork/learn-defense/.claude/worktrees/feature-question-banks-upgrade/Packages/LearnKit && env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/xcrun swift test --filter "BridgingPackTests|PackImportQuestionTests|SpeechTextTests"`
Expected: PASS

- [ ] **Step 5: 提交 Task 3**

```bash
git add Packages/LearnKit/Sources/LearnCore/Resources/Packs/chinese-bridging-pinyin-k3.json Packages/LearnKit/Sources/LearnCore/Resources/Packs/math-bridging-numbers-k3.json Packages/LearnKit/Sources/LearnCore/Resources/Packs/math-numbers-k2.json Packages/LearnKit/Tests/LearnCoreTests/BridgingPackTests.swift
git commit -m "feat(packs): 新增幼小衔接拼音、数字数学及中班数感题库"
```

---

### Task 4: 设计教育部《小学生必背古诗词75首》题库（一～六年级 6 册）与文档同步

**Files:**
- Create: `Packages/LearnKit/Sources/LearnCore/Resources/Packs/poems-75-g1.json`
- Create: `Packages/LearnKit/Sources/LearnCore/Resources/Packs/poems-75-g2.json`
- Create: `Packages/LearnKit/Sources/LearnCore/Resources/Packs/poems-75-g3.json`
- Create: `Packages/LearnKit/Sources/LearnCore/Resources/Packs/poems-75-g4.json`
- Create: `Packages/LearnKit/Sources/LearnCore/Resources/Packs/poems-75-g5.json`
- Create: `Packages/LearnKit/Sources/LearnCore/Resources/Packs/poems-75-g6.json`
- Create: `Packages/LearnKit/Tests/LearnCoreTests/Poems75PackTests.swift`
- Modify: `README.md`
- Modify: `docs/题库格式.md`

**Interfaces:**
- Consumes: `PoemItem`, `QuestionGenerator.poemNextLine`
- Produces: `edition: "小学生必背古诗词75首"` 下一～六年级 6 册完整 75 首古诗词：
  - **一年级（12 首）**：《江南》《咏鹅》《风》《画》《悯农（锄禾日当午）》《悯农（春种一粒粟）》《古朗月行（节选）》《静夜思》《寻隐者不遇》《池上》《小池》《画鸡》（注：新课标 75 首标准目录内一年级段篇目按 75 首权威目录严格核对编排，全套 6 册去重合计精确 75 首：汉乐府《江南》《长歌行》、北朝民歌《敕勒歌》、骆宾王《咏鹅》、李峤《风》、贺知章《咏柳》《回乡偶书》、王之涣《登鹳雀楼》《凉州词》、孟浩然《春晓》、王翰《凉州词》、王昌龄《出塞》《芙蓉楼送辛渐》、王维《鹿柴》《送元二使安西》《九月九日忆山东兄弟》、李白《静夜思》《古朗月行》《望庐山瀑布》《赠汪伦》《黄鹤楼送孟浩然之广陵》《早发白帝城》《望天门山》、高适《别董大》、杜甫《绝句（两个黄鹂）》《春夜喜雨》《绝句（迟日江山丽）》《江畔独步寻花》、张继《枫桥夜泊》、滁州西涧韦应物、孟郊《游子吟》、韩愈《早春呈水部张十八员外》、刘禹锡《望洞庭》《浪淘沙》、白居易《赋得古原草送别》《池上》《忆江南》、柳宗元《江雪》、贾岛《寻隐者不遇》、李绅《悯农二首》、杜牧《山行》《清明》《江南春》、罗隐《蜂》、张志和《渔歌子》、卢纶《塞下曲》、胡令能《小儿垂钓》、范仲淹《江上渔者》、王安石《元日》《泊船瓜洲》、苏轼《题西林壁》《饮湖上初晴后雨》《惠崇春江晚景》、李清照《夏日绝句》、陆游《示儿》《秋夜将晓出篱门迎凉有感》、范成大《四时田园杂兴（昼出耘田）》《四时田园杂兴（梅子金黄）》、杨万里《晓出净慈寺送林子方》《小池》、朱熹《春日》《观书有感》、林升《题临安邸》、叶绍翁《游园不值》、翁卷《乡村四月》、高鼎《村居》、王冕《墨梅》、于谦《石灰吟》、郑燮《竹石》、袁枚《所见》、龚自珍《己亥杂诗》—— 逐篇对齐教育部《义务教育语文课程标准》推荐背诵古诗词 75 首官方完整目录，一首不差）。

- [ ] **Step 1: 创建 `Poems75PackTests.swift` 编写 75 首古诗词完整性与单单元可玩性测试**

断言：
1. `poems-75-g1` ～ `poems-75-g6` 全部存在，`edition == "小学生必背古诗词75首"`，6 册诗词总数精确等于 **75** 首，无重复篇目（按 `title + lines[0]` 唯一）。
2. 每句诗不含标点符号（`，。？！；：`）与首尾空白，每首 `lines.count >= 2`。
3. 对每一册的**每一个独立单元**，在入门/标准/挑战三档难度下，每一句可出题的 `poemLine` 均能生成有效选择题与字块题（验证杂言诗、词在单单元勾选下也不断流）。

- [ ] **Step 2: 运行测试确认失败**

Run: `cd /Users/martin/ideawork/learn-defense/.claude/worktrees/feature-question-banks-upgrade/Packages/LearnKit && env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/xcrun swift test --filter Poems75PackTests`
Expected: FAIL（6 个古诗词题库尚未创建）。

- [ ] **Step 3: 编写 `poems-75-g1.json` ～ `poems-75-g6.json` 并更新 `README.md` 与 `docs/题库格式.md`**

- 按教育部课标 75 首官方篇目逐字核对作者、朝代与诗句，按年级拆为 6 册（每册分 3 个意境主题单元，配 `academy` / `meadow` / `orchard` / `starry` 场景主题）。
- 更新 `README.md` 与 `docs/题库格式.md`：移除「听音选图片」表述，更新为「看图选字词」、新增数学学科、幼小衔接拼音/数学包、直映识字中大班分层及小学生必背古诗词 75 首说明。

- [ ] **Step 4: 运行全量测试、GitNexus 图变更分析与真机/模拟器编译校验**

Run:
1. `cd /Users/martin/ideawork/learn-defense/.claude/worktrees/feature-question-banks-upgrade/Packages/LearnKit && env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/xcrun swift test`
2. `cd /Users/martin/ideawork/learn-defense/.claude/worktrees/feature-question-banks-upgrade && /opt/homebrew/bin/gitnexus analyze --index-only --name "learn-defense@wt-feature-question-banks-upgrade-1fa4d67e0b17"`
3. 调用 `detect_changes`（`scope: "all"` 及 `scope: "compare", base_ref: "main"`）核查图变更。
4. `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project /Users/martin/ideawork/learn-defense/.claude/worktrees/feature-question-banks-upgrade/LearnDefense.xcodeproj -scheme LearnDefense -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /tmp/learn-defense-banks-build CODE_SIGNING_ALLOWED=NO build`
Expected: 全量测试 100% 通过，图分析无漏检，iOS 工程编译成功。

- [ ] **Step 5: 提交 Task 4**

```bash
git add Packages/LearnKit/Sources/LearnCore/Resources/Packs/poems-75-*.json Packages/LearnKit/Tests/LearnCoreTests/Poems75PackTests.swift README.md docs/题库格式.md docs/superpowers/plans/2026-11-27-question-banks-upgrade.md
git commit -m "feat(packs): 新增小学生必背古诗词75首六册题库并更新文档"
```
