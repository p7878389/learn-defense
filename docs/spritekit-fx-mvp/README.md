# SKS 资源化 MVP 验收

完整方案：`../superpowers/specs/2026-11-20-spritekit-fx-resources.md`。

## 已接入的功能

- 普通圆弹：`PeaImpact.sks` 组合接触光、扩散环和碎屑。
- 墨点：`InkBurst.sks` 发射器，复用原颜色、数量、比例接口。
- 受击：原生 `CombatActions.sks` 中的 HitReaction 动作；只作用于存活精灵，保留冻色与逻辑坐标。
- 加载器：包内纹理、模板与动作缓存；每次独立实例；同步暂停和清理。

## 运行测试和导出

从本 worktree 的 `Packages/LearnKit` 运行：

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test

LEARN_FX_PREVIEW="$PWD/../../docs/spritekit-fx-mvp" \
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun swift test --filter FXResourceTests
```

预览通过实际 `GameScene.fire → ShotAttack → flash/defeat` 运行，并由 Metal / SKRenderer 按 60 fps 推进、30 fps 导出。素材演示最后一段重复调用生产 `InkBurstEffect`，显示同一资源的多实例颜色绑定；没有使用网页或合成概念图替代运行效果。

从本目录转换视频：

```sh
ffmpeg -y -framerate 30 -i frames/%03d.png -c:v libx264 -crf 18 -pix_fmt yuv420p -movflags +faststart runtime.mp4
ffmpeg -y -i runtime.mp4 -vf 'fps=20,scale=900:-1:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse' runtime.gif
```

帧和视频为可再生产物，保存在本目录但不提交；仅 `.sks`、PNG、小型文档及测试属于维护源。

## 测试覆盖

归档读取和命名动作、多实例隔离、普通命中组合、重复受击回正、冻色恢复、有限粒子清理、连发回调、暂停像素不变、暂停期间创建、回合休息继续演出、缺失资源与零数量安全处理。

## 环境边界

本机默认 CommandLineTools 缺少 SwiftData 宏插件，验证命令显式使用已安装 Xcode，不修改系统选择。iOS 模拟器 SDK 可以构建，但当前没有可用的 iPad 模拟器设备/运行时；macOS 实际渲染不能替代 iPad 真机性能与 iOS 运行验收。

## 验收记录

- 2026-11-20：完整 `swift test` 通过，LearnGameTests 157 项、LearnCoreTests 141 项，共 298 项；包含本次 12 项测试（首帧暂停另有两个参数化场景）。预览导出测试带环境变量实际运行，通过两只敌人各一次击杀结算和最终清理断言。
- iOS Simulator 通用目标 Debug 构建通过，未签名；没有可用模拟器运行时，因此未进行 iPad/iOS 实际运行或真机性能验收。
- Xcode 27.2 已打开并保存粒子与场景资源，粒子速度通过编辑器从 135 调到 150；原生动作库通过公开 API 加载与真实播放验证，尚未单独做 Action 编辑器保存往返验收。
- 回归发现原命中组合 0.56 秒让既有连发清理测试超时，已仅修改动作库为 0.48 秒、碎屑最长结束时间约 0.43 秒；未削弱旧测试。
- 通过实际像素对比确认主动暂停不继续推进画面；回合休息继续播放。独立审查发现的两种首帧暂停顺序已先复现失败，再修复并通过参数化测试；复审确认关闭。
- `git diff --check` 通过；GitNexus `detect_changes(scope: all)` 报 9 个变更符号、28 条影响流程、critical，来源为原有高耦合墨点/受击/暂停入口。图检查只列出 5 个已跟踪文件，新增加载器、测试和二进制资源另用源码审查、真实解档/播放与回归覆盖，未把图结果当完整证明。
- 原有 `GuardTests.swift` 弱引用与 `UnitSpriteTests.swift` actor 隔离相关编译警告在基线已存在，本次未扩展处理。
- 未提交、未推送、未合并；主仓库、OSS worktree 和昨晚动画修复 worktree 未修改。

## 本地效果产物

- `runtime.mp4` / `runtime.gif`：7 秒实际战斗流程。
- `impact-slow.gif`：从同一运行录像裁出的命中与退场慢放，2 倍时间、2 倍画面尺寸。
- `frames/`：210 张原始渲染帧；`preview-check.txt`：导出中的结算断言记录。
