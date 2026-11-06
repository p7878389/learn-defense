#!/usr/bin/env python3
"""从项目原始透明序列帧生成装扮。仅离线需要 Pillow，不改变原图。

运行：python3 scripts/generate-character-skins.py
皮肤保留所有画布、crop、pivot、muzzle、帧数与帧时长。
"""
import colorsys
import hashlib
import json
import math
from pathlib import Path

import sys
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
import character_skin_bamboo  # noqa: E402
import character_skin_egg  # noqa: E402
import character_skin_voxel  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
SPRITES = ROOT / "Packages/LearnKit/Sources/LearnGame/Resources/Sprites"
PREVIEW = ROOT / "docs/character-skins"
SOURCES = ["plant-inkling", "zombie-blob", "zombie-blob-attack", "zombie-blob-die", "zombie-head", "zombie-boom"]
# 整株重画、只有射手的原创皮肤：风格 id → 绘制模块（draw_frame / manifest）。
REDRAWN = {"bamboo": character_skin_bamboo, "voxel": character_skin_voxel, "egg": character_skin_egg}


def shade(rgb, lightness):
    factor = 0.40 + lightness * 0.75
    return tuple(min(255, round(c * factor)) for c in rgb)


def costume(image, name, style, index):
    image = image.convert("RGBA")
    silhouette = image.getchannel("A")
    pixels = image.load()
    plant = name.startswith("plant")
    head = []
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if not plant:
                # 只升级夹克材质，保留皮肤、裤子和眼睛；黑色轮廓不变。
                if 0.035 < h < 0.14 and s > 0.35 and v > 0.14:
                    color = (245, 118, 180) if style == "party" else (158, 91, 225)
                    level = min(1, v * 1.6)
                    if style == "pixel":
                        level = round(level * 3) / 3
                    pixels[x, y] = (*shade(color, level), a)
                elif g > r and g > b and v > 0.25:
                    if y < 75 or name == "zombie-head":
                        head.append((x, y))
    base = image
    # 仅装备图层超采样；原角色不缩放、不模糊、不像素化。
    image = Image.new("RGBA", (base.width * 4, base.height * 4))
    draw = ImageDraw.Draw(image)

    def poly(points, fill, outline=None):
        draw.polygon([(round(x * 4), round(y * 4)) for x, y in points], fill=fill)
        if outline:
            draw.line([(round(x * 4), round(y * 4)) for x, y in points + [points[0]]], fill=outline, width=4)

    def box(rect, fill, radius=0, outline=None):
        draw.rounded_rectangle(tuple(round(n * 4) for n in rect), radius=radius * 4, fill=fill, outline=outline, width=4)

    def dot(rect, fill, outline=None):
        draw.ellipse(tuple(round(n * 4) for n in rect), fill=fill, outline=outline, width=4)

    if plant:
        sway = round(math.sin(index / 13 * math.tau))
        if style == "party":
            # 标志性的奶油粉头盔，收在原有头部剪影内。
            box((13 + sway, 4, 34 + sway, 16), "#ff94c4", 6, "#775470")
            box((17 + sway, 6, 31 + sway, 9), "#fff2bd", 1)
            box((13 + sway, 14, 34 + sway, 18), "#fff0ce", 2)
            poly([(27, 44), (20, 40), (20, 49)], "#fff2bd", "#b75f87")
            poly([(27, 44), (34, 40), (34, 49)], "#ff8cc3", "#b75f87")
            dot((25, 42, 29, 46), "#69d9eb")
            for x in (16, 25, 34, 43):
                dot((x, 62, x + 3, 65), "#fff2bd")
        else:
            box((12 + sway, 5, 35 + sway, 13), "#193c50")
            box((14 + sway, 5, 32 + sway, 10), "#eec65c")
            box((22 + sway, 5, 28 + sway, 11), "#d8fff0")
            box((19, 41, 33, 47), "#305a70")
            box((23, 41, 28, 45), "#eec65c")
            for x in (12, 24, 38):
                box((x, 61, x + 6, 65), "#65f6c7")
    elif head and name not in ("zombie-blob-die", "zombie-boom"):
        left = min(x for x, y in head)
        right = max(x for x, y in head)
        top = min(y for x, y in head)
        cx = (left + right) / 2
        width = min(31, right - left)
        if style == "party":
            # 帽子跟随每一帧检测到的头部，不固定在角色节点上漂移。
            poly([(cx - width / 2, top + 6), (cx - 1, max(1, top - 7)), (cx + width / 2, top + 5)], "#77dfed", "#69516f")
            poly([(cx - 4, top - 3), (cx + 6, top + 5), (cx + 1, top + 7), (cx - 8, top)], "#ffb4d6")
            box((cx - width / 2, top + 4, cx + width / 2, top + 8), "#fff2cf", 2)
            dot((cx - 3, max(0, top - 9), cx + 2, max(5, top - 4)), "#ff84af")
        else:
            box((cx - width / 2, top, cx + width / 2, top + 10), "#28475a", outline="#163642")
            box((cx - width / 2 + 2, top + 1, cx + width / 2 - 2, top + 5), "#63eed3")
            box((cx - 4, top + 2, cx + 3, top + 7), "#e7c35a")
    overlay = image.resize(base.size, Image.Resampling.NEAREST if style == "pixel" else Image.Resampling.LANCZOS)
    # 黑轮廓验收：包括半透明边缘在内，每一帧的 alpha 必须与原图逐像素一致。
    result = Image.alpha_composite(base, overlay)
    result.putalpha(silhouette)
    return result


def main():
    clips = json.loads((SPRITES / "clips.json").read_text())
    generated = {}
    checksums = {}
    PREVIEW.mkdir(parents=True, exist_ok=True)
    for style in ("party", "pixel"):
        for name in SOURCES:
            key = f"skin-{style}-{name}"
            meta = dict(clips[name])
            meta.pop("colorKey", None)
            meta["source"] = f"generated by scripts/generate-character-skins.py from {name}"
            if "states" in meta:
                meta["states"] = {k: f"skin-{style}-{v}" for k, v in meta["states"].items()}
            generated[key] = meta
            folder = SPRITES / key
            folder.mkdir(exist_ok=True)
            for index in range(meta["frameCount"]):
                source = Image.open(SPRITES / name / f"{index}.png").convert("RGBA")
                if "colorKey" in clips[name]:
                    key_color = tuple(clips[name]["colorKey"])
                    source.putdata([(r, g, b, 0 if (r, g, b) == key_color else a) for r, g, b, a in source.getdata()])
                result = costume(source, name, style, index)
                output = folder / f"{index}.png"
                result.save(output, optimize=True)
                checksums[f"{key}/{index}.png"] = hashlib.sha256(output.read_bytes()).hexdigest()
    # 原创重绘的皮肤：不基于原图像素，只沿用显示比例与子弹出口。
    for style, module in REDRAWN.items():
        key = f"skin-{style}-plant-inkling"
        generated[key] = module.manifest()
        folder = SPRITES / key
        folder.mkdir(exist_ok=True)
        for index in range(generated[key]["frameCount"]):
            output = folder / f"{index}.png"
            module.draw_frame(index).save(output, optimize=True)
            checksums[f"{key}/{index}.png"] = hashlib.sha256(output.read_bytes()).hexdigest()
    (SPRITES / "skins.json").write_text(json.dumps(generated, ensure_ascii=False, indent=2) + "\n")
    (SPRITES / "skins-sha256.json").write_text(json.dumps(checksums, indent=2) + "\n")
    all_clips = {**clips, **generated}
    # 自包含对比页：直接显示 App 使用的 PNG，不依赖网络或生成平台。
    import base64
    frames = {}
    for name, meta in all_clips.items():
        if name not in SOURCES and not name.startswith("skin-"):
            continue
        frames[name] = {"meta": meta, "images": ["data:image/png;base64," + base64.b64encode((SPRITES / name / f"{i}.png").read_bytes()).decode() for i in range(meta["frameCount"])]}
    template = (ROOT / "scripts/character-skins-preview.html").read_text()
    (PREVIEW / "index.html").write_text(template.replace("/*FRAME_DATA*/{}", json.dumps(frames)))
    # 为交付提供无需打开浏览器也能播放的循环动图。
    gif = []
    for tick in range(48):
        stage = Image.new("RGB", (350 * (3 + len(REDRAWN)), 570), "#f7f4ec")
        draw = ImageDraw.Draw(stage)
        for col, style in enumerate((None, "party", "pixel", *REDRAWN)):
            for row, base in enumerate(("plant-inkling", "zombie-blob")):
                name = f"skin-{style}-{base}" if style else base
                if name not in all_clips:
                    continue
                meta = all_clips[name]
                x, y, w, h = meta["crop"]
                frame = Image.open(SPRITES / name / f"{tick % meta['frameCount']}.png").convert("RGBA")
                frame = frame.crop((x, y, x + w, y + h))
                factor = min(185 / w, 195 / h)
                frame = frame.resize((round(w * factor), round(h * factor)), Image.Resampling.NEAREST if style == "pixel" else Image.Resampling.LANCZOS)
                cx, cy = col * 350 + 175, row * 255 + 155
                draw.ellipse((cx - 83, cy + 73, cx + 83, cy + 95), fill="#dce7cf")
                stage.paste(frame, (cx - frame.width // 2, cy + 84 - frame.height), frame)
        gif.append(stage)
    gif[0].save(PREVIEW / "comparison.gif", save_all=True, append_images=gif[1:], duration=90, loop=0)
    gif[0].save(PREVIEW / "comparison.png")
    print(f"Generated {len(checksums)} PNG frames across {len(generated)} clips; preview: {PREVIEW / 'index.html'}")


if __name__ == "__main__":
    main()
