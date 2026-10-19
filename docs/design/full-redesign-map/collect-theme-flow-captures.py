#!/usr/bin/env python3
"""Collect actual iPhone detail, sheet, and exercise scenes for all themes."""

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
DESTINATION = HERE / "actual" / "flows"
NAME = re.compile(r"^(Desert|Ocean|Forest|Sakura|Arctic|Solar|Contour|Water Lilies) (Light|Dark) (Detail|Sheet|Workout)$")


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
                        help="Replace later captures from the same device, preserving other flows")
    args = parser.parse_args()
    if not args.xcresult.is_dir() or args.xcresult.suffix != ".xcresult":
        parser.error("Input must be an existing .xcresult bundle")

    collector = load_collector()
    device = collector.device_metadata(args.xcresult, "regular")
    revision, dirty = collector.git_source_metadata(None, None)
    staging = Path(tempfile.mkdtemp(prefix="dune-theme-flow-captures-", dir="/private/tmp"))
    staging.chmod(0o755)
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
                theme_name, style, surface_name = match.groups()
                theme = collector.THEMES[theme_name]
                appearance = style.lower()
                surface = surface_name.lower()
                source = staging / "export" / attachment["exportedFileName"]
                if not source.is_file():
                    raise FileNotFoundError(source)
                key = f"{theme}/{appearance}/{surface}"
                captures[key] = {
                    "theme": theme,
                    "appearance": appearance,
                    "surface": surface,
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
        existing = None
        if args.replace_existing:
            index_path = DESTINATION / "capture-index.json"
            if not index_path.is_file():
                raise FileNotFoundError(f"Existing flow index is required: {index_path}")
            existing = json.loads(index_path.read_text(encoding="utf-8"))
            if existing.get("device", {}).get("identifier") != device.get("identifier"):
                raise ValueError("Replacement must come from the same simulator")
            if not captures:
                raise ValueError("No named flow captures found")
            for key, record in captures.items():
                previous = existing.get("captures", {}).get(key)
                if previous is None or not (DESTINATION / previous["file"]).is_file():
                    raise ValueError(f"Cannot replace a missing flow capture: {key}")
                if float(record.get("timestamp") or 0) <= float(previous.get("timestamp") or 0):
                    raise ValueError(f"Replacement is not newer: {key}")
        else:
            if len(captures) != 48:
                raise ValueError(f"Expected 48 flow captures, found {len(captures)}")
            if DESTINATION.exists():
                raise FileExistsError(f"Refusing to overwrite {DESTINATION}")
        print(f"iPhone flows: {len(captures)} captures from {device.get('model_name')}")
        if args.dry_run:
            return
        DESTINATION.mkdir(parents=True, exist_ok=args.replace_existing)
        for record in captures.values():
            target = DESTINATION / record["file"]
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(record.pop("source"), target)
        if existing is not None:
            existing["captures"].update(captures)
            payload = existing
        else:
            payload = {"schema_version": 1, "device": device, "captures": captures}
        temporary = DESTINATION / "capture-index.json.tmp"
        temporary.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        os.replace(temporary, DESTINATION / "capture-index.json")
    finally:
        shutil.rmtree(staging, ignore_errors=True)


if __name__ == "__main__":
    main()
