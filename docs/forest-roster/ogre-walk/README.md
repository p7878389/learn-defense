# 巨魔酋长行走序列

- 来源：2026-11-10，内置 image_gen 以现有 ogre.webp 为角色参考生成；不是第三方下载素材。
- 原图：source.png（1536×1024，3 列×2 行）。保留现有棕色皮肤、蓝色纹身、颅骨护甲、腰带和骨锤。
- 游戏帧：Sprites/ForestRoster/ogre-walk-0.webp 至 ogre-walk-5.webp，512×512，统一朝左，脚底 y=448。
- 处理：python3 scripts/import-ogre-walk.py；仅切帧、清理低 alpha 残留、共享缩放与脚底对齐。参数及源图边界见 frames.json。
- 播放：按实际路程一周六帧，定身冻结；施法使用原 ogre/ogre-skill。原图朝左，在向右时镜像；不再叠加通用重型怪物的整图步行摇摆。
- 原始大图只放文档目录，不随应用打包；六帧成品总计约 361 KB。

## 验证

- 六帧 512×512、alpha 范围 0～255、承重脚底 y=448；画面中补偿到原地面阴影的锚点高度。
- 森林专项 53 项测试通过，覆盖帧资源、左右原图方向、按路程选帧、定身冻结与攻击姿态切换。
- 已导出左右行走放大 GIF 并检查关键帧；没有真机交互和帧率测量。
- 全包 LearnCore 的 28 项 XCTest 与 139 项 Swift Testing 通过；图形测试没有全部通过，以下测试报告 MTLCreateSystemDefaultDevice() 返回空：iceVolleyKeepsImpactOrderAndCleansTransientEffects、ultimateBurnsZombiesWithoutDroppingHeads、freezeStopsTheWalkCycleAndThawResumesIt、breakingIntoTheBaseBitesFirst、fumeShroomPlaysAttackThenReturnsToIdle、fumeBeamHitsOnceAtTheSameMomentAndCleansUp、defeatedZombieLosesHeadFallsAndIsCleanedUp、peaSplatsOnImpactAndIsCleanedUp。未修改基线的 CombatAnimationTests 也未通过；不修改或删除这些无关测试。
- Git diff 检查通过；变更图存在流程截断，新增素材另行通过资源解码和渲染测试检查。

## 生成提示词

Create a production animation sprite sheet from this EXACT ogre character reference. Preserve face, brown skin, blue glowing tattoos, brown hair, horned skull armor, skull belt, loincloth, bare feet and spiked bone mace, illustration style, colors and scale. One transparent PNG sheet, exactly 3 columns by 2 rows of equal square cells, 6 sequential frames of ONE seamless slow heavy WALK cycle, read left-to-right then next row. All frames facing LEFT in the same three-quarter left view as the reference, never change facing or camera. Crucial: real alternating leg steps, not duplicates or a standing pose bobbing. Frame0 left-facing near leg forward planted, far leg trailing; frame1 weight on near foot, far knee bending and swinging forward; frame2 far foot passing near foot; frame3 far leg forward planted, near leg trailing; frame4 near knee bends and swings; frame5 near foot passes ready to loop into frame0. Keep one planted foot supporting weight in every frame; feet separated fore/aft visibly, modest natural opposite arm counter-swing, mace securely held upright with small sway not an attack. Same torso dimensions, same skull accessories count, same weapon hand in every frame. Each character is centered at identical relative pelvis X and baseline within its cell. Keep full mace and all feet inside each cell with generous clear transparent margins. Body from head to floor uses about 75 percent of each cell height, consistent in every frame. No shadows, no floor, no dust, no labels, no grid lines, no background, no extra figures. This is a cohesive six-frame animation sheet, not a character redesign.
