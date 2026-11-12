# 雷霆大招透明素材

本目录四张 WebP 由 `scripts/import-thunder-artwork.py` 从 `docs/battle-ui/originals/` 的透明 PNG 原图烘焙而来，原图不进应用包。
原图由内置 ImageGen 按用户认可的设计图生成，提示词、原始尺寸与 SHA-256 见 `docs/battle-ui/provenance/` 的 `prompts.json`、`cloud-prompt.txt`、`asset-manifest.json`。

- `button-shell.webp`：金边与闪电徽章，不包含文字、数字或进度格。
- `storm-clouds.webp`：雷云，包含柔和透明边缘。
- `lightning.webp`：白芯雷柱、分叉与蓝色辉光，独立于云层和落点。
- `impact.webp`：命中爆光、椭圆电环与金色火花。

烘焙时已缩到运行时用得到的尺寸：按钮最大边 640，雷柱 1024，雷云 1536，命中 768。`ThunderArtwork` 只负责解码，进入战场时在后台预热；图片与纹理缓存共享，不在每次施法时重复解码。保持 alpha 和线性过滤，不使用黑底色键。
