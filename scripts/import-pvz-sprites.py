#!/usr/bin/env python3
"""从指定版本的 pypvz 本地检出复制所需序列帧，不重新编码原始 PNG。

用法：python3 scripts/import-pvz-sprites.py /path/to/pypvz
"""

import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

REVISION = "c88a018209ca48457e24db124f6532aea350f60d"
DEST = Path(__file__).resolve().parent.parent / "Packages/LearnKit/Sources/LearnGame/Resources/Sprites"
# 同一动画共用透明内容的包围盒，裁去僵尸左侧留白但不逐帧裁切，避免播放时抖动。
# 名称、上游目录、文件前缀、帧数、像素包围盒（左、上、宽、高）、帧间隔。
CLIPS = [
    ("plant-inkling", "Plants/Peashooter", "Peashooter", 13, [0, 0, 70, 71], 0.10),
    ("plant-twin", "Plants/RepeaterPea", "RepeaterPea", 15, [0, 0, 73, 71], 0.10),
    ("plant-frost", "Plants/SnowPea", "SnowPea", 15, [0, 0, 71, 71], 0.10),
    ("plant-stroke", "Plants/FumeShroom/FumeShroom", "FumeShroom", 16, [1, 0, 84, 87], 0.10),
    ("plant-starling", "Plants/StarFruit", "StarFruit", 13, [0, 0, 77, 70], 0.10),
    ("zombie-blob", "Zombies/NormalZombie/Zombie", "Zombie", 22, [63, 20, 87, 124], 0.09),
    ("zombie-hopper", "Zombies/ConeheadZombie/ConeheadZombie", "ConeheadZombie", 21, [79, 0, 87, 144], 0.09),
    ("zombie-dasher", "Zombies/FootballZombie/FootballZombie", "FootballZombie", 22, [0, 0, 154, 160], 0.07),
    ("zombie-drowsy", "Zombies/NewspaperZombie/NewspaperZombie", "NewspaperZombie", 19, [48, 21, 96, 137], 0.12),
    ("zombie-armored", "Zombies/BucketheadZombie/BucketheadZombie", "BucketheadZombie", 15, [52, 2, 94, 142], 0.10),
    ("zombie-king", "Zombies/ScreenDoorZombie/ScreenDoorZombie", "ScreenDoorZombie", 23, [43, 13, 104, 131], 0.10),
    ("pea", "Bullets/PeaNormal", "PeaNormal", 1, [28, 5, 24, 24], 0.10),
    ("ice-pea", "Bullets/PeaIce", "PeaIce", 1, [26, 3, 26, 26], 0.10),
    ("star", "Bullets/StarBullet", "StarBullet", 1, [3, 3, 32, 32], 0.10),
]


def main() -> None:
    source = Path(sys.argv[1]).resolve()
    revision = subprocess.check_output(["git", "-C", str(source), "rev-parse", "HEAD"], text=True).strip()
    if revision != REVISION:
        raise SystemExit(f"需要 pypvz {REVISION}，实际为 {revision}")
    clips = {}
    checksums = {}
    for name, directory, prefix, count, crop, frame_time in CLIPS:
        output = DEST / name
        output.mkdir(parents=True, exist_ok=True)
        for index in range(count):
            path = source / "resources/graphics" / directory / f"{prefix}_{index}.png"
            data = path.read_bytes()
            if not data.startswith(b"\x89PNG\r\n\x1a\n"):
                raise SystemExit(f"无效 PNG：{path}")
            shutil.copyfile(path, output / f"{index}.png")
            checksums[f"{name}/{index}.png"] = hashlib.sha256(data).hexdigest()
        clips[name] = {"frameCount": count, "frameTime": frame_time, "crop": crop,
                       "source": f"resources/graphics/{directory}"}
        if name == "zombie-drowsy":
            clips[name]["colorKey"] = [255, 255, 255]
    (DEST / "clips.json").write_text(json.dumps(clips, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (DEST / "sha256.json").write_text(json.dumps(checksums, indent=2) + "\n", encoding="utf-8")
    print(f"已复制 {len(checksums)} 帧，共 {len(clips)} 组；来源版本 {revision}")


if __name__ == "__main__":
    main()
