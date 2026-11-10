#!/usr/bin/env python3
"""把已生成并人工检查的 3×3 怪物图集切为游戏动作帧。

源图仅作为美术参考；此脚本只做确定性切图、alpha 清理、共享缩放和锚点对齐。
"""
from __future__ import annotations

import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SOURCE_ROOT = ROOT / "docs/forest-roster/actions"
OUTPUT = ROOT / "Packages/LearnKit/Sources/LearnGame/Resources/Sprites/ForestActions"
KINDS = [
    "knight", "goblin", "acolyte", "berserker", "frostKing",
    "infernal", "pharaoh", "reaper", "slime", "gargoyle", "shaman",
]


def clean_alpha(image: Image.Image) -> Image.Image:
    image = image.convert("RGBA")
    alpha = image.getchannel("A").point(lambda a: 0 if a <= 8 else round((a - 8) * 255 / 246))
    image.putalpha(alpha)
    return image


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    manifest = {}
    for kind in KINDS:
        source = Image.open(SOURCE_ROOT / kind / "source.png").convert("RGBA")
        if source.width != source.height or source.width % 3:
            raise SystemExit(f"{kind}: 源图必须是 3×3 正方形图集")
        cell = source.width // 3
        crops = [
            clean_alpha(source.crop((column * cell, row * cell, (column + 1) * cell, (row + 1) * cell)))
            for row in range(3) for column in range(3)
        ]
        bounds = [
            image.getchannel("A").point(lambda a: 255 if a >= 128 else 0).getbbox()
            for image in crops
        ]
        if any(box is None for box in bounds):
            raise SystemExit(f"{kind}: 找到空帧")
        max_width = max(box[2] - box[0] for box in bounds)
        max_height = max(box[3] - box[1] for box in bounds)
        scale = min(292 / max_width, 272 / max_height)
        records = []
        for index, (image, box) in enumerate(zip(crops, bounds)):
            size = (round(image.width * scale), round(image.height * scale))
            scaled = image.resize(size, Image.Resampling.LANCZOS)
            scaled_box = tuple(round(value * scale) for value in box)
            offset = (
                round(160 - (scaled_box[0] + scaled_box[2]) / 2),
                280 - scaled_box[3],
            )
            canvas = Image.new("RGBA", (320, 320))
            canvas.alpha_composite(scaled, offset)
            path = OUTPUT / f"{kind}-action-{index}.webp"
            canvas.save(path, "WEBP", quality=90, method=6)
            records.append({
                "index": index,
                "source_cell": [
                    (index % 3) * cell, (index // 3) * cell, cell, cell
                ],
                "source_alpha_bounds": box,
                "offset": offset,
                "bytes": path.stat().st_size,
            })
        manifest[kind] = {
            "source": f"docs/forest-roster/actions/{kind}/source.png",
            "scale": scale,
            "frames": records,
        }
    (OUTPUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")


if __name__ == "__main__":
    main()
