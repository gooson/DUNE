#!/usr/bin/env python3
"""Run a verification command and explicitly check its reusable receipt.

Usage:
  python3 scripts/codex-check.py run NAME --context CONTEXT [--content-only] -- COMMAND [ARG ...]
  python3 scripts/codex-check.py check NAME --context CONTEXT [--content-only] -- COMMAND [ARG ...]

Only `run` executes COMMAND. A `check` exit code of zero means the last run of
NAME completed successfully against the current worktree and identical inputs.
Use --content-only only for commands independent of Git HEAD and index metadata.
Git-dependent commands must use the default mode or encode the exact revision in
--context.
"""

import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import uuid


STORE = ".codex-checks"


def git(root, *args):
    return subprocess.run(
        ["git", *args], cwd=root, check=True, stdout=subprocess.PIPE
    ).stdout


def repo_root():
    return Path(git(Path.cwd(), "rev-parse", "--show-toplevel").decode().strip()).resolve()


def fingerprint(root, content_only=False):
    """Hash repository identity and every tracked or nonignored untracked path."""
    digest = hashlib.sha256()
    identity = [str(root).encode()]
    if not content_only:
        identity.extend((git(root, "rev-parse", "HEAD").strip(),
                         git(root, "ls-files", "-z", "--stage")))
    for part in identity:
        digest.update(len(part).to_bytes(8, "big"))
        digest.update(part)

    tracked = set(p for p in git(root, "ls-files", "-z", "--cached").split(b"\0") if p)
    untracked = set(p for p in git(root, "ls-files", "-z", "--others", "--exclude-standard").split(b"\0") if p)
    paths = tracked | untracked

    for raw in sorted(paths):
        rel = os.fsdecode(raw)
        if rel == STORE or rel.startswith(STORE + "/"):
            if raw in tracked:
                raise ValueError(f"{STORE} must not contain tracked files")
            continue
        path = root / rel
        info = path.lstat() if path.exists() or path.is_symlink() else None
        digest.update(len(raw).to_bytes(8, "big"))
        digest.update(raw)
        if info is None:
            digest.update(b"missing")
        elif stat.S_ISLNK(info.st_mode):
            digest.update(b"symlink")
            digest.update(os.fsencode(os.readlink(path)))
        elif stat.S_ISREG(info.st_mode):
            digest.update(b"file")
            digest.update((info.st_mode & 0o777).to_bytes(2, "big"))
            with path.open("rb") as source:
                while chunk := source.read(1024 * 1024):
                    digest.update(chunk)
        else:
            raise ValueError(f"unsupported worktree path: {rel}")
    return digest.hexdigest()


def write_receipt(path, value):
    temporary = path.with_suffix(".tmp")
    temporary.write_text(json.dumps(value, sort_keys=True) + "\n", encoding="utf-8")
    temporary.replace(path)


def file_hash(path):
    digest = hashlib.sha256()
    with path.open("rb") as source:
        while chunk := source.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def run(root, name, context, command, content_only):
    store = root / STORE
    if store.is_symlink():
        print(f"verification failed: {STORE} must be a directory", file=sys.stderr)
        return 1
    store.mkdir(exist_ok=True)
    key = hashlib.sha256(name.encode()).hexdigest()[:24]
    receipt_path = store / f"{key}.json"
    log_path = store / f"{key}-{uuid.uuid4().hex}.log"
    record = {"name": name, "context": context, "command": command,
              "content_only": content_only, "status": "running", "log": log_path.name}
    with (store / f"{key}.lock").open("a+b") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        return run_locked(root, name, command, content_only, receipt_path, log_path, record)


def run_locked(root, name, command, content_only, receipt_path, log_path, record):
    # Invalidate previous success before doing any validation or command work.
    write_receipt(receipt_path, record)
    try:
        before = fingerprint(root, content_only)
        with log_path.open("wb") as log:
            result = subprocess.run(command, cwd=root, stdout=log,
                                    stderr=subprocess.STDOUT, check=False)
        log_hash = file_hash(log_path)
        after = fingerprint(root, content_only)
        record.update(status="success" if result.returncode == 0 and before == after else "failed",
                      fingerprint=before, exit_code=result.returncode, log_hash=log_hash)
        if before != after:
            record["reason"] = "worktree changed during command"
        write_receipt(receipt_path, record)
        print(f"{record['status']}: {name} (exit {result.returncode}); log: {log_path}")
        if record["status"] != "success":
            with log_path.open("rb") as log:
                log.seek(max(0, log_path.stat().st_size - 4096))
                print(log.read().decode(errors="replace"), file=sys.stderr)
            return result.returncode or 1
        return 0
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        record.update(status="failed", reason=str(error))
        write_receipt(receipt_path, record)
        print(f"verification failed: {error}", file=sys.stderr)
        return 1


def check(root, name, context, command, content_only):
    key = hashlib.sha256(name.encode()).hexdigest()[:24]
    store = root / STORE
    if store.is_symlink():
        print(f"receipt invalid: {STORE} must be a directory", file=sys.stderr)
        return 1
    path = root / STORE / f"{key}.json"
    try:
        with (store / f"{key}.lock").open("a+b") as lock:
            fcntl.flock(lock, fcntl.LOCK_SH | fcntl.LOCK_NB)
            record = json.loads(path.read_text(encoding="utf-8"))
            if (record.get("status") != "success" or record.get("name") != name
                    or record.get("context") != context or record.get("command") != command
                    or record.get("content_only") is not content_only):
                raise ValueError("no matching successful receipt")
            log = store / record["log"]
            if not log.is_file() or not log.name.startswith(f"{key}-") or log.suffix != ".log":
                raise ValueError("verification log is missing")
            if file_hash(log) != record.get("log_hash"):
                raise ValueError("verification log has changed")
            if record.get("fingerprint") != fingerprint(root, content_only):
                raise ValueError("worktree has changed")
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(f"receipt invalid: {error}", file=sys.stderr)
        return 1
    print(f"receipt valid: {name}; log: {log}")
    return 0


def main():
    # Split first so command options cannot be parsed as helper options.
    if "--" not in sys.argv[1:]:
        raise SystemExit("provide a command after --")
    divider = sys.argv.index("--")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("run", "check"))
    parser.add_argument("name")
    parser.add_argument("--context", required=True)
    parser.add_argument("--content-only", action="store_true")
    args = parser.parse_args(sys.argv[1:divider])
    command = sys.argv[divider + 1:]
    if not command:
        parser.error("provide a command after --")
    try:
        root = repo_root()
    except subprocess.SubprocessError as error:
        parser.exit(1, f"cannot locate git worktree: {error}\n")
    return (run if args.action == "run" else check)(
        root, args.name, args.context, command, args.content_only
    )


if __name__ == "__main__":
    sys.exit(main())
