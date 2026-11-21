#!/usr/bin/env python3
"""把经典森林怪物清单需要的 Stitch 立绘（白底 JPG）烘焙成透明 WebP。

用法：python3 scripts/import-forest-roster.py [原图目录]

- 原图目录默认是 docs/forest-roster/originals，来源见其中的 sources.json；原图不进应用包。
- 输出到 Packages/LearnKit/Sources/LearnGame/Resources/Sprites/ForestRoster/<同名>.webp。
- 只导入 forest-classic.json 引用的立绘；其他角色原图保留作美术参考。
- 去底沿用 import-forest-fx.py 的做法：与边缘连通的白底，加上被肢体、特效围住的大块纯白空隙转成透明，
  边缘保留半透明过渡；铠甲、骨头等内部的小块白色高光不动。
- 画布保持原图的正方形、不裁边：游戏里按整张画布定位脚底，裁了会让角色错位。
"""
from __future__ import annotations

import importlib.util
import json
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


def forest_fx():
    """复用 import-forest-fx.py 里的去底函数（文件名带连字符，不能直接 import）。"""
    spec = importlib.util.spec_from_file_location("import_forest_fx", ROOT / "scripts/import-forest-fx.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> None:
    originals = Path(sys.argv[1]) if len(sys.argv) > 1 else ORIGINALS
    manifest = json.loads((ROOT / "Packages/LearnKit/Sources/LearnGame/Resources/Sprites/forest-classic.json").read_text())
    required = {Path(name).name for clip in manifest.values() for name in clip["files"]
                if name.startswith("ForestRoster/") and "-walk-" not in name}
    sources = [originals / f"{name}.jpg" for name in sorted(required)]
    if not sources:
        sys.exit(f"{originals} 里没有 JPG 原图")
    fx = forest_fx()
    OUTPUT.mkdir(parents=True, exist_ok=True)
    total = 0
    for source in sources:
        rgb = np.asarray(Image.open(source).convert("RGB"))
        rgba = fx.white_to_alpha(rgb, fx.background_region(rgb))
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
