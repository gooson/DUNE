#!/usr/bin/env python3
"""Publish paired native artist-theme captures from a passing focused UI run."""

from __future__ import annotations

import argparse
from collections import defaultdict
from hashlib import sha256
from html import escape
import json
from pathlib import Path
import re
import runpy
import shutil
import subprocess
import tempfile
from uuid import UUID

from PIL import Image

HERE = Path(__file__).resolve().parent
DESTINATION = HERE / "actual" / "artist-themes"
THEMES = {
    "desertWarm": "Dune",
    "oceanCool": "Ocean",
    "forestGreen": "Forest",
    "sakuraCalm": "Sakura",
    "arcticDawn": "Arctic",
    "solarPop": "Solar",
    "contourAtlas": "Contour",
    "waterLilies": "Water Lilies",
    "patisserie": "Pâtisserie",
}
DEVICES = {"regular": "iPhone", "ipad": "iPad", "duo": "Duo 접힘", "duo-open": "Duo 펼침"}
STYLES = {"light": "라이트", "dark": "다크"}
SCREENS = {
    "T03": ("Today", "dashboard-hero-condition"),
    "T04": ("컨디션 상세", "condition-score-detail-screen"),
    "A01": ("Activity", "activity-hero-readiness"),
    "A02": ("운동 준비도", "activity-training-readiness-detail-screen"),
    "W28": ("운동 기록 · 목록의 상세 패널", "healthkit-workout-detail-screen"),
    "H01": ("Wellness", "wellness-hero-score"),
    "H02": ("웰니스 점수", "wellness-score-detail-screen"),
    "T06": ("수면 상세", "metric-detail-screen-sleep"),
    "L01": ("Life", "life-hero-progress"),
    "L08": ("습관 주간 보고서", "life-weekly-report-rate"),
    "S01": ("설정의 선택된 테마", None),
}
TEST_CLASS = "ArtistThemeNativeUITests"
WEEKLY_REPORT_SELECTOR = f"{TEST_CLASS}/testWeeklyReportReadingInk"
WEEKLY_REPORT_REFRESH_THEMES = {"forestGreen", "oceanCool", "sakuraCalm"}
ACTION = r"Artist (\w+) (light|dark) ([A-Z]\d{2})"
EXPORTED_SUFFIX = re.compile(r"(?:_\d+_[0-9a-fA-F-]{36})?\.(?:png|txt)$|_\d+_[0-9a-fA-F-]{36}$")
HIERARCHY_EXPORT_SUFFIX = re.compile(r"_\d+_[0-9a-fA-F-]{36}(?=\.swift-\d+$)")
MAIN_WINDOW = re.compile(r"^    Window(?: \(Main\))?, .*?\}, \{([\d.]+), ([\d.]+)\}\}", re.MULTILINE)


def read_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def run(*arguments: str) -> str:
    result = subprocess.run(arguments, check=True, capture_output=True, text=True, timeout=180)
    return result.stdout


def test_name(theme: str) -> str:
    return f"{TEST_CLASS}/test{theme[0].upper()}{theme[1:]}"


def read_receipt(path: Path, test_identifier: str, allow_passing_selector: bool) -> dict:
    receipt = read_json(path)
    selector = f"DUNEUITests/{test_identifier}"
    if selector not in receipt.get("requested_selectors", []) or selector in receipt.get("skipped_selectors", []):
        raise ValueError(f"Standard runner receipt must include {selector}")
    if receipt.get("status") == "passed" and receipt.get("run_exit_status") == 0:
        return receipt
    if allow_passing_selector:
        verifier = HERE.parents[2] / "scripts" / "lib" / "verify-ui-test-log.py"
        _, passed_cases, _ = runpy.run_path(str(verifier))["read_log"](Path(receipt["log_path"]), "DUNEUITests")
        if selector in passed_cases:
            return receipt
    raise ValueError(f"Expected passing runner evidence for {selector}")


def verify_provenance(path: Path, receipt_path: Path, receipt: dict, xcresult: Path, revision: str) -> dict:
    record = read_json(path)
    log = Path(receipt["log_path"]).resolve(strict=True)
    if (Path(record["log"]).resolve() != log
            or Path(record["receipt"]).resolve() != receipt_path.resolve()
            or Path(record["preserved_xcresult"]).resolve() != xcresult.resolve()
            or record["source_revision"] != revision
            or record["log_sha256"] != sha256(log.read_bytes()).hexdigest()
            or record["receipt_sha256"] != sha256(receipt_path.read_bytes()).hexdigest()):
        raise ValueError("Provenance must bind the receipt, original log, source revision and preserved xcresult")
    source_result = record["emitted_xcresult"]
    sources = re.findall(r"(?m)^\s*(/[^\r\n]*\.xcresult)\s*$", log.read_text(encoding="utf-8", errors="replace"))
    if source_result not in sources:
        raise ValueError("The original test log did not emit the xcresult in provenance")
    return record


def read_attachments(result: Path, folder: Path, theme: str, test_identifier: str,
                     partial: bool) -> tuple[dict, dict, dict | None]:
    summary = json.loads(run("xcrun", "xcresulttool", "get", "test-results", "summary", "--path", str(result)))
    configurations = summary.get("devicesAndConfigurations", [])
    if len(configurations) != 1 or summary.get("passedTests", 0) == 0 or (not partial and summary.get("failedTests") != 0):
        raise ValueError("Expected a successful single-device XCTest result")
    device = configurations[0]["device"]
    identifier = f"{test_identifier}()"
    selector_result = None
    if partial:
        details = json.loads(run("xcrun", "xcresulttool", "get", "test-results", "test-details", "--path",
                                 str(result), "--test-id", identifier))
        case = details["testIdentifier"].removeprefix("DUNEUITests/").removesuffix("()")
        device_ids = [entry["deviceId"] for entry in details.get("devices", [])]
        if case != test_identifier or details.get("testResult") != "Passed" or device_ids != [device["deviceId"]]:
            raise ValueError(f"xcresult does not confirm a passing {test_identifier} on the recorded device")
        selector_result = {"testIdentifier": details["testIdentifier"], "testResult": details["testResult"]}
    run("xcrun", "xcresulttool", "export", "attachments", "--path", str(result),
        "--output-path", str(folder), "--test-id", identifier)
    captures = defaultdict(dict)
    for test in read_json(folder / "manifest.json"):
        identifier = test["testIdentifier"].removeprefix("DUNEUITests/").removesuffix("()")
        if identifier != test_identifier:
            continue
        for attachment in test["attachments"]:
            if attachment.get("isAssociatedWithFailure"):
                continue
            name = EXPORTED_SUFFIX.sub("", attachment["suggestedHumanReadableName"])
            name = HIERARCHY_EXPORT_SUFFIX.sub("", name)
            if match := re.fullmatch(r"screen-0-\d+x\d+-" + ACTION, name):
                kind = "png"
            elif match := re.fullmatch(r"hierarchy-" + ACTION + r"-[\w./]+\.swift-\d+", name):
                kind = "txt"
            else:
                continue
            if match[1] == theme:
                add_capture(captures, (match[2], match[3]), kind, folder / attachment["exportedFileName"])
    return captures, device, selector_result


def read_duo_checkpoints(folder: Path, theme: str, udid: str, suffix: str) -> dict:
    runner = read_json(folder / "runner-result.json")
    if runner.get("returncode") != 0 or runner.get("termination") or udid not in (folder / "run.log").read_text():
        raise ValueError(f"Expected successful host checkpoints from {udid}")
    captures = defaultdict(dict)
    for line in (folder / "checkpoints.jsonl").read_text().splitlines():
        checkpoint = json.loads(line)
        match = re.fullmatch(r"DUNE_VISUAL_AUDIT_READY " + ACTION + r" \[.+\] DEADLINE=[\d.]+",
                             checkpoint["action"])
        if not match or match[1] != theme:
            continue
        if not checkpoint["acknowledged"] or not checkpoint["valid_evidence"]:
            raise ValueError(f"Invalid Duo checkpoint {checkpoint['sequence']}")
        sequence = f"{checkpoint['sequence']:03}"
        key = (match[2], match[3])
        add_capture(captures, key, "png", folder / f"{sequence}{suffix}.png")
        add_capture(captures, key, "txt", folder / f"{sequence}-hierarchy.txt")
    return captures


def read_duo_displays(paths: list[Path], profile: str) -> dict:
    expected = "LCD" if profile == "duo" else "LCD-1"
    readbacks = {}
    for phase, path in zip(("before", "after"), paths, strict=True):
        readback = read_json(path)
        active = [display["name"] for display in readback["result"]["displays"] if display.get("active")]
        if active != [expected]:
            raise ValueError(f"Duo {phase} readback requires active {expected}; saw {active}")
        readbacks[f"display-{phase}.json"] = readback
    return readbacks


def add_capture(captures: dict, key: tuple[str, str], kind: str, path: Path) -> None:
    if kind in captures[key]:
        raise ValueError(f"Multiple {kind} captures for {' '.join(key)}")
    captures[key][kind] = path


def validate_captures(captures: dict, theme: str, screen_ids: tuple[str, ...] = tuple(SCREENS)) -> dict:
    expected = {(style, screen) for style in STYLES for screen in screen_ids}
    incomplete = sorted(key for key in expected if set(captures.get(key, {})) != {"png", "txt"})
    if incomplete or captures.keys() - expected:
        raise ValueError(f"Unexpected capture inventory. Missing pairs: {incomplete}. "
                         f"Unexpected: {sorted(captures.keys() - expected)}")
    records = {}
    for style in STYLES:
        for screen in screen_ids:
            _, marker = SCREENS[screen]
            pair = captures[style, screen]
            hierarchy = pair["txt"].read_text(encoding="utf-8")
            marker = marker or f"settings-theme-{theme}"
            marker_line = re.search(rf"identifier: '{re.escape(marker)}'[^\n]*", hierarchy)
            if not marker_line:
                raise ValueError(f"{style} {screen} accessibility hierarchy missing {marker}")
            if screen == "S01" and not re.search(r"\bSelected\b", marker_line[0]):
                raise ValueError(f"{style} Settings capture does not show {theme} selected")
            with Image.open(pair["png"]) as photo:
                if photo.format != "PNG" or not any(low != high for low, high in photo.convert("RGB").getextrema()):
                    raise ValueError(f"{style} {screen} screenshot is missing rendered content")
                width, height = photo.size
            window = MAIN_WINDOW.search(hierarchy)
            if not window:
                raise ValueError(f"{style} {screen} hierarchy has no main viewport")
            points_width, points_height = map(float, window.groups())
            if points_width == 0 or abs(points_height * width / points_width - height) > 2:
                raise ValueError(f"{style} {screen} screenshot and accessibility viewport disagree")
            records[f"{style}/{screen}"] = {
                "width": width, "height": height, "viewport_points": [points_width, points_height],
                **{f"{kind}_sha256": sha256(path.read_bytes()).hexdigest() for kind, path in pair.items()},
            }
    if len({(record["width"], record["height"]) for record in records.values()}) != 1:
        raise ValueError("Capture run contains more than one viewport")
    for screen in screen_ids:
        if records[f"light/{screen}"]["png_sha256"] == records[f"dark/{screen}"]["png_sha256"]:
            raise ValueError(f"{screen} has identical light and dark images")
    return records


def refresh_weekly_report(original: dict, refresh: dict, revision: str) -> dict:
    if original["device"]["deviceId"] != refresh["device"]["deviceId"]:
        raise ValueError("Weekly report refresh must use the existing gallery simulator")
    previous = original["captures"]
    replacements = refresh["captures"]
    for route, record in replacements.items():
        if previous[route]["viewport_points"] != record["viewport_points"]:
            raise ValueError(f"Weekly report viewport changed at {route}")
        previous[route] = record | {"source_revision": revision, "refresh_selector": WEEKLY_REPORT_SELECTOR}
    original.setdefault("refreshes", []).append({
        **{key: value for key, value in refresh.items() if key != "captures"},
        "selector": WEEKLY_REPORT_SELECTOR,
        "screens": sorted(replacements),
    })
    return original


def page(title: str, body: str) -> str:
    return f"""<!doctype html>
<html lang="ko">
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{escape(title)}</title>
<style>
  body {{ color-scheme: dark; margin: auto; max-width: 1250px; padding: 24px; background: #101819;
          color: #f5f2eb; font: 16px/1.5 system-ui, sans-serif; }}
  a {{ color: #b7e5db; }}
  .grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(min(210px, 100%), 1fr)); gap: 18px; }}
  figure {{ margin: 0; }}
  img {{ display: block; width: 100%; height: auto; }}
  figcaption {{ margin-top: .4em; }}
</style>
<main>
<h1>{escape(title)}</h1>
{body}
</main>
</html>
"""


def render_device(theme: str, profile: str, records: dict) -> str:
    sections = []
    for style, label in STYLES.items():
        figures = []
        for screen, (title, _) in SCREENS.items():
            route = f"{style}/{screen}"
            capture = records[route]
            figures.append(
                f'<figure><a href="{route}.png"><img loading="lazy" src="{route}.png" '
                f'alt="{escape(title)} · {label}" width="{capture["width"]}" height="{capture["height"]}"></a>'
                f'<figcaption>{escape(title)} · {screen} · <a href="{route}.txt">접근성 트리</a></figcaption></figure>'
            )
        sections.append(f'<section><h2>{label}</h2><div class="grid">\n' + "\n".join(figures) + "\n</div></section>")
    return page(f"{THEMES[theme]} · {DEVICES[profile]} 실제 화면",
                '<p><a href="../../index.html">작가 테마 모음</a> · <a href="capture.json">캡처 출처</a></p>\n'
                '<p>예시 건강 기록 · 기본 글씨 크기 · 장식을 고정한 화면</p>\n' + "\n".join(sections))


def render_index(destination: Path) -> str:
    links = []
    for theme, title in THEMES.items():
        variants = [
            f'<a href="{theme}/{profile}/index.html">{label}</a>'
            for profile, label in DEVICES.items() if (destination / theme / profile / "capture.json").is_file()
        ]
        if (destination / theme / "motion" / "index.html").is_file():
            variants.append(f'<a href="{theme}/motion/index.html">움직임</a>')
        if variants:
            links.append(f"<li>{escape(title)} · {' · '.join(variants)}</li>")
    return page("DUNE · 작가 테마 실제 화면",
                '<p><a href="../index.html">전체 실제 화면</a></p>\n'
                "<p>수집한 정지 화면과 움직임 검증입니다. 정지 화면은 네 탭과 여섯 상세의 라이트·다크, "
                "접근성 트리 및 설정의 테마 선택을 포함합니다.</p>\n"
                + "<ul>\n" + "\n".join(links) + "\n</ul>")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("theme", choices=THEMES)
    parser.add_argument("device", choices=DEVICES)
    parser.add_argument("receipt", type=Path)
    parser.add_argument("simulator_udid")
    parser.add_argument("source_revision")
    parser.add_argument("--xcresult", type=Path)
    parser.add_argument("--duo-captures", type=Path)
    parser.add_argument("--duo-suffix", default="", help="Display filename suffix for captures made with 'all'")
    parser.add_argument("--duo-separated-appearances", action="store_true",
                        help="Require separately timed DuoLight and DuoDark methods from one run")
    parser.add_argument("--display-readback", type=Path, nargs=2, metavar=("BEFORE", "AFTER"),
                        help="Official devicectl display JSON from before and after the Duo run")
    parser.add_argument("--source-dirty", action="store_true")
    parser.add_argument("--provenance", type=Path, help="Bind the preserved xcresult to the original runner log")
    parser.add_argument("--allow-passing-selector", action="store_true",
                        help="Allow a selector that passed in an otherwise failed iPhone/iPad batch")
    parser.add_argument("--refresh-weekly-report", action="store_true",
                        help="Replace only L08 pairs from the focused report selector")
    parser.add_argument("--output", type=Path, default=DESTINATION)
    args = parser.parse_args()
    if not re.fullmatch(r"[0-9a-fA-F]{7,64}", args.source_revision):
        parser.error("source_revision must be a Git revision hash")
    try:
        simulator_udid = str(UUID(args.simulator_udid)).upper()
    except ValueError:
        parser.error("simulator_udid must be a UUID")
    if not re.fullmatch(r"(?:-\d+x\d+)?", args.duo_suffix):
        parser.error("--duo-suffix must be a display size such as -2898x2010")
    is_duo = args.device.startswith("duo")
    if is_duo:
        if args.xcresult or not args.duo_captures or not args.display_readback:
            parser.error("Duo requires --duo-captures and --display-readback")
    elif not args.xcresult or args.duo_captures or args.display_readback or args.duo_suffix or args.duo_separated_appearances:
        parser.error("iPhone and iPad require --xcresult only")
    if args.allow_passing_selector and (is_duo or not args.provenance):
        parser.error("--allow-passing-selector requires --provenance and a regular or ipad run")
    if args.provenance and is_duo:
        parser.error("--provenance is only for an xcresult-based capture run")
    if args.refresh_weekly_report and (args.device != "regular" or args.theme not in WEEKLY_REPORT_REFRESH_THEMES
                                       or not args.provenance or args.allow_passing_selector):
        parser.error("Weekly report refresh requires a passing regular Forest/Ocean/Sakura result and --provenance")
    target = args.output / args.theme / args.device
    if args.refresh_weekly_report and not (target / "capture.json").is_file():
        parser.error(f"Weekly report refresh requires an existing gallery: {target}")
    if target.exists() and not args.refresh_weekly_report:
        parser.error(f"Capture directory already exists: {target}")

    try:
        test_identifier = WEEKLY_REPORT_SELECTOR if args.refresh_weekly_report else test_name(args.theme)
        if args.duo_separated_appearances:
            receipt = read_receipt(args.receipt, f"{test_identifier}DuoLight", False)
            read_receipt(args.receipt, f"{test_identifier}DuoDark", False)
        else:
            receipt = read_receipt(args.receipt, test_identifier, args.allow_passing_selector)
        with tempfile.TemporaryDirectory(prefix="dune-artist-captures-") as staging:
            folder = Path(staging) / "attachments"
            if is_duo:
                captures = read_duo_checkpoints(args.duo_captures, args.theme, simulator_udid, args.duo_suffix)
                device = {"deviceId": simulator_udid, "modelName": "iPhone Duo"}
                display_readbacks = read_duo_displays(args.display_readback, args.device)
            else:
                partial = receipt["status"] != "passed"
                captures, device, selector_result = read_attachments(args.xcresult, folder, args.theme, test_identifier, partial)
                if device.get("deviceId", "").upper() != simulator_udid:
                    raise ValueError("xcresult simulator is different from the requested device")
            screen_ids = ("L08",) if args.refresh_weekly_report else tuple(SCREENS)
            records = validate_captures(captures, args.theme, screen_ids)
            bundle = {
                "theme": args.theme, "device_profile": args.device, "device": device,
                "source_revision": args.source_revision, "source_worktree_dirty": args.source_dirty,
                "receipt": receipt, "captures": records,
            }
            if is_duo:
                bundle["capture_run"] = str(args.duo_captures.resolve())
                bundle["display_readbacks"] = list(display_readbacks)
            else:
                bundle["xcresult"] = str(args.xcresult.resolve())
                if args.provenance:
                    bundle["provenance"] = verify_provenance(args.provenance, args.receipt, receipt,
                                                            args.xcresult, args.source_revision)
                if selector_result:
                    bundle["passing_selector_in_failed_batch"] = selector_result
            gallery = Path(staging) / "gallery"
            if args.refresh_weekly_report:
                shutil.copytree(target, gallery)
                bundle = refresh_weekly_report(read_json(gallery / "capture.json"), bundle, args.source_revision)
            for (style, screen), pair in captures.items():
                (gallery / style).mkdir(parents=True, exist_ok=True)
                for kind, path in pair.items():
                    shutil.copyfile(path, gallery / style / f"{screen}.{kind}")
            if is_duo:
                for name, readback in display_readbacks.items():
                    (gallery / name).write_text(json.dumps(readback, ensure_ascii=False, indent=2) + "\n",
                                                encoding="utf-8")
            (gallery / "capture.json").write_text(json.dumps(bundle, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
            (gallery / "index.html").write_text(render_device(args.theme, args.device, bundle["captures"]), encoding="utf-8")
            target.parent.mkdir(parents=True, exist_ok=True)
            with tempfile.TemporaryDirectory(prefix=".stage-", dir=target.parent) as destination_staging:
                pending = Path(destination_staging) / args.device
                shutil.copytree(gallery, pending)
                prior = Path(destination_staging) / "prior"
                if args.refresh_weekly_report:
                    target.rename(prior)
                try:
                    pending.rename(target)
                except OSError:
                    if prior.exists():
                        prior.rename(target)
                    raise
    except (KeyError, OSError, ValueError, subprocess.SubprocessError) as error:
        if isinstance(error, subprocess.CalledProcessError):
            parser.error(error.stderr.strip() or str(error))
        parser.error(str(error))
    (args.output / "index.html").write_text(render_index(args.output), encoding="utf-8")
    print(f"{THEMES[args.theme]} · {DEVICES[args.device]} · {len(records)} PNG/AX pairs → {target}")


if __name__ == "__main__":
    main()
