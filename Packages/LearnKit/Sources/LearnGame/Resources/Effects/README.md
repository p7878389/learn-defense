# SpriteKit 特效资源

本目录的 `.sks` 是维护源文件，构建时直接打包，不重新生成覆盖。V1 的 InkDrop、ImpactRing、ImpactFlash 三张纹理由 CoreGraphics 几何绘制生成；V1 粒子与场景已用 Xcode 27.2 打开并保存验证。

V2 在此基础上使用内置 ImageGen 制作六张透明翡翠/金色特效纹理，增加 PeaMuzzle、PeaFlight、DefeatBloom，升级 PeaImpact 与 CombatActions（12 个命名动作）。这些 V2 资源已做原生 API 加载、实际渲染、暂停/清理验证；未重新宣称所有 V2 文件都完成 Xcode 保存往返。设计与来源见 `docs/superpowers/specs/2026-11-20-sks-emerald-comet-v2.md` 和 `docs/spritekit-fx-mvp/design-v2/`。

| 文件 | Xcode 编辑方式 | 运行时用途 |
| --- | --- | --- |
| `InkBurst.sks` | 粒子编辑器 | 墨点退场、掉防具、地雷、植物损坏 |
| `PeaMuzzle.sks` | 场景编辑器 | 枪口亮核与能量弧 |
| `PeaFlight.sks` | 场景编辑器 | 附着弹体的循环彗星尾焰 |
| `PeaImpact.sks` | 场景编辑器 | flash / ring / echo / slashA / slashB / debris |
| `DefeatBloom.sks` | 场景编辑器 | 击败光冠、外环与放射碎屑 |
| `CombatActions.sks` | SpriteKit Action 编辑器 | HitReaction、ImpactFlash、ImpactRing、ImpactLifetime 等 12 个命名动作 |
| `InkDrop.png` | 透明纹理 | 墨滴和命中碎屑 |
| `ImpactRing.png` / `ImpactFlash.png` | V1 透明纹理 | 保留初版素材，V2 组合改用下列素材 |
| `CometTail.png` / `ImpactStar.png` / `EnergySlash.png` | ImageGen 透明纹理 | 彗星尾 / 撞击星 / 能量弧 |
| `ShockRing.png` / `EnergyShard.png` / `DefeatCorona.png` | ImageGen 透明纹理 | 断裂环 / 尖角碎屑 / 击败光冠 |

## 如何调整

1. 在 Xcode 打开 `.sks`。粒子选 Attributes Inspector；动作库选对应命名动作的时间线。
2. 修改粒子速度、寿命、方向、透明度与大小曲线，或动作的时长、角度、缩放。
3. 保存文件。重新运行 `FXResourceTests` 或导出预览；修改资源不会改变 Swift 业务逻辑，但仍需重新打包。
4. 若替换贴图，Texture 栏设置同目录 PNG 文件名，同时将节点 User Data 的 `texture` 改为不带扩展名的名字。包内加载使用该字段，避免依赖主 App bundle。
5. V2 六张纹理保持金白/翡翠/青蓝多色材质，节点不设置 `tint`。若后续要做单色变体，可启用 `tint` 绑定调用方颜色，但会覆盖原材质颜色层次。墨点入口仍保留现有 API，颜色、数量、整体比例由调用方传入。

## 稳定约定

- 组合场景根节点名为 `effect`，原点表示命中位置；布局尺寸用场景点。
- `userData.texture`：本目录 PNG 名字；运行时统一解析并缓存。
- `userData.tint`：可选的调用方颜色绑定；V2 多色素材不启用，InkBurst 的动态颜色沿用原接口。
- `userData.action`：`CombatActions.sks` 中的动作名。effect → 对应有限生命周期；flight/comet → CometPulse 循环并随弹体销毁。
- **不要依赖 `run(..., withKey:)` 保存到场景的运行时键。** 实测 Xcode 保存会清除/改写这些键。固定动作独立存放在原生 Action 库，用 `SKAction(named:from:)` 加载。
- 场景编辑器负责组合布局，Action 编辑器负责固定动作。MVP 的 User Data 绑定由加载器执行，因此完整组合播放以游戏内预览为准，场景编辑器不会自动解释此自定义绑定。
- 墨点是有限发射，运行时从实际发射率、数量、最长寿命推导清理期限；不要改为无限发射。
- ImpactLifetime 定义组合结束时间；调整其他动作/粒子寿命后，应把它放在所有子效果结束之后，并运行清理测试。
- `fxResource` 等字段由运行时写入用于暂停管理，编辑时无需添加。

## 来源与验证

首版几何纹理由本任务制作；V2 六张纹理由内置 ImageGen 生成、确定性裁切缩放并检验 alpha。完整原图、提示词和素材报告保存在 `docs/spritekit-fx-mvp/design-v2/`。`.sks` 为 SpriteKit 归档；原生 Action 库结构参考本机 Xcode 模板，使用公开 `SKAction(named:from:)` 读取。

Xcode 中已将 InkBurst 的速度从 135 修改为 150 并保存，验证编辑后的归档能继续由应用加载。资源允许重新设计，不通过固定数值断言锁住视觉参数；测试验证实际播放、模板隔离、有限清理和业务语义。

参见仓库 `docs/superpowers/specs/2026-11-20-spritekit-fx-resources.md` 与 `docs/spritekit-fx-mvp/README.md`。
