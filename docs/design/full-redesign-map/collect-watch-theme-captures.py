#!/usr/bin/env python3
"""Collect eight-theme Watch home, exercise-list, and workout screenshots from XCTest."""

from __future__ import annotations

import argparse
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import sys
import tempfile


HERE = Path(__file__).resolve().parent
DESTINATION = HERE / "actual" / "watch"
NAME = re.compile(r"^(Desert|Ocean|Forest|Sakura|Arctic|Solar|Contour|Water Lilies) Watch (Home|All Exercises|Workout)$")


def load_collector():
    sys.dont_write_bytecode = True
    spec = importlib.util.spec_from_file_location("theme_capture_collector", HERE / "collect-theme-captures.py")
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("xcresult", type=Path)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--replace-existing", action="store_true",
                        help="Replace all 24 captures only with newer captures from the same simulator")
    args = parser.parse_args()
    if not args.xcresult.is_dir() or args.xcresult.suffix != ".xcresult":
        parser.error("Input must be an existing .xcresult bundle")

    collector = load_collector()
    device = collector.device_metadata(args.xcresult, "watch")
    revision, dirty = collector.git_source_metadata(None, None)
    staging = Path(tempfile.mkdtemp(prefix="dune-watch-theme-captures-", dir="/private/tmp"))
    staging.chmod(0o755)
    ready: Path | None = None
    try:
        manifest = collector.export_result(args.xcresult, staging / "export")
        captures = {}
        for test in manifest:
            for attachment in test.get("attachments", []):
                match = NAME.fullmatch(collector.normalized_attachment_name(
                    attachment.get("suggestedHumanReadableName", "")
                ))
                if not match or attachment.get("isAssociatedWithFailure", False):
                    continue
                theme_name, scene_name = match.groups()
                theme = collector.THEMES[theme_name]
                scene = {"Home": "home", "All Exercises": "all-exercises", "Workout": "workout"}[scene_name]
                source = staging / "export" / attachment["exportedFileName"]
                if not source.is_file():
                    raise FileNotFoundError(source)
                key = f"{theme}/{scene}"
                captures[key] = {
                    "theme": theme,
                    "scene": scene,
                    "file": f"{key}.png",
                    "attachment_name": attachment["suggestedHumanReadableName"],
                    "test_identifier": test.get("testIdentifier"),
                    "timestamp": attachment.get("timestamp"),
                    "result_bundle": str(args.xcresult.resolve()),
                    "device": device,
                    "source_revision": revision,
                    "source_worktree_dirty": dirty,
                    "source": source,
                }
        if len(captures) != 24:
            raise ValueError(f"Expected 24 Watch captures, found {len(captures)}")
        previous = None
        if DESTINATION.exists():
            if not args.replace_existing:
                raise FileExistsError(f"Refusing to overwrite {DESTINATION}")
            previous = json.loads((DESTINATION / "capture-index.json").read_text(encoding="utf-8"))
            old_captures = previous.get("captures", {})
            if set(old_captures) != set(captures):
                raise ValueError("Replacement must contain the same 24 Watch screens")
            if previous.get("device", {}).get("identifier") != device.get("identifier"):
                raise ValueError("Replacement must use the same Watch simulator")
            for key, record in captures.items():
                old_file = DESTINATION / old_captures[key]["file"]
                if not old_file.is_file():
                    raise FileNotFoundError(old_file)
                if float(record["timestamp"] or 0) <= float(old_captures[key]["timestamp"] or 0):
                    raise ValueError(f"Replacement capture is not newer: {key}")
        print(f"Watch: {len(captures)} captures from {device.get('model_name')}")
        if args.dry_run:
            return
        ready = Path(tempfile.mkdtemp(prefix=".watch-captures-ready-", dir=DESTINATION.parent))
        for record in captures.values():
            target = ready / record["file"]
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(record.pop("source"), target)
        payload = {"schema_version": 1, "device": device, "captures": captures}
        (ready / "capture-index.json").write_text(
            json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
        if previous is None:
            os.replace(ready, DESTINATION)
        else:
            backup = Path(tempfile.mkdtemp(prefix=".watch-captures-backup-", dir=DESTINATION.parent))
            backup.rmdir()
            os.replace(DESTINATION, backup)
            try:
                os.replace(ready, DESTINATION)
            except Exception:
                os.replace(backup, DESTINATION)
                raise
            shutil.rmtree(backup)
    finally:
        if ready is not None:
            shutil.rmtree(ready, ignore_errors=True)
        shutil.rmtree(staging, ignore_errors=True)


if __name__ == "__main__":
    main()
