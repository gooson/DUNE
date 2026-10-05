"""Exercise snapshot scope and stale detection using real isolated Git repositories."""

import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


HELPER = Path(__file__).resolve().parents[1] / "codex-context.py"


class ContextTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.git("init", "-q")
        (self.root / "original.txt").write_text("original\n")
        self.git("add", ".")
        self.commit()
        self.base = self.git("rev-parse", "HEAD").stdout.strip()

    def git(self, *args):
        return subprocess.run(["git", *args], cwd=self.root, check=True,
                              capture_output=True, text=True)

    def commit(self):
        self.git("-c", "user.name=Test", "-c", "user.email=test@example.com",
                 "commit", "-qm", "fixture")

    def run_helper(self, *args):
        return subprocess.run([sys.executable, str(HELPER), *args], cwd=self.root,
                              capture_output=True, text=True)

    def snapshot(self):
        result = self.run_helper("snapshot", "--base", self.base)
        self.assertEqual(result.returncode, 0, result.stderr)
        directory = Path(json.loads(result.stdout)["snapshot"])
        self.addCleanup(shutil.rmtree, directory)
        return directory, json.loads((directory / "manifest.json").read_text())

    def test_branch_index_worktree_and_untracked_scope(self):
        self.git("mv", "original.txt", "renamed space.txt")
        self.commit()
        (self.root / "renamed space.txt").write_text("staged content\n")
        self.git("add", ".")
        (self.root / "renamed space.txt").write_text("working content\n")
        (self.root / "new\nfile.txt").write_text("new\n")
        directory, manifest = self.snapshot()
        self.assertEqual(manifest["paths"], ["original.txt", "renamed space.txt"])
        self.assertEqual(manifest["untracked_read_separately"], ["new\nfile.txt"])
        self.assertIn("staged content", (directory / "staged.patch").read_text())
        self.assertIn("working content", (directory / "unstaged.patch").read_text())
        self.assertEqual(self.run_helper("check", str(directory)).returncode, 0)
        (self.root / "new\nfile.txt").write_text("changed\n")
        self.assertNotEqual(self.run_helper("check", str(directory)).returncode, 0)

    def test_staged_change_reverted_in_worktree_is_not_lost(self):
        (self.root / "original.txt").write_text("index only\n")
        self.git("add", ".")
        (self.root / "original.txt").write_text("original\n")
        _, manifest = self.snapshot()
        self.assertIn("original.txt", manifest["paths"])

    def test_missing_or_modified_patch_is_rejected(self):
        for remove in (False, True):
            directory, _ = self.snapshot()
            patch = directory / "branch.patch"
            if remove:
                patch.unlink()
            else:
                patch.write_text("corrupted")
            self.assertNotEqual(self.run_helper("check", str(directory)).returncode, 0)

    def test_deletion_and_binary_are_visible(self):
        (self.root / "original.txt").unlink()
        (self.root / "binary.dat").write_bytes(b"\x00\xff")
        self.git("add", ".")
        directory, manifest = self.snapshot()
        self.assertEqual(manifest["paths"], ["binary.dat", "original.txt"])
        self.assertIn("Binary files", (directory / "staged.patch").read_text())

    def test_invalid_base_fails_without_success_output(self):
        result = self.run_helper("snapshot", "--base", "nonexistent-ref")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")

    def test_inventory_does_not_print_instruction_content(self):
        (self.root / "AGENTS.md").write_text("PRIVATE INSTRUCTION BODY")
        result = self.run_helper("inventory")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("PRIVATE INSTRUCTION BODY", result.stdout)
        self.assertEqual(json.loads(result.stdout)["files"], 1)


if __name__ == "__main__":
    unittest.main()
