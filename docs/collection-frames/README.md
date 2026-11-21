# 金属徽饰品质边框

## 来源与素材

基于本会话用户认可的“荣耀徽饰”设计稿，通过内置 `imagegen` 编辑生成三张空卡框。画布外透明、内部深蓝；无文字、无角色，运行时叠加真实游戏内容。

- `Packages/LearnKit/Sources/LearnGame/Resources/Pictures/CollectionFrames/frame-common.png`：银蓝金属、小型冰蓝宝石。
- `Packages/LearnKit/Sources/LearnGame/Resources/Pictures/CollectionFrames/frame-rare.png`：紫晶、暗银金属及顶部翼饰。
- `Packages/LearnKit/Sources/LearnGame/Resources/Pictures/CollectionFrames/frame-legendary.png`：金色翼饰、冰蓝中心宝石。

三张均为 1086×1448 RGBA PNG，未对生成结果做裁剪或重绘。外角 alpha 为 0，中心 alpha 不低于 252。作为静态 UI 素材使用，不属于战斗粒子或动画特效。

## 接入范围

- 收藏馆射手、怪物卡片使用相同边框，按照配置中的 rarity 映射；未拥有的怪物立绘灰化，未解锁叠加灰锁。
- 游戏内射手选择卡根据实际装备皮肤查询品质；原版为普通。
- 游戏内怪物题牌根据实际选中的外观查询品质；原版为普通。题牌文字位于框图上方，目标锁定的橙色描边保留。
- 原有血量、移动、题目、购买门槛和随机外观池不变。纹理由 `HeraldicArtwork` 缓存复用，缺素材时保留现有回退。

## 生成提示词

生成方式：内置 `image_gen`，`transparent_background: true`。参考输入为用户已认可的三档边框设计图。

每张使用下面的公共提示词，将 `<DETAIL>` 替换为相应档位说明，`<NAME>` 替换为 Common / Rare / Legendary：

```text
Asset production edit. <DETAIL> Output ONE isolated finished empty game card frame with its opaque DARK NAVY INTERIOR BACKPLATE, no characters, no foliage, no title, no text, no numbers, no status badges, no rarity label plate, no internal horizontal divider. Keep the approved refined League-of-Legends-inspired sculpted metal style from the reference, do NOT use rounded plastic gradients. PORTRAIT 3:4 composition. Frame including crest occupies a centered rectangle from roughly x=4% to96%, y=3% to97%, little even transparent safety margin. Interior should be a calm solid midnight navy #182332 with a very faint center glow, no patterns, no satin or diamonds. The interior is OPAQUE and ready for game characters/text to be drawn over it; only pixels OUTSIDE the ornamental frame must be genuinely TRANSPARENT. Edge details never cross into central 75% of width. Same overall card proportions for all tiers. No shadow outside bounds, no cream background, no watermark. Preserve metal engraving and restrained gemstone illumination. Design is intended for real UI card background asset '<NAME>'.
```

Common:
```text
Extract/redesign the LEFT silver-blue COMMON card frame: narrow angular silver-blue metal rim, clipped corners, small icy cyan top gem. Minimal clean crest.
```

Rare:
```text
Extract/redesign the MIDDLE amethyst RARE card frame: dark silver-gunmetal with violet crystal inlays, symmetrical swept-back top shoulders and a small purple central diamond crest.
```

Legendary:
```text
Extract/redesign the RIGHT gold LEGENDARY card frame: narrow champagne-gold metal rim, symmetrical gold wing-like top crest, small icy cyan central gem, small gold lower insignia.
```

## 验证

`HeraldicArtworkTests` 覆盖三档资源加载、纹理复用、怪物题目文本、目标描边、血量以及默认品质回退。另使用原生 SwiftUI/SpriteKit 渲染检查收藏馆、选择卡和怪物题牌小尺寸效果。

## 收藏页浅色内衬

按用户确认的完整卡片设计稿，为收藏页新增独立资源，游戏内选择卡及题牌继续使用原深色版本：

- `frame-common-light.png`：浅冰蓝灰内衬。
- `frame-rare-light.png`：浅紫白内衬。
- `frame-legendary-light.png`：浅香槟内衬。

均位于上述 `Pictures/CollectionFrames` 目录，1086×1448 RGBA，外部透明。仅修改图片内衬，保留原金属轮廓与宝石。由内置 imagegen 编辑，未用程序重绘图片。`HeraldicArtwork.image(for:lightInterior:)` 使用独立缓存键，默认仍返回游戏内深色图。

普通、传说的生成提示词（分别替换 `<COLOR>` 为 `pale icy blue-gray #EEF5FA`、`light champagne ivory #FFF4DC`，`<TIER>` 为 common、legendary）：

```text
Precise game asset edit for approved LIGHT collection cards. Keep the EXACT existing sculpted metallic border, gem colors, top and bottom crests, every contour, proportions and position. Change ONLY the dark navy interior backplate to <COLOR>, with a very subtle center illumination and shallow recessed shadow near inner edges. Whole interior including bottom area LIGHT and opaque. Absolutely no black/navy interior, no satin, diamonds, stripes or extra ornament. Keep pixels outside the frame genuinely transparent, same portrait canvas and little outer margin. No character, no text, no title plaque, no divider, no watermark. Output one isolated empty <TIER> frame image. Preserve metal and jewel details faithfully.
```

稀有版沿用已生成的浅紫修订，提示词：

```text
Precise asset edit. Change ONLY the dark navy INTERIOR BACKPLATE of this empty game collection frame to very pale lavender ivory #F2EAF9. The interior must be LIGHT and luminous, NOT black, NOT navy, NOT dark gray. Keep it clean and mostly matte with a subtle soft center glow and very gentle depth near the inset edges. No fabric pattern, no diagonal stripes, no diamonds, no added objects. Preserve EVERY detail of the approved outer sculpted metallic frame, its original metal and gem colors, top and bottom crests, geometry, proportions, highlights and position. Keep the same portrait composition and same transparent outside area. The interior should be fully opaque pale light color, only OUTSIDE the ornate frame remains transparent. No characters, text, labels, icons or watermark. Do not recolor the metal or redraw its silhouette. Deliver one empty 'rare' frame asset for a warm, light-themed collection gallery, with the exact existing border and newly bright interior.
```
