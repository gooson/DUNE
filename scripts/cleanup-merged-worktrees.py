#!/usr/bin/env python3
"""Clean local refs/worktrees only after confirming a merged GitHub PR."""

import argparse
from contextlib import ExitStack, redirect_stderr, redirect_stdout
import fcntl
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import tempfile


SCRIPTS = Path(__file__).resolve().parent
MARKER = "# DUNE merged-worktree cleanup hook"
LOCAL_GIT_ENV = (
    "GIT_DIR", "GIT_COMMON_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE", "GIT_PREFIX",
    "GIT_OBJECT_DIRECTORY", "GIT_ALTERNATE_OBJECT_DIRECTORIES", "GIT_NAMESPACE",
)
BUNDLE_FILES = (
    "cleanup-merged-worktrees.py", "cleanup-worktree-deriveddata.py",
    "lib/simulator-test-lock.py", "lib/worktree-simulator-registry.py",
    "lib/command-deadline.py",
)


def environment():
    env = os.environ.copy()
    for key in LOCAL_GIT_ENV:
        env.pop(key, None)
    env["DUNE_AUTO_CLEANUP_RUNNING"] = "1"
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    return env


def run(args, *, cwd=None, timeout=15, check=True):
    return subprocess.run(args, cwd=cwd, env=environment(), capture_output=True,
                          text=True, timeout=timeout, check=check)


def git(root, *args, check=True):
    return run(["git", "-C", str(root), *args], check=check)


def ancestor(root, older, newer):
    result = git(root, "merge-base", "--is-ancestor", older, newer, check=False)
    if result.returncode not in (0, 1):
        raise RuntimeError(result.stderr.strip())
    return result.returncode == 0


def load_helper(relative):
    spec = importlib.util.spec_from_file_location("cleanup_helper", SCRIPTS / relative)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def worktrees(root):
    raw = git(root, "worktree", "list", "--porcelain", "-z").stdout
    return [dict((field.partition(" ")[0], field.partition(" ")[2])
                 for field in record.split("\0") if field)
            for record in raw.strip("\0").split("\0\0") if record]


def repository(root):
    url = git(root, "remote", "get-url", "origin").stdout.strip()
    match = re.fullmatch(r"(?:git@github\.com:|https://github\.com/)([\w.-]+/[\w.-]+?)(?:\.git)?", url)
    if match is None:
        raise ValueError("origin must be a github.com SSH or HTTPS repository")
    return match[1]


def merged_pr(root, repo, head, base):
    result = run(["gh", "api", "--hostname", "github.com",
                  f"repos/{repo}/commits/{head}/pulls?per_page=100"], timeout=10)
    pulls = json.loads(result.stdout)
    if not isinstance(pulls, list):
        raise ValueError("Unexpected GitHub commit pull-request response")
    for pr in pulls:
        if (pr.get("merged_at") and pr.get("state") == "closed"
                and pr.get("base", {}).get("ref") == "main"
                and pr.get("base", {}).get("repo", {}).get("full_name") == repo):
            pr_head = pr.get("head", {}).get("sha", "")
            merge = pr.get("merge_commit_sha", "")
            if (re.fullmatch(r"[0-9a-f]{40,64}", pr_head)
                    and re.fullmatch(r"[0-9a-f]{40,64}", merge)
                    and ancestor(root, head, pr_head) and ancestor(root, merge, base)):
                return pr["number"]
    return None


def process_uses(path):
    # A failed process inventory must never become permission to delete a checkout.
    processes = run(["ps", "-axo", "command="]).stdout.splitlines()
    if any("xcodebuild" in line and str(path) in line for line in processes):
        return True
    lsof = shutil.which("lsof")
    if lsof is None:
        raise RuntimeError("lsof unavailable; cannot check active files and directories")
    result = run([lsof, "-nP", "-Fn"], timeout=10, check=False)
    if result.returncode != 0 or not result.stdout.strip():
        raise RuntimeError("Cannot inspect active files and working directories")
    return any(Path(line[1:]).is_relative_to(path)
               for line in result.stdout.splitlines() if line.startswith("n/"))


def protected(root, item, caller, primary, head):
    path = Path(item["worktree"])
    if path.resolve() in (caller, primary):
        return "primary or invoking checkout"
    if "locked" in item or "prunable" in item or not path.is_dir() or path.is_symlink():
        return "locked, missing, prunable or symlink checkout"
    if git(path, "rev-parse", "HEAD").stdout.strip() != head:
        return "HEAD changed"
    if git(path, "symbolic-ref", "-q", "HEAD", check=False).stdout.strip() != item.get("branch", ""):
        return "checkout branch changed"
    git_dir = Path(git(path, "rev-parse", "--absolute-git-dir").stdout.strip())
    if any(git_dir.glob("*.lock")):
        return "Git operation lock"
    if git(path, "status", "--porcelain", "--untracked-files=all").stdout:
        return "uncommitted or untracked files"
    ignored = git(path, "ls-files", "--others", "--ignored", "--exclude-standard", "-z").stdout.split("\0")
    owned_records = {"", ".codex-checks/worktree-simulators.json", ".codex-checks/worktree-simulators.lock"}
    if any(name not in owned_records for name in ignored):
        return "ignored files outside the verified simulator registry"
    if process_uses(path):
        return "active process uses checkout"
    return None


def cleanup_assets(root, path, apply):
    args = [sys.executable, str(SCRIPTS / "cleanup-worktree-deriveddata.py"), "--worktree", str(path)]
    # Explicit roots override the default, matching the existing ownership tool.
    roots = git(root, "config", "--get-all", "dune.cleanupDerivedDataRoot", check=False)
    if roots.returncode not in (0, 1):
        raise RuntimeError(roots.stderr.strip())
    for cache_root in roots.stdout.splitlines():
        args.extend(["--derived-data-root", cache_root])
    dry = run(args, timeout=30)
    for line in dry.stdout.splitlines():
        if not line.startswith("Preserved:"):
            print(line)
    if apply:
        deadline = [sys.executable, str(SCRIPTS / "lib/command-deadline.py"), "--seconds", "120", "--"]
        for command in ([sys.executable, str(SCRIPTS / "lib/worktree-simulator-registry.py"), "cleanup", str(path)],
                        args + ["--apply"]):
            result = run(deadline + command, timeout=130)
            for line in result.stdout.splitlines():
                if not line.startswith("Preserved:"):
                    print(line)


def remove_worktree(root, item, caller, primary, head, apply):
    path = Path(item["worktree"]).resolve()
    locks = load_helper("lib/simulator-test-lock.py")
    with ExitStack() as stack:
        for lock_path in (locks.worktree_lock_path(path)[0], locks.lock_path(path)):
            fd = locks.open_lock(lock_path)
            stack.callback(os.close, fd)
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        # Re-read both Git's worktree lock and live filesystem under runner locks.
        current = next((w for w in worktrees(root) if Path(w["worktree"]).resolve() == path), None)
        if current is None or current.get("branch") != item.get("branch"):
            raise RuntimeError("Worktree registration changed")
        reason = protected(root, current, caller, primary, head)
        if reason:
            raise RuntimeError(reason)
        cleanup_assets(root, path, apply)
        if apply:
            current = next(w for w in worktrees(root) if Path(w["worktree"]).resolve() == path)
            reason = protected(root, current, caller, primary, head)
            if reason:
                raise RuntimeError(reason)
            git(primary, "worktree", "remove", str(path))
            print(f"Removed worktree: {path}")


def cleanup(root, apply=False):
    caller = Path(git(root, "rev-parse", "--show-toplevel").stdout.strip()).resolve()
    entries = worktrees(root)
    primary = Path(entries[0]["worktree"]).resolve()
    base = git(root, "rev-parse", "refs/remotes/origin/main^{commit}").stdout.strip()
    repo = repository(root)
    attached = {w["branch"]: w for w in entries if "branch" in w}
    refs = git(root, "for-each-ref", "--format=%(refname) %(objectname)", "refs/heads").stdout.splitlines()
    removed = 0
    failures = 0
    for line in refs:
        ref, head = line.split()
        if ref == "refs/heads/main" or not ancestor(root, head, base):
            continue
        item = attached.get(ref)
        if item and Path(item["worktree"]).resolve() in (caller, primary):
            continue
        try:
            pr = merged_pr(root, repo, head, base)
            if pr is None:
                print(f"Preserved: {ref} (no merged PR proof)")
                continue
            print(f"Candidate: {ref} (PR #{pr}, {head[:12]})")
            if item:
                remove_worktree(root, item, caller, primary, head, apply)
            if apply:
                if any(w.get("branch") == ref for w in worktrees(root)):
                    raise RuntimeError("Branch is now checked out")
                # Compare-and-delete prevents deleting a branch that advanced after inspection.
                git(primary, "update-ref", "-d", ref, head)
                print(f"Deleted branch: {ref.removeprefix('refs/heads/')}")
                removed += 1
                config = git(primary, "config", "--remove-section", "branch." + ref.removeprefix("refs/heads/"), check=False)
                if config.returncode not in (0, 128):
                    raise RuntimeError("Branch removed but tracking config could not be cleaned")
        except (OSError, ValueError, RuntimeError, subprocess.SubprocessError, StopIteration) as error:
            failures += 1
            detail = getattr(error, "stderr", None) or str(error)
            print(f"Preserved: {ref} ({detail.strip()})", file=sys.stderr)
    print(f"{'Cleanup' if apply else 'Dry run'}: {removed} local branches deleted; {failures} deferred.")
    return 1 if failures else 0


def install(root):
    common = Path(git(root, "rev-parse", "--path-format=absolute", "--git-common-dir").stdout.strip())
    hooks = common / "hooks"
    configured = git(root, "config", "--path", "--get", "core.hooksPath", check=False).stdout.strip()
    if configured and Path(configured).resolve() != hooks:
        raise ValueError(f"Custom core.hooksPath is protected: {configured}")
    hooks.mkdir(exist_ok=True)
    target = hooks / "reference-transaction"
    if target.is_symlink() or (target.exists() and MARKER not in target.read_text()):
        raise ValueError(f"Existing hook is protected: {target}")
    digest = hashlib.sha256()
    for relative in BUNDLE_FILES:
        digest.update(relative.encode())
        digest.update((SCRIPTS / relative).read_bytes())
    bundle = common / "dune-merge-cleanup" / digest.hexdigest()[:16]
    bundle.mkdir(parents=True, exist_ok=True)
    for relative in BUNDLE_FILES:
        destination = bundle / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(SCRIPTS / relative, destination)
    text = (f"#!/bin/sh\n{MARKER}\nexec {shlex.quote(sys.executable)} "
            f"{shlex.quote(str(bundle / 'cleanup-merged-worktrees.py'))} --hook \"$@\"\n")
    fd, temporary = tempfile.mkstemp(prefix=".reference-transaction-", dir=hooks)
    try:
        with os.fdopen(fd, "w") as output:
            output.write(text)
        os.chmod(temporary, 0o700)
        os.replace(temporary, target)
    finally:
        if Path(temporary).exists():
            Path(temporary).unlink()
    git(root, "config", "dune.autoCleanupMerged", "true")
    print(f"Installed and enabled: {target}")


def hook(state):
    if state != "committed" or os.environ.get("DUNE_AUTO_CLEANUP_RUNNING") == "1":
        return
    changes = [line.split() for line in sys.stdin.read().splitlines()]
    if not any(len(row) == 3 and row[0] != row[1] and set(row[1]) != {"0"}
               and row[2] in ("refs/heads/main", "refs/remotes/origin/main") for row in changes):
        return
    root = Path.cwd()
    if git(root, "config", "--bool", "dune.autoCleanupMerged", check=False).stdout.strip() != "true":
        return
    common = Path(git(root, "rev-parse", "--path-format=absolute", "--git-common-dir").stdout.strip())
    locks = load_helper("lib/simulator-test-lock.py")
    fd = locks.open_lock(common / "dune-merge-cleanup.lock")
    try:
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        log_fd = os.open(common / "dune-merge-cleanup.log", os.O_WRONLY | os.O_CREAT | os.O_APPEND | os.O_NOFOLLOW, 0o600)
        with os.fdopen(log_fd, "a", buffering=1) as log, redirect_stdout(log), redirect_stderr(log):
            print(f"\nReference update: {changes}")
            # An idle Codex chat can own a clean checkout without a process or
            # open file. Git cannot prove that chat has released its worktree.
            print("Automatic cleanup is audit-only: chat ownership is unverified.")
            cleanup(root, apply=False)
    finally:
        os.close(fd)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--install", action="store_true", help="Install and enable the shared local hook")
    group.add_argument("--apply", action="store_true", help="Delete verified merged local branches/worktrees")
    group.add_argument("--hook", metavar="STATE", help=argparse.SUPPRESS)
    args = parser.parse_args()
    try:
        if args.hook is not None:
            hook(args.hook)
        elif args.install:
            install(Path.cwd())
        else:
            return cleanup(Path.cwd(), args.apply)
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        detail = getattr(error, "stderr", None) or str(error)
        print(f"Merged-worktree cleanup: {detail.strip()}", file=sys.stderr)
        # Cleanup can never change the outcome of an already committed Git update.
        return 0 if args.hook is not None else 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
