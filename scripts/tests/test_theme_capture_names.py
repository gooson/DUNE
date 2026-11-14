import importlib.util
from pathlib import Path
import sys
import unittest


ROOT = Path(__file__).resolve().parents[2]
COLLECTOR_PATH = ROOT / "docs/design/full-redesign-map/collect-theme-captures.py"
FLOW_COLLECTOR_PATH = ROOT / "docs/design/full-redesign-map/collect-theme-flow-captures.py"


def load_module(name, path):
    sys.dont_write_bytecode = True
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Unable to load {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


collector = load_module("theme_capture_collector_test", COLLECTOR_PATH)
flow_collector = load_module("theme_flow_capture_collector_test", FLOW_COLLECTOR_PATH)


class ThemeCaptureNameTests(unittest.TestCase):
    def test_legacy_export_uuid_suffix_still_classifies(self):
        name = "Desert Light Today_12_01234567-89ab-cdef-0123-456789abcdef.png"
        self.assertEqual(collector.classify_attachment(name), ("dune", "light", "T03"))

    def test_screen_prefixed_matrix_names_classify(self):
        name = "screen-0-1206x2622-Water Lilies Today Dark.png"
        self.assertEqual(collector.classify_attachment(name), ("water-lilies", "dark", "T03"))

    def test_water_lilies_reversed_style_name_remains_supported(self):
        name = "screen-2-2048x2732-Water Lilies Wellness Light"
        self.assertEqual(collector.classify_attachment(name), ("water-lilies", "light", "H01"))

    def test_invalid_theme_or_state_is_rejected_after_normalization(self):
        for name in (
            "screen-0-1206x2622-Neon Light Today",
            "screen-0-1206x2622-Desert Sepia Today",
            "screen-0-1206x2622-Desert Light Tomorrow",
        ):
            with self.subTest(name=name):
                self.assertIsNone(collector.classify_attachment(name))

    def test_screen_prefix_only_accepts_exact_anchored_shape(self):
        for name in (
            "Screen-0-1206x2622-Desert Light Today",
            "screen-x-1206x2622-Desert Light Today",
            "screen-0-1206-2622-Desert Light Today",
            "prefix-screen-0-1206x2622-Desert Light Today",
        ):
            with self.subTest(name=name):
                self.assertIsNone(collector.classify_attachment(name))

    def test_normalized_screen_prefixed_flow_name_matches_flow_collector(self):
        name = "screen-1-1206x2622-Water Lilies Dark Detail.png"
        normalized = collector.normalized_attachment_name(name)
        self.assertIsNotNone(flow_collector.NAME.fullmatch(normalized))


if __name__ == "__main__":
    unittest.main()
