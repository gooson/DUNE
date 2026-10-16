#!/usr/bin/env python3
"""Build the self-contained theme gallery from its manifest and template."""

import argparse
import html
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent
MANIFEST = ROOT / "manifest.json"
TEMPLATE = ROOT / "template.html.in"
OUTPUT = ROOT / "index.html"


def escaped(value: str) -> str:
    return html.escape(value, quote=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Verify the generated map is current")
    args = parser.parse_args()
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    entries = data["themes"] + data["studies"]
    ids = [entry["id"] for entry in entries]
    files = [entry["file"] for entry in entries]
    if len(ids) != len(set(ids)) or len(files) != len(set(files)):
        raise ValueError("Theme IDs and filenames must be unique")
    for entry in entries:
        file = ROOT / "themes" / entry["file"]
        if file.parent != ROOT / "themes" or not file.is_file():
            raise FileNotFoundError(file)
    first = data["themes"][0]
    cards = []
    options = []
    for theme in data["themes"]:
        colors = "".join(f'<i style="background:{escaped(color)}"></i>' for color in theme["colors"])
        cards.append(
            f'<div class="theme-card"><button class="theme-choice" type="button" '
            f'data-theme="{escaped(theme["id"])}" aria-pressed="{str(theme is first).lower()}">'
            f'<span class="theme-name">{escaped(theme["name"])}</span>'
            f'<span class="theme-title">{escaped(theme["title"])}</span>'
            f'<span class="theme-motif">{escaped(theme["motif"])}</span></button>'
            f'<a class="theme-open" href="themes/{escaped(theme["file"])}" target="_blank" rel="noopener">열기 ↗</a>'
            f'<div class="swatches" aria-hidden="true">{colors}</div></div>'
        )
        options.append(f'<option value="{escaped(theme["id"])}">{escaped(theme["name"])} · {escaped(theme["title"])}</option>')
    study = data["studies"][0]
    embedded = json.dumps(data, ensure_ascii=False).replace("<", "\\u003c")
    replacements = {
        "__THEME_MANIFEST__": embedded,
        "__UPDATED__": escaped(data["updated"]),
        "__THEME_COUNT__": str(len(data["themes"])),
        "__THEME_CARDS__": "\n".join(cards),
        "__STUDY_NAME__": escaped(study["name"]),
        "__STUDY_FILE__": escaped(study["file"]),
        "__STUDY_DETAIL__": escaped(study["detail"]),
        "__FIRST_NAME__": escaped(first["name"]),
        "__FIRST_TITLE__": escaped(first["title"]),
        "__FIRST_DESCRIPTION__": escaped(f'{first["motif"]} · {first["motion"]}. {first["detail"]}'),
        "__FIRST_FILE__": escaped(first["file"]),
        "__COMPARE_OPTIONS__": "\n".join(options),
    }
    result = TEMPLATE.read_text(encoding="utf-8")
    for placeholder, value in replacements.items():
        if placeholder not in result:
            raise ValueError(f"Missing placeholder: {placeholder}")
        result = result.replace(placeholder, value)
    if args.check:
        if not OUTPUT.is_file() or OUTPUT.read_text(encoding="utf-8") != result:
            raise SystemExit("Theme map is outdated; run build-theme-map.py")
        print("Theme map is current")
    else:
        OUTPUT.write_text(result, encoding="utf-8")
        print(f"Built {OUTPUT.relative_to(ROOT)} with {len(data['themes'])} themes and {len(data['studies'])} studies")


if __name__ == "__main__":
    main()
