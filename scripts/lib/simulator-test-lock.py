#!/usr/bin/env python3
"""Serialize simulator test runners by repository or opted-in worktree."""

import fcntl
import hashlib
import math
import os
from pathlib import Path
import stat
import subprocess
import sys
import time


LOCK_FD_ENV = "DUNE_SIM_TEST_LOCK_FD"
WORKTREE_LOCK_FD_ENV = "DUNE_SIM_TEST_WORKTREE_LOCK_FD"
WAIT_SECONDS_ENV = "DUNE_SIM_TEST_LOCK_WAIT_SECONDS"
SCOPE_ENV = "DUNE_SIM_TEST_LOCK_SCOPE"


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


def worktree_lock_path(root: Path) -> tuple[Path, bool]:
    result = subprocess.run(
        ["git", "-C", str(root), "rev-parse", "--show-toplevel", "--git-dir", "--git-common-dir"],
        capture_output=True, text=True, check=True,
    )
    lines = result.stdout.splitlines()
    if len(lines) != 3:
        raise ValueError("Could not resolve Git worktree identity")
    top = Path(lines[0]).resolve(strict=True)
    git_dir = (root / lines[1]).resolve(strict=True)
    common_dir = (root / lines[2]).resolve(strict=True)
    if not top.is_dir() or not git_dir.is_dir() or not common_dir.is_dir():
        raise ValueError("Git worktree identity is not a directory")
    identity = hashlib.sha256(os.fsencode(top)).hexdigest()
    path = Path("/tmp") / f"dune-simulator-test-worktree-{os.getuid()}-{identity}.lock"
    return path, git_dir != common_dir


def check_lock_file(fd: int, path: Path) -> None:
    opened = os.fstat(fd)
    expected = path.lstat()
    if not stat.S_ISREG(opened.st_mode) or not stat.S_ISREG(expected.st_mode):
        raise ValueError("Simulator test lock is not a regular file")
    if opened.st_uid != os.getuid() or expected.st_uid != os.getuid():
        raise ValueError("Simulator test lock has a different owner")
    if (opened.st_dev, opened.st_ino) != (expected.st_dev, expected.st_ino):
        raise ValueError("Simulator test lock descriptor does not match the lock file")


def open_lock(path: Path) -> int:
    original_fd = os.open(path, os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    try:
        fd = fcntl.fcntl(original_fd, fcntl.F_DUPFD, 10)
    finally:
        os.close(original_fd)
    check_lock_file(fd, path)
    return fd


def acquire_lock(fd: int, label: str, wait_seconds: str | None, deadline: float | None) -> None:
    if wait_seconds is None:
        print(f"Waiting for {label} simulator test lock...", file=sys.stderr, flush=True)
        fcntl.flock(fd, fcntl.LOCK_EX)
        return
    assert deadline is not None
    while True:
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            return
        except BlockingIOError:
            if time.monotonic() >= deadline:
                raise TimeoutError(f"{label} simulator test lock remained busy for {wait_seconds}s")
            time.sleep(min(0.2, max(0, deadline - time.monotonic())))


def main() -> None:
    if len(sys.argv) < 3:
        raise ValueError("Usage: simulator-test-lock.py ROOT --verify | ROOT -- COMMAND [ARG ...]")

    root = Path(sys.argv[1]).resolve(strict=True)
    scope = os.environ.get(SCOPE_ENV, "repository")
    if scope not in ("repository", "worktree"):
        raise ValueError(f"{SCOPE_ENV} must be repository or worktree")
    repository_path = lock_path(root)
    worktree_path, is_linked = worktree_lock_path(root)
    if scope == "worktree" and not is_linked:
        raise ValueError("worktree lock scope requires a linked Git worktree")
    primary_path = repository_path if scope == "repository" else worktree_path
    if sys.argv[2] == "--verify":
        if len(sys.argv) != 3:
            raise ValueError("--verify takes no arguments")
        fd = int(os.environ.get(LOCK_FD_ENV, ""))
        check_lock_file(fd, primary_path)
        # The parent shell owns this inherited open-file description. The lock
        # remains held when this short verification process exits.
        fcntl.flock(fd, fcntl.LOCK_EX)
        secondary = os.environ.get(WORKTREE_LOCK_FD_ENV)
        if scope == "repository":
            worktree_fd = int(secondary or "")
            check_lock_file(worktree_fd, worktree_path)
            fcntl.flock(worktree_fd, fcntl.LOCK_EX)
        elif secondary is not None:
            raise ValueError("Unexpected inherited worktree lock descriptor")
        return

    if sys.argv[2] != "--" or len(sys.argv) < 4:
        raise ValueError("Expected -- COMMAND [ARG ...]")
    wait_seconds = os.environ.get(WAIT_SECONDS_ENV)
    deadline = None
    if wait_seconds is not None:
        try:
            wait_duration = float(wait_seconds)
        except ValueError as error:
            raise ValueError(f"{WAIT_SECONDS_ENV} must be a non-negative number") from error
        if not math.isfinite(wait_duration) or wait_duration < 0:
            raise ValueError(f"{WAIT_SECONDS_ENV} must be a non-negative number")
        deadline = time.monotonic() + wait_duration
    worktree_fd = open_lock(worktree_path)
    acquire_lock(worktree_fd, "worktree", wait_seconds, deadline)
    if scope == "repository":
        repository_fd = open_lock(repository_path)
        acquire_lock(repository_fd, "repository", wait_seconds, deadline)
        os.set_inheritable(repository_fd, True)
        os.set_inheritable(worktree_fd, True)
        os.environ[LOCK_FD_ENV] = str(repository_fd)
        os.environ[WORKTREE_LOCK_FD_ENV] = str(worktree_fd)
    else:
        os.set_inheritable(worktree_fd, True)
        os.environ[LOCK_FD_ENV] = str(worktree_fd)
        os.environ.pop(WORKTREE_LOCK_FD_ENV, None)
    os.execvp(sys.argv[3], sys.argv[3:])


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, TimeoutError, subprocess.CalledProcessError) as error:
        print(f"Simulator test lock: {error}", file=sys.stderr)
        sys.exit(2)
