"""「竹筒小侠」：完全原创的豌豆射手皮肤，逐帧矢量绘制，不读取任何原作像素。

竹筒身体、红头带、竹枝炮管；画布与对齐约定见 character_skin_art。
"""
import math

import character_skin_art as art
from character_skin_art import INK, Pen, ellipse, phase, rounded
BAMBOO = (126, 200, 80)
BAMBOO_LIGHT = (190, 234, 132)
BAMBOO_SHADE = (92, 162, 60)
NODE = (82, 140, 52)
RIM = (236, 218, 152)
HOLLOW = (62, 104, 42)
LEAF = (88, 168, 64)
LEAF_DARK = (58, 124, 46)
SOIL = (140, 98, 62)
SOIL_DARK = (96, 64, 40)
BAND = (222, 66, 66)
BAND_DARK = (160, 38, 46)
CHEEK = (246, 166, 150)


def ribbon(y, length, phase, thick):
    top, bottom = [], []
    n = 14
    for k in range(n + 1):
        s = k / n
        x = 15.5 - length * s
        wave = 1.6 * math.sin(phase + s * 3.4) * s
        h = thick * (1 - 0.45 * s) / 2
        top.append((x, y + wave + s * 2.2 - h))
        bottom.append((x, y + wave + s * 2.2 + h))
    return top + bottom[::-1]


def draw_frame(index):
    t = phase(index)
    pen = Pen()
    pen.sy = 1 + 0.03 * math.sin(t)
    pen.sx = 1 - 0.022 * math.sin(t)
    sway = 7 * math.sin(t + 0.6)

    # 根部：两片竹叶托着一小堆土，不随身体呼吸。
    pen.leaf(22, 64.5, 152 + sway * 0.3, 18, 9, bend=0.5, body=False)
    pen.leaf(38, 64.5, 28 - sway * 0.3, 17, 8.5, bend=-0.5, body=False)
    pen.poly(ellipse(30, 69.5, 15, 4.2), SOIL, SOIL_DARK, 1.0, body=False)

    # 侠客头带的飘带在身体后面。
    pen.poly(ribbon(16.2, 13, t, 4.4), BAND, BAND_DARK, 0.9)
    pen.poly(ribbon(18, 10, t + 1.4, 3.6), BAND, BAND_DARK, 0.9)

    # 竹筒身体：主体、高光、背光、两道竹节。
    pen.poly(rounded(15, 12, 45, 66, 5.5), BAMBOO, None)
    pen.poly(rounded(17.5, 15, 21.5, 63, 2), BAMBOO_LIGHT, None)
    pen.poly(rounded(39.5, 15, 43.5, 63, 2), BAMBOO_SHADE, None)
    for y in (21.5, 47):
        pen.poly(rounded(14.2, y - 1.2, 45.8, y + 1.2, 1.2), NODE, None)
        pen.line([(17, y + 2), (43, y + 2)], BAMBOO_LIGHT, 0.7)
    pen.poly(rounded(15, 12, 45, 66, 5.5), None, INK, 1.4)

    # 竹筒口与头顶新叶。
    pen.poly(ellipse(30, 12.5, 15, 3.5), RIM, INK, 1.1)
    pen.poly(ellipse(30, 12.6, 11.6, 2.2), HOLLOW, None)
    pen.leaf(27, 12.5, 118 + sway, 9.5, 4.6, bend=0.4)
    pen.leaf(31, 12.5, 78 + sway * 0.8, 8.8, 4.4, bend=-0.4)
    pen.leaf(34, 12.8, 40 + sway * 0.6, 7, 3.8, bend=-0.5)

    # 红头带。
    pen.poly(rounded(14.4, 14.6, 45.6, 18.2, 1.4), BAND, BAND_DARK, 0.9)
    pen.poly(ellipse(15.5, 16.6, 2.7, 2.5), BAND, BAND_DARK, 0.9)

    # 右侧竹枝炮管，从竹节处长出；口径中心对准原版 muzzle。
    pen.poly(rounded(42, 15.8, 63, 24.2, 2.2), BAMBOO, INK, 1.2)
    pen.poly(rounded(44, 16.8, 61.5, 18.4, 0.8), BAMBOO_LIGHT, None)
    pen.poly(rounded(50.2, 15.3, 52.4, 24.7, 0.9), NODE, None)
    pen.poly(ellipse(63.2, 20, 2.3, 4.7), RIM, INK, 1.0)
    pen.poly(ellipse(63.5, 20, 1.3, 3.2), HOLLOW, None)
    pen.leaf(47, 16.2, 62 - sway * 0.7, 6.5, 3.2, bend=-0.3)

    # 脸：坚定的眉毛、看向右边的大眼睛、红脸蛋、小微笑。
    for cx in (24.5, 35.5):
        pen.poly(ellipse(cx + 3.5, 33.6, 2.4, 1.3), CHEEK, None)
    if index == 9:
        for cx in (24.5, 35.5):
            pen.line([(cx - 3, 28.6), (cx, 29.8), (cx + 3, 28.6)], INK, 1.0)
    else:
        lid = 0.45 if index == 10 else 1.0
        for cx in (24.5, 35.5):
            pen.poly(ellipse(cx, 28.4, 3.6, 4.1 * lid), (255, 255, 255), INK, 0.9)
            pen.poly(ellipse(cx + 1.2, 28.8, 1.9, 2.5 * lid), (30, 34, 40), None)
            pen.poly(ellipse(cx + 1.8, 27.6, 0.7, 0.8 * lid), (255, 255, 255), None)
    pen.line([(20.8, 22.6), (26.8, 23.8)], INK, 1.2)
    pen.line([(33.2, 23.8), (39.4, 22.4)], INK, 1.2)
    pen.line([(28.6, 35.4), (30.2, 36.6), (32.2, 36.4), (33.4, 35.2)], INK, 0.9)

    return pen.finish()


def manifest():
    return art.manifest("character_skin_bamboo.py")
