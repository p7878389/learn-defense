# 雷霆大招透明素材

本目录四张 PNG 与 原雷霆任务的 `docs/ui-ultimate-thunder/art-sample-v1/assets/` 中的原图逐字节一致。
由内置 ImageGen 按用户认可的设计图生成，提示词、原始尺寸与 SHA-256 见当前工作区 `docs/battle-ui/provenance/` 的 `prompts.json`、`cloud-prompt.txt`、`asset-manifest.json`。

- `button-shell.png`：金边与闪电徽章，不包含文字、数字或进度格。
- `storm-clouds.png`：雷云，包含柔和透明边缘。
- `lightning.png`：白芯雷柱、分叉与蓝色辉光，独立于云层和落点。
- `impact.png`：命中爆光、椭圆电环与金色火花。

运行时由 `ThunderArtwork` 使用 ImageIO 缩略解码：按钮及雷柱最大边 1024，雷云 1536，命中 768。图片与纹理缓存共享，不在每次施法时重复解码。保持 alpha 和线性过滤，不使用黑底色键。
