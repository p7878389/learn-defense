# 字灵守卫

给自家孩子用的 iPad 学习塔防游戏。僵尸举着题目牌子走向书架，答对题，植物守卫就发动攻击。

- 年级：中班、大班、一～六年级；难度：入门 / 标准 / 挑战，游戏中还会按答题表现自动调速
- 幼儿园：听读音选图片或汉字，全程语音，不设失败
- 小学：看字选拼音、看拼音选字、选字填空、成语补全、古诗接下一句、手写选择题
- 答错会标出正确答案并朗读，要再点一次正确答案才能发射；答错的知识点进入错题本，之后出现得更频繁
- 成长系统：每局按年级段和难度固定题量；通关或失败后结算经验和积分，升级解锁外观，收藏馆里用积分买子弹、僵尸退场特效和道具皮肤，徽章墙收集 12 枚徽章；当天第 6 局起奖励减半，提醒休息
- 开局先进入准备阶段：把植物卡拖到草坪空位布阵，种下后不能修改；准备好后点「开始闯关」，不同难度初始阳光不同
- 打败僵尸会获得更多阳光，高血量僵尸奖励更多
- 不同僵尸需要答对 1～3 题才能打倒，头顶红点显示剩余血量；连续答对攒能量，放「成语大招」清空全场
- 打败怪物仍会掉落道具（冰冻符、爱心叶、幸运星）
- 画面：天空、远山、飘动的云和蝴蝶，按单元换背景（草地、果园、星空、书院）；图片题、头像、道具都用 3D 图片
- 答对一题会弹出单词卡（图片 + 字词 + 拼音），边打怪边再看一遍、听一遍
- 6 种僵尸、5 种植物守卫，使用透明序列帧动画；种下的植物在答对时攻击，单发、连发、光束、冰冻、击退由答题触发
- 朗读：优先播放预先生成的高质量语音（题库自带、App 内置，或在「语音设置」填火山引擎 API Key 后在后台生成并缓存），没有时用系统里品质最好的普通话语音；详见 [docs/题库格式.md](docs/题库格式.md#语音)
- 战斗动画：豌豆从嘴里射出、打中溅开，大喷菇喷孢子烟；僵尸答错时张嘴咬、铁桶铁门被打掉、被打败时掉头倒下，成语大招把僵尸烧焦，冰冻时僵尸停住不动

## 目录

```text
LearnDefense.xcodeproj      iOS App 工程（只有入口和图标）
LearnDefense/               App 入口
Packages/LearnKit/          全部代码
  Sources/LearnCore/        题库、出题、学习记录、难度（纯逻辑，可在 Mac 上直接测试）
    Resources/Packs/        内置题库 JSON
  Sources/LearnGame/        SwiftUI 界面 + SpriteKit 游戏场景
    Resources/Speech/       内置的预生成语音（<文本key>.mp3）
  Sources/SpeechPack/       speech-pack 命令行：用火山引擎为题库预先生成语音
  Tests/LearnCoreTests/     单元测试
docs/题库格式.md             题库 JSON 格式说明
docs/角色与道具扩展.md        怪物、字灵、道具、特效、背景主题的组合结构和扩展方法
docs/成长系统设计方案.md      等级、积分、徽章、外观的规则和数值
docs/ui-growth/              成长系统界面设计稿（HTML + iPad 截图）
scripts/fetch-pictures.py      下载 3D 图片（Microsoft Fluent Emoji，MIT 许可）
scripts/import-pvz-sprites.py  从固定版本 pypvz 导入植物、僵尸和弹丸序列帧
scripts/run-simulator.sh    命令行编译并在 iPad 模拟器运行
```

## 运行

植物和僵尸素材参考并取自 [wszqkzqk/pypvz](https://github.com/wszqkzqk/pypvz)，已随项目保存，无需运行时下载。来源版本、使用范围和重新导入方式见 [Sprites/SOURCE.md](Packages/LearnKit/Sources/LearnGame/Resources/Sprites/SOURCE.md)；这部分素材仅供个人学习研究，Fluent Emoji 的 MIT 许可不覆盖它们。

需要先安装 Xcode（App Store），然后切换开发工具：

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

在 iPad 模拟器里运行：

```bash
scripts/run-simulator.sh
```

只测试逻辑部分（不需要 Xcode）：

```bash
cd Packages/LearnKit && swift build --target LearnCoreTests && swift test --skip-build
```

## 装到真实的 iPad

1. 打开一次 Xcode → Settings → Accounts，登录 Apple ID（免费账号即可）。
2. iPad 用数据线连上 Mac，在 iPad「设置 → 隐私与安全性 → 开发者模式」里打开。
3. 在工程的 Signing 里选你的 Team（`PRODUCT_BUNDLE_IDENTIFIER` 如果冲突就改一个）。

免费账号装的 App 7 天后会失效，需要重新安装；付费开发者账号可以用一年。

## 导入题库

格式见 [docs/题库格式.md](docs/题库格式.md)。把 JSON 放到 iPad「文件」App →「我的 iPad」→「字灵守卫」→「Packs」，在孩子主页点「重新加载题库」。
