"""经典森林立绘导入：只产出经典清单需要的素材，保留原有图像。"""
import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]


class ForestRosterImportTests(unittest.TestCase):
    def test_import_only_builds_classic_portraits_without_changing_pixels(self):
        spec = importlib.util.spec_from_file_location(
            "forest_roster_import", ROOT / "scripts/import-forest-roster.py"
        )
        importer = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(importer)
        original = importer.OUTPUT / "ogre-skill.webp"
        with tempfile.TemporaryDirectory(prefix=".forest-import-test-", dir=ROOT) as directory:
            importer.OUTPUT = Path(directory)
            with patch.object(sys, "argv", [str(spec.origin)]):
                importer.main()
            self.assertEqual({p.name for p in importer.OUTPUT.iterdir()}, {"ogre-skill.webp"})
            with Image.open(original) as expected, Image.open(importer.OUTPUT / "ogre-skill.webp") as actual:
                self.assertEqual(actual.size, expected.size)
                self.assertEqual(actual.convert("RGBA").tobytes(), expected.convert("RGBA").tobytes())


if __name__ == "__main__":
    unittest.main()
