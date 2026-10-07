import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
FORMATTER = ROOT / "scripts/format-xcstrings.swift"


class StringCatalogFormattingTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.module_cache = tempfile.TemporaryDirectory()

    @classmethod
    def tearDownClass(cls):
        cls.module_cache.cleanup()

    def run_formatter(self, *arguments):
        environment = os.environ.copy()
        environment["CLANG_MODULE_CACHE_PATH"] = self.module_cache.name
        environment["SWIFT_MODULE_CACHE_PATH"] = self.module_cache.name
        return subprocess.run(
            ["swift", str(FORMATTER), *map(str, arguments)],
            capture_output=True,
            text=True,
            env=environment,
            check=False,
        )

    def test_existing_catalogs_match_xcode_format(self):
        result = self.run_formatter("--check")
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_formats_and_checks_without_changing_catalog_values(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            catalog = Path(temporary_directory) / "Localizable.xcstrings"
            catalog.write_text(
                '{"version":"1.0","strings":{"Zulu":{"localizations":'
                '{"ko":{"stringUnit":{"value":"가/나","state":"translated"}}}},'
                '"Alpha":{}},"sourceLanguage":"en"}\n',
                encoding="utf-8",
            )
            self.assertEqual(self.run_formatter("--check", catalog).returncode, 1)
            result = self.run_formatter(catalog)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(
                catalog.read_text(encoding="utf-8"),
                '{\n  "sourceLanguage" : "en",\n  "strings" : {\n'
                '    "Alpha" : {\n\n    },\n'
                '    "Zulu" : {\n      "localizations" : {\n'
                '        "ko" : {\n          "stringUnit" : {\n'
                '            "state" : "translated",\n'
                '            "value" : "가/나"\n          }\n        }\n'
                '      }\n    }\n  },\n  "version" : "1.0"\n}',
            )
            self.assertEqual(self.run_formatter("--check", catalog).returncode, 0)

    def test_rejects_duplicate_keys_without_rewriting(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            catalog = Path(temporary_directory) / "Localizable.xcstrings"
            original = (
                '{"sourceLanguage":"en","strings":{"Hello":{},'
                '"\\u0048ello":{}},"version":"1.0"}'
            )
            catalog.write_text(original, encoding="utf-8")
            result = self.run_formatter(catalog)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Duplicate JSON key: Hello", result.stderr)
            self.assertEqual(catalog.read_text(encoding="utf-8"), original)

    def test_precommit_checks_staged_catalog_not_working_copy(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            repository = Path(temporary_directory)
            (repository / "scripts/hooks").mkdir(parents=True)
            (repository / "Shared/Resources").mkdir(parents=True)
            (repository / "DUNEWatch/Resources").mkdir(parents=True)
            shutil.copy2(FORMATTER, repository / "scripts/format-xcstrings.swift")
            shutil.copy2(ROOT / "scripts/hooks/pre-commit.sh", repository / "scripts/hooks/pre-commit.sh")
            cleanup = repository / "scripts/hooks/cleanup-artifacts.sh"
            cleanup.write_text("#!/bin/bash\nexit 0\n", encoding="utf-8")
            cleanup.chmod(0o755)

            catalog = repository / "Shared/Resources/Localizable.xcstrings"
            watch_catalog = repository / "DUNEWatch/Resources/Localizable.xcstrings"
            for path in (catalog, watch_catalog):
                path.write_text('{"sourceLanguage":"en","strings":{},"version":"1.0"}', encoding="utf-8")

            def git(*arguments):
                return subprocess.run(
                    ["git", "-C", str(repository), *arguments],
                    capture_output=True,
                    text=True,
                    check=True,
                ).stdout

            git("init", "-q")
            git("config", "user.name", "Catalog Test")
            git("config", "user.email", "catalog@example.invalid")
            environment = os.environ.copy()
            environment["CLANG_MODULE_CACHE_PATH"] = self.module_cache.name
            environment["SWIFT_MODULE_CACHE_PATH"] = self.module_cache.name
            for path in (catalog, watch_catalog):
                subprocess.run(["swift", str(repository / "scripts/format-xcstrings.swift"), str(path)],
                               env=environment, check=True, capture_output=True)
            git("add", "--", "scripts", "Shared", "DUNEWatch")
            git("-c", "core.hooksPath=/dev/null", "commit", "-qm", "baseline")

            catalog.write_text('{"version":"1.0","strings":{},"sourceLanguage":"en"}', encoding="utf-8")
            git("add", "--", "Shared/Resources/Localizable.xcstrings")
            subprocess.run(["swift", str(repository / "scripts/format-xcstrings.swift"), str(catalog)],
                           env=environment, check=True, capture_output=True)
            result = subprocess.run(["bash", str(repository / "scripts/hooks/pre-commit.sh")],
                                    cwd=repository, env=environment, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Format the staged catalog and add it again", result.stdout)


if __name__ == "__main__":
    unittest.main()
