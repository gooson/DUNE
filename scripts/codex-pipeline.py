#!/usr/bin/env python3
"""Record explicit pipeline checks, phase evidence, and document reads.

Examples:
  python3 scripts/codex-pipeline.py run unit --context ios --scope tests -- python3 -m unittest
  python3 scripts/codex-pipeline.py check unit --context ios --scope tests -- python3 -m unittest
  python3 scripts/codex-pipeline.py phase Review passed --review-file review.md --source agent --context diff --scope review
  python3 scripts/codex-pipeline.py doc remember .codex/skill-compat.md
  python3 scripts/codex-pipeline.py report
"""

import argparse
import fcntl
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time
import uuid


sys.dont_write_bytecode = True
SPEC = importlib.util.spec_from_file_location("codex_check", Path(__file__).with_name("codex-check.py"))
CHECK = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CHECK)
STATE_DIR = Path(CHECK.STORE) / "pipeline"


def safe_path(path, directory=False):
    for part in (path, *path.parents):
        if part.is_symlink():
            raise ValueError(f"symlink rejected: {part}")
    if path.exists() and (not path.is_dir() if directory else not path.is_file()):
        raise ValueError(f"unexpected path type: {path}")
    return path


def store_for(root):
    store = safe_path(root / STATE_DIR, directory=True)
    store.mkdir(parents=True, exist_ok=True)
    return store


def key_for(value):
    return hashlib.sha256(value.encode()).hexdigest()[:24]


def read_json(path, default):
    safe_path(path)
    if not path.exists():
        return default
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"invalid state: {path}")
    return value


def write_json(path, value):
    safe_path(path)
    safe_path(path.with_suffix(".tmp"))
    # The imported receipt writer provides the same atomic replace as codex-check.
    CHECK.write_receipt(path, value)


def lock_store(store, exclusive):
    lock_path = safe_path(store / "worktree.lock")
    lock = lock_path.open("a+b")
    try:
        fcntl.flock(lock, (fcntl.LOCK_EX if exclusive else fcntl.LOCK_SH) | fcntl.LOCK_NB)
    except BlockingIOError:
        lock.close()
        raise ValueError("pipeline operation already running")
    return lock


def stop_group(process):
    try:
        os.killpg(process.pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    except PermissionError:
        if process.poll() is None:
            process.terminate()
    time.sleep(0.1)
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except (ProcessLookupError, PermissionError):
        if process.poll() is None:
            process.kill()
    process.wait()


def group_alive(pgid):
    if not isinstance(pgid, int) or pgid <= 0:
        raise ValueError("running check lacks a recorded process group")
    try:
        os.killpg(pgid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def unresolved_runs(store):
    for path in store.glob("check-*.json"):
        record = read_json(path, {})
        attempts = record.get("attempts", [])
        if attempts and attempts[-1].get("status") == "running":
            last = attempts[-1]
            if group_alive(last.get("child_pgid")):
                raise ValueError(f"running check still has a live process group: {record.get('id')}")
            raise ValueError(f"unfinished check requires recover: {record.get('id')}")


def cached_fingerprint(root, content_only, cache):
    key = ("fingerprint", content_only)
    if cache is not None and key in cache:
        return cache[key]
    value = CHECK.fingerprint(root, content_only)
    if cache is not None:
        cache[key] = value
    return value


def cached_file_hash(path, cache):
    key = ("file", str(path))
    if cache is not None and key in cache:
        return cache[key]
    value = CHECK.file_hash(path)
    if cache is not None:
        cache[key] = value
    return value


def check_record(root, store, name, context, scope, command, content_only, cache=None):
    record = read_json(store / f"check-{key_for(name)}.json", {})
    attempts = record.get("attempts", [])
    if record.get("id") != name or not attempts:
        raise ValueError("no named check evidence")
    last = attempts[-1]
    if last.get("status") != "success":
        raise ValueError("last check did not succeed")
    if (last.get("context"), last.get("scope"), last.get("command"), last.get("content_only")) != (context, scope, command, content_only):
        raise ValueError("check inputs changed")
    log = safe_path(store / last["log"])
    if log.parent != store or not log.name.startswith(f"check-{key_for(name)}-") or log.suffix != ".log" or not log.exists():
        raise ValueError("check log missing")
    if cached_file_hash(log, cache) != last.get("log_hash"):
        raise ValueError("check log changed")
    if last.get("before") != last.get("after") or last.get("after") != cached_fingerprint(root, content_only, cache):
        raise ValueError("check fingerprint stale")
    retry = last.get("retry_evidence")
    if retry and cached_file_hash(document_path(root, retry["file"]), cache) != retry["hash"]:
        raise ValueError("retry evidence changed")
    return last


def run_check(root, store, args):
    unresolved_runs(store)
    path = store / f"check-{key_for(args.id)}.json"
    record = read_json(path, {"schema_version": 1, "worktree": str(root),
                              "id": args.id, "attempts": []})
    if record.get("id") != args.id or not isinstance(record.get("attempts"), list):
        raise ValueError("invalid check history")
    attempts = record["attempts"]
    if attempts:
        last = attempts[-1]
        if last["status"] == "running":
            raise ValueError("previous run is incomplete; inspect it before continuing")
        if last["status"] == "success":
            try:
                check_record(root, store, args.id, args.context, args.scope, args.command, args.content_only)
            except ValueError:
                pass
            else:
                raise ValueError("successful evidence already valid; reuse it")
        else:
            failures = 0
            for prior in reversed(attempts):
                if prior["status"] == "success":
                    break
                failures += 1
            if failures >= 2:
                raise ValueError("retry limit reached for this check ID")
            if not args.retry_cause or not args.remediation or not args.retry_evidence:
                raise ValueError("retry requires --retry-cause, --remediation, and --retry-evidence")
            current_content = CHECK.fingerprint(root, True)
            if current_content == last.get("after_content") and args.context == last.get("context"):
                raise ValueError("retry requires changed content or context")
            if "after_content" not in last and args.context == last.get("context"):
                raise ValueError("older failure lacks content change evidence; change context explicitly")
    elif args.retry_cause or args.remediation or args.retry_evidence:
        raise ValueError("retry evidence is only valid after failure")

    log_name = f"check-{key_for(args.id)}-{uuid.uuid4().hex}.log"
    log_path = safe_path(store / log_name)
    before = CHECK.fingerprint(root, args.content_only)
    before_content = before if args.content_only else CHECK.fingerprint(root, True)
    attempt = {"status": "running", "command": args.command, "context": args.context,
               "scope": args.scope, "content_only": args.content_only, "before": before,
               "before_content": before_content,
               "log": log_name, "started": time.time()}
    if args.retry_cause:
        evidence = document_path(root, args.retry_evidence)
        attempt.update(retry_cause=args.retry_cause, remediation=args.remediation,
                       retry_evidence={"file": str(evidence.relative_to(root)),
                                       "hash": CHECK.file_hash(evidence)})
    attempts.append(attempt)
    write_json(path, record)
    process = None
    previous = {}

    def interrupt(signum, _frame):
        raise KeyboardInterrupt(f"signal {signum}")

    try:
        for sig in (signal.SIGINT, signal.SIGTERM):
            previous[sig] = signal.signal(sig, interrupt)
        with log_path.open("wb") as log:
            process = subprocess.Popen(args.command, cwd=root, stdout=log,
                                       stderr=subprocess.STDOUT, start_new_session=True)
            attempt.update(child_pid=process.pid, child_pgid=process.pid)
            write_json(path, record)
            try:
                exit_code = process.wait(timeout=args.timeout)
                status = "success" if exit_code == 0 else "failed"
            except subprocess.TimeoutExpired:
                status, exit_code = "timeout", None
            except KeyboardInterrupt:
                status, exit_code = "interrupted", None
            if status in ("timeout", "interrupted"):
                stop_group(process)
        after = CHECK.fingerprint(root, args.content_only)
        after_content = after if args.content_only else CHECK.fingerprint(root, True)
        if after != before:
            if status == "success":
                status = "failed"
            attempt["reason"] = "worktree changed during command"
        attempt.update(status=status, exit_code=exit_code, after=after,
                       after_content=after_content,
                       log_hash=CHECK.file_hash(log_path), ended=time.time())
    except (OSError, ValueError) as error:
        attempt.update(status="failed", reason=str(error), ended=time.time())
        if process:
            stop_group(process)
    finally:
        for sig, handler in previous.items():
            signal.signal(sig, handler)
        write_json(path, record)
    if attempt["status"] == "success":
        for prior in attempts[:-1]:
            if prior["status"] != "success":
                continue
            if not prior.get("log_pruned"):
                old_log = safe_path(store / prior["log"])
                if old_log.parent == store and old_log.name.startswith(f"check-{key_for(args.id)}-") and old_log.suffix == ".log":
                    old_log.unlink(missing_ok=True)
                    prior["log_pruned"] = True
            if "command" in prior:
                prior["command_hash"] = hashlib.sha256(
                    json.dumps(prior.pop("command"), separators=(",", ":")).encode()
                ).hexdigest()
        write_json(path, record)
    print(f"{attempt['status']}: {args.id}; log: {log_path}")
    if attempt["status"] != "success":
        if log_path.exists():
            with log_path.open("rb") as log:
                log.seek(max(0, log_path.stat().st_size - 2048))
                print(log.read().decode(errors="replace"), file=sys.stderr)
        return 1
    return 0


def document_path(root, value):
    path = root / value
    if path.resolve().is_relative_to(root) is False:
        raise ValueError("document must be within worktree")
    safe_path(path)
    if not path.is_file():
        raise ValueError("document missing")
    return path


def phase_status(root, store, phase, cache=None):
    record = read_json(store / f"phase-{key_for(phase)}.json", {})
    if record.get("phase") != phase:
        raise ValueError("phase not recorded")
    if record.get("status") == "skipped":
        if cached_fingerprint(root, record["content_only"], cache) != record["fingerprint"]:
            raise ValueError("skip decision stale")
    if record.get("status") == "passed":
        if "evidence" in record:
            evidence = record["evidence"]
            check_record(root, store, evidence["id"], evidence["context"], evidence["scope"],
                         evidence["command"], evidence["content_only"], cache)
        elif "review" in record:
            review = record["review"]
            if cached_file_hash(document_path(root, review["file"]), cache) != review["hash"]:
                raise ValueError("review evidence changed")
            if cached_fingerprint(root, review["content_only"], cache) != review["fingerprint"]:
                raise ValueError("review evidence stale")
        else:
            raise ValueError("passed phase lacks evidence")
    return record


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="action", required=True)
    for action in ("run", "check"):
        item = sub.add_parser(action)
        item.add_argument("id")
        item.add_argument("--context", required=True)
        item.add_argument("--scope", required=True)
        item.add_argument("--content-only", action="store_true")
        if action == "run":
            item.add_argument("--timeout", type=float)
            item.add_argument("--retry-cause")
            item.add_argument("--remediation")
            item.add_argument("--retry-evidence")
    item = sub.add_parser("phase")
    item.add_argument("name")
    item.add_argument("status", choices=("passed", "skipped", "failed"))
    item.add_argument("--evidence")
    item.add_argument("--review-file")
    item.add_argument("--source")
    item.add_argument("--context")
    item.add_argument("--scope")
    item.add_argument("--content-only", action="store_true")
    item.add_argument("--reason")
    item = sub.add_parser("recover")
    item.add_argument("id")
    item.add_argument("--reason", required=True)
    sub.add_parser("report")
    item = sub.add_parser("status")
    item.add_argument("id", nargs="?")
    item = sub.add_parser("doc")
    item.add_argument("operation", choices=("remember", "check"))
    item.add_argument("path")
    raw = sys.argv[1:]
    if raw[:1] in (["run"], ["check"]):
        if "--" not in raw:
            parser.error("command required after --")
        divider = raw.index("--")
        args = parser.parse_args(raw[:divider])
        args.command = raw[divider + 1:]
    else:
        args = parser.parse_args(raw)
    try:
        root = CHECK.repo_root()
        store = store_for(root)
        with lock_store(store, exclusive=args.action in ("run", "phase", "recover") or
                        (args.action == "doc" and args.operation == "remember")):
            if args.action in ("run", "check"):
                if not args.command:
                    raise ValueError("command required after --")
                if args.action == "run":
                    if args.timeout is not None and args.timeout <= 0:
                        raise ValueError("timeout must be positive")
                    return run_check(root, store, args)
                check_record(root, store, args.id, args.context, args.scope, args.command, args.content_only)
                print(f"valid: {args.id}")
            elif args.action == "doc":
                path = document_path(root, args.path)
                state = store / f"doc-{key_for(str(path.relative_to(root)))}.json"
                digest = CHECK.file_hash(path)
                if args.operation == "remember":
                    write_json(state, {"file": str(path.relative_to(root)), "hash": digest, "recorded": time.time()})
                    print(f"document hash recorded: {args.path} {digest}")
                elif read_json(state, {}).get("hash") != digest:
                    raise ValueError("document changed or was not recorded")
                else:
                    print(f"document hash current: {args.path}")
            elif args.action == "phase":
                record = {"schema_version": 1, "worktree": str(root),
                          "phase": args.name, "status": args.status, "recorded": time.time()}
                if args.status == "passed":
                    if args.evidence and args.review_file or not (args.evidence or args.review_file):
                        raise ValueError("passed phase requires exactly one evidence source")
                    if args.evidence:
                        evidence = read_json(store / f"check-{key_for(args.evidence)}.json", {})
                        last = evidence.get("attempts", [])[-1]
                        check_record(root, store, args.evidence, last["context"], last["scope"],
                                     last["command"], last["content_only"])
                        record["evidence"] = {"id": args.evidence, "context": last["context"],
                                              "scope": last["scope"], "command": last["command"],
                                              "content_only": last["content_only"]}
                    else:
                        if not all((args.source, args.context, args.scope)):
                            raise ValueError("review requires source, context, and scope")
                        review = document_path(root, args.review_file)
                        record["review"] = {"file": str(review.relative_to(root)),
                                            "hash": CHECK.file_hash(review), "source": args.source,
                                            "context": args.context, "scope": args.scope,
                                            "content_only": args.content_only,
                                            "fingerprint": CHECK.fingerprint(root, args.content_only)}
                else:
                    if not args.reason:
                        raise ValueError("skipped/failed phase requires --reason")
                    record["reason"] = args.reason
                    if args.status == "skipped":
                        record["fingerprint"] = CHECK.fingerprint(root, args.content_only)
                        record["content_only"] = args.content_only
                write_json(store / f"phase-{key_for(args.name)}.json", record)
                print(f"phase {args.name}: {args.status}")
            elif args.action == "recover":
                path = store / f"check-{key_for(args.id)}.json"
                record = read_json(path, {})
                if record.get("id") != args.id or not record.get("attempts"):
                    raise ValueError("no check to recover")
                last = record["attempts"][-1]
                if last.get("status") != "running":
                    raise ValueError("check is not recorded as running")
                if group_alive(last.get("child_pgid")):
                    raise ValueError("recorded process group is still alive")
                last.update(status="interrupted", reason=args.reason,
                            after=CHECK.fingerprint(root, last["content_only"]),
                            after_content=CHECK.fingerprint(root, True), ended=time.time())
                log = safe_path(store / last["log"])
                if log.is_file():
                    last["log_hash"] = CHECK.file_hash(log)
                write_json(path, record)
                print(f"recovered interrupted check: {args.id}")
            else:
                result = {"checks": [], "phases": []}
                cache = {}
                for path in sorted(store.glob("check-*.json")):
                    state = read_json(path, {})
                    if args.action == "status" and args.id and state.get("id") != args.id:
                        continue
                    last = state.get("attempts", [])[-1:]
                    if last:
                        item = {"id": state.get("id"), "status": last[0].get("status"),
                                "attempts": len(state["attempts"]), "log": last[0].get("log")}
                        if item["status"] == "success":
                            try:
                                check_record(root, store, item["id"], last[0]["context"], last[0]["scope"],
                                             last[0]["command"], last[0]["content_only"], cache)
                            except (ValueError, OSError) as error:
                                item.update(status="stale", reason=str(error))
                        result["checks"].append(item)
                for path in sorted(store.glob("phase-*.json")):
                    state = read_json(path, {})
                    if args.action == "status" and args.id and state.get("phase") != args.id:
                        continue
                    try:
                        phase_status(root, store, state["phase"], cache)
                    except (ValueError, OSError) as error:
                        state.update(status="stale", reason=str(error))
                    result["phases"].append(state)
                print(json.dumps(result, sort_keys=True))
    except (OSError, ValueError, KeyError, IndexError, TypeError, subprocess.SubprocessError) as error:
        print(f"pipeline invalid: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
