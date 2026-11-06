#!/usr/bin/env python3
"""从指定版本的 pypvz 本地检出复制所需序列帧，不重新编码原始 PNG。

用法：python3 scripts/import-pvz-sprites.py /path/to/pypvz

上游检出没有 git 提交记录（例如直接解压的源码包）时，改为核对已导入帧的 sha256：
全部一致才认为是同一版本，新增的帧会打印提示。
"""

import hashlib
import json
from pathlib import Path
import shutil
import struct
import subprocess
import sys

REVISION = "c88a018209ca48457e24db124f6532aea350f60d"
DEST = Path(__file__).resolve().parent.parent / "Packages/LearnKit/Sources/LearnGame/Resources/Sprites"
WHITE = [255, 255, 255]
# 同一动画共用透明内容的包围盒，裁去僵尸左侧留白但不逐帧裁切，避免播放时抖动。
# 名称、上游目录、文件前缀、帧数、像素包围盒（左、上、宽、高）、帧间隔、附加信息。
# 附加信息：
# - pivot：对齐用的横向基准（画布像素）。同一角色切换动画时，各动画的 pivot 与画布底边对齐。
#   僵尸取上游 ZOMBIE_RECT 裁切区的中线，植物取画布左缘，掉头取左缘（上游把头放在身体中线右侧）。
# - muzzle：子弹出口（画布像素，左上角为原点）。
# - states：这个角色的其他动画，比如 attack 啃咬、die 倒下、head 掉头、boom 烧焦、bare 掉了防具。
# - colorKey：纯色底板，运行时转成透明。
CLIPS = [
    ("plant-inkling", "Plants/Peashooter", "Peashooter", 13, [0, 0, 70, 71], 0.10,
     {"pivot": 0, "muzzle": [64, 20]}),
    ("plant-twin", "Plants/RepeaterPea", "RepeaterPea", 15, [0, 0, 73, 71], 0.10,
     {"pivot": 0, "muzzle": [70, 21]}),
    ("plant-frost", "Plants/SnowPea", "SnowPea", 15, [0, 0, 71, 71], 0.10,
     {"pivot": 0, "muzzle": [67, 19]}),
    ("plant-stroke", "Plants/FumeShroom/FumeShroom", "FumeShroom", 16, [1, 0, 84, 87], 0.10,
     {"pivot": 0, "muzzle": [80, 42], "states": {"attack": "plant-stroke-attack"}}),
    ("plant-stroke-attack", "Plants/FumeShroom/FumeShroomAttack", "FumeShroomAttack", 23, [0, 0, 124, 87], 0.05,
     {"pivot": 0}),
    ("plant-starling", "Plants/StarFruit", "StarFruit", 13, [0, 0, 77, 70], 0.10, {"pivot": 0}),
    # 防御道具：坚果按耐久换裂纹帧；土豆雷先埋着（init），出土后待机，踩到时炸开（explode，居中对齐）
    ("plant-wallnut", "Plants/WallNut/WallNut", "WallNut", 16, [0, 0, 64, 72], 0.10,
     {"pivot": 0, "states": {"cracked1": "plant-wallnut-cracked1", "cracked2": "plant-wallnut-cracked2"}}),
    ("plant-wallnut-cracked1", "Plants/WallNut/WallNut_cracked1", "WallNut_cracked1", 11, [0, 2, 64, 71], 0.10,
     {"pivot": 0}),
    ("plant-wallnut-cracked2", "Plants/WallNut/WallNut_cracked2", "WallNut_cracked2", 15, [0, 6, 64, 67], 0.10,
     {"pivot": 0}),
    ("plant-tallnut", "Plants/TallNut/TallNut", "TallNut", 14, [0, 0, 82, 119], 0.10,
     {"pivot": 0, "states": {"cracked1": "plant-tallnut-cracked1", "cracked2": "plant-tallnut-cracked2"}}),
    ("plant-tallnut-cracked1", "Plants/TallNut/TallNut_cracked1", "TallNut_cracked1", 17, [1, 0, 82, 119], 0.10,
     {"pivot": 0}),
    ("plant-tallnut-cracked2", "Plants/TallNut/TallNut_cracked2", "TallNut_cracked2", 15, [0, 2, 82, 117], 0.10,
     {"pivot": 0}),
    ("plant-potato", "Plants/PotatoMine/PotatoMine", "PotatoMine", 8, [1, 0, 74, 55], 0.12,
     {"pivot": 37.5, "states": {"init": "plant-potato-init", "explode": "plant-potato-explode"}}),
    ("plant-potato-init", "Plants/PotatoMine/PotatoMineInit", "PotatoMineInit", 1, [20, 23, 36, 30], 0.10,
     {"pivot": 37.5}),
    ("plant-potato-explode", "Plants/PotatoMine/PotatoMineExplode", "PotatoMineExplode", 1, [1, 1, 131, 92], 0.50,
     {"pivot": 66}),
    ("zombie-blob", "Zombies/NormalZombie/Zombie", "Zombie", 22, [63, 20, 87, 124], 0.09,
     {"pivot": 107, "states": {"attack": "zombie-blob-attack", "die": "zombie-blob-die",
                               "head": "zombie-head", "boom": "zombie-boom"}}),
    ("zombie-blob-attack", "Zombies/NormalZombie/ZombieAttack", "ZombieAttack", 21, [63, 23, 87, 121], 0.08,
     {"pivot": 107}),
    ("zombie-blob-die", "Zombies/NormalZombie/ZombieDie", "ZombieDie", 10, [0, 59, 165, 85], 0.07,
     {"pivot": 82}),
    ("zombie-head", "Zombies/NormalZombie/ZombieHead", "ZombieHead", 12, [9, 1, 140, 185], 0.07,
     {"pivot": 0}),
    ("zombie-boom", "Zombies/NormalZombie/BoomDie", "BoomDie", 20, [69, 30, 79, 113], 0.07,
     {"pivot": 108}),
    ("zombie-hopper", "Zombies/ConeheadZombie/ConeheadZombie", "ConeheadZombie", 21, [79, 0, 87, 144], 0.09,
     {"pivot": 120, "states": {"attack": "zombie-hopper-attack", "die": "zombie-blob-die",
                               "head": "zombie-head", "boom": "zombie-boom"}}),
    ("zombie-hopper-attack", "Zombies/ConeheadZombie/ConeheadZombieAttack", "ConeheadZombieAttack", 11,
     [79, 0, 87, 144], 0.08, {"pivot": 122.5}),
    ("zombie-dasher", "Zombies/FootballZombie/FootballZombie", "FootballZombie", 22, [0, 0, 154, 160], 0.07,
     {"pivot": 77, "states": {"attack": "zombie-dasher-attack", "die": "zombie-dasher-die",
                              "boom": "zombie-boom"}}),
    ("zombie-dasher-attack", "Zombies/FootballZombie/FootballZombieAttack", "FootballZombieAttack", 20,
     [7, 19, 126, 141], 0.06, {"pivot": 77}),
    ("zombie-dasher-die", "Zombies/FootballZombie/FootballZombieDie", "FootballZombieDie", 16,
     [44, 36, 192, 134], 0.06, {"pivot": 118}),
    ("zombie-drowsy", "Zombies/NewspaperZombie/NewspaperZombie", "NewspaperZombie", 19, [48, 21, 96, 137], 0.12,
     {"pivot": 94, "colorKey": WHITE, "states": {"attack": "zombie-drowsy-attack", "die": "zombie-drowsy-die",
                                                 "head": "zombie-head", "boom": "zombie-boom"}}),
    ("zombie-drowsy-attack", "Zombies/NewspaperZombie/NewspaperZombieAttack", "NewspaperZombieAttack", 8,
     [47, 17, 101, 141], 0.1, {"pivot": 94, "colorKey": WHITE}),
    ("zombie-drowsy-die", "Zombies/NewspaperZombie/NewspaperZombieDie", "NewspaperZombieDie", 11,
     [0, 58, 140, 106], 0.07, {"pivot": 50, "colorKey": WHITE}),
    ("zombie-armored", "Zombies/BucketheadZombie/BucketheadZombie", "BucketheadZombie", 15, [52, 2, 94, 142], 0.10,
     {"pivot": 99, "states": {"attack": "zombie-armored-attack", "bare": "zombie-blob",
                              "bareAttack": "zombie-blob-attack", "die": "zombie-blob-die",
                              "head": "zombie-head", "boom": "zombie-boom"}}),
    ("zombie-armored-attack", "Zombies/BucketheadZombie/BucketheadZombieAttack", "BucketheadZombieAttack", 11,
     [47, 8, 88, 136], 0.08, {"pivot": 91}),
    ("zombie-king", "Zombies/ScreenDoorZombie/ScreenDoorZombie", "ScreenDoorZombie", 23, [43, 13, 104, 131], 0.10,
     {"pivot": 91, "states": {"attack": "zombie-king-attack", "bare": "zombie-blob",
                              "bareAttack": "zombie-blob-attack", "die": "zombie-blob-die",
                              "head": "zombie-head", "boom": "zombie-boom"}}),
    ("zombie-king-attack", "Zombies/ScreenDoorZombie/ScreenDoorZombieAttack", "ScreenDoorZombieAttack", 24,
     [43, 19, 88, 138], 0.08, {"pivot": 91}),
    ("pea", "Bullets/PeaNormal", "PeaNormal", 1, [28, 5, 24, 24], 0.10, {"states": {"hit": "pea-hit"}}),
    ("pea-hit", "Bullets/PeaNormalExplode", "PeaNormalExplode", 1, [1, 0, 51, 45], 0.10, {}),
    ("ice-pea", "Bullets/PeaIce", "PeaIce", 1, [26, 3, 26, 26], 0.10, {}),
    ("star", "Bullets/StarBullet", "StarBullet", 1, [3, 3, 32, 32], 0.10, {"states": {"hit": "star-hit"}}),
    ("star-hit", "Bullets/StarBulletExplode", "StarBulletExplode", 1, [1, 0, 51, 45], 0.10, {}),
    ("fume", "Bullets/Fume", "Fume", 8, [0, 0, 343, 59], 0.06, {}),
]


def png_size(data: bytes) -> list[int]:
    width, height = struct.unpack(">II", data[16:24])
    return [width, height]


def check_source(source: Path) -> str:
    try:
        revision = subprocess.check_output(["git", "-C", str(source), "rev-parse", "HEAD"], text=True,
                                           stderr=subprocess.DEVNULL).strip()
    except subprocess.CalledProcessError:
        revision = ""
    if revision:
        if revision != REVISION:
            raise SystemExit(f"需要 pypvz {REVISION}，实际为 {revision}")
        return revision
    # 没有提交记录：用已导入帧的校验和确认版本
    recorded = json.loads((DEST / "sha256.json").read_text(encoding="utf-8"))
    known = {name: (directory, prefix) for name, directory, prefix, *_ in CLIPS}
    for key, digest in recorded.items():
        name, file = key.split("/")
        directory, prefix = known[name]
        path = source / "resources/graphics" / directory / f"{prefix}_{file}"
        if hashlib.sha256(path.read_bytes()).hexdigest() != digest:
            raise SystemExit(f"上游检出没有提交记录，且 {path} 与已导入的版本不一致")
    print(f"上游检出没有提交记录；已核对 {len(recorded)} 帧与 {REVISION} 一致")
    return f"{REVISION}（按校验和核对）"


def main() -> None:
    source = Path(sys.argv[1]).resolve()
    revision = check_source(source)
    recorded = json.loads((DEST / "sha256.json").read_text(encoding="utf-8"))
    clips = {}
    checksums = {}
    added = 0
    for name, directory, prefix, count, crop, frame_time, extra in CLIPS:
        output = DEST / name
        output.mkdir(parents=True, exist_ok=True)
        canvas = None
        for index in range(count):
            path = source / "resources/graphics" / directory / f"{prefix}_{index}.png"
            data = path.read_bytes()
            if not data.startswith(b"\x89PNG\r\n\x1a\n"):
                raise SystemExit(f"无效 PNG：{path}")
            size = png_size(data)
            if canvas is None:
                canvas = size
            elif size != canvas:
                raise SystemExit(f"{name} 的帧尺寸不一致：{path}")
            shutil.copyfile(path, output / f"{index}.png")
            key = f"{name}/{index}.png"
            checksums[key] = hashlib.sha256(data).hexdigest()
            added += key not in recorded
        if crop[0] + crop[2] > canvas[0] or crop[1] + crop[3] > canvas[1]:
            raise SystemExit(f"{name} 的包围盒超出画布 {canvas}")
        clips[name] = {"frameCount": count, "frameTime": frame_time, "crop": crop, "canvas": canvas,
                       "source": f"resources/graphics/{directory}", **extra}
    for name, clip in clips.items():
        for state, target in clip.get("states", {}).items():
            if target not in clips:
                raise SystemExit(f"{name} 的 {state} 指向不存在的 {target}")
    (DEST / "clips.json").write_text(json.dumps(clips, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (DEST / "sha256.json").write_text(json.dumps(checksums, indent=2) + "\n", encoding="utf-8")
    print(f"已复制 {len(checksums)} 帧（新增 {added} 帧），共 {len(clips)} 组；来源版本 {revision}")


if __name__ == "__main__":
    main()
