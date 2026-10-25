#!/usr/bin/env python3
"""Record bounded, read-only host context for a simulator UI test run."""

import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile


def caller_launch_manager() -> str:
    try:
        result = subprocess.run(
            ["launchctl", "managername"], capture_output=True, text=True,
            timeout=1.5, check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return "unknown"
    if result.returncode != 0:
        return "unknown"
    manager = result.stdout.strip()
    if manager == "Aqua":
        return "Aqua"
    if manager:
        return "other"
    return "unknown"


def console_user_session() -> str:
    try:
        console_uid = Path("/dev/console").stat().st_uid
    except OSError:
        return "unknown"
    if console_uid == 0:
        return "no"
    return "yes" if console_uid == os.getuid() else "no"


def parse_host_lock(data: bytes, uid: int) -> str:
    try:
        roots = plistlib.loads(data)
    except (plistlib.InvalidFileException, ValueError, TypeError):
        return "unknown"
    if isinstance(roots, dict):
        roots = [roots]
    if not isinstance(roots, list) or not roots or not all(isinstance(root, dict) for root in roots):
        return "unknown"

    on_console = []
    for root in roots:
        users = root.get("IOConsoleUsers")
        if not isinstance(users, list):
            return "unknown"
        for user in users:
            if not isinstance(user, dict):
                return "unknown"
            if user.get("kCGSSessionOnConsoleKey") is True:
                on_console.append(user)
    if len(on_console) != 1:
        return "unknown"
    user = on_console[0]
    session_uid = user.get("kCGSSessionUserIDKey")
    locked = user.get("CGSSessionScreenIsLocked")
    if type(session_uid) is not int or session_uid != uid or type(locked) is not bool:
        return "unknown"
    return "yes" if locked else "no"


def host_locked() -> str:
    try:
        result = subprocess.run(
            ["/usr/sbin/ioreg", "-n", "Root", "-d", "1", "-a"],
            capture_output=True, timeout=1.5, check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return "unknown"
    if result.returncode != 0 or len(result.stdout) > 1_000_000:
        return "unknown"
    return parse_host_lock(result.stdout, os.getuid())


def receipt(runner: str) -> dict[str, str]:
    return {
        "schema": "ui-host-state-v1",
        "observed_at_utc": datetime.now(timezone.utc).isoformat(),
        "runner": runner,
        "caller_launch_manager": caller_launch_manager(),
        "console_user_session": console_user_session(),
        "host_locked": host_locked(),
        "host_lock_source": "ioreg Root IOConsoleUsers; implementation-specific diagnostic",
        "display_sleep": "unknown",
        "system_sleep": "unknown",
        "ui_automation_permission": "unknown",
        "interpretation": "Context only; launch manager and lock diagnostics do not establish UI test eligibility.",
    }


def write_receipt(path: Path, data: dict[str, str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w", encoding="utf-8", dir=path.parent,
            prefix=f".{path.name}.", suffix=".tmp", delete=False,
        ) as output:
            temporary = Path(output.name)
            json.dump(data, output, indent=2)
            output.write("\n")
        os.replace(temporary, path)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runner", choices=("ios", "watch"), required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        write_receipt(args.output, receipt(args.runner))
    except OSError as error:
        print(f"Host state receipt unavailable: {error}", file=sys.stderr)
        return 0
    print(f"Host state context: {args.output}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
