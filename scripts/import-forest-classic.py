#!/usr/bin/env python3
"""给经典模式生成森林怪物的动画清单 Sprites/forest-classic.json。

不复制图片：清单里的 files 直接指向 ForestActions / ForestRoster 里已有的透明 WebP，
运行时由 UnitSprites 读取。经典模式的怪物从右往左走，朝右的素材用 mirrored 在加载时水平翻转。

用法（需要 Pillow）：python3 scripts/import-forest-classic.py
"""
import json
import sys
from pathlib import Path

from PIL import Image

SPRITES = Path(__file__).resolve().parent.parent / "Packages/LearnKit/Sources/LearnGame/Resources/Sprites"

# 九帧动作图：0~5 行走，6 蓄力，7 出手，8 收招；原图朝右
ACTION_KINDS = ["goblin", "acolyte", "knight", "berserker", "frostKing", "infernal",
                "pharaoh", "reaper", "slime", "gargoyle", "shaman"]
WALK_FRAME_TIME = 0.12
ATTACK_FRAME_TIME = 0.2


def bbox(files, mirrored):
    """这些帧的公共不透明范围 [左, 上, 宽, 高]；mirrored 时换算到翻转后的坐标。"""
    left = top = None
    right = bottom = 0
    size = None
    for name in files:
        image = Image.open(SPRITES / f"{name}.webp").convert("RGBA")
        size = size or image.size
        if image.size != size:
            sys.exit(f"{name} 的尺寸 {image.size} 和同组其他帧 {size} 不一致")
        box = image.getbbox()
        if box is None:
            sys.exit(f"{name} 是全透明的")
        left = box[0] if left is None else min(left, box[0])
        top = box[1] if top is None else min(top, box[1])
        right, bottom = max(right, box[2]), max(bottom, box[3])
    if mirrored:
        left, right = size[0] - right, size[0] - left
    return [left, top, right - left, bottom - top], list(size)


def clip(files, frame_time, crop, canvas, mirrored, states=None):
    entry = {"frameCount": len(files), "frameTime": frame_time, "crop": crop, "canvas": canvas,
             "files": files, "mirrored": mirrored}
    if states:
        entry["states"] = states
    return entry


def main():
    clips = {}
    for kind in ACTION_KINDS:
        frames = [f"ForestActions/{kind}-action-{i}" for i in range(9)]
        # 行走和出手共用一个裁切框，切换动画时角色不会跳位置
        crop, canvas = bbox(frames, mirrored=True)
        clips[f"zombie-{kind}"] = clip(frames[:6], WALK_FRAME_TIME, crop, canvas, True,
                                       {"attack": f"zombie-{kind}-attack"})
        clips[f"zombie-{kind}-attack"] = clip(frames[6:], ATTACK_FRAME_TIME, crop, canvas, True)

    # 巨魔：六帧行走图本来就朝左；没有九帧动作图，出手用技能立绘
    walk = [f"ForestRoster/ogre-walk-{i}" for i in range(6)]
    crop, canvas = bbox(walk, mirrored=False)
    clips["zombie-ogre"] = clip(walk, WALK_FRAME_TIME, crop, canvas, False, {"attack": "zombie-ogre-attack"})
    skill = ["ForestRoster/ogre-skill"]
    crop, canvas = bbox(skill, mirrored=False)
    clips["zombie-ogre-attack"] = clip(skill, 0.6, crop, canvas, False)

    target = SPRITES / "forest-classic.json"
    target.write_text(json.dumps(clips, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"写入 {target}：{len(clips)} 段动画")


if __name__ == "__main__":
    main()
