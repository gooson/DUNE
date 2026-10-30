#!/usr/bin/env python3
"""Remove external Xcode caches whose WorkspacePath belongs to one worktree."""

import argparse
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile
from typing import NamedTuple
from xml.parsers.expat import ExpatError


class Cache(NamedTuple):
    path: Path
    workspace: Path
    device: int
    inode: int


def worktree_root(path: Path) -> Path:
    root = path.expanduser().resolve(strict=True)
    result = subprocess.run(
        ["git", "-C", str(root), "rev-parse", "--show-toplevel", "--git-dir", "--git-common-dir"],
        check=True, capture_output=True, text=True,
    )
    paths = result.stdout.splitlines()
    if len(paths) != 3 or Path(paths[0]).resolve(strict=True) != root:
        raise ValueError(f"Expected an existing Git worktree root: {root}")
    if (root / paths[1]).resolve(strict=True) == (root / paths[2]).resolve(strict=True):
        raise ValueError(f"Primary checkout is protected; expected a linked worktree: {root}")
    return root


def inspect_cache(path: Path, worktree: Path) -> tuple[Cache | None, str]:
    if path.is_symlink() or not path.is_dir():
        return None, "not a regular cache directory"
    if path.is_relative_to(worktree) or worktree.is_relative_to(path):
        return None, "overlaps the source worktree"
    if (path / ".git").exists():
        return None, "contains a Git checkout"
    info = path / "info.plist"
    if info.is_symlink() or not info.is_file():
        return None, "no regular info.plist"
    try:
        data = plistlib.loads(info.read_bytes())
    except (plistlib.InvalidFileException, ExpatError, ValueError, TypeError, OverflowError) as error:
        return None, f"invalid info.plist ({type(error).__name__})"
    raw = data.get("WorkspacePath") if isinstance(data, dict) else None
    if not isinstance(raw, str) or not raw or not Path(raw).is_absolute():
        return None, "no absolute WorkspacePath"
    workspace = Path(raw).resolve()
    if workspace.suffix not in (".xcodeproj", ".xcworkspace"):
        return None, "WorkspacePath is not an Xcode project or workspace"
    if not workspace.is_relative_to(worktree):
        return None, "WorkspacePath belongs elsewhere"
    # A nested checkout is a different owner, even when its parent is this worktree.
    for parent in workspace.parents:
        if parent == worktree:
            break
        if (parent / ".git").exists():
            return None, "WorkspacePath belongs to a nested checkout"
    identity = path.stat()
    return Cache(path, workspace, identity.st_dev, identity.st_ino), ""


def delete_cache(expected: Cache, worktree: Path) -> Path | None:
    current, reason = inspect_cache(expected.path, worktree)
    if current != expected:
        raise ValueError(f"cache ownership or identity changed: {reason}")
    # Atomically detach the cache from its public pathname. A build recreating
    # that pathname cannot have its new directory removed by the recursive delete.
    quarantine = Path(tempfile.mkdtemp(prefix=".worktree-deriveddata-cleanup-", dir=expected.path.parent))
    staged = quarantine / "cache"
    try:
        expected.path.rename(staged)
        current, reason = inspect_cache(staged, worktree)
        if current != expected._replace(path=staged):
            raise ValueError(f"cache changed while being detached: {reason}")
        shutil.rmtree(staged)
        if staged.exists() or staged.is_symlink():
            raise OSError("cache still exists after deletion")
    except (OSError, ValueError, RuntimeError):
        if staged.exists() or staged.is_symlink():
            print(f"Recovery required: preserved {staged}; original path {expected.path}", file=sys.stderr)
        else:
            quarantine.rmdir()
        raise
    try:
        quarantine.rmdir()
    except OSError as error:
        print(f"Could not remove empty staging directory {quarantine}: {error}", file=sys.stderr)
        return quarantine
    return None


def cleanup(worktree: Path, roots: list[Path], apply: bool = False, *, allow_missing: bool = False) -> int:
    candidates = []
    seen = set()
    failures = 0
    for supplied in roots:
        try:
            root = supplied.expanduser().resolve()
            if root in seen:
                continue
            if any(root.is_relative_to(other) or other.is_relative_to(root) for other in seen):
                raise ValueError(f"Overlapping cache roots are not allowed: {root}")
            seen.add(root)
            if not root.exists():
                if not allow_missing:
                    raise FileNotFoundError(f"Explicit cache root does not exist: {root}")
                print(f"Absent cache root: {root}")
                continue
            if root.is_relative_to(worktree) or worktree.is_relative_to(root):
                raise ValueError(f"External cache root overlaps the worktree: {root}")
            for path in sorted(root.iterdir()):
                try:
                    cache, reason = inspect_cache(path, worktree)
                    if cache is None:
                        print(f"Preserved: {path} ({reason})")
                    else:
                        candidates.append(cache)
                        print(f"Candidate: {cache.path} <- {cache.workspace}")
                except (OSError, ValueError, RuntimeError) as error:
                    failures += 1
                    print(f"Could not inspect {path}: {error}", file=sys.stderr)
        except (OSError, ValueError, RuntimeError) as error:
            failures += 1
            print(f"Could not scan {supplied}: {error}", file=sys.stderr)

    # A partial scan must not silently become an approved deletion plan.
    if failures:
        print("No caches deleted because inspection was incomplete.", file=sys.stderr)
        return 1

    removed = 0
    if apply:
        for expected in candidates:
            try:
                leftover = delete_cache(expected, worktree)
                removed += 1
                print(f"Deleted: {expected.path}")
                if leftover is not None:
                    failures += 1
            except (OSError, ValueError, RuntimeError) as error:
                failures += 1
                print(f"Could not delete {expected.path}: {error}", file=sys.stderr)
    print(f"{'Cleanup' if apply else 'Dry run'}: {len(candidates)} matched, {removed} deleted, {failures} failed.")
    return 1 if failures else 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--worktree", type=Path, required=True,
                        help="Existing worktree root; run before git worktree remove")
    parser.add_argument("--derived-data-root", type=Path, action="append",
                        help="Cache parent to scan (repeatable; overrides the Xcode default)")
    parser.add_argument("--apply", action="store_true", help="Delete matches; default is dry run")
    args = parser.parse_args()
    try:
        root = worktree_root(args.worktree)
        roots = args.derived_data_root or [Path.home() / "Library/Developer/Xcode/DerivedData"]
        return cleanup(root, roots, args.apply, allow_missing=args.derived_data_root is None)
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        print(f"DerivedData cleanup: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
