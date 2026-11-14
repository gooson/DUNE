#!/usr/bin/env python3
"""Verify both CoreSimulator and the selected Xcode recognize a live destination."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys


def validate(devices: dict, runtimes: dict, destinations: str, udid: str, platform: str) -> dict:
    matches = [(runtime, device) for runtime, entries in devices.get("devices", {}).items()
               for device in entries if device.get("udid") == udid]
    if len(matches) != 1:
        raise ValueError("Expected exactly one matching simulator device")
    runtime_id, device = matches[0]
    if device.get("state") != "Booted" or device.get("isAvailable") is not True:
        raise ValueError(f"Simulator is not booted and available: {device.get('state')}")
    prefix = f"com.apple.CoreSimulator.SimRuntime.{platform}-"
    if not runtime_id.startswith(prefix):
        raise ValueError(f"Simulator runtime is not for {platform}: {runtime_id}")
    runtime_matches = [item for item in runtimes.get("runtimes", [])
                       if item.get("identifier") == runtime_id]
    if len(runtime_matches) != 1 or runtime_matches[0].get("isAvailable") is not True:
        raise ValueError(f"Simulator runtime is unavailable: {runtime_id}")
    version = runtime_matches[0].get("version")
    if not isinstance(version, str) or not re.fullmatch(r"\d+(?:\.\d+)*", version):
        raise ValueError(f"Simulator runtime has no valid version: {version!r}")

    # CoreSimulator bootstatus alone can succeed while Xcode sees OS (null).
    # Require the same available ID, OS, and architecture in Xcode's readback.
    available = destinations.split("Ineligible destinations", 1)[0]
    for line in available.splitlines():
        identity = re.search(r"\bid:\s*" + re.escape(udid) + r"\s*[,}]", line)
        os_version = re.search(r"\bOS:\s*([\d.]+)\s*[,}]", line)
        arch = re.search(r"\barch:\s*([A-Za-z0-9_]+)\s*[,}]", line)
        if (identity and os_version and arch and "error:" not in line
                and f"platform:{platform} Simulator" in line.replace(": ", ":")
                and os_version.group(1) == version):
            return {"udid": udid, "runtime": runtime_id, "version": version,
                    "state": device["state"], "architecture": arch.group(1)}
    raise ValueError(f"Selected Xcode does not expose a usable {platform} {version} destination for {udid}")


def output(command: list[str]) -> str:
    result = subprocess.run(command, capture_output=True, text=True, check=True, timeout=30)
    return result.stdout


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--udid", required=True)
    parser.add_argument("--platform", required=True, choices=("iOS", "watchOS"))
    parser.add_argument("--project", required=True)
    parser.add_argument("--scheme", required=True)
    args = parser.parse_args()
    devices = json.loads(output(["xcrun", "simctl", "list", "devices", "--json"]))
    runtimes = json.loads(output(["xcrun", "simctl", "list", "runtimes", "--json"]))
    destinations = output(["xcodebuild", "-showdestinations", "-project", args.project,
                           "-scheme", args.scheme])
    print("Simulator readiness: " + json.dumps(validate(devices, runtimes, destinations, args.udid, args.platform)))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ValueError, subprocess.SubprocessError) as error:
        print(f"Simulator readiness failed: {error}", file=sys.stderr)
        sys.exit(2)
