# 内置语音

App 自带的高质量语音：根目录的 `manifest.json` 记录「文本 → 路径」，音频按业务分类存放、以文本命名
（`game/<分类>/…`、`packs/<题库>/<单元>/<课>/…`，规则见 `SpeechCatalog` 和 docs/题库格式.md「语音」一节）。
没有清单时按旧版文件名 `<文本key>.mp3` 查找。

朗读时按「题库自带 → 这里 → 用家长账号生成的缓存 → 云端（OSS）下载的缓存 → 系统语音」的顺序查找。

用火山引擎（豆包语音）为内置题库和游戏提示语生成：

```bash
cd Packages/LearnKit
VOLC_TTS_API_KEY=<你的 API Key> swift run speech-pack --bundled --game-lines \
  --out Sources/LearnGame/Resources/Speech
```

目录为空也没关系：配置了云端地址或 API Key 后，App 会在运行时下载或生成并缓存，都没有时用系统语音。
全部内置会让安装包增大约 25 MB，一般放 OSS，以 ZIP 整包下载并校验解压即可；安装成功后离线复用。
