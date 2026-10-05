"""Regression checks for Contour Atlas's dark-only watch palette."""

import json
from pathlib import Path
import unittest


CATALOG = Path(__file__).resolve().parents[2] / "Shared/Resources/Colors.xcassets"


def luminance(color):
    components = color["components"]
    channels = [float(components[key]) for key in ("red", "green", "blue")]
    linear = [v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in channels]
    return sum(v * weight for v, weight in zip(linear, (0.2126, 0.7152, 0.0722)))


class ContourWatchColorsTests(unittest.TestCase):
    def setUp(self):
        self.assets = {
            path.parent.stem: json.loads(path.read_text())["colors"]
            for path in CATALOG.glob("Contour*.colorset/Contents.json")
        }

    def watch_color(self, name):
        variants = [entry for entry in self.assets[name] if entry["idiom"] == "watch"]
        self.assertEqual(len(variants), 1, name)
        self.assertNotIn("appearances", variants[0], name)
        return variants[0]["color"]

    def test_every_contour_asset_has_an_unconditional_watch_palette(self):
        self.assertTrue(self.assets)
        for name, variants in self.assets.items():
            with self.subTest(asset=name):
                dark = next(entry["color"] for entry in variants
                            if entry["idiom"] == "universal"
                            and {"appearance": "luminosity", "value": "dark"}
                            in entry.get("appearances", []))
                self.assertEqual(self.watch_color(name), dark)

    def test_watch_text_contrast_on_opaque_surfaces(self):
        for surface in ("ContourBackground", "ContourCardBackground"):
            background = self.watch_color(surface)
            self.assertEqual(float(background["components"]["alpha"]), 1)
            dark = luminance(background)
            for text in ("white", "ContourInk", "ContourAccent", "ContourSand", "ContourBronze"):
                with self.subTest(surface=surface, text=text):
                    foreground = 1 if text == "white" else luminance(self.watch_color(text))
                    ratio = (max(foreground, dark) + 0.05) / (min(foreground, dark) + 0.05)
                    self.assertGreaterEqual(ratio, 4.5)


if __name__ == "__main__":
    unittest.main()
