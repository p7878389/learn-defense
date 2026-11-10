#!/usr/bin/env python3
"""将已生成的 3×2 巨魔行走图集切为游戏帧；不绘制或变形角色。"""
from pathlib import Path
import json
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "docs/forest-roster/ogre-walk/source.png"
OUTPUT = ROOT / "Packages/LearnKit/Sources/LearnGame/Resources/Sprites/ForestRoster"


def main():
    sheet = Image.open(SOURCE).convert("RGBA")
    assert sheet.size == (1536, 1024), "源图必须是 3×2 个 512 像素单元"
    report = []
    for i in range(6):
        x, y = (i % 3) * 512, (i // 3) * 512
        frame = sheet.crop((x, y, x + 512, y + 512))
        # 清除生成图透明区域的极低 alpha 残留，保留主体和半透明边缘。
        alpha = frame.getchannel("A").point(lambda a: 0 if a <= 8 else round((a - 8) * 255 / 246))
        frame.putalpha(alpha)
        bounds = alpha.point(lambda a: 255 if a >= 128 else 0).getbbox()
        assert bounds and bounds[3] > 350
        # 所有帧使用同一缩放；仅竖直平移，将承重脚对齐到原始素材的 y=448。
        scaled = frame.resize((461, 461), Image.Resampling.LANCZOS)
        offset = (25, 448 - round(bounds[3] * 461 / 512))
        canvas = Image.new("RGBA", (512, 512))
        canvas.alpha_composite(scaled, offset)
        path = OUTPUT / f"ogre-walk-{i}.webp"
        canvas.save(path, "WEBP", quality=92, method=6)
        report.append({"file": path.name, "source_cell": [x, y, 512, 512],
                       "source_opaque_bounds": bounds, "offset": offset,
                       "bytes": path.stat().st_size})
    (SOURCE.parent / "frames.json").write_text(json.dumps(report, indent=2) + "\n")


if __name__ == "__main__":
    main()
