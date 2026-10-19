#!/usr/bin/env python3
"""Build and check the theme-to-screen implementation map."""

import argparse
import html
import json
from datetime import datetime
from pathlib import Path


ROOT = Path(__file__).resolve().parent
DESIGN = ROOT.parent
THEME_MANIFEST = DESIGN / "theme-map" / "manifest.json"
INVENTORY = DESIGN / "phone-design-map" / "screen-inventory.md"
SPEC = ROOT / "spec.json"
TEMPLATE = ROOT / "template.html.in"
OUTPUT = ROOT / "index.html"
ACTUAL = ROOT / "actual"
DEVICE_NAMES = {"regular": "iPhone", "ipad": "iPad", "duo": "Duo 접힘", "duo-open": "Duo 펼침"}


def escape(value: object) -> str:
    return html.escape(str(value), quote=True)


def embedded_json(value: object) -> str:
    return json.dumps(value, ensure_ascii=False).replace("<", "\\u003c")


def read_inventory() -> list[dict[str, str]]:
    screens = []
    for line in INVENTORY.read_text(encoding="utf-8").splitlines():
        columns = [value.strip() for value in line.split("|")[1:-1]]
        if len(columns) == 8 and len(columns[0]) == 3 and columns[0][0] in "TAWHPLS" and columns[0][1:].isdigit():
            screen_id, name, entry, presentation, iphone, ipad, duo, code = columns
            screens.append({
                "id": screen_id,
                "name": name,
                "entry": entry,
                "presentation": presentation,
                "iphone": iphone,
                "ipad": ipad,
                "duo": duo,
                "code": code.strip("`"),
                "reachable": screen_id not in {"W17", "W18"},
            })
    ids = [screen["id"] for screen in screens]
    if len(screens) != 108 or len(ids) != len(set(ids)):
        raise ValueError(f"Expected 108 unique screen IDs, found {len(screens)}")
    return screens


def application_pattern(presentation: str) -> str:
    if presentation == "root":
        return "전체 장면 · 히어로 · 행동"
    if presentation == "launch":
        return "브랜드 장면 · 읽기 우선"
    if presentation == "cover":
        return "제어 우선 · 장면 최소"
    if presentation == "state":
        return "흐름 유지 · 장식 최소"
    if presentation == "window":
        return "별도 창 표면 · 대비"
    if "sheet" in presentation or presentation == "inspector":
        return "안정 표면 · 모티프 축소"
    return "상세 장면 축소 · 데이터 대비"


def read_capture_indexes() -> dict[str, dict]:
    indexes = {}
    for device in DEVICE_NAMES:
        path = ACTUAL / device / "capture-index.json"
        if not path.exists():
            indexes[device] = {}
            continue
        payload = json.loads(path.read_text(encoding="utf-8"))
        captures = payload.get("captures", {})
        if not isinstance(captures, dict):
            raise ValueError(f"Invalid capture index: {path}")
        for key, record in captures.items():
            image = ACTUAL / device / record["file"]
            if not image.is_file() or image.suffix.lower() != ".png":
                raise ValueError(f"Missing actual capture for {key}: {image}")
        indexes[device] = captures
    return indexes


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    source = json.loads(THEME_MANIFEST.read_text(encoding="utf-8"))
    spec = json.loads(SPEC.read_text(encoding="utf-8"))
    verification_capture_after = datetime.fromisoformat(spec["verification_capture_after"]).timestamp()
    screens = read_inventory()
    capture_indexes = read_capture_indexes()
    watch_index_path = ACTUAL / "watch" / "capture-index.json"
    watch_captures = {}
    if watch_index_path.is_file():
        watch_captures = json.loads(watch_index_path.read_text(encoding="utf-8")).get("captures", {})
        for record in watch_captures.values():
            if not (ACTUAL / "watch" / record["file"]).is_file():
                raise ValueError(f"Missing Watch actual capture: {record['file']}")
    flow_index_path = ACTUAL / "flows" / "capture-index.json"
    flow_captures = {}
    if flow_index_path.is_file():
        flow_captures = json.loads(flow_index_path.read_text(encoding="utf-8")).get("captures", {})
        for record in flow_captures.values():
            if not (ACTUAL / "flows" / record["file"]).is_file():
                raise ValueError(f"Missing flow actual capture: {record['file']}")
    source_ids = [theme["id"] for theme in source["themes"]]
    spec_ids = [theme["id"] for theme in spec["themes"]]
    if source_ids != spec_ids or len(source_ids) != 8:
        raise ValueError("Implementation theme IDs must match all eight source themes")
    if [tab["id"] for tab in spec["tabs"]] != ["T03", "A01", "H01", "L01"]:
        raise ValueError("The four root screen IDs have changed")
    if [family["prefix"] for family in spec["families"]] != list("TAWHPLS"):
        raise ValueError("A phone screen family is missing")
    if not (DESIGN / "theme-map" / "themes" / source["themes"][-1]["file"]).is_file():
        raise ValueError("Water Lilies source direction is missing")

    themes = []
    for source_theme, implementation in zip(source["themes"], spec["themes"]):
        themes.append({**source_theme, **implementation})

    theme_buttons = []
    for theme in themes:
        colors = "".join(f'<i style="background:{escape(color)}"></i>' for color in theme["colors"])
        theme_buttons.append(
            f'<button class="theme-choice" type="button" data-theme="{escape(theme["id"])}" '
            f'aria-pressed="{str(theme is themes[0]).lower()}">'
            f'<span class="theme-id">{escape(theme["name"])}</span>'
            f'<span class="theme-subtitle">{escape(theme["title"])}</span>'
            f'<span class="swatches" aria-hidden="true">{colors}</span></button>'
        )

    tab_cards = []
    for tab in spec["tabs"]:
        tab_cards.append(
            f'<article class="tab-card" id="{escape(tab["id"])}">'
            f'<div class="tab-card-head"><span>{escape(tab["id"])}</span><h3>{escape(tab["name"])}</h3></div>'
            f'<p class="tab-question">{escape(tab["question"])}</p>'
            f'<p class="flow">{escape(tab["order"])}</p>'
            f'<dl><dt>주 행동</dt><dd>{escape(tab["action"])}</dd>'
            f'<dt>데이터 없음</dt><dd>{escape(tab["empty"])}</dd>'
            f'<dt>앱 구현</dt><dd>{escape(tab["code"])}</dd></dl>'
            f'<a href="../phone-design-map/actual/regular/images/{escape(tab["id"])}.png">현재 실제 화면 ↗</a></article>'
        )

    family_cards = []
    for family in spec["families"]:
        count = sum(screen["id"].startswith(family["prefix"]) for screen in screens)
        family_cards.append(
            f'<article><b>{escape(family["prefix"])} · {count}개 화면</b>'
            f'<p>{escape(family["treatment"])}</p></article>'
        )

    screen_rows = []
    primary_captures = {}
    for device in DEVICE_NAMES:
        path = DESIGN / "phone-design-map" / "actual" / device / "capture-index.json"
        primary_captures[device] = json.loads(path.read_text(encoding="utf-8")).get("captured", {}) if path.is_file() else {}
    for screen in screens:
        flag = "<span class=\"deferred\">진입 경로 없음</span>" if not screen["reachable"] else "<span>적용 대상</span>"
        search_text = " ".join([screen["id"], screen["name"], screen["entry"], screen["code"]]).lower()
        actual_links = []
        for device, label in DEVICE_NAMES.items():
            record = primary_captures[device].get(screen["id"])
            if not record:
                actual_links.append(f'<span class="capture-pending">{escape(label)} 미캡처</span>')
                continue
            path = DESIGN / "phone-design-map" / "actual" / device / "images" / record["file"]
            if not path.is_file():
                raise ValueError(f"Missing primary actual capture: {path}")
            freshness = "이번 개편 촬영" if float(record.get("timestamp", 0)) >= verification_capture_after else "기존 캡처"
            url = f'../phone-design-map/actual/{device}/images/{record["file"]}'
            actual_links.append(f'<a href="{escape(url)}">{escape(label)} · {freshness} ↗</a>')
        screen_rows.append(
            f'<tr data-family="{escape(screen["id"][0])}" data-search="{escape(search_text)}">'
            f'<td><b>{escape(screen["id"])}</b></td><td>{escape(screen["name"])}</td>'
            f'<td>{escape(screen["presentation"])}</td><td>{escape(application_pattern(screen["presentation"]))}</td>'
            f'<td>{escape(screen["iphone"])}<br><span class="device-secondary">iPad: {escape(screen["ipad"])}<br>Duo: {escape(screen["duo"])}</span></td>'
            f'<td><code>{escape(screen["code"])}</code></td>'
            f'<td><div class="capture-links">{"".join(actual_links)}</div></td><td>{flag}</td></tr>'
        )

    matrix_rows = []
    evidence_sections = []
    watch_evidence_sections = []
    flow_evidence_sections = []
    for theme in themes:
        cells = []
        evidence_figures = []
        for tab in spec["tabs"]:
            screen_id = tab["id"]
            capture_links = []
            for appearance, appearance_label in (("light", "밝음"), ("dark", "어두움")):
                key = f'{theme["id"]}/{appearance}/{screen_id}'
                record = capture_indexes["regular"].get(key)
                if record:
                    url = f'actual/regular/{record["file"]}'
                    capture_links.append(f'<a href="{escape(url)}">iPhone {appearance_label} 실제 ↗</a>')
                    visual = f'<a href="{escape(url)}"><img src="{escape(url)}" alt="{escape(theme["name"])} {escape(tab["name"])} {appearance_label} 실제 앱 화면" loading="lazy"></a>'
                else:
                    capture_links.append(f'<span class="capture-pending">iPhone {appearance_label} 미캡처</span>')
                    visual = '<div class="capture-placeholder">실제 캡처 대기</div>'
                evidence_figures.append(
                    f'<figure>{visual}<figcaption>{escape(tab["name"])} · {appearance_label}</figcaption></figure>'
                )
            other_devices = []
            for device in ("ipad", "duo", "duo-open"):
                count = sum(f'{theme["id"]}/{appearance}/{screen_id}' in capture_indexes[device] for appearance in ("light", "dark"))
                other_devices.append(f'{DEVICE_NAMES[device]} {count}/2')
            cells.append(
                f'<td><b>{escape(screen_id)}</b><div class="capture-links">{"".join(capture_links)}</div>'
                f'<small>{escape(" · ".join(other_devices))}</small></td>'
            )
        kind = "신규 테마" if theme["id"] == "water-lilies" else "기존 테마 재설계"
        matrix_rows.append(f'<tr><th scope="row"><a href="../theme-map/themes/{escape(theme["file"])}">{escape(theme["name"])}</a><small>{kind}</small></th>{"".join(cells)}</tr>')
        evidence_sections.append(
            f'<div class="evidence-grid" data-evidence-theme="{escape(theme["id"])}" hidden>{"".join(evidence_figures)}</div>'
        )
        watch_figures = []
        for scene, label in (("home", "홈"), ("all-exercises", "전체 운동"), ("workout", "운동 중")):
            record = watch_captures.get(f'{theme["id"]}/{scene}')
            if record:
                url = f'actual/watch/{record["file"]}'
                visual = f'<a href="{escape(url)}"><img src="{escape(url)}" alt="{escape(theme["name"])} Watch {label} 실제 화면" loading="lazy"></a>'
            else:
                visual = '<div class="capture-placeholder">Watch 실제 캡처 대기</div>'
            watch_figures.append(f'<figure>{visual}<figcaption>{escape(label)}</figcaption></figure>')
        watch_evidence_sections.append(
            f'<div class="evidence-grid" data-watch-theme="{escape(theme["id"])}" hidden>{"".join(watch_figures)}</div>'
        )
        flow_figures = []
        for appearance, appearance_label in (("light", "밝음"), ("dark", "어두움")):
            for surface, surface_label in (("detail", "상세"), ("sheet", "시트"), ("workout", "운동 선택")):
                record = flow_captures.get(f'{theme["id"]}/{appearance}/{surface}')
                if record:
                    url = f'actual/flows/{record["file"]}'
                    visual = f'<a href="{escape(url)}"><img src="{escape(url)}" alt="{escape(theme["name"])} {appearance_label} {surface_label} 실제 화면" loading="lazy"></a>'
                else:
                    visual = '<div class="capture-placeholder">실제 캡처 대기</div>'
                flow_figures.append(f'<figure>{visual}<figcaption>{escape(surface_label)} · {appearance_label}</figcaption></figure>')
        flow_evidence_sections.append(
            f'<div class="evidence-grid" data-flow-theme="{escape(theme["id"])}" hidden>{"".join(flow_figures)}</div>'
        )

    replacements = {
        "__DATE__": escape(spec["date"]),
        "__FIRST_SCENE__": escape(themes[0]["scene"]),
        "__FIRST_SURFACE__": escape(themes[0]["surface"]),
        "__FIRST_RING__": escape(themes[0]["ring"]),
        "__FIRST_GRAPH__": escape(themes[0]["graph"]),
        "__FIRST_MOTION__": escape(themes[0]["motion"]),
        "__FIRST_CHECK__": escape(themes[0]["check"]),
        "__FIRST_GAP__": escape(themes[0]["gap"]),
        "__FIRST_CODE__": escape(themes[0]["code"]),
        "__THEME_BUTTONS__": "\n".join(theme_buttons),
        "__TAB_CARDS__": "\n".join(tab_cards),
        "__FAMILY_CARDS__": "\n".join(family_cards),
        "__SCREEN_ROWS__": "\n".join(screen_rows),
        "__MATRIX_ROWS__": "\n".join(matrix_rows),
        "__EVIDENCE_SECTIONS__": "\n".join(evidence_sections),
        "__WATCH_EVIDENCE_SECTIONS__": "\n".join(watch_evidence_sections),
        "__WATCH_COUNT__": str(len(watch_captures)),
        "__FLOW_EVIDENCE_SECTIONS__": "\n".join(flow_evidence_sections),
        "__FLOW_COUNT__": str(len(flow_captures)),
        "__CAPTURE_COUNTS__": " · ".join(
            f'{name} {len(capture_indexes[device])}/64' for device, name in DEVICE_NAMES.items()
        ),
        "__THEMES_JSON__": embedded_json(themes),
        "__SCREEN_COUNT__": str(len(screens)),
        "__REACHABLE_COUNT__": str(sum(screen["reachable"] for screen in screens)),
    }
    result = TEMPLATE.read_text(encoding="utf-8")
    for placeholder, value in replacements.items():
        if placeholder not in result:
            raise ValueError(f"Template placeholder missing: {placeholder}")
        result = result.replace(placeholder, value)
    if args.check:
        if not OUTPUT.exists() or OUTPUT.read_text(encoding="utf-8") != result:
            raise SystemExit("Full redesign map is outdated; run build-full-redesign-map.py")
        print("Full redesign map is current: 8 themes, 4 tabs, 108 inventoried screens")
    else:
        OUTPUT.write_text(result, encoding="utf-8")
        print(f"Built {OUTPUT.relative_to(ROOT)}: 8 themes, 4 tabs, {len(screens)} screens")


if __name__ == "__main__":
    main()
