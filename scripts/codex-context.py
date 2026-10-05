#!/usr/bin/env python3
"""Inventory instruction sizes or save one review snapshot without printing bodies."""

import argparse
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile


sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location(
    "codex_check", Path(__file__).with_name("codex-check.py"))
checks = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checks)


def emit(value):
    print(json.dumps(value, ensure_ascii=True, indent=2))


def inventory(root):
    paths = {root / name for name in ("AGENTS.md", "CLAUDE.md")}
    for directory in (".codex", ".claude"):
        paths.update(path for path in (root / directory).rglob("*.md")
                     if "worktrees" not in path.relative_to(root / directory).parts)
    rows = sorted(({"path": str(path.relative_to(root)), "bytes": path.stat().st_size}
                   for path in paths if path.is_file()),
                  key=lambda row: (-row["bytes"], row["path"]))
    emit({"files": len(rows), "total_bytes": sum(row["bytes"] for row in rows),
          "largest_10": rows[:10], "token_count": "unknown",
          "note": "File sizes only; this is not automatic context usage or a rule skip list."})


def snapshot(root, base):
    before = checks.fingerprint(root)
    ancestor = checks.git(root, "merge-base", "HEAD", base).decode().strip()
    options = ("--no-ext-diff", "--no-textconv", "--no-renames")
    changed = checks.git(root, "diff", *options, "--name-only", "-z", ancestor, "--")
    untracked = checks.git(root, "ls-files", "--others", "--exclude-standard", "-z")
    decode = lambda data: sorted(p.decode(errors="surrogateescape") for p in data.split(b"\0") if p)
    # Separate index/worktree patches preserve staged edits reverted in the worktree.
    patches = {
        "branch.patch": (ancestor, "HEAD"),
        "staged.patch": ("--cached", "HEAD"),
        "unstaged.patch": (),
    }
    staged = checks.git(root, "diff", *options, "--cached", "--name-only", "-z", "HEAD", "--")
    unstaged = checks.git(root, "diff", *options, "--name-only", "-z", "--")
    with tempfile.TemporaryDirectory(prefix="codex-context-build-") as scratch:
        scratch = Path(scratch)
        for name, revisions in patches.items():
            with (scratch / name).open("wb") as output:
                subprocess.run(["git", "diff", *options, *revisions, "--"], cwd=root,
                               stdout=output, check=True)
        if before != checks.fingerprint(root):
            raise ValueError("worktree changed during snapshot; do not reuse")
        destination = Path(tempfile.mkdtemp(prefix="codex-context-"))
        for name in patches:
            (scratch / name).replace(destination / name)
    manifest = {"root": str(root), "base": base, "merge_base": ancestor,
                "fingerprint": before,
                "paths": sorted(set(decode(changed) + decode(staged) + decode(unstaged))),
                "untracked_read_separately": decode(untracked),
                "patches": {name: checks.file_hash(destination / name) for name in patches},
                "note": "Binary bodies and untracked content require separate inspection. Not review/test evidence."}
    (destination / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    emit({"snapshot": str(destination), "tracked_paths": len(manifest["paths"]),
          "untracked_paths": len(manifest["untracked_read_separately"]),
          "patch_bytes": sum((destination / name).stat().st_size for name in patches),
          "note": manifest["note"]})


def validate(root, directory):
    manifest = json.loads((directory / "manifest.json").read_text())
    ancestor = checks.git(root, "merge-base", "HEAD", manifest["base"]).decode().strip()
    if (manifest["root"] != str(root) or manifest["merge_base"] != ancestor
            or manifest["fingerprint"] != checks.fingerprint(root)):
        raise ValueError("snapshot is stale; collect current changes")
    for name in ("branch.patch", "staged.patch", "unstaged.patch"):
        if checks.file_hash(directory / name) != manifest["patches"][name]:
            raise ValueError("snapshot patch is missing or modified")
    emit({"snapshot": str(directory), "status": "current", "review_passed": False})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="action", required=True)
    commands.add_parser("inventory")
    create = commands.add_parser("snapshot")
    create.add_argument("--base", required=True)
    check = commands.add_parser("check")
    check.add_argument("directory", type=Path)
    args = parser.parse_args()
    try:
        root = checks.repo_root()
        if args.action == "inventory":
            inventory(root)
        elif args.action == "snapshot":
            snapshot(root, args.base)
        else:
            validate(root, args.directory)
        return 0
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as error:
        print(f"context failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
