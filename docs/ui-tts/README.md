# 朗读语音（TTS）设置 UI 设计稿

家长专区的「朗读语音设置」页，支持豆包（火山引擎）、讯飞两家云端 TTS，用 Tab 切换，并支持两级权重。尺寸和 `docs/ui-growth` 一致：11 寸 iPad 横屏 1194×834 pt，PNG 为 @2x。

| 文件 | 内容 |
|---|---|
| `01-朗读语音设置.html` | 可交互稿：点 Tab 切换、点 −/＋ 改服务商权重、拖音色滑块，百分比实时重算。URL 加 `#doubao` / `#xfyun` 打开对应 Tab |
| `01-朗读语音设置-豆包.png` | 豆包 Tab |
| `01b-朗读语音设置-讯飞.png` | 讯飞 Tab（含额度预警、权重 0 的停用音色） |
| `02-stitch-朗读语音设置.html` / `.png` | 同一需求用 Stitch 生成的版本，供对比。只有豆包 Tab 的静态稿，Tab 不能切换，权重百分比不会联动 |

## 交互规则

- **第一级：服务商权重**（左栏）。整数 0~10，按 `权重 / 合计` 换算成比例，每次朗读按比例随机挑一家；填 0 等于暂停这一家。顶部比例条和 Tab 上的「权重 N%」同步显示。
- **第二级：音色权重**（Tab 内）。选中某一家后，在这家的音色里再按权重挑一个；音色权重为 0 显示为「停用」并置灰。
- **出错切换**：每家可配超时时间、失败重试次数；超时 / 失败 / 额度用完时把这次请求交给另一家；两家都不可用时用 iPad 系统语音（即现有 `Speech` 里的 `AVSpeechSynthesizer`），系统语音不参与权重。
- **账号密钥**：豆包为 App ID / Access Token / Cluster，讯飞为 APPID / APIKey / APISecret；密钥默认打码，点眼睛查看。「测试连接」显示连通状态、延迟或额度预警。
- **朗读参数**：语速、音调、音量按服务商分别设置，同一家的音色共用。
- **试读**：按当前权重随机挑音色读一遍，显示用了哪个音色和出声耗时。
- 页面带「家长专区」标识，修改后顶部提示未保存数量，点「保存」才生效。

## 说明

- 音色 ID（如 `BV700_streaming`、`xiaoyan`）和左下「最近 100 次朗读」的统计数字都是示意，接入时以两家控制台实际开通的音色为准。
- 和 `ui-growth` 一样使用 Tailwind CDN，需要联网打开。
- `01` 是手写的；`02-stitch` 由 Stitch 在「字灵守卫 · 成长系统 UI」项目（id `8521719561410772302`）生成，页面名「🔒 朗读语音设置 · 家长专区 - 字灵守卫」，HTML 原样下载，未改动。

重新导出 PNG：

```bash
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --hide-scrollbars \
  --window-size=1194,834 --force-device-scale-factor=2 --virtual-time-budget=10000 \
  --screenshot=01-朗读语音设置-豆包.png "file://$PWD/01-朗读语音设置.html#doubao"
```
