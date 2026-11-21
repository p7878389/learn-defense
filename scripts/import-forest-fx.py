#!/usr/bin/env python3
"""经典森林角色立绘的通用去白底函数，供 import-forest-roster.py 复用。"""
from __future__ import annotations

import numpy as np
from scipy import ndimage


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
