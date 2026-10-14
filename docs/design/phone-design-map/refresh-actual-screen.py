#!/usr/bin/env python3
"""Recapture one existing design-map state on one explicit simulator."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
import uuid


HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
DEVICES = ("regular", "ipad", "duo", "duo-open", "watch")
TEST_NAME = re.compile(r"^([A-Za-z_]\w*)/([A-Za-z_]\w*)\(\)$")
UDID = re.compile(r"^[0-9A-Fa-f]{8}(?:-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}$")


def result_bundles(folder: Path) -> set[Path]:
    return {path.resolve() for path in folder.glob("*.xcresult")}


def verify_duo_display(device: str, udid: str) -> None:
    expected = "LCD" if device == "duo" else "LCD-1"
    output = subprocess.run(
        ["xcrun", "devicectl", "device", "info", "displays", "--device", udid,
         "--quiet", "--json-output", "-"],
        cwd=REPO, check=True, capture_output=True, text=True,
    ).stdout
    displays = json.loads(output)["result"]["displays"]
    active = [display["name"] for display in displays if display.get("active")]
    if active != [expected]:
        raise ValueError(f"{device} requires active {expected}; readback shows {active}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("device", choices=DEVICES)
    parser.add_argument("screen", help="Screen ID in capture-index.json, such as W04 or S16")
    parser.add_argument("simulator_udid", help="Simulator UUID for this device")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    if not UDID.fullmatch(args.simulator_udid):
        parser.error("simulator_udid must be a UUID")
    index_path = HERE / "actual" / args.device / "capture-index.json"
    if not index_path.exists():
        parser.error(f"capture index does not exist: {index_path}")
    current = json.loads(index_path.read_text())
    prior = current.get("captured", {}).get(args.screen)
    if prior is None:
        parser.error(f"{args.device}/{args.screen} has no capture test; add a route test first")
    match = TEST_NAME.fullmatch(prior.get("test", ""))
    if match is None:
        parser.error(f"{args.device}/{args.screen} needs manual capture: {prior.get('test', '')}")

    target = "DUNEWatchUITests" if args.device == "watch" else "DUNEUITests"
    selector = f"{target}/{match.group(1)}/{match.group(2)}"
    stamp = uuid.uuid4().hex[:10]
    log = f".xcodebuild/design-map-{args.device}-{args.screen}-{stamp}.log"
    if args.device == "watch":
        result = REPO / ".deriveddata" / "watch-design-map" / f"{args.screen}-{stamp}.xcresult"
        command = ["xcodebuild", "test", "-project", "DUNE/DUNE.xcodeproj",
                   "-scheme", "DUNEWatchUITests", "-destination",
                   f"platform=watchOS Simulator,id={args.simulator_udid}",
                   f"-only-testing:{selector}", "-parallel-testing-enabled", "NO",
                   "-resultBundlePath", str(result), "-quiet"]
        collector = [sys.executable, "docs/design/watch-workout/collect-actual-captures.py", str(result)]
    else:
        result_dir = REPO / os.environ.get("DAILVE_UI_TEST_DERIVED_DATA_DIR", ".deriveddata/ui-tests") / "Logs/Test"
        command = ["bash", "scripts/test-ui.sh", "--no-regen", "--test-plan",
                   "DUNEUITests-DesignCapture", "--simulator-udid", args.simulator_udid,
                   "--only-testing", selector, "--log-file", log]
        collector = []

    print(shlex.join(command), flush=True)
    if args.dry_run:
        return 0

    if args.device in ("duo", "duo-open"):
        try:
            verify_duo_display(args.device, args.simulator_udid)
        except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
            print(f"Duo display preflight failed: {error}", file=sys.stderr)
            return 1
    before = result_bundles(result_dir) if args.device != "watch" else set()
    if args.device == "watch":
        result.parent.mkdir(parents=True, exist_ok=True)
    status = subprocess.run(command, cwd=REPO, check=False).returncode
    if status != 0:
        print(f"Capture test failed ({status}); design map was not updated", file=sys.stderr)
        return status
    if args.device in ("duo", "duo-open"):
        try:
            verify_duo_display(args.device, args.simulator_udid)
        except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
            print(f"Duo display changed during capture: {error}", file=sys.stderr)
            return 1
    if args.device != "watch":
        created = result_bundles(result_dir) - before
        if not created:
            print("Capture test passed but produced no new xcresult", file=sys.stderr)
            return 1
        result = max(created, key=lambda path: path.stat().st_mtime)
        collector = [sys.executable, "docs/design/phone-design-map/collect-real-captures.py",
                     args.device, str(result), "--refresh-screen", args.screen]

    status = subprocess.run(collector, cwd=REPO, check=False).returncode
    if status != 0:
        return status
    refreshed = json.loads(index_path.read_text()).get("captured", {}).get(args.screen)
    if refreshed is None or refreshed.get("timestamp", 0) <= prior.get("timestamp", 0):
        print(f"{args.device}/{args.screen} did not receive a newer capture", file=sys.stderr)
        return 1
    image = index_path.parent / "images" / refreshed["file"]
    if not image.is_file():
        print(f"New capture is missing: {image}", file=sys.stderr)
        return 1
    print(f"Updated {args.device}/{args.screen}: {image}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
