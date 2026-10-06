#!/usr/bin/env python3
"""Capture Duo displays at VisualAudit checkpoints, then acknowledge the test.

Usage: duo-visual-audit.py OUTPUT DEVICE_UUID all|WIDTHxHEIGHT|DISPLAY_UUID scripts/test-ui.sh --stream-log ...
Set DEVELOPER_DIR explicitly. The test plan must opt into DUNE_VISUAL_AUDIT and
DUNE_VISUAL_AUDIT_HOST_ONLY. `FOLD:<state>` checkpoints print FOLD_PENDING and
pause until the operator changes Device Hub state and creates the release file.
The host then requests a fresh XCTest hierarchy before capturing both displays.
Set DAILVE_DUO_HINGE_CLI to a reviewed hinge executable to set and verify the
angle automatically without Device Hub UI interaction.
ORIENT checkpoints verify physical orientation through devicectl. Set
DAILVE_DUO_ORIENTATION_CLI to a reviewed guest HID driver if the official setter
does not change the Duo motion controller's readback.
"""
from pathlib import Path
import json
import math
import os
import re
import subprocess
import sys
import time


FOLD_STATES = {"closed", "partiallyOpen", "openFlat"}
FOLD_ANGLES = {"closed": 0, "partiallyOpen": 90, "openFlat": 180}
ORIENTATION_STATES = {"portrait", "landscapeLeft", "landscapeRight"}


def orientation_state(action):
    match = re.match(r"^ORIENT:([^\s]+)(?:\s|$)", action)
    if not match:
        return None
    state = match.group(1)
    if state not in ORIENTATION_STATES:
        raise RuntimeError(f"Unknown orientation: {state}")
    return state


def set_device_orientation(output, sequence, orientation, device, test_deadline):
    if not re.fullmatch(r"[A-Fa-f0-9]{8}(?:-[A-Fa-f0-9]{4}){3}-[A-Fa-f0-9]{12}", device):
        raise RuntimeError("Orientation control requires an explicit simulator UDID")
    receipt = {"device": device, "target_orientation": orientation, "verified": False}
    try:
        cli = None
        if configured := os.environ.get("DAILVE_DUO_ORIENTATION_CLI"):
            cli = Path(configured).resolve(strict=True)
            if not cli.is_file() or not os.access(cli, os.X_OK):
                raise RuntimeError("Configured orientation CLI is not an executable file")
            receipt["cli"] = str(cli)
        prefix = ["xcrun", "devicectl", "device", "orientation"]
        for command in ["set", "get"]:
            budget = test_deadline - time.time() - 37
            if budget <= 0:
                raise RuntimeError("Orientation change has insufficient capture budget")
            args = prefix + [command, "--device", device]
            if command == "set":
                args.append(orientation)
            args += ["--timeout", "10", "--json-output", "-"]
            if command == "set" and cli:
                args = [str(cli), "-d", device, orientation]
            result = subprocess.run(args, capture_output=True, text=True, timeout=min(12, budget))
            if result.returncode:
                raise RuntimeError(f"Orientation {command} failed ({result.returncode}): {result.stderr[-600:]}")
            if command == "get":
                actual = json.loads(result.stdout)["result"]["deviceOrientation"]
                receipt["actual_orientation"] = actual
                if actual != orientation:
                    raise RuntimeError(f"Orientation readback mismatch: target={orientation}, actual={actual}")
        receipt["verified"] = True
        print(f"ORIENTATION_VERIFIED target={orientation} actual={actual}", flush=True)
    except Exception as exc:
        receipt["error"] = str(exc)
        raise
    finally:
        (output / f"{sequence:03}-orientation.json").write_text(json.dumps(receipt) + "\n")


def set_fold_with_cli(output, sequence, state, device, test_deadline):
    cli = Path(os.environ["DAILVE_DUO_HINGE_CLI"]).resolve(strict=True)
    if not cli.is_file() or not os.access(cli, os.X_OK):
        raise RuntimeError("Configured hinge CLI is not an executable file")
    if not re.fullmatch(r"[A-Fa-f0-9]{8}(?:-[A-Fa-f0-9]{4}){3}-[A-Fa-f0-9]{12}", device):
        raise RuntimeError("Automatic hinge control requires an explicit simulator UDID")
    target = FOLD_ANGLES[state]
    receipt = {"device": device, "state": state, "target_angle": target,
               "cli": str(cli), "actual_angle": None, "verified": False}
    try:
        for command in [str(target), "get"]:
            budget = test_deadline - time.time() - 37
            if budget <= 0:
                raise RuntimeError("Automatic fold has insufficient capture budget")
            result = subprocess.run([str(cli), "-d", device, command],
                                    capture_output=True, text=True, timeout=min(20, budget))
            if result.returncode:
                raise RuntimeError(f"Hinge {command} failed ({result.returncode}): {result.stderr[-600:]}")
            if command == "get":
                actual = float(result.stdout.strip())
                if not math.isfinite(actual):
                    raise RuntimeError("Hinge readback is not a finite angle")
                receipt["actual_angle"] = actual
                if abs(actual - target) > 1:
                    raise RuntimeError(f"Hinge readback mismatch: target={target}, actual={actual}")
            else:
                time.sleep(0.5)
        receipt["verified"] = True
        print(f"FOLD_VERIFIED {state} target={target} actual={receipt['actual_angle']}", flush=True)
    except Exception as exc:
        receipt["error"] = str(exc)
        raise
    finally:
        (output / f"{sequence:03}-fold.json").write_text(json.dumps(receipt) + "\n")


def resolve_displays(device, requested_display, deadline):
    requested_size = re.fullmatch(r"(\d+)x(\d+)", requested_display)
    if requested_display != "all" and not requested_size:
        return [(requested_display, "")]

    # Device Hub allocates fresh ports when a foldable display changes state.
    ports = subprocess.check_output(
        ["xcrun", "simctl", "io", device, "enumerate"], text=True,
        timeout=min(8, max(0.1, deadline - time.monotonic())),
    )
    displays = []
    for port in ports.split("Port:"):
        if "Display class: 0" not in port:
            continue
        identifier = re.search(r"UUID: ([A-F0-9-]+)", port)
        width = re.search(r"Default width: (\d+)", port)
        height = re.search(r"Default height: (\d+)", port)
        if not all((identifier, width, height)):
            continue
        size = f"{width.group(1)}x{height.group(1)}"
        if requested_display == "all":
            displays.append((identifier.group(1), f"-{size}"))
        elif size == requested_display:
            displays.append((identifier.group(1), ""))
    if displays:
        return displays
    raise RuntimeError(f"No matching built-in simulator display: {requested_display}")


def validate_ack_path(raw_path, container_root):
    acknowledgement = Path(raw_path).resolve()
    # Only the direct tmp child of an application container may be touched.
    app_container = acknowledgement.parent.parent
    if (acknowledgement.parent.name != "tmp"
            or app_container.parent != container_root
            or not re.fullmatch(r"[A-Fa-f0-9]{8}(?:-[A-Fa-f0-9]{4}){3}-[A-Fa-f0-9]{12}", app_container.name)
            or not re.fullmatch(r"dune-visual-audit-[A-Fa-f0-9-]+\.ack", acknowledgement.name)):
        raise RuntimeError("Unexpected capture acknowledgement path")
    return acknowledgement


def fold_state(action):
    match = re.match(r"^FOLD:([^\s]+)(?:\s|$)", action)
    if not match:
        return None
    state = match.group(1)
    if state not in FOLD_STATES:
        raise RuntimeError(f"Unknown fold state: {state}")
    return state


def wait_for_fold_release(output, sequence, state, test_deadline):
    release = output / f"fold-release-{sequence:03}.signal"
    release.unlink(missing_ok=True)  # A reused output directory cannot release this run.
    # Preserve time for the hierarchy refresh and both display screenshots.
    release_deadline = min(time.time() + 80, test_deadline - 37)
    if release_deadline <= time.time():
        raise RuntimeError("Fold checkpoint has insufficient time to capture after release")
    pending = {"sequence": sequence, "state": state, "release_file": str(release),
               "release_deadline": release_deadline, "test_deadline": test_deadline}
    pending_tmp = output / "pending.json.tmp"
    pending_tmp.write_text(json.dumps(pending) + "\n")
    pending_tmp.replace(output / "pending.json")
    print(f"FOLD_PENDING {state} {release} deadline={release_deadline:.3f}", flush=True)
    try:
        while time.time() < release_deadline:
            if release.is_file():
                release.unlink()
                return
            time.sleep(0.1)
        raise RuntimeError(f"Fold checkpoint {sequence} was not released before deadline")
    finally:
        (output / "pending.json").unlink(missing_ok=True)


def refresh_fold_hierarchy(acknowledgement, test_deadline, timeout=8):
    refresh = acknowledgement.with_suffix(".ack.refresh")
    ready = acknowledgement.with_suffix(".ack.ready")
    ready.unlink(missing_ok=True)  # Never accept a stale response.
    refresh.touch()
    refresh_deadline = min(time.time() + timeout, test_deadline - 27)
    try:
        while time.time() < refresh_deadline:
            if ready.is_file():
                return
            time.sleep(0.05)
        raise RuntimeError("Fold hierarchy refresh timed out before capture")
    finally:
        refresh.unlink(missing_ok=True)
        ready.unlink(missing_ok=True)


def capture_checkpoint(line, sequence, output, device, requested_display,
                       container_root, captures, checkpoints):
    started = time.monotonic()
    checkpoint_line = line[line.index("DUNE_VISUAL_AUDIT_READY "):]
    action = checkpoint_line.strip().split(" ACK=", 1)[0]
    acknowledged = False
    captured = False
    error = None
    try:
        deadline_match = re.search(r" DEADLINE=([0-9.]+) ACK=(\S+)\s*$", checkpoint_line)
        if not deadline_match:
            raise RuntimeError("Checkpoint lacks a viewport hold deadline; rebuild the audit tests")
        test_deadline = float(deadline_match.group(1))
        acknowledgement = validate_ack_path(deadline_match.group(2), container_root)
        state = fold_state(action.removeprefix("DUNE_VISUAL_AUDIT_READY "))
        orientation = orientation_state(action.removeprefix("DUNE_VISUAL_AUDIT_READY "))
        if state:
            if os.environ.get("DAILVE_DUO_HINGE_CLI"):
                set_fold_with_cli(output, sequence, state, device, test_deadline)
            else:
                wait_for_fold_release(output, sequence, state, test_deadline)
            refresh_fold_hierarchy(acknowledgement, test_deadline)
        elif orientation:
            set_device_orientation(output, sequence, orientation, device, test_deadline)
            refresh_fold_hierarchy(acknowledgement, test_deadline)
        remaining = test_deadline - time.time() - 2
        if remaining <= 0:
            raise RuntimeError("Checkpoint expired before capture; discard its screenshots")
        deadline = started + min(25, remaining) if not (state or orientation) else time.monotonic() + min(25, remaining)
        displays = resolve_displays(device, requested_display, deadline)
        # Fold checkpoints need both built-in screens, even when one is black.
        if (state or orientation) and (requested_display != "all" or len(displays) != 2):
            raise RuntimeError("Motion checkpoint requires both built-in Duo displays")
        succeeded = True
        for display, suffix in displays:
            destination = output / f"{sequence:03}{suffix}.png"
            destination.unlink(missing_ok=True)
            capture_returncode = 124
            try:
                budget = deadline - time.monotonic()
                if budget <= 0:
                    raise subprocess.TimeoutExpired("screenshot", 0)
                capture = subprocess.run(
                    ["xcrun", "simctl", "io", device, "screenshot",
                     f"--display={display}", str(destination)],
                    stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True,
                    timeout=min(8, budget),
                )
                capture_returncode = capture.returncode
            except subprocess.TimeoutExpired:
                pass
            valid_image = capture_returncode == 0 and destination.is_file() and destination.stat().st_size > 0
            succeeded &= valid_image
            captures.write(f"{sequence:03}{suffix}\t{action}\t{capture_returncode}\t{int(valid_image)}\n")
            captures.flush()
        if not succeeded or time.monotonic() >= deadline:
            raise RuntimeError(f"Capture failed or expired at checkpoint {sequence}")
        hierarchy = acknowledgement.with_suffix(".ack.txt")
        if not hierarchy.is_file():
            raise RuntimeError("Checkpoint hierarchy is missing")
        (output / f"{sequence:03}-hierarchy.txt").write_bytes(hierarchy.read_bytes())
        acknowledgement.touch()
        acknowledged = True
        captured = True
        print(f"capture {sequence:03}: {action}", flush=True)
    except Exception as exc:
        error = str(exc)
        raise
    finally:
        checkpoints.write(json.dumps({"sequence": sequence, "action": action,
                                      "elapsed_seconds": round(time.monotonic() - started, 3),
                                      "acknowledged": acknowledged,
                                      "valid_evidence": acknowledged and captured,
                                      "error": error}) + "\n")
        checkpoints.flush()


def should_report_line(line):
    # Stack traces contain Objective-C selector fragments such as `error:`;
    # report diagnostics rather than flooding the conversation with those frames.
    return bool(re.search(r"^error:|:\d+(?::\d+)?: error:|^Test Case |^\*\* TEST|^Executed ", line))


def main():
    if len(sys.argv) < 5:
        raise SystemExit(__doc__)
    output, device, requested_display = Path(sys.argv[1]).resolve(), sys.argv[2], sys.argv[3]
    output.mkdir(parents=True, exist_ok=True)
    container_root = (
        Path.home() / "Library/Developer/CoreSimulator/Devices" / device
        / "data/Containers/Data/Application"
    ).resolve()
    lock_fd = os.environ.get("DUNE_SIM_TEST_LOCK_FD")
    inherited_fds = (int(lock_fd),) if lock_fd else ()
    process = subprocess.Popen(sys.argv[4:], stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                               text=True, bufsize=1, pass_fds=inherited_fds)
    sequence = 0
    try:
        with (output / "run.log").open("w") as log, (output / "captures.tsv").open("w") as captures, (output / "checkpoints.jsonl").open("w") as checkpoints:
            for line in process.stdout:
                log.write(line)
                log.flush()
                if "DUNE_VISUAL_AUDIT_READY " not in line:
                    if should_report_line(line):
                        print(line.strip(), flush=True)
                    continue
                sequence += 1
                capture_checkpoint(line, sequence, output, device, requested_display,
                                   container_root, captures, checkpoints)
        return process.wait()
    except BaseException:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
        raise


if __name__ == "__main__":
    sys.exit(main())
