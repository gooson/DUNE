#!/usr/bin/env python3
"""Record simulator clones and delete only verified clones of this worktree."""

from contextlib import contextmanager
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time


UDID = re.compile(r"^[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$")


def registry_path(root: Path) -> Path:
    root = root.resolve()
    return root / ".codex-checks" / "worktree-simulators.json"


def orphan_directories(root: Path) -> tuple[Path, Path]:
    root = root.resolve()
    digest = hashlib.sha256(str(root).encode()).hexdigest()[:16]
    return (root / ".codex-checks" / "simulator-orphans",
            Path(tempfile.gettempdir()) / f"dune-simulator-orphans-{os.getuid()}-{digest}")


def orphan_files(root: Path) -> list[Path]:
    return [path for directory in orphan_directories(root) if directory.is_dir()
            for path in directory.glob("*.json")]


def mark_orphan(root: Path, udid: str, name: str) -> None:
    root = root.resolve()
    if not UDID.fullmatch(udid) or not name.endswith(worktree_suffix(root)):
        raise ValueError("invalid orphan simulator identity")
    record = {"udid": udid, "name": name, "worktree": str(root)}
    failures = []
    for directory in orphan_directories(root):
        path = directory / f"{udid}.json"
        try:
            directory.mkdir(mode=0o700, parents=True, exist_ok=True)
            with path.open("x") as output:
                json.dump(record, output)
                output.write("\n")
            return
        except FileExistsError:
            if path.is_file():
                try:
                    if json.loads(path.read_text()) == record:
                        return
                except (OSError, json.JSONDecodeError):
                    pass
            failures.append(f"orphan marker conflicts with existing path: {path}")
        except OSError as error:
            failures.append(str(error))
    raise OSError("could not persist orphan marker: " + "; ".join(failures))


def is_orphan(root: Path, udid: str) -> bool:
    return any(path.stem == udid for path in orphan_files(root))


def is_recorded(root: Path, udid: str, name: str) -> bool:
    root = root.resolve()
    with registry_lock(root):
        return any(item.get("udid") == udid and item.get("name") == name
                   and item.get("worktree") == str(root)
                   and item.get("preclone_verified") is True
                   for item in read_registry(root))


def read_registry(root: Path) -> list[dict[str, str]]:
    path = registry_path(root)
    if not path.exists():
        return []
    data = json.loads(path.read_text())
    if not isinstance(data, list) or not all(isinstance(item, dict) for item in data):
        raise ValueError("simulator registry must be a list of records")
    return data


@contextmanager
def registry_lock(root: Path):
    directory = registry_path(root).parent
    directory.mkdir(parents=True, exist_ok=True)
    with (directory / "worktree-simulators.lock").open("a+") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            yield
        finally:
            fcntl.flock(lock, fcntl.LOCK_UN)


def write_registry(root: Path, records: list[dict[str, str]]) -> None:
    path = registry_path(root)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", dir=path.parent,
                                         prefix="worktree-simulators-", suffix=".tmp",
                                         delete=False) as output:
            temporary = Path(output.name)
            json.dump(records, output, indent=2)
            output.write("\n")
            output.flush()
            os.fsync(output.fileno())
        os.replace(temporary, path)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def devices() -> dict[str, dict]:
    result = subprocess.run(["xcrun", "simctl", "list", "devices", "-j"],
                            check=True, capture_output=True, text=True)
    data = json.loads(result.stdout)
    return {device["udid"]: device
            for runtime in data["devices"].values() for device in runtime}


def record(root: Path, udid: str, name: str, preexisting: set[str]) -> None:
    root = root.resolve()
    if not UDID.fullmatch(udid) or not name.endswith(worktree_suffix(root)):
        raise ValueError("invalid worktree simulator identity")
    if udid.upper() in {existing.upper() for existing in preexisting}:
        raise ValueError("cloned simulator existed before clone")
    with registry_lock(root):
        existing = devices().get(udid)
        if existing is None or existing.get("name") != name:
            raise ValueError("new simulator identity does not match simctl")
        records = read_registry(root)
        if any(item.get("udid") == udid and item.get("name") != name for item in records):
            raise ValueError("simulator UDID has a conflicting ownership record")
        if not any(item.get("udid") == udid for item in records):
            records.append({"udid": udid, "name": name, "worktree": str(root),
                            "preclone_verified": True})
            write_registry(root, records)


def worktree_suffix(root: Path) -> str:
    # The shell helper supplies the complete name. This suffix check is only
    # a guard against recording an unrelated simulator via a wrong argument.
    root = root.resolve()
    label = re.sub(r"[^A-Za-z0-9]+", "-", root.parent.name).strip("-")
    digest = hashlib.sha256(str(root).encode()).hexdigest()[:12]
    return f"-wt-{root.name}-{label}-{digest}"


def rollback_safe(root: Path, udid: str, name: str, preexisting: set[str]) -> bool:
    root = root.resolve()
    if not UDID.fullmatch(udid) or not name.endswith(worktree_suffix(root)):
        return False
    if udid.upper() in {existing.upper() for existing in preexisting}:
        return False
    return devices().get(udid, {}).get("name") == name


def cleanup(root: Path) -> int:
    root = root.resolve()
    with registry_lock(root):
        return _cleanup(root)


def _cleanup(root: Path) -> int:
    records = read_registry(root)
    orphans = orphan_files(root)
    if not records and not orphans:
        print("No recorded worktree simulators to clean up.")
        return 0

    remaining = []
    deleted = 0
    snapshot = devices()
    unresolved_orphans = 0
    for path in orphans:
        try:
            item = json.loads(path.read_text())
            udid = item.get("udid", "")
            name = item.get("name", "")
            if (item.get("worktree") != str(root) or not isinstance(udid, str)
                    or not isinstance(name, str) or not UDID.fullmatch(udid)
                    or not name.endswith(worktree_suffix(root))):
                raise ValueError("invalid orphan marker")
            if udid in snapshot:
                print(f"Manual cleanup required for untracked clone: {name} [{udid}]",
                      file=sys.stderr)
                unresolved_orphans += 1
            else:
                path.unlink()
                print(f"Cleared absent orphan marker: {name} [{udid}]")
        except (OSError, ValueError, AttributeError, json.JSONDecodeError) as error:
            print(f"Preserved unreadable orphan marker {path}: {error}", file=sys.stderr)
            unresolved_orphans += 1
    for item in records:
        udid = item.get("udid", "")
        name = item.get("name", "")
        if (item.get("worktree") != str(root) or item.get("preclone_verified") is not True
                or not isinstance(udid, str)
                or not isinstance(name, str) or not UDID.fullmatch(udid)
                or not name.endswith(worktree_suffix(root))):
            print(f"Preserved unverified simulator record: {name} [{udid}]", file=sys.stderr)
            remaining.append(item)
            continue
        try:
            current = snapshot.get(udid)
            if current is None:
                print(f"Already absent: {name} [{udid}]")
                continue
            if current.get("name") != name:
                print(f"Preserved name mismatch: {name} [{udid}]", file=sys.stderr)
                remaining.append(item)
                continue
            if current.get("state") != "Shutdown":
                subprocess.run(["xcrun", "simctl", "shutdown", udid], check=True)
                for _ in range(10):
                    if devices().get(udid, {}).get("state") == "Shutdown":
                        break
                    time.sleep(1)
                else:
                    raise RuntimeError("shutdown was not confirmed")
            subprocess.run(["xcrun", "simctl", "delete", udid], check=True)
            if udid in devices():
                raise RuntimeError("simulator still exists after delete")
            snapshot.pop(udid, None)
            print(f"Deleted: {name} [{udid}]")
            deleted += 1
        except (OSError, subprocess.CalledProcessError, ValueError, KeyError,
                json.JSONDecodeError, RuntimeError) as error:
            print(f"Preserved after cleanup failure: {name} [{udid}]: {error}",
                  file=sys.stderr)
            remaining.append(item)

    write_registry(root, remaining)
    print(f"Deleted {deleted} worktree simulator(s); {len(remaining)} recorded and "
          f"{unresolved_orphans} untracked remain.")
    return 1 if remaining or unresolved_orphans else 0


def main() -> int:
    operations = {"record", "cleanup", "absent", "rollback-safe", "mark-orphan",
                  "is-orphan", "is-recorded"}
    if len(sys.argv) < 3 or sys.argv[1] not in operations:
        print("Usage: worktree-simulator-registry.py record ROOT UDID NAME BASELINE_JSON | cleanup ROOT | absent ROOT UDID | rollback-safe ROOT UDID NAME BASELINE_JSON | mark-orphan ROOT UDID NAME | is-orphan ROOT UDID | is-recorded ROOT UDID NAME",
              file=sys.stderr)
        return 2
    operation = sys.argv[1]
    root = Path(sys.argv[2]).resolve()
    try:
        if operation == "record" and len(sys.argv) == 6:
            baseline = json.loads(Path(sys.argv[5]).read_text())
            preexisting = {device["udid"] for runtime in baseline["devices"].values()
                           for device in runtime}
            record(root, sys.argv[3], sys.argv[4], preexisting)
            return 0
        if operation == "cleanup" and len(sys.argv) == 3:
            return cleanup(root)
        if operation == "absent" and len(sys.argv) == 4 and UDID.fullmatch(sys.argv[3]):
            return 0 if sys.argv[3] not in devices() else 1
        if operation == "rollback-safe" and len(sys.argv) == 6:
            baseline = json.loads(Path(sys.argv[5]).read_text())
            preexisting = {device["udid"] for runtime in baseline["devices"].values()
                           for device in runtime}
            return 0 if rollback_safe(root, sys.argv[3], sys.argv[4], preexisting) else 1
        if operation == "mark-orphan" and len(sys.argv) == 5:
            mark_orphan(root, sys.argv[3], sys.argv[4])
            return 0
        if operation == "is-orphan" and len(sys.argv) == 4:
            return 0 if is_orphan(root, sys.argv[3]) else 1
        if operation == "is-recorded" and len(sys.argv) == 5:
            return 0 if is_recorded(root, sys.argv[3], sys.argv[4]) else 1
        raise ValueError("invalid arguments")
    except (OSError, subprocess.CalledProcessError, ValueError, KeyError,
            json.JSONDecodeError) as error:
        print(f"Simulator registry error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
