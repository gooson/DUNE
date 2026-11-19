import json
import unittest
from pathlib import Path


class WatchPrimaryIconTests(unittest.TestCase):
    def test_watch_ships_the_ios_primary_artwork(self):
        root = Path(__file__).resolve().parents[2]

        def primary_artwork(target, platform):
            icon_set = root / target / "Resources/Assets.xcassets/AppIcon.appiconset"
            entries = json.loads((icon_set / "Contents.json").read_text())["images"]
            primary, = [entry for entry in entries if entry.get("platform") == platform
                        and entry["size"] == "1024x1024" and "appearances" not in entry]
            return (icon_set / primary["filename"]).read_bytes()

        self.assertTrue(
            primary_artwork("DUNE", "ios") == primary_artwork("DUNEWatch", "watchos"),
            "Regenerate the Watch icon with scripts/generate-app-icon-assets.swift",
        )
