"""Exercise cache deletion only in temporary directories."""

import contextlib
import importlib.util
import io
from pathlib import Path
import plistlib
import subprocess
import tempfile
import unittest
from unittest import mock


SCRIPT = Path(__file__).resolve().parents[1] / "cleanup-worktree-deriveddata.py"
spec = importlib.util.spec_from_file_location("cleanup_deriveddata", SCRIPT)
cleanup = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cleanup)


class CleanupDerivedDataTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        self.worktree = self.root / "first/Health"
        self.other = self.root / "second/Health"
        self.main = self.root / "main/Health"
        self.cache_root = self.root / "DerivedData"
        for path in (self.main, self.cache_root):
            path.mkdir(parents=True)
        self.git("init", "-q", str(self.main))
        self.git("-C", str(self.main), "-c", "user.name=Test", "-c", "user.email=test@example.com",
                 "commit", "--allow-empty", "-qm", "initial")
        for path in (self.worktree, self.other):
            self.git("-C", str(self.main), "worktree", "add", "--detach", str(path), "HEAD")

    def git(self, *args):
        return subprocess.run(["git", *args], check=True, capture_output=True)

    def cache(self, name, workspace=None, binary=False):
        path = self.cache_root / name
        path.mkdir()
        data = {} if workspace is None else {"WorkspacePath": str(workspace)}
        (path / "info.plist").write_bytes(plistlib.dumps(
            data, fmt=plistlib.FMT_BINARY if binary else plistlib.FMT_XML,
        ))
        (path / "Build").mkdir()
        (path / "Build/product").write_text("artifact")
        return path

    def run_cleanup(self, apply=False, roots=None):
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            return cleanup.cleanup(self.worktree, roots or [self.cache_root], apply)

    def test_dry_run_preserves_everything_then_apply_deletes_only_exact_owner(self):
        owned = self.cache("arbitrary-name", self.worktree / "DUNE/DUNE.xcodeproj")
        sibling = self.cache("Health-same-name", self.other / "DUNE/DUNE.xcodeproj")
        prefix = self.cache("prefix", Path(str(self.worktree) + "-old/DUNE.xcworkspace"))
        main = self.cache("main", self.root / "main/Health/DUNE.xcodeproj")
        shared = self.cache("ModuleCache.noindex")
        self.assertEqual(self.run_cleanup(), 0)
        self.assertTrue(owned.exists())
        self.assertEqual(self.run_cleanup(apply=True), 0)
        self.assertFalse(owned.exists())
        for path in (sibling, prefix, main, shared):
            self.assertTrue((path / "Build/product").exists())

    def test_binary_plist_custom_parent_and_missing_project_are_supported(self):
        owned = self.cache("binary", self.worktree / "missing/DUNE.xcworkspace", binary=True)
        custom = self.root / "CustomDerivedData"
        custom.mkdir()
        moved = custom / owned.name
        owned.rename(moved)
        self.assertEqual(self.run_cleanup(True, [self.cache_root, custom, custom]), 0)
        self.assertFalse(moved.exists())

    def test_invalid_or_missing_metadata_is_preserved(self):
        for name, value in (("relative", "DUNE.xcodeproj"), ("wrong-type", 42),
                            ("wrong-suffix", self.worktree / "README.md")):
            self.cache(name, value)
        malformed = self.cache("malformed")
        (malformed / "info.plist").write_bytes(b"invalid plist")
        xml = self.cache("truncated-xml")
        (xml / "info.plist").write_bytes(b"<?xml version='1.0'?><plist><dict>")
        array = self.cache("array")
        (array / "info.plist").write_bytes(plistlib.dumps(["unexpected"]))
        missing = self.cache_root / "SDKStatCaches.noindex"
        missing.mkdir()
        before = set(self.cache_root.iterdir())
        self.assertEqual(self.run_cleanup(True), 0)
        self.assertEqual(set(self.cache_root.iterdir()), before)

    def test_symlink_cache_and_metadata_are_preserved(self):
        outside = self.root / "outside"
        outside.mkdir()
        (outside / "info.plist").write_bytes(plistlib.dumps({
            "WorkspacePath": str(self.worktree / "DUNE.xcodeproj"),
        }))
        link = self.cache_root / "linked-cache"
        link.symlink_to(outside, target_is_directory=True)
        cache = self.cache("linked-info")
        (cache / "info.plist").unlink()
        (cache / "info.plist").symlink_to(outside / "info.plist")
        self.assertEqual(self.run_cleanup(True), 0)
        self.assertTrue(link.is_symlink())
        self.assertTrue(cache.exists())
        self.assertTrue(outside.exists())

    def test_nested_checkout_and_workspace_symlink_to_other_owner_are_preserved(self):
        nested = self.worktree / "nested"
        nested.mkdir()
        (nested / ".git").write_text("gitdir: elsewhere")
        cache = self.cache("nested", nested / "DUNE.xcodeproj")
        alias = self.worktree / "linked-project"
        alias.symlink_to(self.other, target_is_directory=True)
        linked = self.cache("outside-owner", alias / "DUNE.xcodeproj")
        self.assertEqual(self.run_cleanup(True), 0)
        self.assertTrue(cache.exists())
        self.assertTrue(linked.exists())

    def test_cache_root_must_be_external(self):
        owned = self.cache("owned", self.worktree / "DUNE.xcodeproj")
        self.assertEqual(self.run_cleanup(True, [self.cache_root, self.root]), 1)
        self.assertTrue(owned.exists())

    def test_incomplete_scan_and_deletion_failure_are_reported(self):
        owned = self.cache("owned", self.worktree / "DUNE.xcodeproj")
        with mock.patch.object(cleanup, "inspect_cache", side_effect=PermissionError("denied")):
            self.assertEqual(self.run_cleanup(True), 1)
        self.assertTrue(owned.exists())
        with mock.patch.object(cleanup.shutil, "rmtree", side_effect=PermissionError("denied")):
            self.assertEqual(self.run_cleanup(True), 1)
        recovery = list(self.cache_root.glob(".worktree-deriveddata-cleanup-*/cache/Build/product"))
        self.assertEqual(len(recovery), 1)

    def test_changed_ownership_between_scan_and_delete_is_preserved(self):
        owned = self.cache("owned", self.worktree / "DUNE.xcodeproj")
        original = cleanup.inspect_cache
        calls = 0

        def inspect(path, worktree):
            nonlocal calls
            calls += 1
            if calls == 2:
                (path / "info.plist").write_bytes(plistlib.dumps({
                    "WorkspacePath": str(self.other / "DUNE.xcodeproj"),
                }))
            return original(path, worktree)

        with mock.patch.object(cleanup, "inspect_cache", side_effect=inspect):
            self.assertEqual(self.run_cleanup(True), 1)
        self.assertTrue(owned.exists())

    def test_replaced_cache_directory_is_preserved(self):
        owned = self.cache("owned", self.worktree / "DUNE.xcodeproj")
        original = cleanup.inspect_cache
        calls = 0

        def inspect(path, worktree):
            nonlocal calls
            calls += 1
            if calls == 2:
                path.rename(self.root / "original-cache")
                self.cache("owned", self.worktree / "DUNE.xcodeproj")
            return original(path, worktree)

        with mock.patch.object(cleanup, "inspect_cache", side_effect=inspect):
            self.assertEqual(self.run_cleanup(True), 1)
        self.assertTrue(owned.exists())
        self.assertTrue((self.root / "original-cache").exists())

    def test_cli_requires_existing_worktree_root(self):
        (self.worktree / "DUNE").mkdir()
        for target in (self.worktree, self.worktree / "DUNE", self.main, self.root / "absent"):
            result = subprocess.run(
                ["python3", str(SCRIPT), "--worktree", str(target),
                 "--derived-data-root", str(self.cache_root)],
                capture_output=True, text=True,
            )
            self.assertEqual(result.returncode, 0 if target == self.worktree else 1)

    def test_replacement_after_final_inspection_is_preserved_in_recovery_directory(self):
        owned = self.cache("owned", self.worktree / "DUNE.xcodeproj")
        rename = Path.rename

        def replace_then_rename(path, target):
            if path == owned:
                rename(path, self.root / "original-cache")
                self.cache("owned", self.other / "DUNE.xcodeproj")
            return rename(path, target)

        with mock.patch.object(Path, "rename", replace_then_rename):
            self.assertEqual(self.run_cleanup(True), 1)
        recovery = list(self.cache_root.glob(".worktree-deriveddata-cleanup-*/cache/Build/product"))
        self.assertEqual(len(recovery), 1)
        self.assertTrue((self.root / "original-cache/Build/product").exists())

    def test_primary_checkout_apply_preserves_main_cache(self):
        owned = self.cache("main-owned", self.main / "DUNE.xcodeproj")
        result = subprocess.run(
            ["python3", str(SCRIPT), "--worktree", str(self.main),
             "--derived-data-root", str(self.cache_root), "--apply"],
            capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 1)
        self.assertIn("Primary checkout is protected", result.stderr)
        self.assertTrue((owned / "Build/product").exists())

    def test_new_cache_at_original_path_survives_recursive_delete(self):
        owned = self.cache("owned", self.worktree / "DUNE.xcodeproj")
        rmtree = cleanup.shutil.rmtree

        def recreate_then_delete(path):
            self.cache("owned", self.other / "DUNE.xcodeproj")
            rmtree(path)

        with mock.patch.object(cleanup.shutil, "rmtree", side_effect=recreate_then_delete):
            self.assertEqual(self.run_cleanup(True), 0)
        self.assertTrue((owned / "Build/product").exists())

    def test_missing_cache_root_is_successful_noop(self):
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(cleanup.cleanup(self.worktree, [self.root / "absent"], True,
                                             allow_missing=True), 0)

    def test_overlapping_cache_roots_preserve_other_owner_in_both_orders(self):
        for reverse in (False, True):
            with self.subTest(reverse=reverse):
                owned = self.cache(f"owned-{reverse}", self.worktree / "DUNE.xcodeproj")
                nested = owned / "other"
                nested.mkdir()
                (nested / "info.plist").write_bytes(plistlib.dumps({
                    "WorkspacePath": str(self.other / "DUNE.xcodeproj"),
                }))
                roots = [self.cache_root, owned]
                self.assertEqual(self.run_cleanup(True, roots[::-1] if reverse else roots), 1)
                self.assertTrue((owned / "Build/product").exists())
                self.assertTrue((nested / "info.plist").exists())

    def test_explicit_missing_root_blocks_all_deletion(self):
        owned = self.cache("owned", self.worktree / "DUNE.xcodeproj")
        result = subprocess.run(
            ["python3", str(SCRIPT), "--worktree", str(self.worktree),
             "--derived-data-root", str(self.cache_root),
             "--derived-data-root", str(self.root / "typo"), "--apply"],
            capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 1)
        self.assertIn("Explicit cache root does not exist", result.stderr)
        self.assertTrue((owned / "Build/product").exists())

    def test_empty_staging_cleanup_failure_still_counts_deleted_cache(self):
        owned = self.cache("owned", self.worktree / "DUNE.xcodeproj")
        original = Path.rmdir

        def rmdir(path):
            if path.name.startswith(".worktree-deriveddata-cleanup-"):
                raise PermissionError("denied")
            return original(path)

        output = io.StringIO()
        with mock.patch.object(Path, "rmdir", rmdir), contextlib.redirect_stdout(output), \
                contextlib.redirect_stderr(io.StringIO()):
            result = cleanup.cleanup(self.worktree, [self.cache_root], True)
        self.assertEqual(result, 1)
        self.assertIn("1 deleted, 1 failed", output.getvalue())
        self.assertFalse(owned.exists())
        remaining = list(self.cache_root.glob(".worktree-deriveddata-cleanup-*"))
        self.assertEqual(len(remaining), 1)
        self.assertEqual(list(remaining[0].iterdir()), [])


if __name__ == "__main__":
    unittest.main()
