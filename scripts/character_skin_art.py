"""整株重画皮肤的公共画笔与形状。

坐标以原版豌豆射手 71×71 画布为单位，输出放大 SCALE 倍（先 SUPER 倍超采样再缩小）。
crop 与 muzzle 按同倍数换算，所以战场占位、子弹出口与原版一致，只是更清晰。
"""
import math

from PIL import Image, ImageDraw

FRAMES = 13
FRAME_TIME = 0.1
SCALE = 3
SUPER = 4
UNIT = SCALE * SUPER
CANVAS = [71 * SCALE, 71 * SCALE]
CROP = [0, 0, 70 * SCALE, 71 * SCALE]
MUZZLE = [64 * SCALE, 20 * SCALE]
MUZZLE_UNITS = (64, 20)

INK = (38, 74, 34)


def manifest(script):
    return {
        "frameCount": FRAMES,
        "frameTime": FRAME_TIME,
        "crop": CROP,
        "canvas": CANVAS,
        "source": f"original art drawn by scripts/{script}",
        "pivot": 0,
        "muzzle": MUZZLE,
    }


def phase(index):
    return index / FRAMES * math.tau


def ellipse(cx, cy, rx, ry, n=56):
    return [(cx + rx * math.cos(a), cy + ry * math.sin(a)) for a in (i / n * math.tau for i in range(n))]


def rounded(x0, y0, x1, y1, r, n=8):
    pts = []
    for cx, cy, start in ((x1 - r, y0 + r, -90), (x1 - r, y1 - r, 0), (x0 + r, y1 - r, 90), (x0 + r, y0 + r, 180)):
        for k in range(n + 1):
            a = math.radians(start + 90 * k / n)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def rect(x0, y0, x1, y1):
    return [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]


def leaf(bx, by, degrees, length, width, bend=0.0, n=18):
    """尖头叶片；角度以向右为 0、逆时针为正（画布 y 向下，所以取反）。返回轮廓与叶脉。"""
    a = math.radians(degrees)
    dx, dy = math.cos(a), -math.sin(a)
    nx, ny = -dy, dx
    side = []
    for k in range(n + 1):
        s = k / n
        half = width / 2 * math.sin(math.pi * min(1, s * 1.15)) ** 0.8 * (1 - 0.35 * s)
        curve = bend * math.sin(math.pi * s * 0.9) * length * 0.15
        side.append((bx + dx * length * s + nx * curve, by + dy * length * s + ny * curve, half))
    left = [(x + nx * h, y + ny * h) for x, y, h in side]
    right = [(x - nx * h, y - ny * h) for x, y, h in side]
    vein = [(x, y) for x, y, _ in side[1:-3]]
    return left + right[::-1], vein


class Pen:
    """body=True 的形状按 (axis, foot) 做挤压拉伸并整体平移；body=False 固定不动。"""

    def __init__(self, axis=30.0, foot=66.0):
        self.image = Image.new("RGBA", (CANVAS[0] * SUPER, CANVAS[1] * SUPER))
        self.draw = ImageDraw.Draw(self.image)
        self.axis, self.foot = axis, foot
        self.sx = self.sy = 1.0
        self.dx = self.dy = 0.0

    def tf(self, pts, body=True):
        if not body:
            return [(x * UNIT, y * UNIT) for x, y in pts]
        return [((self.axis + (x - self.axis) * self.sx + self.dx) * UNIT,
                 (self.foot - (self.foot - y) * self.sy + self.dy) * UNIT) for x, y in pts]

    def poly(self, pts, fill, outline=INK, width=1.3, body=True):
        p = self.tf(pts, body)
        if fill:
            self.draw.polygon(p, fill=fill)
        if outline:
            self.draw.line(p + [p[0]], fill=outline, width=round(width * UNIT), joint="curve")

    def line(self, pts, fill=INK, width=1.0, body=True):
        p = self.tf(pts, body)
        self.draw.line(p, fill=fill, width=round(width * UNIT), joint="curve")
        r = width * UNIT / 2
        for x, y in (p[0], p[-1]):
            self.draw.ellipse((x - r, y - r, x + r, y + r), fill=fill)

    def leaf(self, *args, fill=(88, 168, 64), vein=(58, 124, 46), outline=INK, body=True, **kwargs):
        shape, center = leaf(*args, **kwargs)
        self.poly(shape, fill, outline, 1.0, body=body)
        self.line(center, vein, 0.6, body=body)

    def finish(self):
        return self.image.resize(tuple(CANVAS), Image.Resampling.LANCZOS)
