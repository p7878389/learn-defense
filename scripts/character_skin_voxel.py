"""「方块工匠」：原创方块体素风射手，逐帧绘制，不读取任何原作像素。

立体方块脑袋、阶梯叶子、方形炮管和砖陶花盆；动作按整格跳动，体现方块感。
画布与对齐约定见 character_skin_art。
"""
import math

import character_skin_art as art
from character_skin_art import INK, Pen, phase, rect

GREENS = [(122, 198, 70), (108, 182, 60), (140, 214, 88), (128, 206, 78)]
TOP = (178, 232, 116)
TOP_SPOT = (198, 242, 140)
SIDE = (84, 146, 50)
SIDE_SPOT = (96, 160, 58)
STEM = (96, 168, 58)
STEM_DARK = (70, 132, 44)
LEAF = (104, 186, 66)
LEAF_DARK = (74, 146, 48)
POT = [(196, 112, 72), (182, 100, 64), (208, 126, 82)]
POT_RIM = (156, 84, 54)
BARREL = (112, 188, 64)
BARREL_LIGHT = (164, 226, 110)
BARREL_DARK = (78, 140, 46)
HOLE = (36, 60, 34)
CHEEK = (246, 150, 150)
WHITE = (255, 255, 255)
PUPIL = (30, 34, 40)

CELL = 4


def tone(palette, x, y):
    return palette[(x * 7 + y * 13 + x * y) % len(palette)]


def blocks(pen, x0, y0, cols, rows, palette, body=True):
    for i in range(cols):
        for j in range(rows):
            x, y = x0 + i * CELL, y0 + j * CELL
            pen.poly(rect(x, y, x + CELL, y + CELL), tone(palette, i, j), None, body=body)


def draw_frame(index):
    t = phase(index)
    pen = Pen(foot=71)
    step = round(1.4 * math.sin(t))
    sway = round(1.2 * math.sin(t + 0.8))

    # 砖陶花盆与茎、阶梯叶子：固定不动。
    blocks(pen, 18, 63, 6, 2, POT, body=False)
    pen.poly(rect(18, 63, 42, 71), None, INK, 1.2, body=False)
    pen.poly(rect(15, 58.5, 45, 63), POT_RIM, INK, 1.2, body=False)
    pen.poly(rect(27, 41, 33, 59), STEM, None, body=False)
    pen.poly(rect(30.5, 41, 33, 59), STEM_DARK, None, body=False)
    pen.poly(rect(27, 41, 33, 59), None, INK, 1.1, body=False)
    for pieces, dark in (
        ([(19 - sway, 49, 27, 53), (14 - sway, 46, 21 - sway, 50), (10 - sway, 43, 16 - sway, 47)], (19 - sway, 51.5, 27, 53)),
        ([(33, 51, 41 + sway, 55), (39 + sway, 48, 46 + sway, 52), (44 + sway, 45, 50 + sway, 49)], (33, 53.5, 41 + sway, 55)),
    ):
        for x0, y0, x1, y1 in pieces:
            pen.poly(rect(x0, y0, x1, y1), LEAF, INK, 1.0, body=False)
        pen.poly(rect(*dark), LEAF_DARK, None, body=False)

    # 方块脑袋：正面、顶面、右侧面，按整格上下跳动。
    pen.dy = step
    blocks(pen, 13, 12, 8, 8, GREENS)
    top = [(13, 12), (45, 12), (49, 8), (17, 8)]
    pen.poly(top, TOP, None)
    for x in (21, 33):
        pen.poly([(x, 11), (x + 4, 11), (x + 6, 9), (x + 2, 9)], TOP_SPOT, None)
    pen.poly([(45, 12), (49, 8), (49, 40), (45, 44)], SIDE, None)
    pen.poly([(45.8, 22), (48.2, 19.6), (48.2, 25.6), (45.8, 28)], SIDE_SPOT, None)
    pen.poly(rect(13, 12, 45, 44), None, INK, 1.4)
    pen.poly(top, None, INK, 1.2)
    pen.poly([(45, 12), (49, 8), (49, 40), (45, 44)], None, INK, 1.2)

    # 头顶方块芽。
    pen.poly(rect(29.5, 3.8, 32, 9.5), STEM, INK, 0.9)
    pen.poly(rect(23 + sway, 4.8, 29.5, 8.2), LEAF, INK, 0.9)
    pen.poly(rect(21 + sway, 3.3, 25 + sway, 6.2), LEAF, INK, 0.9)
    pen.poly(rect(32, 4.3, 38 + sway, 7.6), LEAF, INK, 0.9)
    pen.poly(rect(36 + sway, 2.8, 40 + sway, 5.7), LEAF, INK, 0.9)

    # 方形炮管：从右侧面伸出，炮口方块中心对准原版 muzzle。
    pen.poly(rect(49, 15, 62, 25), BARREL, INK, 1.2)
    pen.poly(rect(50, 16, 61, 18), BARREL_LIGHT, None)
    pen.poly(rect(50, 22.5, 61, 24.2), BARREL_DARK, None)
    pen.line([(55.5, 15.6), (55.5, 24.4)], BARREL_DARK, 0.8)
    pen.poly(rect(61, 13, 66.5, 27), BARREL, INK, 1.2)
    pen.poly(rect(62.6, 16.4, 66.5, 23.6), HOLE, None)

    # 脸：方块大眼睛看向右边、方块脸蛋、阶梯微笑。
    pen.poly(rect(15.5, 31, 19.5, 34.5), CHEEK, None)
    pen.poly(rect(39.5, 31, 43.5, 34.5), CHEEK, None)
    for x in (18, 31):
        if index == 9:
            pen.poly(rect(x, 25, x + 7, 27.2), PUPIL, None)
        else:
            lid = 3.5 if index == 10 else 0
            pen.poly(rect(x, 21.5 + lid, x + 7, 29), WHITE, INK, 0.9)
            pen.poly(rect(x + 3.5, 23.5 + lid, x + 7, 29), PUPIL, None)
            if not lid:
                pen.poly(rect(x + 4, 24, x + 5.5, 25.5), WHITE, None)
    for piece in ((23, 34.5, 25.5, 37), (25.5, 37, 32.5, 39.5), (32.5, 34.5, 35, 37)):
        pen.poly(rect(*piece), PUPIL, None)

    return pen.finish()


def manifest():
    return art.manifest("character_skin_voxel.py")
