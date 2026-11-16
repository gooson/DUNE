#!/usr/bin/env python3
"""Collect the 50 original generated PNGs and rebuild the dashboard data."""

import json
import shutil
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parent
ASSETS = ROOT.parent


def main():
    manifest = json.loads((ROOT / "prompts.json").read_text())
    missing = [c["id"] for c in manifest["concepts"] if not (ROOT / "receipts" / (c["id"] + ".json")).is_file()]
    if missing:
        raise SystemExit(f"Generation not complete: {len(missing)} missing receipts")
    all_concepts = []
    for version in ["v1", "v2", "v3"]:
        source = json.loads((ASSETS / version / "prompts.json").read_text())
        for concept in source["concepts"]:
            if version == "v3":
                receipt = json.loads((ROOT / "receipts" / (concept["id"] + ".json")).read_text())
                destination = ROOT / (concept["id"] + ".png")
                shutil.copy2(receipt["generated_path"], destination)
                with Image.open(destination) as image:
                    if image.width != image.height or image.width < 1024:
                        raise ValueError(f"Invalid dimensions: {destination}")
                    if "A" in image.getbands() and image.getchannel("A").getextrema() != (255, 255):
                        raise ValueError(f"Unexpected transparency: {destination}")
            all_concepts.append({key: concept[key] for key in ["id", "name", "desc", "group", "groupName", "theme", "themeName"] if key in concept} | {
                "version": version,
                "image": version + "/" + concept["id"] + ".png",
            })
    manifest["status"] = "generated-exploration-not-approved"
    (ROOT / "prompts.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    data = {
        "concepts": all_concepts,
        "groups": manifest["groups"],
        "references": json.loads((ASSETS / "references/sources.json").read_text()),
        "designReferences": json.loads((ASSETS / "references/dribbble/sources.json").read_text()),
    }
    (ASSETS / "data.js").write_text("window.duneIconData = " + json.dumps(data, ensure_ascii=False, indent=2) + ";\n")
    print(f"Collected {len(manifest['concepts'])} new PNGs; dashboard has {len(all_concepts)} concepts")


if __name__ == "__main__":
    main()
