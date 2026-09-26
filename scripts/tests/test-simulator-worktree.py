#!/usr/bin/env python3
"""Check simulator isolation without booting or deleting any simulator."""

import pathlib
import subprocess
import tempfile
import unittest


SCRIPT = pathlib.Path(__file__).resolve().parents[1] / "lib/simulator-worktree.sh"


class SimulatorWorktreeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = pathlib.Path(self.temp.name)
        self.repo = self.root / "main"
        self.repo.mkdir()
        self.git(self.repo, "init", "-q")
        self.git(self.repo, "-c", "user.name=Test", "-c", "user.email=test@example.com",
                 "commit", "--allow-empty", "-qm", "initial")
        self.worktrees = [self.root / name / "Health" for name in ("first", "second")]
        for path in self.worktrees:
            self.git(self.repo, "worktree", "add", "--detach", str(path), "HEAD")

    def git(self, cwd, *args):
        return subprocess.run(["git", *args], cwd=cwd, check=True, capture_output=True)

    def shell(self, cwd, command, check=True):
        return subprocess.run(
            ["bash", "-c", 'source "$1"; ' + command, "test", str(SCRIPT)],
            cwd=cwd, check=check, capture_output=True, text=True,
        )

    def test_same_basename_has_distinct_stable_device_names(self):
        command = '''
        _find_simulator_by_name() { printf '%s\\n' "$1"; }
        ensure_worktree_simulator AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE 'iPhone Test'
        '''
        first = self.shell(self.worktrees[0], command).stdout.strip()
        second = self.shell(self.worktrees[1], command).stdout.strip()
        self.assertNotEqual(first, second)
        self.assertEqual(first, self.shell(self.worktrees[0], command).stdout.strip())
        self.assertRegex(first, r"^iPhone Test-wt-Health-[0-9a-f]{12}$")

    def test_current_cleanup_uses_same_unique_key(self):
        command = '''
        _find_simulators_matching() { printf '%s\\n' "$1" >&2; }
        cleanup_worktree_simulators --current
        '''
        keys = [self.shell(path, "_worktree_basename").stdout.strip() for path in self.worktrees]
        for path, key in zip(self.worktrees, keys):
            self.assertEqual(self.shell(path, command).stderr.strip(), "-wt-" + key)
        self.assertNotEqual(keys[0], keys[1])

    def test_main_checkout_preserves_source_device(self):
        result = self.shell(self.repo,
                            "ensure_worktree_simulator AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE 'iPhone Test'")
        self.assertEqual(result.stdout.strip(), "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")

    def test_hash_failure_does_not_fall_back_to_shared_device(self):
        commands = [
            "ensure_worktree_simulator AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE 'iPhone Test'",
            "apply_worktree_destination 'id=AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE' 'iPhone Test' iOS",
            "cleanup_worktree_simulators --current",
        ]
        for command in commands:
            with self.subTest(command=command):
                result = self.shell(self.worktrees[0], "shasum() { return 1; }; " + command,
                                    check=False)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stdout, "")
                self.assertIn("Cannot compute worktree identity", result.stderr)


if __name__ == "__main__":
    unittest.main()
