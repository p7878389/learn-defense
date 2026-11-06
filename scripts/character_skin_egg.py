"""「弹弹蛋」：原创果冻蛋派对风射手，逐帧绘制，不读取任何原作像素。

圆滚滚的薄荷色蛋身做弹跳挤压，头顶豆苗，手拿彩条喇叭当炮口。
画布与对齐约定见 character_skin_art。
"""
import math

import character_skin_art as art
from character_skin_art import INK, Pen, ellipse, phase

SHELL = (162, 228, 178)
SHELL_SHADE = (120, 200, 146)
SHELL_LIGHT = (214, 246, 222)
BELLY = (232, 250, 226)
FEET = (255, 172, 120)
FEET_DARK = (206, 116, 76)
STRIPE_A = (255, 136, 178)
STRIPE_B = (255, 222, 112)
BELL = (255, 242, 204)
BELL_HOLE = (186, 64, 104)
MOUTH = (150, 46, 62)
TONGUE = (250, 128, 140)
CHEEK = (255, 156, 160)
WHITE = (255, 255, 255)
PUPIL = (34, 38, 60)


def egg(cx, cy, rx, ry, n=72):
    pts = []
    for k in range(n):
        a = k / n * math.tau
        s, c = math.sin(a), math.cos(a)
        narrow = 1 - 0.13 * max(0.0, -s)
        pts.append((cx + rx * c * narrow, cy + ry * s))
    return pts


def horn(t0, t1):
    """喇叭沿中心线从 44 到 63 逐渐张开；t0、t1 是 0…1 的分段位置。"""
    def edge(s, side):
        x = 44 + 19 * s
        y = 24 - 4 * s
        half = 2 + 4.2 * s ** 1.4
        return (x, y + side * half)
    return [edge(t0, -1), edge(t1, -1), edge(t1, 1), edge(t0, 1)]


def draw_frame(index):
    t = phase(index)
    pen = Pen(foot=70)
    pen.sy = 1 + 0.05 * math.sin(t)
    pen.sx = 1 - 0.04 * math.sin(t)
    sway = 10 * math.sin(t + 0.5)

    for cx in (22.5, 37.5):
        pen.poly(ellipse(cx, 68.3, 5.2, 2.7), FEET, FEET_DARK, 1.0, body=False)

    # 蛋身：暗面打底，再叠亮面、肚皮和高光。
    pen.poly(egg(30, 44, 20, 24), SHELL_SHADE, None)
    pen.poly(egg(28.8, 42.8, 18.4, 22.6), SHELL, None)
    pen.poly(ellipse(30, 55, 10.5, 8), BELLY, None)
    pen.poly(ellipse(20.5, 30, 3.2, 5.2), SHELL_LIGHT, None)
    pen.poly(ellipse(23.5, 24.5, 1.4, 1.4), SHELL_LIGHT, None)
    pen.poly(egg(30, 44, 20, 24), None, INK, 1.4)

    # 头顶豆苗。
    pen.line([(30, 20.5), (30.4, 17), (30, 14)], (88, 168, 64), 1.3)
    pen.leaf(30, 14.5, 145 + sway, 8, 5, bend=0.4)
    pen.leaf(30, 14.5, 35 + sway * 0.8, 8, 5, bend=-0.4)

    # 彩条喇叭当炮口：喇叭口中心对准原版 muzzle。
    for k in range(5):
        pen.poly(horn(k / 5, (k + 1) / 5), STRIPE_A if k % 2 == 0 else STRIPE_B, None)
    outline = horn(0, 1)
    pen.poly(outline, None, INK, 1.1)
    pen.poly(ellipse(63.2, 20, 2.2, 6.4), BELL, INK, 1.0)
    pen.poly(ellipse(63.5, 20, 1.3, 4.6), BELL_HOLE, None)
    pen.poly(ellipse(43.8, 24, 1.8, 2.2), STRIPE_B, INK, 0.9)

    # 小短手握住喇叭。
    pen.line([(46.5, 35), (46, 29), (45.2, 25.5)], INK, 4.6)
    pen.line([(46.5, 35), (46, 29), (45.2, 25.5)], SHELL, 2.8)
    pen.poly(ellipse(45.4, 25.4, 2.9, 2.6), SHELL, INK, 1.0)

    # 脸：亮晶晶的大眼睛、腮红、张嘴笑。
    for cx in (19.5, 40.5):
        pen.poly(ellipse(cx, 45.5, 3, 1.7), CHEEK, None)
    for cx in (24, 36):
        if index == 9:
            pen.line([(cx - 3.6, 38), (cx, 40), (cx + 3.6, 38)], INK, 1.1)
        else:
            lid = 0.4 if index == 10 else 1.0
            pen.poly(ellipse(cx, 38, 4.4, 5.2 * lid), WHITE, INK, 0.9)
            pen.poly(ellipse(cx + 0.9, 38.5, 3.1, 4 * lid), PUPIL, None)
            pen.poly(ellipse(cx + 1.9, 36.6, 1.2, 1.3 * lid), WHITE, None)
            pen.poly(ellipse(cx - 0.2, 40.6, 0.6, 0.6 * lid), WHITE, None)
    mouth = [(30 + 3.8 * math.cos(a), 45.6 + 3.4 * math.sin(a)) for a in (math.pi * k / 16 for k in range(17))]
    pen.poly(mouth, MOUTH, INK, 0.9)
    pen.poly(ellipse(30, 47.6, 2, 1.2), TONGUE, None)

    return pen.finish()


def manifest():
    return art.manifest("character_skin_egg.py")
