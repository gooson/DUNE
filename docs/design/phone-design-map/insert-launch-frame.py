"""Add a visually verified frame from simctl's real launch recording to T01."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import runpy
import shutil


HERE = Path(__file__).resolve().parent
collector = runpy.run_path(str(HERE / "collect-real-captures.py"))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("device", choices=list(collector["DEVICE_LABELS"]))
    parser.add_argument("frame", type=Path)
    parser.add_argument("frame_time", help="Time in seconds from the start of launch.mov")
    args = parser.parse_args()
    destination = HERE / "actual" / args.device
    video = destination / "launch.mov"
    index_path = destination / "capture-index.json"
    if not video.is_file() or not index_path.is_file() or not collector["has_visible_pixels"](args.frame):
        parser.error("the source video, prior capture index, and visible actual frame are required")
    target = destination / "images" / "T01.png"
    shutil.copyfile(args.frame, target)
    index = json.loads(index_path.read_text())
    index["captured"]["T01"] = {
        "row_id": "T01", "evidence": "visually verified simctl frame",
        "test": "simctl io recordVideo", "action": f"app launch at {args.frame_time}s",
        "timestamp": video.stat().st_mtime, "image": "launch.mov",
        "screen": "actual simulator launch frame", "file": "T01.png",
        "video": "launch.mov", "frame_time": args.frame_time,
    }
    index_path.write_text(json.dumps(index, ensure_ascii=False, indent=2) + "\n")
    rows = collector["ROWS"]
    chosen = index["captured"]
    (destination / "index.html").write_text(collector["render_gallery"](rows, chosen, args.device))
    collector["render_boards"](rows, chosen, destination / "images", destination, args.device)
    collector["render_portal"]()
    print(f"{args.device}: T01 verified launch frame inserted; {len(chosen)} actual screen captures")


if __name__ == "__main__":
    main()
