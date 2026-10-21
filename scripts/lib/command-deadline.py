#!/usr/bin/env python3
"""Run one owned command tree with a wall-clock deadline."""

import argparse
import os
from pathlib import Path
import signal
import subprocess
import sys
import time


def stop_command(process: subprocess.Popen, owns_group: bool) -> None:
    # Only the outermost watchdog owns the group. Nested watchdogs must not
    # create a session of their own or signal the outer runner and themselves.
    def send(sig: signal.Signals) -> None:
        try:
            if owns_group:
                os.killpg(process.pid, sig)
            else:
                process.send_signal(sig)
        except ProcessLookupError:
            pass
        except OSError as error:
            print(f"Could not signal owned command: {error}", file=sys.stderr,
                  flush=True)

    send(signal.SIGTERM)
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        pass
    # The direct child can exit before its descendants. The owner must still
    # kill the group, including descendants of a nested deadline wrapper.
    send(signal.SIGKILL)
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        print("Owned command did not exit after SIGKILL; cleanup incomplete.",
              file=sys.stderr, flush=True)


def file_state(path: Path | None) -> tuple[int, int] | None:
    if path is None:
        return None
    try:
        state = path.stat()
        return state.st_mtime_ns, state.st_size
    except OSError:
        return None


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seconds", type=int, required=True)
    parser.add_argument("--idle-seconds", type=int)
    parser.add_argument("--activity-file", type=Path)
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ["--"] else args.command
    if args.seconds <= 0 or not command:
        parser.error("a positive deadline and command are required")
    if (args.idle_seconds is None) != (args.activity_file is None):
        parser.error("idle-seconds and activity-file must be used together")
    if args.idle_seconds is not None and args.idle_seconds <= 0:
        parser.error("idle-seconds must be positive")

    env = os.environ.copy()
    env["DUNE_UI_WATCHDOG_ACTIVE"] = "1"
    env.setdefault("DUNE_SIM_TEST_LOCK_WAIT_SECONDS", "60")
    lock_fd = env.get("DUNE_SIM_TEST_LOCK_FD")
    pass_fds = (int(lock_fd),) if lock_fd and lock_fd.isdecimal() else ()
    owns_group = not bool(os.environ.get("DUNE_UI_WATCHDOG_ACTIVE"))
    process = subprocess.Popen(command, env=env, pass_fds=pass_fds,
                               start_new_session=owns_group)
    def interrupt(_signum, _frame):
        raise KeyboardInterrupt

    previous = signal.signal(signal.SIGTERM, interrupt)
    try:
        started = time.monotonic()
        last_activity = started
        previous_file_state = file_state(args.activity_file)
        while True:
            returncode = process.poll()
            if returncode is not None:
                return returncode
            now = time.monotonic()
            current_file_state = file_state(args.activity_file)
            if current_file_state != previous_file_state:
                previous_file_state = current_file_state
                last_activity = now
            if now - started >= args.seconds:
                reason = f"exceeded {args.seconds}s"
            elif args.idle_seconds is not None and now - last_activity >= args.idle_seconds:
                reason = f"had no activity for {args.idle_seconds}s"
            else:
                deadline = started + args.seconds
                if args.idle_seconds is not None:
                    deadline = min(deadline, last_activity + args.idle_seconds)
                try:
                    return process.wait(timeout=min(2, max(0.01, deadline - now)))
                except subprocess.TimeoutExpired:
                    continue
            print(f"UI test command {reason}; stopping its owned process group.",
                  file=sys.stderr, flush=True)
            stop_command(process, owns_group)
            return 124
    except KeyboardInterrupt:
        stop_command(process, owns_group)
        return 130
    finally:
        if owns_group:
            # A successful or failed command may have left background children.
            # Its group remains owned until the outer watchdog exits.
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            except OSError as error:
                # Preserve the command result while exposing incomplete cleanup.
                print(f"Could not clean owned process group: {error}",
                      file=sys.stderr, flush=True)
        signal.signal(signal.SIGTERM, previous)


if __name__ == "__main__":
    sys.exit(main())
