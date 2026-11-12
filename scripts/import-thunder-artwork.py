#!/usr/bin/env python3
"""把雷霆大招的透明 PNG 原图烘焙成游戏用的透明 WebP。

用法：python3 scripts/import-thunder-artwork.py [原图目录]

- 原图目录默认是 docs/battle-ui/originals，来源见 docs/battle-ui/provenance；原图不进应用包。
- 输出到 Packages/LearnKit/Sources/LearnGame/Resources/Sprites/UltimateThunder/<同名>.webp。
- 原图自带透明通道，这里只缩到运行时用得到的尺寸再压缩，不抠图、不裁边：
  游戏按整张画布定位（命中电环的锚点在自下往上约 37% 处），裁了会错位。
"""
from __future__ import annotations

from pathlib import Path
import sys

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
ORIGINALS = ROOT / "docs/battle-ui/originals"
OUTPUT = ROOT / "Packages/LearnKit/Sources/LearnGame/Resources/Sprites/UltimateThunder"
# 最长边像素。按钮在界面上 160pt 宽，3 倍屏 480 像素；其余沿用原先运行时缩略解码的上限。
MAX_SIDE = {"button-shell": 640, "storm-clouds": 1536, "lightning": 1024, "impact": 768}
# 颜色有损、透明通道无损；辉光是大面积渐变，90 时看不出色带。
QUALITY = 90


def main() -> None:
    originals = Path(sys.argv[1]) if len(sys.argv) > 1 else ORIGINALS
    OUTPUT.mkdir(parents=True, exist_ok=True)
    total = 0
    for name, side in MAX_SIDE.items():
        source = originals / f"{name}.png"
        if not source.exists():
            sys.exit(f"缺少原图 {source}")
        image = Image.open(source).convert("RGBA")
        if image.getextrema()[3][0] != 0:
            sys.exit(f"{source.name} 没有透明区域：原图应是透明底")
        image.thumbnail((side, side), Image.LANCZOS)
        path = OUTPUT / f"{name}.webp"
        # exact=True 保留全透明像素的颜色，辉光边缘做线性过滤时不会带出黑边。
        image.save(path, "WEBP", quality=QUALITY, method=6, exact=True)
        total += path.stat().st_size
        print(f"{path.relative_to(ROOT)} {image.size[0]}x{image.size[1]} {path.stat().st_size // 1024}KB")
    print(f"共 {len(MAX_SIDE)} 张，{total // 1024}KB")


if __name__ == "__main__":
    main()
