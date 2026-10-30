import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
FORMATTER = ROOT / "scripts/format-xcstrings.swift"
CATALOGS = (
    ROOT / "Shared/Resources/Localizable.xcstrings",
    ROOT / "DUNEWatch/Resources/Localizable.xcstrings",
    ROOT / "DUNEWatch/Resources/InfoPlist.xcstrings",
)


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
        result = self.run_formatter("--check", "--check-manual")
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_existing_catalog_entries_are_manually_managed(self):
        # Shared catalogs and dynamic keys cannot rely on one target's extraction.
        for catalog in CATALOGS:
            with self.subTest(catalog=catalog.relative_to(ROOT)):
                strings = json.loads(catalog.read_text(encoding="utf-8"))["strings"]
                unmanaged = [key for key, entry in strings.items()
                             if entry.get("extractionState") != "manual"]
                self.assertEqual(unmanaged, [],
                                 f"Register catalog entries as manual: {unmanaged[:10]}")

    def test_manual_check_rejects_extracted_entries_without_rewriting(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            catalog = Path(temporary_directory) / "InfoPlist.xcstrings"
            for state in (None, "extracted_with_value", "stale"):
                with self.subTest(state=state):
                    entry = {} if state is None else {"extractionState": state}
                    catalog.write_text(json.dumps({"sourceLanguage": "en", "strings": {
                        "CFBundleDisplayName": entry}, "version": "1.0"}), encoding="utf-8")
                    self.assertEqual(self.run_formatter(catalog).returncode, 0)
                    original = catalog.read_bytes()
                    result = self.run_formatter("--check", "--check-manual", catalog)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn("Set extractionState to manual: CFBundleDisplayName", result.stderr)
                    self.assertEqual(catalog.read_bytes(), original)

    @unittest.skipUnless(shutil.which("xcrun") and shutil.which("xcodegen"), "Xcode tools required")
    def test_infoplist_sync_includes_project_keys_and_values(self):
        result = subprocess.run(
            ["xcodegen", "dump", "--spec", str(ROOT / "DUNE/project.yml"), "--type", "json"],
            capture_output=True, text=True, check=True,
        )
        project = json.loads(result.stdout)
        settings = project["targets"]["DUNEWatch"]["settings"]["base"]
        info = plistlib.loads((ROOT / "DUNEWatch/Resources/Info.plist").read_bytes())
        info.update({key.removeprefix("INFOPLIST_KEY_"): value
                     for key, value in settings.items() if key.startswith("INFOPLIST_KEY_")})
        info["CFBundleName"] = settings["PRODUCT_NAME"]
        # Xcode extracts bundle names and privacy descriptions into this table.
        keys = [key for key in info if key in ("CFBundleName", "CFBundleDisplayName")
                or key.endswith("UsageDescription")]
        with tempfile.TemporaryDirectory() as temporary_directory:
            directory = Path(temporary_directory)
            catalog = directory / "InfoPlist.xcstrings"
            original = (ROOT / "DUNEWatch/Resources/InfoPlist.xcstrings").read_bytes()
            catalog.write_bytes(original)
            extracted = directory / "InfoPlist.stringsdata"
            extracted.write_text(json.dumps({
                "source": "Info.plist", "tables": {"InfoPlist": [
                    {"key": key, "value": info[key], "comment": ""} for key in keys
                ]}, "version": 1,
            }), encoding="utf-8")
            result = subprocess.run(
                ["xcrun", "xcstringstool", "sync", str(catalog), "--stringsdata", str(extracted)],
                capture_output=True, text=True, check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(catalog.read_bytes(), original,
                             "Register all Info.plist keys before building")
            strings = json.loads(original)["strings"]
            for key in keys:
                with self.subTest(key=key):
                    self.assertEqual(strings[key]["localizations"]["en"]["stringUnit"]["value"], info[key])

    @unittest.skipUnless(shutil.which("xcrun"), "Xcode tools required")
    def test_xcode_sync_preserves_catalogs_across_target_extraction(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            directory = Path(temporary_directory)
            extracted = directory / "Probe.stringsdata"
            # Same schema emitted by swiftc -emit-localized-strings.
            for catalog in CATALOGS:
                copy = directory / catalog.name
                original = catalog.read_bytes()
                copy.write_bytes(original)
                strings = json.loads(original)["strings"]
                for keys in ([], list(strings)[:3], list(strings)[-3:]):
                    with self.subTest(catalog=catalog.relative_to(ROOT), keys=keys):
                        extracted.write_text(json.dumps({
                            "source": "Probe.swift",
                            "tables": {catalog.stem: [
                                {"key": key, "comment": "", "location": {
                                    "startingColumn": 1, "startingLine": index + 1}}
                                for index, key in enumerate(keys)
                            ]},
                            "version": 1,
                        }), encoding="utf-8")
                        result = subprocess.run(
                            ["xcrun", "xcstringstool", "sync", str(copy),
                             "--stringsdata", str(extracted)],
                            capture_output=True, text=True, check=False,
                        )
                        self.assertEqual(result.returncode, 0, result.stderr)
                        self.assertEqual(copy.read_bytes(), original,
                                         "Xcode sync rewrote the catalog")

    @unittest.skipUnless(shutil.which("xcrun"), "Xcode tools required")
    def test_health_query_extraction_does_not_add_unmanaged_keys(self):
        # Captured from the user's Xcode build. Existing %lld and single-%
        # entries do not cover %@ and escaped-percent extraction variants.
        keys = ["/100", "× %@", "Relative change: %@%%",
                "Showing the latest 50 of %@ sources."]
        original = CATALOGS[0].read_bytes()
        strings = json.loads(original)["strings"]
        for key in keys:
            with self.subTest(key=key):
                self.assertEqual(strings.get(key, {}).get("extractionState"), "manual")
        with tempfile.TemporaryDirectory() as temporary_directory:
            directory = Path(temporary_directory)
            catalog = directory / "Localizable.xcstrings"
            catalog.write_bytes(original)
            extracted = directory / "HealthQueryResultCard.stringsdata"
            extracted.write_text(json.dumps({
                "source": "HealthQueryResultCard.swift",
                "tables": {"Localizable": [{"key": key, "comment": ""} for key in keys]},
                "version": 1,
            }), encoding="utf-8")
            result = subprocess.run(
                ["xcrun", "xcstringstool", "sync", str(catalog),
                 "--stringsdata", str(extracted)],
                capture_output=True, text=True, check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(catalog.read_bytes(), original,
                             "Health query extraction changed the catalog")

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

    def test_build_checks_catalogs_before_and_after_xcode(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            repository = Path(temporary_directory)
            for relative in ("scripts/lib", "DUNE/DUNE.xcodeproj", "bin"):
                (repository / relative).mkdir(parents=True)
            for relative in ("scripts/build-ios.sh", "scripts/lib/regen-project.sh",
                             "scripts/lib/xcodebuild-resources.sh",
                             "scripts/format-xcstrings.swift"):
                shutil.copy2(ROOT / relative, repository / relative)
            for original in CATALOGS:
                catalog = repository / original.relative_to(ROOT)
                catalog.parent.mkdir(parents=True, exist_ok=True)
                catalog.write_text('{"sourceLanguage":"en","strings":{},"version":"1.0"}',
                                   encoding="utf-8")
                self.assertEqual(self.run_formatter(catalog).returncode, 0)
            watched = repository / "DUNEWatch/Resources/InfoPlist.xcstrings"
            baseline = watched.read_bytes()
            # Exercise the real build wrapper and formatter without an app compile.
            for name, body in {
                "xcodegen": "exit 0\n",
                "xcodebuild": 'touch built\n'
                              'if [[ "${CATALOG_DRIFT:-0}" == "1" ]]; then\n'
                              '  echo \'{"sourceLanguage":"en","strings":{"New key":{}},"version":"1.0"}\' '
                              '> DUNEWatch/Resources/InfoPlist.xcstrings\n'
                              'fi\n'
                              'echo "** BUILD SUCCEEDED **"\n',
            }.items():
                tool = repository / "bin" / name
                tool.write_text("#!/bin/bash\n" + body, encoding="utf-8")
                tool.chmod(0o755)
            environment = os.environ.copy()
            environment.update({
                "PATH": str(repository / "bin") + os.pathsep + environment["PATH"],
                "CLANG_MODULE_CACHE_PATH": self.module_cache.name,
                "SWIFT_MODULE_CACHE_PATH": self.module_cache.name,
            })
            for scenario in ("clean", "before", "after"):
                with self.subTest(scenario=scenario):
                    watched.write_bytes(baseline)
                    (repository / "built").unlink(missing_ok=True)
                    if scenario == "before":
                        watched.write_text('{"sourceLanguage":"en","strings":{"New key":{}},'
                                           '"version":"1.0"}', encoding="utf-8")
                    environment["CATALOG_DRIFT"] = "1" if scenario == "after" else "0"
                    result = subprocess.run(
                        ["bash", str(repository / "scripts/build-ios.sh"), "--no-regen"],
                        cwd=repository, env=environment, capture_output=True, text=True,
                    )
                    self.assertEqual(result.returncode, 0 if scenario == "clean" else 1,
                                     result.stdout + result.stderr)
                    self.assertEqual((repository / "built").exists(), scenario != "before")
                    if scenario == "after":
                        self.assertIn("String catalogs changed during the build", result.stdout)
                        self.assertIn('"New key"', watched.read_text(encoding="utf-8"))

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
            info_catalog = repository / "DUNEWatch/Resources/InfoPlist.xcstrings"
            catalogs = (catalog, watch_catalog, info_catalog)
            for path in catalogs:
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
            for path in catalogs:
                subprocess.run(["swift", str(repository / "scripts/format-xcstrings.swift"), str(path)],
                               env=environment, check=True, capture_output=True)
            git("add", "--", "scripts", "Shared", "DUNEWatch")
            git("-c", "core.hooksPath=/dev/null", "commit", "-qm", "baseline")

            for catalog in catalogs:
                for issue in ("format", "extraction"):
                    with self.subTest(catalog=catalog.relative_to(repository), issue=issue):
                        entry = {} if issue == "format" else {"New key": {}}
                        catalog.write_text(json.dumps({"version": "1.0", "strings": entry,
                                                       "sourceLanguage": "en"}), encoding="utf-8")
                        if issue == "extraction":
                            subprocess.run(["swift", str(repository / "scripts/format-xcstrings.swift"),
                                            str(catalog)], env=environment, check=True, capture_output=True)
                        git("add", "--", str(catalog.relative_to(repository)))
                        # The working copy is valid; the staged blob must still fail.
                        catalog.write_text('{"sourceLanguage":"en","strings":{},"version":"1.0"}',
                                           encoding="utf-8")
                        subprocess.run(["swift", str(repository / "scripts/format-xcstrings.swift"),
                                        str(catalog)], env=environment, check=True, capture_output=True)
                        result = subprocess.run(["bash", str(repository / "scripts/hooks/pre-commit.sh")],
                                                cwd=repository, env=environment, capture_output=True, text=True)
                        self.assertNotEqual(result.returncode, 0)
                        self.assertIn("Format the staged catalog and add it again", result.stdout)
                        if issue == "extraction":
                            self.assertIn("Set extractionState to manual: New key", result.stderr)
                        git("restore", "--staged", "--worktree", "--", str(catalog.relative_to(repository)))


if __name__ == "__main__":
    unittest.main()
