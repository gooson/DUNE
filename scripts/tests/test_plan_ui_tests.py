"""Behavior and real Git fixtures for conservative UI gate planning."""

import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("plan_ui_tests", ROOT / "scripts/plan-ui-tests.py")
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class PlanTests(unittest.TestCase):
    def plan(self, *paths):
        return MODULE.make_plan(list(paths), ROOT)

    def test_document_only_does_not_launch_ui(self):
        plan = self.plan("docs/plan.md", "AGENTS.md", ".codex/skill-compat.md")
        self.assertEqual(plan["commands"], [])
        self.assertEqual(plan["status"], "planned-not-executed")

    def test_app_markdown_is_not_document_exemption(self):
        self.assertEqual(self.plan("DUNE/Resources/help.md")["platforms"]["ios"]["mode"], "full")

    def test_feature_viewmodel_gets_smoke_and_related_suites(self):
        plan = self.plan("DUNE/Presentation/Life/LifeViewModel.swift")
        self.assertEqual(plan["platforms"]["ios"]["mode"], "targeted")
        self.assertEqual(plan["platforms"]["watch"]["mode"], "skip")
        argv = plan["commands"][0]["argv"]
        self.assertIn("--smoke", argv)
        self.assertIn("DUNEUITests/LifeRegressionTests", argv)

    def test_multiple_features_union_without_duplicate_selectors(self):
        plan = self.plan("DUNE/Presentation/Sleep/A.swift", "DUNE/Presentation/Wellness/B.swift")
        selectors = plan["platforms"]["ios"]["selectors"]
        self.assertEqual(len(selectors), len(set(selectors)))
        self.assertIn("DUNEUITests/SleepDetailSmokeTests", selectors)
        self.assertIn("DUNEUITests/WellnessRegressionTests", selectors)

    def test_all_mappings_reference_existing_classes(self):
        classes = MODULE.known_classes(ROOT)
        for feature, suites in MODULE.FEATURE_SUITES.items():
            with self.subTest(feature=feature):
                self.assertTrue(set(suites).issubset(classes))

    def test_missing_suite_falls_back_to_full(self):
        with tempfile.TemporaryDirectory() as directory:
            plan = MODULE.make_plan(["DUNE/Presentation/Life/A.swift"], Path(directory))
        self.assertEqual(plan["platforms"]["ios"]["mode"], "full")

    def test_shared_unknown_and_domain_never_skip(self):
        for path in ("DUNE/Presentation/Shared/Charts/A.swift", "DUNE/App/ContentView.swift",
                     "DUNE/Domain/UseCases/A.swift", "DUNE/Data/Persistence/Models/A.swift",
                     "DUNE/Presentation/NewFeature/A.swift", "DUNE/project.yml",
                     "Shared/Resources/Localizable.xcstrings", "new-root/config.json"):
            with self.subTest(path=path):
                plan = self.plan(path)
                self.assertEqual(plan["platforms"]["ios"]["mode"], "full")
                self.assertEqual(plan["platforms"]["watch"]["mode"], "full")

    def test_full_dominates_feature_and_clears_selectors(self):
        plan = self.plan("DUNE/Presentation/Life/A.swift", "DUNE/App/ContentView.swift")
        self.assertEqual(plan["commands"][0]["argv"], ["scripts/test-ui.sh"])
        self.assertEqual(plan["platforms"]["ios"]["selectors"], [])

    def test_watch_tests_use_watch_runner(self):
        plan = self.plan("DUNEWatchUITests/HomeTests.swift")
        self.assertEqual(plan["commands"], [{"platform": "watch", "argv": ["scripts/test-watch-ui.sh"]}])

    def test_watch_app_includes_companion_regression(self):
        plan = self.plan("DUNEWatch/ContentView.swift")
        self.assertEqual(len(plan["commands"]), 2)

    def test_unit_test_only_has_unit_obligation_but_no_ui(self):
        plan = self.plan("DUNETests/CalculationTests.swift")
        self.assertEqual(plan["commands"], [])
        self.assertIn("unit tests", plan["changes"][0]["reason"])

    def test_gate_tooling_requires_contracts_without_app_ui(self):
        plan = self.plan(*MODULE.UI_GATE_TOOLING)
        self.assertEqual(plan["commands"], [])
        self.assertEqual(plan["platforms"]["ios"]["mode"], "skip")
        self.assertEqual(plan["platforms"]["watch"]["mode"], "skip")
        self.assertTrue(any("contract tests" in item for item in plan["additional_validation"]))
        self.assertTrue(any("launch/install/seed" in item for item in plan["additional_validation"]))

    def test_tooling_does_not_hide_app_changes(self):
        plan = self.plan("scripts/plan-ui-tests.py", "DUNE/App/ContentView.swift")
        self.assertEqual(plan["platforms"]["ios"]["mode"], "full")

    def test_codex_tooling_is_an_exact_allowlist_with_contract_obligation(self):
        plan = self.plan(*MODULE.CODEX_TOOLING)
        self.assertEqual(plan["commands"], [])
        self.assertTrue(any("contract tests" in item for item in plan["additional_validation"]))
        for path in ("scripts/codex-new.py", "scripts/tests/test_unknown.py",
                     "scripts/lib/simulator-worktree.sh"):
            self.assertEqual(self.plan(path)["platforms"]["ios"]["mode"], "full")

    def test_codex_tooling_mixed_with_watch_app_still_requires_both(self):
        plan = self.plan("scripts/codex-pipeline.py", "DUNEWatch/ContentView.swift")
        self.assertEqual(plan["platforms"]["ios"]["mode"], "full")
        self.assertEqual(plan["platforms"]["watch"]["mode"], "full")

    def test_workflow_requires_execution_evidence_before_skip(self):
        self.assertEqual(self.plan(MODULE.UI_WORKFLOW)["platforms"]["ios"]["mode"], "full")
        self.assertEqual(MODULE.make_plan([MODULE.UI_WORKFLOW], ROOT,
                                         workflow_selection_only=True)["commands"], [])

    def test_shared_helpers_and_unknown_tooling_are_full(self):
        for path in ("scripts/lib/simulator-boot.sh", "DUNEUITests/Helpers/UITestBaseCase.swift"):
            with self.subTest(path=path):
                self.assertEqual(self.plan(path)["platforms"]["ios"]["mode"], "full")

    def test_other_targets_require_additional_validation(self):
        self.assertTrue(self.plan("DUNEVision/App.swift")["additional_validation"])


class GitChangeTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="ui plan ")
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.git("init", "-b", "main")
        self.git("config", "user.email", "fixture@example.test")
        self.git("config", "user.name", "Fixture")
        self.write("DUNE/App/A.swift", "old\n")
        self.write(".gitignore", "ignored/\n")
        self.git("add", ".")
        self.git("commit", "-m", "baseline")
        self.git("switch", "-c", "feature")

    def git(self, *args):
        return MODULE.git(self.root, *args)

    def write(self, path, content):
        destination = self.root / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(content)

    def test_clean_change_set(self):
        self.assertEqual(MODULE.changed_files(self.root, "main")[1], [])

    def test_committed_staged_unstaged_and_untracked(self):
        self.write("committed.txt", "one")
        self.git("add", "committed.txt")
        self.git("commit", "-m", "feature")
        self.write("staged.txt", "two")
        self.git("add", "staged.txt")
        self.write("DUNE/App/A.swift", "changed\n")
        self.write("untracked with spaces.swift", "three")
        self.write("ignored/output.log", "ignored")
        self.assertEqual(MODULE.changed_files(self.root, "main")[1],
                         ["DUNE/App/A.swift", "committed.txt", "staged.txt", "untracked with spaces.swift"])

    def test_rename_preserves_old_and_new_paths(self):
        self.git("mv", "DUNE/App/A.swift", "DUNE/App/Renamed.swift")
        self.assertEqual(MODULE.changed_files(self.root, "main")[1],
                         ["DUNE/App/A.swift", "DUNE/App/Renamed.swift"])

    def test_deleted_global_file_cannot_disappear_from_gate(self):
        self.git("rm", "DUNE/App/A.swift")
        paths = MODULE.changed_files(self.root, "main")[1]
        self.assertEqual(MODULE.make_plan(paths, ROOT)["platforms"]["ios"]["mode"], "full")

    def test_invalid_base_fails_instead_of_empty_selection(self):
        with self.assertRaises(subprocess.CalledProcessError):
            MODULE.changed_files(self.root, "missing")

    def test_main_advancement_uses_merge_base(self):
        self.git("switch", "main")
        self.write("main-only.txt", "upstream")
        self.git("add", ".")
        self.git("commit", "-m", "upstream")
        self.git("switch", "feature")
        self.assertEqual(MODULE.changed_files(self.root, "main")[1], [])

    def test_workflow_execution_change_cannot_be_skipped(self):
        original = ("jobs:\n  ios-ui-tests:\n    if: true\n    runs-on: macos-15\n"
                    "    steps:\n      - run: scripts/test-ui.sh --smoke\n"
                    "  watch-ui-tests:\n    runs-on: macos-15\n"
                    "    steps:\n      - run: scripts/test-watch-ui.sh --smoke\n")
        self.write(MODULE.UI_WORKFLOW, original)
        self.git("add", ".")
        self.git("commit", "-m", "workflow baseline")
        self.write(MODULE.UI_WORKFLOW, original.replace("if: true", "needs: scope\n    if: false"))
        self.assertTrue(MODULE.workflow_execution_unchanged(self.root, "HEAD"))
        for content in (original.replace("--smoke", "--smoke --no-regen"),
                        original.replace("macos-15", "macos-14"),
                        "env:\n  DAILVE_IOS_OS: '27.0'\n" + original,
                        original.replace("  watch-ui-tests:", "  renamed-job:")):
            self.write(MODULE.UI_WORKFLOW, content)
            self.assertFalse(MODULE.workflow_execution_unchanged(self.root, "HEAD"))
        (self.root / MODULE.UI_WORKFLOW).unlink()
        self.assertFalse(MODULE.workflow_execution_unchanged(self.root, "HEAD"))


if __name__ == "__main__":
    unittest.main()
