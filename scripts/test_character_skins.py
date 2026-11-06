"""验证原图剪影、主体颜色与序列帧几何约束。"""
import importlib.util
import unittest

from PIL import Image, ImageChops

spec = importlib.util.spec_from_file_location("skins", __file__.replace("test_character_skins.py", "generate-character-skins.py"))
skins = importlib.util.module_from_spec(spec)
spec.loader.exec_module(skins)

import character_skin_art as art  # noqa: E402  生成脚本已把 scripts/ 加入 sys.path


class CharacterSkinAssetTests(unittest.TestCase):
    def test_silhouette_matches_each_original_frame(self):
        for name in skins.SOURCES:
            for source_path in (skins.SPRITES / name).glob("*.png"):
                source = Image.open(source_path).convert("RGBA")
                for style in ("party", "pixel"):
                    with self.subTest(name=name, frame=source_path.stem, style=style):
                        result = skins.costume(source.copy(), name, style, int(source_path.stem))
                        self.assertEqual(result.size, source.size)
                        self.assertIsNone(ImageChops.difference(source.getchannel("A"), result.getchannel("A")).getbbox())

    def test_shooter_body_stays_green(self):
        source = Image.open(skins.SPRITES / "plant-inkling/0.png").convert("RGBA")
        for style in ("party", "pixel"):
            result = skins.costume(source.copy(), "plant-inkling", style, 0)
            # 头部下半部与叶子是主体材质，不属于护额、帽子或蝴蝶结。
            for point in [(29, 29), (26, 32), (22, 56), (41, 57)]:
                self.assertEqual(result.getpixel(point), source.getpixel(point), (style, point))


class RedrawnSkinAssetTests(unittest.TestCase):
    """整株重画的皮肤：可复现、站在画布底边、子弹出口在炮口里，且轮廓与原版明显不同。"""

    def test_frames_are_deterministic_and_match_saved_assets(self):
        for style, module in skins.REDRAWN.items():
            for index in range(art.FRAMES):
                with self.subTest(style=style, frame=index):
                    drawn = module.draw_frame(index)
                    saved = Image.open(skins.SPRITES / f"skin-{style}-plant-inkling" / f"{index}.png").convert("RGBA")
                    self.assertEqual(drawn.size, tuple(art.CANVAS))
                    self.assertIsNone(ImageChops.difference(drawn, saved).getbbox())

    def test_stands_on_canvas_bottom_and_muzzle_sits_in_cannon(self):
        for style, module in skins.REDRAWN.items():
            for index in range(art.FRAMES):
                with self.subTest(style=style, frame=index):
                    frame = module.draw_frame(index)
                    alpha = frame.getchannel("A")
                    left, top, right, bottom = alpha.getbbox()
                    self.assertEqual(bottom, frame.height)
                    self.assertGreater(top, 0)
                    self.assertLessEqual(right, art.CROP[2])
                    mx, my = art.MUZZLE
                    self.assertGreater(alpha.getpixel((mx - 3, my)), 200)

    def test_silhouette_is_a_real_redesign(self):
        original = Image.open(skins.SPRITES / "plant-inkling/0.png").convert("RGBA").getchannel("A")
        original = original.resize(tuple(art.CANVAS), Image.Resampling.NEAREST).point(lambda a: 255 if a > 127 else 0)
        for style, module in skins.REDRAWN.items():
            with self.subTest(style=style):
                redrawn = module.draw_frame(0).getchannel("A").point(lambda a: 255 if a > 127 else 0)
                both = ImageChops.multiply(original, redrawn).histogram()[255]
                either = ImageChops.lighter(original, redrawn).histogram()[255]
                self.assertLess(both / either, 0.6)

if __name__ == "__main__":
    unittest.main()
