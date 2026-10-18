"""Export named Watch UI test screenshots into the combined design map."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import runpy
import shutil
import subprocess
import tempfile
import time


HERE = Path(__file__).resolve().parent
DESTINATION = HERE.parent / "phone-design-map" / "actual" / "watch"
PATTERN = re.compile(r"^watch-design-map-([HDGPXSCF]\d\d)_")


def collect(result_paths: list[Path]) -> None:
    images = DESTINATION / "images"
    images.mkdir(parents=True, exist_ok=True)
    index_path = DESTINATION / "capture-index.json"
    captured = json.loads(index_path.read_text()).get("captured", {}) if index_path.exists() else {}
    for entry in captured.values():
        if entry.get("device") == "iPhone 18 Pro":
            entry["device"] = "Apple Watch SE 3 (40mm)"

    for result_path in result_paths:
        summary_command = ["xcrun", "xcresulttool", "get", "test-results", "summary",
                           "--path", str(result_path), "--format", "json"]
        try:
            summary_output = subprocess.run(summary_command, check=True, capture_output=True, text=True).stdout
        except subprocess.CalledProcessError:
            # Xcode can return before the xcresult TestReport finishes writing.
            time.sleep(1)
            summary_output = subprocess.run(summary_command, check=True, capture_output=True, text=True).stdout
        summary = json.loads(summary_output)
        watch_devices = [(item["device"].get("deviceName")
                          or item["device"].get("modelName", "Apple Watch")).split("-wt-", 1)[0]
                         for item in summary.get("devicesAndConfigurations", [])
                         if item.get("device", {}).get("platform") == "watchOS Simulator"]
        device_name = watch_devices[0] if watch_devices else "Apple Watch simulator"
        with tempfile.TemporaryDirectory(prefix="dune-watch-captures-") as temporary:
            export = Path(temporary)
            subprocess.run(
                ["xcrun", "xcresulttool", "export", "attachments", "--path", str(result_path),
                 "--output-path", str(export), "--filter", "*.png"],
                check=True, capture_output=True, text=True,
            )
            for test in json.loads((export / "manifest.json").read_text()):
                for attachment in test["attachments"]:
                    match = PATTERN.match(attachment["suggestedHumanReadableName"])
                    if not match or attachment["isAssociatedWithFailure"]:
                        continue
                    code = match.group(1)
                    if attachment["timestamp"] < captured.get(code, {}).get("timestamp", 0):
                        continue
                    filename = f"{code}.png"
                    shutil.copy2(export / attachment["exportedFileName"], images / filename)
                    captured[code] = {
                        "file": filename,
                        "test": test["testIdentifier"],
                        "device": device_name,
                        "timestamp": attachment["timestamp"],
                        "resultBundle": result_path.name,
                    }

    index_path.write_text(json.dumps({"captured": dict(sorted(captured.items()))}, ensure_ascii=False, indent=2) + "\n")
    renderer = runpy.run_path(str(HERE.parent / "phone-design-map" / "collect-real-captures.py"))
    renderer["render_portal"]()
    print(f"Watch actual capture: {len(captured)} / 62 states")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("xcresults", nargs="+", type=Path)
    arguments = parser.parse_args()
    collect(arguments.xcresults)
