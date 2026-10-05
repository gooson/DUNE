#!/usr/bin/env python3
"""Serialize simulator test runners across worktrees of one Git repository."""

import fcntl
import hashlib
import os
from pathlib import Path
import stat
import subprocess
import sys


LOCK_FD_ENV = "DUNE_SIM_TEST_LOCK_FD"


def lock_path(root: Path) -> Path:
    result = subprocess.run(
        ["git", "-C", str(root), "rev-parse", "--git-common-dir"],
        capture_output=True,
        text=True,
        check=True,
    )
    common_dir = (root / result.stdout.strip()).resolve(strict=True)
    if not common_dir.is_dir():
        raise ValueError(f"Git common directory is not a directory: {common_dir}")
    identity = hashlib.sha256(os.fsencode(common_dir)).hexdigest()
    return Path("/tmp") / f"dune-simulator-test-{os.getuid()}-{identity}.lock"


def check_lock_file(fd: int, path: Path) -> None:
    opened = os.fstat(fd)
    expected = path.lstat()
    if not stat.S_ISREG(opened.st_mode) or not stat.S_ISREG(expected.st_mode):
        raise ValueError("Simulator test lock is not a regular file")
    if opened.st_uid != os.getuid() or expected.st_uid != os.getuid():
        raise ValueError("Simulator test lock has a different owner")
    if (opened.st_dev, opened.st_ino) != (expected.st_dev, expected.st_ino):
        raise ValueError("Simulator test lock descriptor does not match the lock file")


def main() -> None:
    if len(sys.argv) < 3:
        raise ValueError("Usage: simulator-test-lock.py ROOT --verify | ROOT -- COMMAND [ARG ...]")

    root = Path(sys.argv[1]).resolve(strict=True)
    path = lock_path(root)
    if sys.argv[2] == "--verify":
        if len(sys.argv) != 3:
            raise ValueError("--verify takes no arguments")
        fd = int(os.environ.get(LOCK_FD_ENV, ""))
        check_lock_file(fd, path)
        # The parent shell owns this inherited open-file description. The lock
        # remains held when this short verification process exits.
        fcntl.flock(fd, fcntl.LOCK_EX)
        return

    if sys.argv[2] != "--" or len(sys.argv) < 4:
        raise ValueError("Expected -- COMMAND [ARG ...]")
    original_fd = os.open(path, os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    try:
        fd = fcntl.fcntl(original_fd, fcntl.F_DUPFD, 10)
    finally:
        os.close(original_fd)
    check_lock_file(fd, path)
    print("Waiting for repository simulator test lock...", file=sys.stderr, flush=True)
    fcntl.flock(fd, fcntl.LOCK_EX)
    os.set_inheritable(fd, True)
    os.environ[LOCK_FD_ENV] = str(fd)
    os.execvp(sys.argv[3], sys.argv[3:])


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print(f"Simulator test lock: {error}", file=sys.stderr)
        sys.exit(2)
