#!/usr/bin/env python3
"""Copy verified DUNE light roots into the existing actual-screen map.

The theme matrix captures the same running app as the default design map. This
keeps that map's four root screenshots current without launching duplicate UI
tests, while preserving the exact source test and result bundle in its index.
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import os
from pathlib import Path
import shutil
import sys


HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
DEFAULT_MAP = REPO / "docs/design/phone-design-map/actual"
COLLECTOR = REPO / "docs/design/phone-design-map/collect-real-captures.py"
SCREENS = ("T03", "A01", "H01", "L01")
DEVICES = ("regular", "ipad", "duo", "duo-open")


def load_renderer():
    sys.dont_write_bytecode = True
    spec = importlib.util.spec_from_file_location("phone_capture_renderer", COLLECTOR)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def sync(device: str, dry_run: bool, screen_ids: tuple[str, ...]) -> None:
    source_root = HERE / "actual" / device
    source_index = json.loads((source_root / "capture-index.json").read_text(encoding="utf-8"))
    destination = DEFAULT_MAP / device
    index_path = destination / "capture-index.json"
    index = json.loads(index_path.read_text(encoding="utf-8"))
    records = []
    for screen_id in screen_ids:
        record = source_index["captures"][f"dune/light/{screen_id}"]
        source = source_root / record["file"]
        if not source.is_file():
            raise FileNotFoundError(source)
        previous = index["captured"].get(screen_id, {})
        if float(record["timestamp"]) <= float(previous.get("timestamp", 0)):
            raise ValueError(f"{screen_id}: source capture is not newer than the default map")
        records.append((screen_id, record, source))

    revisions = {record["source_revision"] for _, record, _ in records}
    bundles = {record["result_bundle"] for _, record, _ in records}
    if len(revisions) != 1 or len(bundles) != 1:
        raise ValueError("Default root captures must share one build and result bundle")
    print(f"{device}: updating {', '.join(screen_ids)} from {next(iter(bundles))}")
    if dry_run:
        return

    images = destination / "images"
    for screen_id, record, source in records:
        target = images / f"{screen_id}.png"
        temporary = target.with_suffix(".png.tmp")
        shutil.copyfile(source, temporary)
        os.replace(temporary, target)
        index["captured"][screen_id] = {
            "row_id": screen_id,
            "evidence": "DUNE light theme root",
            "test": record["test_identifier"],
            "action": record["attachment_name"],
            "timestamp": record["timestamp"],
            "image": record["attachment_name"],
            "screen": record["attachment_name"],
            "file": f"{screen_id}.png",
        }
    index["source_revision"] = next(iter(revisions))
    index["source_worktree_dirty"] = any(record["source_worktree_dirty"] for _, record, _ in records)
    index["xcresults"] = list(dict.fromkeys(index.get("xcresults", []) + list(bundles)))
    temporary_index = index_path.with_suffix(".json.tmp")
    temporary_index.write_text(json.dumps(index, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    os.replace(temporary_index, index_path)

    renderer = load_renderer()
    (destination / "index.html").write_text(
        renderer.render_gallery(renderer.ROWS, index["captured"], device), encoding="utf-8"
    )
    renderer.render_boards(renderer.ROWS, index["captured"], images, destination, device)
    watch_gallery = DEFAULT_MAP / "watch" / "index.html"
    previous_watch_gallery = watch_gallery.read_bytes()
    try:
        renderer.render_portal()
    finally:
        watch_gallery.write_bytes(previous_watch_gallery)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("device", choices=DEVICES)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--screen-id", choices=SCREENS, action="append", help="sync only selected roots")
    args = parser.parse_args()
    screen_ids = tuple(dict.fromkeys(args.screen_id or SCREENS))
    sync(args.device, args.dry_run, screen_ids)


if __name__ == "__main__":
    main()
