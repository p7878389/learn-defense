#!/usr/bin/env python3
"""从 Stitch「字灵守卫 · 原图动画皮肤对比」项目的特效精灵表裁出森林塔防用的特效图。

用法：python3 scripts/import-forest-fx.py <防御塔特效表.jpg> <小怪特效表.jpg> <骷髅行走表.jpg> <野猪奔跑表.jpg> <森林塔位.jpg>

- 防御塔特效表：Stitch 屏幕 436f87d42ce843af85bff3b4215fcc11（加特林豌豆 / 寒霜晶塔弹道与受击特效）
- 小怪特效表：Stitch 屏幕 0647d4256cc14d78a66247053decab2f（小怪投掷物、冲撞扬尘与打击特效）
- 骷髅行走表：Stitch 屏幕 55c71ca6a9ab4524958a4066d84c3e2e（6 帧单行，帧间有少量粘连）
- 野猪奔跑表：Stitch 屏幕 e2ed88aace5e446bb5a134a6cb3eb53e（6 帧，2 行 3 列）
- 森林塔位：Stitch 屏幕 473214e34773400cb87b342033bda496（空塔位底座，每张地图各配一种）

全部是白底图。特效按“白色转透明”处理，保留光晕的半透明；
怪物和塔只把与边缘连通的白底转成透明，避免骷髅骨头等内部白色被挖空。
"""
from __future__ import annotations

from pathlib import Path
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parent.parent
SPRITES = ROOT / "Packages/LearnKit/Sources/LearnGame/Resources/Sprites"

# 输出名: (裁切框 left, top, right, bottom, 是否发光)，坐标基于 1024x1024 原图。
# 发光类（光晕、拖尾、冰雾）整张做白转透明；描边实心类只去掉外围白底，避免浅色填充变暗。
TOWER_FX = {
    "forest-fx-pea-muzzle": (200, 55, 325, 150, False),
    "forest-fx-pea": (847, 66, 986, 143, True),
    "forest-fx-pea-hit": (228, 313, 320, 397, False),
    "forest-fx-ice-spear": (262, 614, 502, 668, True),
    "forest-fx-ice-shatter": (720, 793, 826, 890, True),
    "forest-fx-ice-nova": (271, 819, 374, 883, True),
}
MINION_FX = {
    "forest-fx-dust": (13, 902, 128, 986, False),
    "forest-fx-poof": (15, 806, 122, 883, False),
    "forest-fx-star": (896, 787, 1018, 890, False),
}
# 塔的原图（白底 JPG）转成透明 PNG，叠在地图上不再需要正片叠底；怪物改用下方的行走/奔跑序列帧
CHARACTERS = ["forest-tower-rapid", "forest-tower-frost"]


def white_to_alpha(rgb: np.ndarray, region: np.ndarray | None = None) -> np.ndarray:
    """GIMP 式 color-to-alpha：在白底上看起来不变，叠到深色地图上时白色部分变透明。"""
    c = rgb.astype(np.float32) / 255
    alpha = (1 - c).max(axis=2)
    alpha = np.clip((alpha - 0.04) / 0.96, 0, 1)  # 去掉 JPEG 白底噪点
    safe = np.maximum(alpha, 1e-4)[..., None]
    color = np.clip((c - (1 - alpha[..., None])) / safe, 0, 1)
    if region is not None:  # 只在背景区域内转透明，其余保持原色不透明
        alpha = np.where(region, alpha, 1)
        color = np.where(region[..., None], color, c)
    out = np.dstack([color, alpha]) * 255
    return out.round().astype(np.uint8)


def background_region(rgb: np.ndarray, hole_area: int = 300) -> np.ndarray:
    """与图片边缘连通的近白区域，加上被肢体围住的大块纯白空隙，再向外扩 2px 覆盖抗锯齿边。"""
    padded = np.pad(rgb.min(axis=2), 1, constant_values=255)  # 裁切框贴着图形时也能从边缘连通
    labels, _ = ndimage.label(padded > 200)
    region = np.isin(labels, np.unique(labels[0][labels[0] > 0]))[1:-1, 1:-1]
    holes, count = ndimage.label(rgb.min(axis=2) > 242)
    sizes = ndimage.sum(np.ones(holes.shape), holes, range(1, count + 1))
    region |= np.isin(holes, np.flatnonzero(sizes >= hole_area) + 1)
    return ndimage.binary_dilation(region, iterations=2)


def trim(rgba: np.ndarray, pad: int = 4) -> Image.Image:
    ys, xs = np.nonzero(rgba[..., 3] > 8)
    top, bottom = max(0, ys.min() - pad), min(rgba.shape[0], ys.max() + pad + 1)
    left, right = max(0, xs.min() - pad), min(rgba.shape[1], xs.max() + pad + 1)
    return Image.fromarray(rgba[top:bottom, left:right], "RGBA")


def save(image: Image.Image, name: str, max_side: int) -> None:
    image.thumbnail((max_side, max_side), Image.LANCZOS)
    path = SPRITES / f"{name}.png"
    image.save(path, optimize=True)
    print(f"{path.relative_to(ROOT)} {image.size[0]}x{image.size[1]}")


def seam(mask: np.ndarray, lo: int, hi: int) -> np.ndarray:
    """在 [lo, hi) 列之间找一条从上到下穿过前景像素最少的竖直接缝，返回每行的切分列。"""
    cost = mask[:, lo:hi].astype(np.float64)
    height, width = cost.shape
    total = cost.copy()
    for y in range(1, height):
        prev = total[y - 1]
        best = np.minimum(prev, np.minimum(np.r_[np.inf, prev[:-1]], np.r_[prev[1:], np.inf]))
        total[y] += best
    path = np.empty(height, dtype=int)
    path[-1] = int(total[-1].argmin())
    for y in range(height - 2, -1, -1):
        x = path[y + 1]
        window = total[y, max(0, x - 1):min(width, x + 2)]
        path[y] = max(0, x - 1) + int(window.argmin())
    return path + lo


def keep_main_body(rgba: np.ndarray) -> np.ndarray:
    """去掉切分时带进来的邻帧碎片（如邻帧的一只脚）：只保留面积不小于主体 12% 的连通块。"""
    solid = rgba[..., 3] > 40
    labels, count = ndimage.label(ndimage.binary_dilation(solid, iterations=2))
    if count > 1:
        sizes = ndimage.sum(solid, labels, range(1, count + 1))
        keep = np.isin(labels, np.flatnonzero(sizes >= sizes.max() * 0.12) + 1)
        rgba = rgba.copy()
        rgba[~keep, 3] = 0
    return rgba


def save_frames(frames: list[np.ndarray], anchors: list[tuple[int, int]], name: str, max_side: int) -> None:
    """按锚点（x 中心、y 底边）把各帧放到同一尺寸画布上，播放时角色不会左右漂移。"""
    left = max(ax for ax, _ in anchors)
    right = max(f.shape[1] - ax for f, (ax, _) in zip(frames, anchors))
    up = max(ay for _, ay in anchors)
    down = max(f.shape[0] - ay for f, (_, ay) in zip(frames, anchors))
    for index, (frame, (ax, ay)) in enumerate(zip(frames, anchors)):
        canvas = np.zeros((up + down, left + right, 4), dtype=np.uint8)
        canvas[up - ay:up - ay + frame.shape[0], left - ax:left - ax + frame.shape[1]] = frame
        save(Image.fromarray(canvas, "RGBA"), f"{name}-{index}", max_side)


def cut_out(rgb: np.ndarray, hole_area: int = 300) -> tuple[np.ndarray, tuple[int, int, int, int]]:
    """去白底、去碎片，返回裁到内容的 RGBA 与它在原图中的范围。"""
    rgba = keep_main_body(white_to_alpha(rgb, background_region(rgb, hole_area)))
    ys, xs = np.nonzero(rgba[..., 3] > 8)
    top, bottom, left, right = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    return rgba[top:bottom, left:right], (left, top, right, bottom)


def skeleton_walk(sheet: np.ndarray) -> None:
    """单行 6 帧，相邻帧的盾和剑有粘连：按头盔定位每帧，再沿最小代价接缝切开。"""
    mask = sheet.min(axis=2) < 215
    rows = np.flatnonzero(mask.any(axis=1))
    head = mask[rows[0]:rows[0] + 70].sum(axis=0) > 3
    labels, count = ndimage.label(head)
    helmets = [s[0] for s in ndimage.find_objects(labels) if s[0].stop - s[0].start > 30]
    centers = [(h.start + h.stop) // 2 for h in helmets]
    assert len(centers) == 6, centers
    # 接缝可在两帧头盔之间较宽的范围内弯曲：上方绕开盾牌，下方绕开后一帧伸到后面的脚
    seams = [seam(mask, a + 10, b - 40) for a, b in zip(centers, centers[1:])]
    columns = np.arange(sheet.shape[1])
    frames, anchors = [], []
    for index, center in enumerate(centers):
        rgb = sheet.copy()
        outside = np.zeros(mask.shape, dtype=bool)
        if index > 0:
            outside |= columns[None, :] < seams[index - 1][:, None]
        if index < len(seams):
            outside |= columns[None, :] >= seams[index][:, None]
        rgb[outside] = 255
        frame, (left, _, _, _) = cut_out(rgb, hole_area=60)  # 肋骨间、手臂内侧的小块白底
        frames.append(frame)
        anchors.append((center - left, frame.shape[0]))
    # 原表各帧脚底已对齐同一基线，统一用底边对齐
    save_frames(frames, anchors, "forest-enemy-skeleton-walk", 256)


def boar_run(sheet: np.ndarray) -> None:
    """2 行 3 列共 6 帧，彼此分开：按行优先顺序取出，以身体重心横向对齐、蹄底对齐。"""
    mask = sheet.min(axis=2) < 215
    labels, count = ndimage.label(ndimage.binary_dilation(mask, iterations=2))
    sizes = ndimage.sum(mask, labels, range(1, count + 1))
    boxes = [ndimage.find_objects(labels)[i] for i in range(count) if sizes[i] > 3000]
    assert len(boxes) == 6, len(boxes)
    boxes.sort(key=lambda b: (b[0].start // 200, b[1].start))
    frames, anchors = [], []
    for box in boxes:
        rgb = np.full_like(sheet, 255)
        rgb[box] = sheet[box]
        rgb[box][labels[box] != labels[box][labels[box] > 0][0]] = 255
        frame, _ = cut_out(rgb, hole_area=25)  # 腿间封闭的小块白底也要去掉
        solid = frame[..., 3] > 128
        cx = int(np.nonzero(solid)[1].mean())
        frames.append(frame)
        anchors.append((cx, frame.shape[0]))
    save_frames(frames, anchors, "forest-enemy-boar-run", 320)


def split_rapid_tower() -> None:
    """把连发塔拆成静止底座和可旋转炮头，两张图保持原画布尺寸，叠放即还原整塔。

    炮头（豌豆头、加特林枪管、弹药罐）在图高 41% 以上，左侧垂下的弹药带（图宽 33% 以内）到 52%；
    底座在颈部（图宽 35%~60%）多保留到 37%，
    炮头转动时颈部不会露出切口。转轴在 (0.46, 0.37)，与界面里的锚点一致。
    """
    whole = SPRITES / "forest-tower-rapid.png"
    rgba = np.asarray(Image.open(whole).convert("RGBA"))
    whole.unlink()  # 整塔图只是中间产物，界面只用拆开后的两张
    height, width = rgba.shape[:2]
    ys, xs = np.mgrid[0:height, 0:width]
    head = (ys < height * 0.41) | ((xs < width * 0.33) & (ys < height * 0.52))
    neck = (ys >= height * 0.37) & (xs >= width * 0.35) & (xs <= width * 0.60)
    for name, keep in (("forest-tower-rapid-head", head), ("forest-tower-rapid-base", ~head | neck)):
        part = rgba.copy()
        part[~keep, 3] = 0
        Image.fromarray(part, "RGBA").save(SPRITES / f"{name}.png", optimize=True)
        print(f"{(SPRITES / name).relative_to(ROOT)}.png {width}x{height}")


def main() -> None:
    if len(sys.argv) != 6:
        sys.exit(__doc__)
    sheets = [Image.open(p).convert("RGB") for p in sys.argv[1:3]]
    for sheet, boxes in zip(sheets, (TOWER_FX, MINION_FX)):
        for name, (*box, glow) in boxes.items():
            rgb = np.asarray(sheet.crop(tuple(box)))
            region = None if glow else background_region(rgb, hole_area=40)
            save(trim(white_to_alpha(rgb, region)), name, 256)
    for name in CHARACTERS:
        rgb = np.asarray(Image.open(SPRITES / f"{name}.jpg").convert("RGB"))
        save(trim(white_to_alpha(rgb, background_region(rgb))), name, 384)
    split_rapid_tower()
    skeleton_walk(np.asarray(Image.open(sys.argv[3]).convert("RGB")).copy())
    boar_run(np.asarray(Image.open(sys.argv[4]).convert("RGB")).copy())
    pad = np.asarray(Image.open(sys.argv[5]).convert("RGB"))
    save(trim(white_to_alpha(pad, background_region(pad))), "forest-slot-pad", 320)


if __name__ == "__main__":
    main()
