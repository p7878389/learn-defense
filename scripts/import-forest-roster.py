#!/usr/bin/env python3
"""把森林首领、小怪、英雄的 Stitch 原图（白底 JPG）烘焙成游戏用的透明 WebP。

用法：python3 scripts/import-forest-roster.py [原图目录]

- 原图目录默认是 docs/forest-roster/originals，来源见其中的 sources.json；原图不进应用包。
- 输出到 Packages/LearnKit/Sources/LearnGame/Resources/Sprites/ForestRoster/<同名>.webp。
- 去底沿用 import-forest-fx.py 的做法：与边缘连通的白底，加上被肢体、特效围住的大块纯白空隙转成透明，
  边缘保留半透明过渡；铠甲、骨头等内部的小块白色高光不动。
- 画布保持原图的正方形、不裁边：游戏里按整张画布定位脚底，裁了会让角色错位。
"""
from __future__ import annotations

import importlib.util
from pathlib import Path
import sys

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
ORIGINALS = ROOT / "docs/forest-roster/originals"
OUTPUT = ROOT / "Packages/LearnKit/Sources/LearnGame/Resources/Sprites/ForestRoster"
# 首领在最大的 iPad 上约 355 像素宽，512 留有余量。
MAX_SIDE = 512
# 颜色有损、透明通道无损。92 时肉眼看不出与 PNG 的差别，体积约为 PNG 的四分之一。
QUALITY = 92
# 默认只挖掉 300 像素以上的纯白空隙，免得误伤高光。个别原图有更小的镂空（骑士披风上的破洞），单独放低门槛。
HOLE_AREA = {"knight": 40}


def forest_fx():
    """复用 import-forest-fx.py 里的去底函数（文件名带连字符，不能直接 import）。"""
    spec = importlib.util.spec_from_file_location("import_forest_fx", ROOT / "scripts/import-forest-fx.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> None:
    originals = Path(sys.argv[1]) if len(sys.argv) > 1 else ORIGINALS
    sources = sorted(originals.glob("*.jpg"))
    if not sources:
        sys.exit(f"{originals} 里没有 JPG 原图")
    fx = forest_fx()
    OUTPUT.mkdir(parents=True, exist_ok=True)
    total = 0
    for source in sources:
        rgb = np.asarray(Image.open(source).convert("RGB"))
        rgba = fx.white_to_alpha(rgb, fx.background_region(rgb, HOLE_AREA.get(source.stem, 300)))
        if rgba[..., 3].max() == 0 or rgba[0, 0, 3] != 0:
            sys.exit(f"{source.name} 去底失败：左上角应是透明背景，主体应不为空")
        image = Image.fromarray(rgba, "RGBA")
        image.thumbnail((MAX_SIDE, MAX_SIDE), Image.LANCZOS)
        path = OUTPUT / f"{source.stem}.webp"
        image.save(path, "WEBP", quality=QUALITY, method=6, exact=False)
        total += path.stat().st_size
        print(f"{path.relative_to(ROOT)} {image.size[0]}x{image.size[1]} {path.stat().st_size // 1024}KB")
    print(f"共 {len(sources)} 张，{total // 1024}KB")


if __name__ == "__main__":
    main()
