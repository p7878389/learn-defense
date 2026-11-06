# 内置语音

App 自带的高质量语音，文件名为 `<文本key>.mp3`（规范化文本的 SHA-256 前 32 位十六进制，见 `SpeechText.key(for:)`）。
朗读时按「题库自带 → 这里 → 运行时缓存 → 系统语音」的顺序查找。

用火山引擎（豆包语音）为内置题库和游戏提示语生成：

```bash
cd Packages/LearnKit
VOLC_TTS_API_KEY=<你的 API Key> swift run speech-pack --bundled --game-lines \
  --out Sources/LearnGame/Resources/Speech
```

目录为空也没关系：配置了 API Key 后 App 会在运行时生成并缓存，没配置时用系统语音。
