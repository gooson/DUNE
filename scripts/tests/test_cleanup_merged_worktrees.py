"""Use disposable Git repos; never delete a developer checkout in these tests."""

import contextlib
import fcntl
import importlib.util
import io
import json
import os
from pathlib import Path
import plistlib
import shlex
import subprocess
import sys
import tempfile
import unittest
from unittest import mock


SCRIPT = Path(__file__).resolve().parents[1] / "cleanup-merged-worktrees.py"
spec = importlib.util.spec_from_file_location("merged_cleanup", SCRIPT)
cleanup = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cleanup)


class MergedCleanupTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.directory = Path(temporary.name).resolve()
        self.root = self.directory / "main"
        self.root.mkdir()
        self.git("init", "-qb", "main")
        self.git("config", "user.name", "Test")
        self.git("config", "user.email", "test@example.com")
        (self.root / ".gitignore").write_text(".codex-checks/\n")
        self.git("add", ".gitignore")
        self.git("commit", "-qm", "initial")
        self.initial = self.git("rev-parse", "HEAD")
        self.git("switch", "-qc", "feature")
        (self.root / "change").write_text("merged work")
        self.git("add", "change")
        self.git("commit", "-qm", "feature")
        self.head = self.git("rev-parse", "HEAD")
        self.git("branch", "alias")
        self.git("switch", "-q", "main")
        self.git("merge", "--no-ff", "-qm", "merge feature", "feature")
        self.merge = self.git("rev-parse", "HEAD")
        self.git("remote", "add", "origin", "git@github.com:test/DUNE.git")
        self.git("update-ref", "refs/remotes/origin/main", self.merge)
        self.pr = {"number": 42, "merged_at": "2026-10-31T01:00:00Z", "state": "closed",
                   "base": {"ref": "main", "repo": {"full_name": "test/DUNE"}},
                   "head": {"sha": self.head}, "merge_commit_sha": self.merge}

    def git(self, *args, root=None):
        return cleanup.git(root or self.root, *args).stdout.strip()

    def branch_exists(self, branch):
        return cleanup.git(self.root, "show-ref", "--verify", "refs/heads/" + branch, check=False).returncode == 0

    def worktree(self, branch="feature"):
        path = self.directory / branch
        self.git("worktree", "add", str(path), branch)
        return path

    def execute(self, apply=True, root=None, assets=None, proof=42):
        with (mock.patch.object(cleanup, "merged_pr", return_value=proof),
              mock.patch.object(cleanup, "process_uses", return_value=False),
              mock.patch.object(cleanup, "cleanup_assets", assets or mock.Mock()),
              contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO())):
            return cleanup.cleanup(root or self.root, apply)

    def test_dry_run_preserves_then_apply_deletes_merged_alias_and_original(self):
        self.assertEqual(self.execute(False), 0)
        self.assertTrue(self.branch_exists("alias"))
        self.assertEqual(self.execute(), 0)
        self.assertFalse(self.branch_exists("feature"))
        self.assertFalse(self.branch_exists("alias"))
        self.assertEqual(self.git("branch", "--show-current"), "main")

    def test_clean_worktree_removed_after_assets_with_caches_on_same_owner(self):
        path = self.worktree()
        caches = self.directory / "caches"
        owned = caches / "owned"
        other = caches / "other"
        for cache, owner in ((owned, path), (other, self.root)):
            cache.mkdir(parents=True)
            (cache / "info.plist").write_bytes(plistlib.dumps({"WorkspacePath": str(owner / "DUNE.xcodeproj")}))
        self.git("config", "dune.cleanupDerivedDataRoot", str(caches))
        self.assertEqual(self.execute(assets=cleanup.cleanup_assets), 0)
        self.assertFalse(path.exists())
        self.assertFalse(owned.exists())
        self.assertTrue(other.exists())
        self.assertFalse(self.branch_exists("feature"))

    def test_dirty_and_untracked_worktrees_preserve_branch_and_assets(self):
        path = self.worktree()
        for filename in ("change", "untracked"):
            with self.subTest(filename=filename):
                file = path / filename
                original = file.read_text() if file.exists() else None
                file.write_text("do not lose")
                assets = mock.Mock()
                self.assertEqual(self.execute(assets=assets), 1)
                assets.assert_not_called()
                self.assertTrue(path.exists())
                self.assertTrue(self.branch_exists("feature"))
                if original is None:
                    file.unlink()
                else:
                    file.write_text(original)

    def test_invoking_checkout_and_locked_worktree_are_preserved(self):
        path = self.worktree()
        self.assertEqual(self.execute(root=path), 0)
        self.assertTrue(path.exists())
        self.git("worktree", "lock", str(path))
        self.assertEqual(self.execute(), 1)
        self.assertTrue(path.exists())
        self.git("worktree", "unlock", str(path))

    def test_ignored_user_files_protect_worktree_and_tracking_config_is_cleaned(self):
        path = self.worktree()
        ignored = path / ".codex-checks/private-notes.txt"
        ignored.parent.mkdir()
        ignored.write_text("keep private notes")
        assets = mock.Mock()
        self.assertEqual(self.execute(assets=assets), 1)
        assets.assert_not_called()
        self.assertEqual(ignored.read_text(), "keep private notes")
        ignored.unlink()
        self.git("config", "branch.feature.remote", "origin")
        self.git("config", "branch.feature.merge", "refs/heads/feature")
        self.assertEqual(self.execute(), 0)
        self.assertFalse(path.exists())
        self.assertEqual(cleanup.git(self.root, "config", "--get", "branch.feature.remote", check=False).returncode, 1)

    def test_open_files_are_detected_even_when_process_working_directory_is_elsewhere(self):
        path = self.worktree()
        def inventory(args, **_):
            if args[0] == "ps":
                return subprocess.CompletedProcess(args, 0, "editor --background\n", "")
            self.assertNotIn("-d", args)
            return subprocess.CompletedProcess(args, 0, f"p123\nn/elsewhere\nn{path}/change\n", "")
        with mock.patch.object(cleanup, "run", side_effect=inventory), mock.patch.object(cleanup.shutil, "which", return_value="lsof"):
            self.assertTrue(cleanup.process_uses(path))

    def test_missing_pr_or_new_commits_are_not_deleted(self):
        self.assertEqual(self.execute(proof=None), 0)
        path = self.worktree()
        self.git("commit", "--allow-empty", "-qm", "not merged", root=path)
        self.assertEqual(self.execute(), 0)
        self.assertTrue(path.exists())
        self.assertTrue(self.branch_exists("feature"))

    def test_cleanup_failure_and_active_runner_lock_preserve_worktree(self):
        path = self.worktree()
        assets = mock.Mock(side_effect=RuntimeError("cache failure"))
        self.assertEqual(self.execute(assets=assets), 1)
        self.assertTrue(path.exists())
        locks = cleanup.load_helper("lib/simulator-test-lock.py")
        fd = locks.open_lock(locks.worktree_lock_path(path)[0])
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            assets = mock.Mock()
            self.assertEqual(self.execute(assets=assets), 1)
            assets.assert_not_called()
        finally:
            os.close(fd)
        self.assertTrue(path.exists())

    def test_active_process_and_failed_inventory_protect_worktree(self):
        self.worktree()
        for outcome in (True, RuntimeError("inventory denied")):
            with (mock.patch.object(cleanup, "merged_pr", return_value=42),
                  mock.patch.object(cleanup, "process_uses", side_effect=outcome if isinstance(outcome, Exception) else None,
                                    return_value=outcome), contextlib.redirect_stdout(io.StringIO()),
                  contextlib.redirect_stderr(io.StringIO())):
                self.assertEqual(cleanup.cleanup(self.root, True), 1)
                self.assertTrue(self.branch_exists("feature"))

    def test_branch_advance_during_cleanup_is_preserved(self):
        path = self.worktree()
        def advance(*_):
            self.git("commit", "--allow-empty", "-qm", "concurrent work", root=path)
        self.assertEqual(self.execute(assets=advance), 1)
        self.assertTrue(path.exists())
        self.assertTrue(self.branch_exists("feature"))

    def test_pr_proof_requires_merged_main_pr_in_same_repo_and_main_history(self):
        original = cleanup.run
        responses = [self.pr]
        def api(args, **kwargs):
            if args[0] == "gh":
                return subprocess.CompletedProcess(args, 0, json.dumps(responses), "")
            return original(args, **kwargs)
        with mock.patch.object(cleanup, "run", side_effect=api):
            self.assertEqual(cleanup.merged_pr(self.root, "test/DUNE", self.head, self.merge), 42)
            for change in ({"merged_at": None}, {"state": "open"},
                           {"base": {"ref": "other", "repo": {"full_name": "test/DUNE"}}},
                           {"base": {"ref": "main", "repo": {"full_name": "other/repo"}}},
                           {"merge_commit_sha": "0" * 40}):
                responses[:] = [dict(self.pr, **change)]
                # An unavailable commit is a failed proof, never authorization to delete.
                try:
                    self.assertIsNone(cleanup.merged_pr(self.root, "test/DUNE", self.head, self.merge))
                except RuntimeError:
                    self.assertEqual(change, {"merge_commit_sha": "0" * 40})

    def test_install_preserves_existing_hooks_and_supports_idempotent_install(self):
        hooks = self.root / ".git/hooks"
        precommit = hooks / "pre-commit"
        precommit.write_text("unchanged")
        target = hooks / "reference-transaction"
        target.write_text("#!/bin/sh\nexit 0\n")
        with self.assertRaisesRegex(ValueError, "Existing hook"):
            cleanup.install(self.root)
        self.assertEqual(target.read_text(), "#!/bin/sh\nexit 0\n")
        target.unlink()
        with contextlib.redirect_stdout(io.StringIO()):
            cleanup.install(self.root)
            before = target.read_text()
            cleanup.install(self.root)
        self.assertEqual(target.read_text(), before)
        self.assertEqual(precommit.read_text(), "unchanged")
        self.assertEqual(self.git("config", "--bool", "dune.autoCleanupMerged"), "true")
        self.git("config", "core.hooksPath", str(self.directory / "custom"))
        with self.assertRaisesRegex(ValueError, "hooksPath"):
            cleanup.install(self.root)

    def test_real_reference_update_triggers_installed_hook_with_bundled_code(self):
        with contextlib.redirect_stdout(io.StringIO()):
            cleanup.install(self.root)
        binary = self.directory / "bin"
        binary.mkdir()
        gh = binary / "gh"
        gh.write_text("#!/bin/sh\nprintf '%s' " + shlex.quote(json.dumps([self.pr])) + "\n")
        gh.chmod(0o700)
        # Set the old tracking ref with recursion suppressed, then let a real Git
        # reference transaction invoke the installed hook without our Python mocks.
        self.git("update-ref", "refs/remotes/origin/main", self.initial)
        env = cleanup.environment()
        env.pop("DUNE_AUTO_CLEANUP_RUNNING")
        env["PATH"] = str(binary) + os.pathsep + env["PATH"]
        result = subprocess.run(["git", "-C", str(self.root), "update-ref", "refs/remotes/origin/main", self.merge],
                                env=env, capture_output=True, text=True, timeout=20)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.branch_exists("feature"))
        self.assertFalse(self.branch_exists("alias"))
        log = self.root / ".git/dune-merge-cleanup.log"
        self.assertIn("Deleted branch: alias", log.read_text())

    def test_hook_ignores_prepared_unrelated_deleted_disabled_and_recursive_events(self):
        event = f"{self.initial} {self.merge} refs/remotes/origin/main\n"
        with (mock.patch.object(cleanup, "cleanup") as execute,
              mock.patch("sys.stdin", io.StringIO(event)), mock.patch.dict(os.environ, {}, clear=False)):
            cleanup.hook("prepared")
            os.environ["DUNE_AUTO_CLEANUP_RUNNING"] = "1"
            cleanup.hook("committed")
            os.environ.pop("DUNE_AUTO_CLEANUP_RUNNING")
            for line in (event.replace("origin/main", "origin/feature"),
                         f"{self.merge} {'0' * 40} refs/remotes/origin/main\n"):
                with mock.patch("sys.stdin", io.StringIO(line)):
                    cleanup.hook("committed")
            with mock.patch.object(cleanup, "git", return_value=subprocess.CompletedProcess([], 1, "", "")):
                with mock.patch("sys.stdin", io.StringIO(event)):
                    cleanup.hook("committed")
            execute.assert_not_called()

    def test_hook_failure_does_not_fail_git_command(self):
        with (mock.patch("sys.argv", [str(SCRIPT), "--hook", "committed"]),
              mock.patch.object(cleanup, "hook", side_effect=RuntimeError("API offline")),
              contextlib.redirect_stderr(io.StringIO())):
            self.assertEqual(cleanup.main(), 0)


if __name__ == "__main__":
    unittest.main()
