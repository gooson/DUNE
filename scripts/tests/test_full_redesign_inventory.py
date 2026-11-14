import importlib.util
from pathlib import Path
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
BUILDER_PATH = ROOT / "docs/design/full-redesign-map/build-full-redesign-map.py"
SPEC = importlib.util.spec_from_file_location("full_redesign_builder", BUILDER_PATH)
BUILDER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BUILDER)


class FullRedesignInventoryTests(unittest.TestCase):
    def test_missing_capture_time_remains_unknown(self):
        for record in ({}, {"timestamp": None}, {"timestamp": "invalid"}, {"timestamp": float("nan")}):
            with self.subTest(record=record):
                self.assertEqual(BUILDER.capture_freshness(record, 100), "시각 미확인")

    def test_only_known_recent_capture_time_is_current(self):
        self.assertEqual(BUILDER.capture_freshness({"timestamp": 100}, 100), "이번 개편 촬영")
        self.assertEqual(BUILDER.capture_freshness({"timestamp": 99}, 100), "기존 캡처")

    def test_current_inventory_parses_all_unique_screens(self):
        screens = BUILDER.read_inventory()
        ids = [screen["id"] for screen in screens]
        self.assertGreater(len(screens), 108)
        self.assertEqual(len(ids), len(set(ids)))
        self.assertTrue({"T03", "A01", "H01", "L01"}.issubset(ids))
        self.assertFalse(next(screen for screen in screens if screen["id"] == "W17")["reachable"])
        self.assertFalse(next(screen for screen in screens if screen["id"] == "W18")["reachable"])

    def test_duplicate_screen_ids_are_rejected(self):
        row = "| T03 | Today | Tabs | root | Tab | Sidebar | Adaptive | `DUNE/Today.swift:1` |"
        with tempfile.TemporaryDirectory() as directory:
            inventory = Path(directory) / "inventory.md"
            inventory.write_text(f"| ID | Name | Entry | Presentation | iPhone | iPad | Duo | Code |\n{row}\n{row}\n")
            with self.assertRaisesRegex(ValueError, "unique IDs"):
                BUILDER.read_inventory(inventory)

    def test_missing_row_is_rejected_against_declared_count(self):
        contents = BUILDER.INVENTORY.read_text()
        removed = next(line for line in contents.splitlines() if line.startswith("| T04 |"))
        with tempfile.TemporaryDirectory() as directory:
            inventory = Path(directory) / "inventory.md"
            inventory.write_text(contents.replace(removed, ""))
            with self.assertRaisesRegex(ValueError, "Declared screen count"):
                BUILDER.read_inventory(inventory)

    def test_inventory_can_grow_with_its_declared_count(self):
        rows = [f"| T0{n} | Screen | Entry | push | Phone | iPad | Duo | `DUNE/Screen.swift:1` |" for n in (1, 2)]
        with tempfile.TemporaryDirectory() as directory:
            inventory = Path(directory) / "inventory.md"
            inventory.write_text("Screens **2개**\n" + "\n".join(rows))
            self.assertEqual(len(BUILDER.read_inventory(inventory)), 2)

    def test_empty_screen_inventory_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            inventory = Path(directory) / "inventory.md"
            inventory.write_text("| ID | Name | Entry | Presentation | iPhone | iPad | Duo | Code |\n")
            with self.assertRaisesRegex(ValueError, "non-empty"):
                BUILDER.read_inventory(inventory)


if __name__ == "__main__":
    unittest.main()
