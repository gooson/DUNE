"""Build a screen index from real XCTest screenshot and accessibility attachments.

Only screenshots exported from an xcresult are displayed. An uncaptured route is
left visibly uncaptured; this script never draws or substitutes a mock screen.
"""

from __future__ import annotations

import argparse
from collections import defaultdict
from html import escape
import json
from pathlib import Path
import re
import runpy
import shutil
import subprocess
import tempfile

from PIL import Image, ImageDraw, ImageFont, ImageOps


HERE = Path(__file__).resolve().parent
REPO = next(path for path in HERE.parents if (path / "DUNE").is_dir())
DEVICE_LABELS = {"regular": "일반 iPhone", "ipad": "iPad", "duo": "iPhone Duo · 외부 화면",
                 "duo-open": "iPhone Duo · 내부 화면"}
IPAD_ONLY = {"S07"}  # A separate workout insights window exists only on iPad.
UNROUTED = {"W17", "W18"}  # TemplateWorkoutView and its reorder sheet have no app call site.
BUILDER = runpy.run_path(str(HERE / "build-phone-design-maps.py"))
ROWS = BUILDER["catalog"](BUILDER["sources"]())
SCREEN_PATTERN = re.compile(r"identifier: '([^']*(?:screen|sheet)[^']*)'")
NAV_PATTERN = re.compile(r"NavigationBar,[^\n]*identifier: '([^']+)'", re.I)
CAPTURE_KEY_PATTERN = re.compile(r"_[0-9]+_([A-Fa-f0-9-]{36})")
ROOT_HINTS = {
    "dashboard-root-scroll": "T03",
    "activity-hero-readiness": "A01",
    "wellness-hero-score": "H01",
    "life-hero-progress": "L01",
    "settings-section-appearance": "S01",
}
ROOT_NAV_TITLES = {"Today": "T03", "Activity": "A01", "Wellness": "H01", "Life": "L01", "Settings": "S01"}
NESTED_WITHOUT_OWN_SCREEN_ID = {"W14", "W20", "L01", "S06"}
PREFIX_HINTS = {"metric-detail-screen-": "T06", "all-data-screen-": "T07"}
CONTENT_HINTS = {
    "exercise-session-detail-scroll": "W27",
    "cloud-sync-consent-view": "T02",
    "health-qa-send": "T17",
    "sleep-debt-info-sheet": "H12",
    "sleep-waso-info-sheet": "H13",
    "rpe-help-sheet": "W09",
    "picker-root-list": "W02",
    "metric-comparison-title": "H04",
    "habit-form-name": "L02",
    "habit-template-list": "L03",
    "habit-heatmap-detail": "L07",
    "life-weekly-report-scroll": "L08",
    "posture-comparison-photos-scroll": "P08",
}
OVERLAY_HINTS = {
    "posture-result-screen": "P04",
    "exercise-session-detail-scroll": "W27",
    "notification-message-detail-screen": "T12",
    "notification-destination-unavailable-screen": "T13",
    "activity-fatigue-info-sheet": "A14",
    "activity-muscle-detail-popover-sheet": "A13",
    "activity-fatigue-algorithm-sheet": "A15",
    "activity-volume-algorithm-sheet": "A16",
    "activity-personal-records-info-sheet": "A17",
    "activity-consistency-info-sheet": "A18",
    "activity-exercise-mix-info-sheet": "A19",
    "activity-recommendation-equipment-sheet": "A20",
    "rest-timer-skip": "W07",
    "workout-session-last-set-sheet": "W31",
    "healthkit-workout-title-editor-screen": "W33",
    "heart-rate-recovery-info-sheet": "H14",
}


def words(value: str) -> set[str]:
    value = re.sub(r"(View|Sheet|Popover)$", "", value)
    value = re.sub(r"([a-z])([A-Z])", r"\1 \2", value)
    return {part.lower() for part in re.split(r"[^A-Za-z0-9]+", value) if part}


def screen_hints(row: dict) -> set[str]:
    if row["id"] in NESTED_WITHOUT_OWN_SCREEN_ID:
        return set()
    body = (REPO / row["source"]).read_text(encoding="utf-8", errors="ignore")
    candidates = set(re.findall(r'\.accessibilityIdentifier\("([^"\\]*(?:screen|sheet)[^"\\]*)"\)', body))
    if not candidates:
        return set()
    if len(candidates) == 1:
        return candidates
    target = words(row["type"])
    ranked = sorted(
        ((len(target & words(candidate)) / max(1, len(target | words(candidate))), candidate)
         for candidate in candidates), reverse=True
    )
    if ranked[0][0] >= 0.25 and (len(ranked) == 1 or ranked[0][0] > ranked[1][0]):
        return {ranked[0][1]}
    return set()


def make_lookup() -> tuple[dict[str, str], dict[str, str]]:
    by_identifier = defaultdict(set)
    by_title = defaultdict(set)
    for row in ROWS:
        for identifier in screen_hints(row):
            by_identifier[identifier].add(row["id"])
        by_title[row["title"]].add(row["id"])
        if row["id"] in NESTED_WITHOUT_OWN_SCREEN_ID:
            continue
        body = (REPO / row["source"]).read_text(encoding="utf-8", errors="ignore")
        titles = set(re.findall(r'\.navigationTitle\("([^"\\]+)"\)', body))
        if len(titles) == 1:
            by_title[next(iter(titles))].add(row["id"])
    exact = {key: next(iter(value)) for key, value in by_identifier.items() if len(value) == 1}
    exact.update(ROOT_HINTS)
    titles = {key: next(iter(value)) for key, value in by_title.items() if len(value) == 1}
    return exact, titles


def classify(hierarchy: str, action: str, lookup: dict[str, str], titles: dict[str, str]) -> tuple[str | None, str]:
    for identifier, row_id in OVERLAY_HINTS.items():
        if f"identifier: '{identifier}'" in hierarchy:
            return row_id, identifier
    identifiers = SCREEN_PATTERN.findall(hierarchy)
    for identifier in reversed(identifiers):
        if identifier in lookup:
            return lookup[identifier], identifier
        for prefix, row_id in PREFIX_HINTS.items():
            if identifier.startswith(prefix):
                return row_id, identifier
    for identifier, row_id in CONTENT_HINTS.items():
        if f"identifier: '{identifier}'" in hierarchy:
            return row_id, identifier
    navigation = NAV_PATTERN.findall(hierarchy)
    for title in reversed(navigation):
        if title in titles:
            return titles[title], f"title:{title}"
        if title in ROOT_NAV_TITLES:
            return ROOT_NAV_TITLES[title], f"title:{title}"
    if navigation:
        return None, f"unmapped-title:{navigation[-1]}"
    for identifier, row_id in ROOT_HINTS.items():
        if identifier in hierarchy:
            return row_id, identifier
    return None, action


def action_name(suggested: str) -> str:
    result = re.sub(r"^screen-\d+-\d+x\d+-", "", suggested)
    return re.sub(r"_\d+_[A-Fa-f0-9-]+\.png$", "", result)


def has_visible_pixels(path: Path) -> bool:
    with Image.open(path) as photo:
        return photo.convert("RGB").getbbox() is not None


def pair_attachments(manifest: list[dict], raw: Path, lookup: dict[str, str], titles: dict[str, str], device: str) -> list[dict]:
    captures = []
    for test in manifest:
        by_event = defaultdict(list)
        for item_index, item in enumerate(test["attachments"]):
            match = CAPTURE_KEY_PATTERN.search(item["suggestedHumanReadableName"])
            key = match.group(1) if match else f"timestamp:{item.get('timestamp', -(item_index + 1))}"
            by_event[key].append(item)
        for items in by_event.values():
            hierarchy_item = next((item for item in items if item["exportedFileName"].endswith(".txt")), None)
            hierarchy = (raw / hierarchy_item["exportedFileName"]).read_text(errors="ignore") if hierarchy_item else ""
            for item in items:
                if not item["exportedFileName"].endswith(".png"):
                    continue
                action = action_name(item["suggestedHumanReadableName"])
                row_id, evidence = classify(hierarchy, action, lookup, titles)
                test_name = test["testIdentifier"]
                if not row_id and "LifeRegressionTests/testVisualAuditHabitHeatmap()" in test_name and evidence == "unmapped-title:Activity Detail":
                    row_id, evidence = "L07", "test-and-title:Activity Detail"
                if not row_id and "LifeRegressionTests/testVisualAuditWeeklyReport()" in test_name and evidence == "unmapped-title:Weekly Report":
                    row_id, evidence = "L08", "test-and-title:Weekly Report"
                if not row_id and "PostureVisualAuditTests/" in test_name and evidence == "unmapped-title:Assessment Detail":
                    row_id, evidence = "P06", "test-and-title:Assessment Detail"
                if not row_id and "PostureVisualAuditTests/testPostureComparison()" in test_name and evidence == "unmapped-title:Comparison":
                    row_id, evidence = "P08", "test-and-title:Comparison"
                if "PostureVisualAuditTests/testWellnessRecentPostureRecordOpensDetail()" in test_name and (
                    action.startswith("tap wellness-posture-record-")
                    or action.startswith("Wellness recent posture record detail")
                ):
                    row_id, evidence = "H07", "test-and-action:Wellness recent posture record"
                if "WellnessRegressionTests/testCompareMetricsSharesPeriodAndDismisses()" in test_name and (
                    action.startswith("Metric comparison") or action.startswith("Comparison inline")
                    or action.startswith("tap wellness-compare-metrics")
                ):
                    row_id, evidence = "H04", "test-and-action:Metric comparison"
                if "testWorkoutDraftAndRestTimerAtMaximumAccessibilityTextSize()" in test_name and action.startswith("Rest timer initial"):
                    row_id, evidence = "W07", "test-and-action:Rest timer initial"
                if "testVisualAuditRestTimerFromQuickStart()" in test_name and action.startswith("Rest timer after first completed set"):
                    row_id, evidence = "W07", "test-and-action:Rest timer after first completed set"
                if "testVisualAuditSetRPEAndHelp()" in test_name and action.startswith("RPE active picker"):
                    row_id, evidence = "W08", "test-and-action:RPE active picker"
                if ("testFullPickerSupportsFilterSelectorsAndSelectionFromTemplateForm()" in test_name
                    and action.startswith("Template exercise picker")):
                    row_id, evidence = "W14", "test-and-action:Template exercise picker"
                if ("testCompoundWorkoutSetupStartsWorkoutAndFinishesFlow()" in test_name
                    and action.startswith("Compound exercise picker")):
                    row_id, evidence = "W20", "test-and-action:Compound exercise picker"
                if ("testVisualAuditTemplateWorkoutFirstSession()" in test_name
                    and action.startswith("Template workout first session")):
                    row_id, evidence = "W16", "test-and-action:Template workout first session"
                if ("testVisualAuditWorkoutInsights()" in test_name
                    and action.startswith("Workout Insights presentation")):
                    row_id = "S07" if device == "ipad" else "W32"
                    evidence = "test-and-action:Workout Insights presentation"
                if ("testVisualAuditWorkoutInsightsSheetFallback()" in test_name
                    and action.startswith("Workout Insights iPad sheet fallback")):
                    row_id, evidence = "W32", "test-and-action:Workout Insights iPad sheet fallback"
                if ("DesignMapNotificationDetailTests/testNotificationPersonalRecordsPush()" in test_name
                    and action.startswith("Personal Records Route Fixture")):
                    row_id, evidence = "T16", "test-and-action:Personal Records notification push"
                if (not row_id and "SettingsSmokeTests/testWhatsNew" in test_name
                    and action.startswith("before teardown")
                    and evidence in {"unmapped-title:근육 지도", "unmapped-title:알림", "unmapped-title:수면 부족"}):
                    row_id, evidence = "S06", f"test-and-{evidence}"
                captures.append({
                    "row_id": row_id,
                    "evidence": evidence,
                    "test": test["testIdentifier"],
                    "action": action,
                    "timestamp": item.get("timestamp", 0),
                    "image": item["exportedFileName"],
                    "screen": item["suggestedHumanReadableName"],
                })
    return captures


def priority(capture: dict, row_id: str) -> tuple[int, int, int, float]:
    action = capture["action"]
    test = capture["test"]
    maximum_text_tests = (
        "testWorkoutDraftAndRestTimerAtMaximumAccessibilityTextSize()",
        "testTemplateListSupportsCreateEditAndTemplateStart()",
        "testCardioFlowReachesSummary()",
    )
    text_size_priority = 1 if any(name in test for name in maximum_text_tests) else 0
    if row_id in {"T03", "A01", "H01", "L01", "S01"}:
        if row_id == "L01" and "DuoLifeStarterTemplateTests/" in capture["test"]:
            return (text_size_priority, 2, 0, -capture["timestamp"])
        return (text_size_priority, 0 if action.startswith("root after setup") else 1, 0, -capture["timestamp"])
    return (
        text_size_priority,
        0 if action.startswith("tap ") else 1 if "viewport" in action.lower() else 2,
        1 if "before teardown" in action else 0,
        -capture["timestamp"],
    )


def applicable(row: dict, device: str) -> bool:
    return row["id"] not in UNROUTED and (row["id"] not in IPAD_ONLY or device == "ipad")


def applicable_count(rows: list[dict], device: str) -> int:
    return sum(applicable(row, device) for row in rows)


def render_gallery(rows: list[dict], chosen: dict[str, dict], device: str) -> str:
    count = len(chosen)
    label = DEVICE_LABELS[device]
    parts = [
        '<!doctype html><html lang="ko"><meta charset="utf-8">',
        '<meta name="viewport" content="width=device-width,initial-scale=1">',
        f'<title>DUNE · {escape(label)} 실제 화면 캡처</title>',
        '<style>body{margin:0;background:#101819;color:#f5f2eb;font-family:-apple-system,BlinkMacSystemFont,sans-serif}',
        'header{position:sticky;top:0;z-index:1;background:#101819ee;padding:22px 30px;border-bottom:1px solid #354244}',
        'h1{font-size:24px;margin:0 0 8px}p{color:#bbc8c6;margin:0}main{padding:22px 30px}',
        'h2{color:#d8af85;margin:34px 0 18px;font-size:19px}.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(230px,1fr));gap:18px}',
        '.card{background:#1a292b;border:1px solid #364447;border-radius:18px;overflow:hidden}.card img{display:block;width:100%;height:410px;object-fit:contain;image-orientation:from-image;background:#070c0d}',
        '.meta{padding:12px 14px}.title{font-weight:700}.id{color:#b5a48f;font-size:12px;margin-right:8px}.note{color:#9db0ad;font-size:12px;margin-top:6px;overflow-wrap:anywhere}',
        '.missing{height:410px;display:grid;place-items:center;background:#182021;color:#91a09d}',
        '</style>',
        f'<header><h1>DUNE · {escape(label)} 실제 화면</h1><p>{count} / {applicable_count(rows, device)} 화면 캡처 확인 · 이미지가 없는 화면은 미캡처로 표시</p></header><main>',
    ]
    groups = defaultdict(list)
    for row in rows:
        groups[row["group"]].append(row)
    for group, entries in groups.items():
        parts.append(f'<h2>{escape(group)} · {sum(row["id"] in chosen for row in entries)} / {applicable_count(entries, device)}</h2><div class="grid">')
        for row in entries:
            item = chosen.get(row["id"])
            parts.append('<article class="card">')
            if item:
                parts.append(f'<a href="images/{escape(item["file"])}"><img loading="lazy" src="images/{escape(item["file"])}" alt="{escape(row["title"])} 실제 화면"></a>')
            elif applicable(row, device):
                parts.append('<div class="missing">미캡처</div>')
            else:
                note = "현재 앱 진입 경로 없음" if row["id"] in UNROUTED else "이 기기에서는 별도 화면 없음"
                parts.append(f'<div class="missing">{note}</div>')
            parts.append(f'<div class="meta"><span class="id">{row["id"]}</span><span class="title">{escape(row["title"])}</span>')
            if item:
                if item.get("current_verification") == "pending":
                    parts.append(f'<div class="note" style="color:#e8bf94">{escape(item["current_verification_note"])}</div>')
                parts.append(f'<div class="note">{escape(item["test"])} · {escape(item["action"])}</div>')
                if item.get("video"):
                    parts.append(f'<div class="note"><a href="{escape(item["video"])}" style="color:#e8bf94">원본 앱 시작 영상</a></div>')
            parts.append('</div></article>')
        parts.append('</div>')
    return "\n".join(parts + ["</main></html>"])


def render_boards(rows: list[dict], chosen: dict[str, dict], images: Path, destination: Path, device: str) -> None:
    groups = defaultdict(list)
    for row in rows:
        groups[row["group"]].append(row)
    boards = destination / "boards"
    boards.mkdir(exist_ok=True)
    font_path = Path("/System/Library/Fonts/AppleSDGothicNeo.ttc")
    if not font_path.exists():
        font_path = Path("/System/Library/Fonts/Supplemental/AppleGothic.ttf")
    title_font = ImageFont.truetype(str(font_path), 31)
    caption_font = ImageFont.truetype(str(font_path), 22)
    small_font = ImageFont.truetype(str(font_path), 17)
    columns = 4 if device == "regular" else 2
    tile_w, tile_h = (285, 620) if device == "regular" else (550, 465)
    margin, gap, header_h = 34, 20, 100
    for index, (group, entries) in enumerate(groups.items(), 1):
        row_count = (len(entries) + columns - 1) // columns
        board = Image.new("RGB", (margin * 2 + columns * tile_w + (columns - 1) * gap,
                                  header_h + margin + row_count * (tile_h + gap)), "#101819")
        draw = ImageDraw.Draw(board)
        draw.text((margin, 25), f"{device.upper()} / {group}", font=title_font, fill="#F8F4EC")
        draw.text((margin, 66), f"실제 앱 캡처 {sum(row['id'] in chosen for row in entries)} / {applicable_count(entries, device)}", font=small_font, fill="#B7C9C4")
        for position, row in enumerate(entries):
            column, line = position % columns, position // columns
            x = margin + column * (tile_w + gap)
            y = header_h + line * (tile_h + gap)
            draw.rounded_rectangle((x, y, x + tile_w, y + tile_h), radius=16, fill="#1B2A2C", outline="#405153", width=2)
            item = chosen.get(row["id"])
            photo_box = (x + 12, y + 12, x + tile_w - 12, y + tile_h - 58)
            if item:
                with Image.open(images / item["file"]) as photo:
                    thumbnail = ImageOps.contain(ImageOps.exif_transpose(photo).convert("RGB"),
                        (photo_box[2] - photo_box[0], photo_box[3] - photo_box[1]))
                    px = photo_box[0] + (photo_box[2] - photo_box[0] - thumbnail.width) // 2
                    py = photo_box[1] + (photo_box[3] - photo_box[1] - thumbnail.height) // 2
                    board.paste(thumbnail, (px, py))
            elif applicable(row, device):
                draw.text((x + 24, y + tile_h // 2), "미캡처", font=caption_font, fill="#8DA09C")
            else:
                draw.text((x + 24, y + tile_h // 2), "별도 화면 없음", font=caption_font, fill="#8DA09C")
            draw.text((x + 14, y + tile_h - 42), f"{row['id']}  {row['title']}", font=caption_font, fill="#F7F3EB")
        board.save(boards / f"{index:02d}-{group.split(' · ')[0]}.png", optimize=True)


def render_watch_gallery() -> None:
    """Show actual Watch states and keep the older design board distinct."""
    watch = HERE.parent / "watch-workout"
    evidence = json.loads((watch / "simulator-evidence" / "manifest.json").read_text())
    state_rows = re.findall(
        r"^\| ([HDGPXSCF]\d\d) \| ([^|]+) \|",
        (REPO / "docs/plans/2026-10-12-watch-workout-redesign.md").read_text(),
        re.MULTILINE,
    )
    index_path = HERE / "actual" / "watch" / "capture-index.json"
    captured = json.loads(index_path.read_text()).get("captured", {}) if index_path.exists() else {}
    group_names = {"H": "홈", "D": "운동 탐색", "G": "자세", "P": "시작 전",
                   "X": "운동 제어", "S": "근력·세트·휴식", "C": "유산소", "F": "완료·저장"}
    sections = []
    for prefix, group_name in group_names.items():
        cards_for_group = []
        for code, title in state_rows:
            if not code.startswith(prefix):
                continue
            item = captured.get(code)
            if item and (HERE / "actual" / "watch" / "images" / item["file"]).exists():
                photo = f'images/{escape(item["file"])}'
                visual = f'<a class="photo" href="{photo}"><img src="{photo}" alt="{code} {escape(title)} 실제 앱 캡처"></a>'
                proof = f'<small>{escape(item["test"])} · 실제 캡처</small>'
                issues = {
                    "H01": "루틴 이름이 카드에서 잘림",
                    "P02": "시작 버튼이 운동 재정렬 조작을 가림",
                    "S16": "심박값이 없을 때 휴식 정보 배치가 빽빽함",
                    "F02": "완료 버튼이 하단 지표를 가림",
                    "F05": "저장 중 버튼이 지표를 가림",
                    "F06": "재시도 버튼이 오류 내용과 지표를 가림",
                    "F07": "완료 버튼이 하단 지표를 가림",
                }
                if code in issues:
                    proof += f'<small class="issue">확인된 문제: {escape(issues[code])}</small>'
                if item.get("provenance"):
                    proof += f'<small>{escape(item["provenance"])}</small>'
            else:
                visual = '<div class="missing">미캡처</div>'
                missing_reasons = {
                    "S08": "완료한 세트에서 이전 세트 버튼이 나타나지 않음",
                    "S11": "휴식 AOD: 시뮬레이터 저휘도 화면 캡처 불가",
                    "S16": "휴식 UI 수정 후 재캡처 중 시뮬레이터 연결 실패",
                    "C12": "유산소 AOD: 시뮬레이터 저휘도 화면 캡처 불가",
                    "C03": "심박 존 변경 후 Watch 시뮬레이터 부팅 실패로 재캡처하지 못함",
                    "C13": "1km 통과 알림 추가 후 Watch 시뮬레이터 부팅 실패로 캡처하지 못함",
                }
                proof = f'<small>{escape(missing_reasons.get(code, "실제 화면 이미지 없음"))}</small>'
            cards_for_group.append(f'<article class="state">{visual}<div class="caption"><strong>{code} {escape(title)}</strong>{proof}</div></article>')
        sections.append(f'<section><h2>{group_name}</h2><div class="grid">' + ''.join(cards_for_group) + '</div></section>')
    labels = {
        "watch-rest-timer-final.png": ("휴식 타이머", "한국어 · 접근성 XXXL"),
        "watch-controls-final.png": ("운동 조작", "한국어 · 접근성 XXXL"),
        "watch-save-error-final.png": ("저장 실패와 재시도", "접근성 XXXL · 재시도 버튼이 내용을 가림"),
    }
    legacy_cards = []
    for item in evidence:
        attachment = item["attachments"][0]
        filename = attachment["exportedFileName"]
        title, condition = labels.get(filename, (filename, "시뮬레이터 캡처"))
        source = f"../../../watch-workout/simulator-evidence/{filename}"
        legacy_cards.append(
            f'<a class="capture" href="{source}"><img src="{source}" alt="{escape(title)} 실제 Watch 캡처">'
            f'<span><strong>{escape(title)}</strong><small>{escape(condition)}</small></span></a>'
        )
    html = ('<!doctype html><html lang="ko"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'
            '<title>DUNE · Watch 운동 디자인맵</title><style>'
            'body{margin:0;background:#101819;color:#f5f2eb;font-family:-apple-system,BlinkMacSystemFont,sans-serif}'
            'main{max-width:1280px;margin:auto;padding:28px}a{color:#e8bf94}h1{font-size:28px;margin:18px 0 8px}'
            'h2{font-size:22px;margin:36px 0 12px}p{color:#bac8c4;line-height:1.5}'
            '.board{display:block;border:1px solid #405153;border-radius:18px;overflow:hidden;background:#0b1112}'
            '.board img{display:block;width:100%;height:auto}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(240px,1fr));gap:18px}'
            '.state{border:1px solid #405153;border-radius:16px;overflow:hidden;background:#1b292b}'
            '.photo{display:block;background:#0b1112}.photo img{display:block;width:100%;height:350px;object-fit:contain}'
            '.missing{height:350px;display:grid;place-items:center;color:#91a09d;background:#0b1112}'
            '.caption{padding:14px;display:grid;gap:8px}.caption small{color:#aebfba;overflow-wrap:anywhere}'
            '.capture{color:inherit;text-decoration:none;border:1px solid #405153;border-radius:16px;overflow:hidden;background:#1b292b}'
            '.capture img{display:block;width:100%;height:360px;object-fit:contain;background:#0b1112}'
            '.capture span{display:flex;justify-content:space-between;gap:12px;padding:14px;align-items:baseline}'
            '.capture small{color:#c9ad8e}.issue{color:#ffaaa8!important}details{margin-top:32px}summary{cursor:pointer;font-size:22px;font-weight:700}'
            'footer{margin:30px 0;color:#bac8c4}</style>'
            '<main><a href="../index.html">← 전체 디자인맵</a><h1>Apple Watch · 실제 화면 맵</h1>'
            f'<p>{len(captured)} / {len(state_rows)}개 상태에 기본 글자 크기의 실제 앱 캡처가 있습니다. '
            '빈 칸은 확인된 이미지가 없는 상태입니다. 상태표에는 현행 흐름에서 열리지 않는 분기와 시스템·AOD 화면도 포함됩니다.</p>'
            '<p><a href="capture-index.json">화면별 테스트 출처</a> · '
            '<a href="../../../../plans/2026-10-12-watch-workout-redesign.md">전체 상태표</a></p>'
            + ''.join(sections) +
            '<details><summary>기존 Watch 운동 최종 시안 · 12개 대표 상태</summary>'
            '<p><a href="../../../watch-workout/watch-workout-design.svg">편집 가능한 SVG 원본</a> · '
            '<a href="../../../watch-workout/README.md">Watch 디자인 설명</a></p>'
            '<a class="board" href="../../../watch-workout/watch-workout-design.png">'
            '<img src="../../../watch-workout/watch-workout-design.png" alt="Watch 운동 최종 디자인 보드의 12개 대표 상태"></a></details>'
            '<h2>기존 검증 캡처 · 3장</h2>'
            '<p>Apple Watch SE 3 (40mm)에서 저장한 기존 검증 화면입니다. XXXL 표기는 의도적으로 크게 설정한 접근성 글자 크기입니다. '
            '저장 실패 화면에서 재시도 버튼이 내용을 가리는 현행 UX 결함을 확인했습니다. '
            '<a href="../../../watch-workout/simulator-evidence/manifest.json">테스트 출처 보기</a></p>'
            '<div class="grid">' + ''.join(legacy_cards) + '</div>'
            '</main></html>')
    destination = HERE / "actual" / "watch"
    destination.mkdir(parents=True, exist_ok=True)
    (destination / "index.html").write_text(html)


def render_portal() -> None:
    entries = []
    pending_notes = set()
    for device, label in DEVICE_LABELS.items():
        folder = HERE / "actual" / device
        index = folder / "capture-index.json"
        captured = json.loads(index.read_text())["captured"] if index.exists() else {}
        count = len(captured)
        pending_notes.update(item["current_verification_note"] for item in captured.values()
                             if item.get("current_verification") == "pending")
        preview_image = folder / "images" / "T03.png"
        preview = (f'<img src="{device}/images/T03.png" alt="{label} 오늘 화면 실제 캡처">'
                   if preview_image.exists() else '<div class="pending">캡처 대기</div>')
        entries.append(f'<a class="card" href="{device}/index.html">{preview}<div class="meta">'
                       f'<strong>{label}</strong><span>{count} / {applicable_count(ROWS, device)} 화면</span></div></a>')
    watch_index = HERE / "actual" / "watch" / "capture-index.json"
    watch_count = len(json.loads(watch_index.read_text()).get("captured", {})) if watch_index.exists() else 0
    watch_preview = "watch/images/S01.png" if (HERE / "actual" / "watch" / "images" / "S01.png").exists() else "../../watch-workout/watch-workout-design.png"
    watch_state_count = len(re.findall(
        r"^\| ([HDGPXSCF]\d\d) \|",
        (REPO / "docs/plans/2026-10-12-watch-workout-redesign.md").read_text(),
        re.MULTILINE,
    ))
    entries.append(f'<a class="card" href="watch/index.html">'
                   f'<img src="{watch_preview}" alt="Watch 운동 실제 화면 맵 미리보기">'
                   f'<div class="meta"><strong>Apple Watch · 운동</strong><span>{watch_count} / {watch_state_count} 상태 실제 캡처</span></div></a>')
    live_index = HERE / "actual" / "live-activity" / "capture-index.json"
    live_data = json.loads(live_index.read_text()) if live_index.exists() else {"captured": {}, "states": {}}
    live_count = len(live_data["captured"])
    live_total = len(live_data["states"])
    live_preview_path = HERE / "actual" / "live-activity" / "images" / "iphone_notification_running.png"
    live_preview = ('<img src="live-activity/images/iphone_notification_running.png" alt="WLA01 운동 진행 실제 캡처">'
                    if live_preview_path.exists() else '<div class="pending">캡처 대기</div>')
    entries.append(f'<a class="card" href="live-activity/index.html">{live_preview}<div class="meta">'
                   f'<strong>WLA01 · Watch 운동 Live Activity</strong><span>{live_count} / {live_total} 상태 실제 캡처</span></div></a>')
    pending_html = ''.join(f'<p style="color:#e8bf94">{escape(note)}</p>' for note in sorted(pending_notes))
    html = ('<!doctype html><html lang="ko"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'
            '<title>DUNE · 전체 디자인맵</title><style>'
            'body{margin:0;background:#101819;color:#f5f2eb;font-family:-apple-system,BlinkMacSystemFont,sans-serif}'
            'main{max-width:1250px;margin:auto;padding:32px}h1{font-size:28px;margin:0 0 8px}p{color:#bac8c4;margin:0 0 28px}'
            '.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:20px}'
            '.card{color:inherit;text-decoration:none;border:1px solid #405153;border-radius:18px;overflow:hidden;background:#1b292b}'
            '.card img,.pending{display:block;width:100%;height:400px;object-fit:contain;image-orientation:from-image;background:#0b1112}'
            '.pending{display:grid;place-items:center;color:#91a09d}.meta{display:flex;justify-content:space-between;gap:12px;padding:16px}'
            '.meta span{color:#c9ad8e}</style><main><h1>DUNE · 전체 디자인맵</h1>'
            '<p>iPhone·iPad·Duo의 현재 앱 실제 화면과 Watch 운동 재작업 결과를 한곳에서 확인합니다.</p>'
            '<p><a href="../../full-redesign-map/review/desert-horizon-final-2026-10-24/index.html" style="color:#e8bf94">DESERT HORIZON 2026-10-24 실제 화면 전후 비교 · iPhone 밝음·어두움·큰 글씨 →</a></p>'
            '<p><a href="compare.html" style="color:#e8bf94">폰·패드·Duo 같은 화면 비교하기 →</a></p>'
            '<p><a href="../../full-redesign-map/review/four-tab-hero-rings-2026-10-19/index.html" style="color:#e8bf94">4탭 히어로 링 최신 iPhone 실제 캡처와 출처 →</a></p>'
            '<p><a href="../../full-redesign-map/review/four-tab-hero-rings-accessibility-2026-10-19/index.html" style="color:#e8bf94">4탭 최대 접근성 글씨 실제 캡처와 출처 →</a></p>'
            '<p><a href="../../full-redesign-map/review/six-theme-hero-rings-2026-10-19/index.html" style="color:#e8bf94">나머지 6개 테마 4탭 최신 iPhone 실제 캡처 →</a></p>'
            '<p><a href="../../full-redesign-map/review/seven-theme-ipad-hero-rings-2026-10-19/index.html" style="color:#e8bf94">나머지 7개 테마 4탭 최신 iPad 실제 캡처 →</a></p>'
            '<p><a href="../../full-redesign-map/review/hero-dark-surface-contrast-2026-10-19/index.html" style="color:#e8bf94">SAKURA·CONTOUR·WATER LILIES Today 카드 대비 수정 후 실제 캡처 →</a></p>'
            '<p><a href="../../full-redesign-map/review/duo-four-tab-hero-rings-2026-10-22/index.html" style="color:#e8bf94">전용 Duo 접힘·펼침 4탭 링 최신 실제 화면 16장 →</a></p>'
            '<p><a href="../../full-redesign-map/review/life-hero-narrative-2026-10-22/index.html" style="color:#e8bf94">Life 히어로 정보 중복 해소 후 5개 기기 조건·큰 글씨 실제 화면 15장 →</a></p>'
            + pending_html + '<div class="grid">' + ''.join(entries) + '</div></main></html>')
    (HERE / "actual" / "index.html").write_text(html)
    render_watch_gallery()
    render_comparison()


def render_comparison() -> None:
    options = []
    for group in dict.fromkeys(row["group"] for row in ROWS):
        options.append(f'<optgroup label="{escape(group)}">')
        for row in ROWS:
            if row["group"] == group:
                options.append(f'<option value="{row["id"]}">{row["id"]} · {escape(row["title"])}</option>')
        options.append('</optgroup>')
    evidence = {}
    for device in DEVICE_LABELS:
        index_path = HERE / "actual" / device / "capture-index.json"
        evidence[device] = json.loads(index_path.read_text())["captured"] if index_path.exists() else {}
    data = json.dumps(evidence, ensure_ascii=False).replace("</", "<\\/")
    cards = ''.join(f'<article><h2>{escape(label)}</h2><div id="slot-{device}"></div></article>'
                    for device, label in DEVICE_LABELS.items())
    html = ('<!doctype html><html lang="ko"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'
            '<title>DUNE · 기기별 실제 화면 비교</title><style>'
            'body{margin:0;background:#101819;color:#f5f2eb;font-family:-apple-system,BlinkMacSystemFont,sans-serif}'
            'main{max-width:1500px;margin:auto;padding:28px}a{color:#e8bf94}h1{margin:12px 0 8px;font-size:28px}'
            'p{color:#bac8c4}select{width:100%;max-width:550px;padding:12px;border-radius:12px;background:#213133;color:#fff;border:1px solid #647572;font-size:16px}'
            '.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));gap:18px;margin-top:24px}'
            'article{border:1px solid #405153;border-radius:18px;overflow:hidden;background:#1b292b}'
            'h2{font-size:17px;margin:0;padding:14px 16px;border-bottom:1px solid #405153}'
            '.photo{display:block;background:#070c0d;padding:12px}.photo img{display:block;width:100%;height:420px;object-fit:contain;image-orientation:from-image}'
            '.missing{height:444px;display:grid;place-items:center;color:#91a09d}.proof{padding:12px 16px;color:#aebfba;font-size:12px;overflow-wrap:anywhere}'
            '</style><main><a href="index.html">← 기기별 전체 맵</a><h1>같은 화면을 기기별로 비교</h1>'
            '<p>선택한 화면의 실제 시뮬레이터 캡처만 표시합니다. 빈 자리는 아직 열어 캡처하지 못한 상태입니다.</p>'
            '<select id="route" aria-label="비교할 화면">' + ''.join(options) + '</select><div class="grid">' + cards + '</div></main>'
            '<script>const evidence=' + data + ';const labels=' + json.dumps(DEVICE_LABELS, ensure_ascii=False) + ';'
            'const picker=document.getElementById("route");picker.value="T03";'
            'function show(){const id=picker.value;for(const device of Object.keys(labels)){const slot=document.getElementById("slot-"+device);'
            'const item=evidence[device][id];if(item){const src=device+"/images/"+item.file;slot.innerHTML="";'
            'const link=document.createElement("a");link.className="photo";link.href=src;const img=document.createElement("img");'
            'img.src=src;img.alt=id+" 실제 화면";link.append(img);slot.append(link);'
            'const proof=document.createElement("div");proof.className="proof";proof.textContent=item.test+" · "+item.action;slot.append(proof);'
            'if(item.current_verification==="pending"){const note=document.createElement("div");note.className="proof";'
            'note.style.color="#e8bf94";note.textContent=item.current_verification_note;slot.append(note);}'
            '}else{slot.innerHTML="";const empty=document.createElement("div");empty.className="missing";'
            'empty.textContent=["W17","W18"].includes(id)?"현재 앱 진입 경로 없음":'
            'id==="S07"&&device!=="ipad"?"이 기기에서는 별도 화면 없음":"미캡처";slot.append(empty)}}}'
            'picker.addEventListener("change",show);show();</script></html>')
    (HERE / "actual" / "compare.html").write_text(html)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("device", choices=list(DEVICE_LABELS))
    parser.add_argument("xcresults", nargs="*", type=Path)
    parser.add_argument("--refresh-screen", help="Replace this screen using only the supplied xcresult")
    args = parser.parse_args()
    if args.refresh_screen and args.refresh_screen not in {row["id"] for row in ROWS}:
        parser.error(f"unknown screen ID: {args.refresh_screen}")
    if args.refresh_screen and not args.xcresults:
        parser.error("--refresh-screen requires an xcresult")
    destination = HERE / "actual" / args.device
    images = destination / "images"
    images.mkdir(parents=True, exist_ok=True)
    previous_index_path = destination / "capture-index.json"
    if not args.xcresults and not previous_index_path.exists():
        parser.error("provide an xcresult for a device without prior captures")
    previous_index = json.loads(previous_index_path.read_text()) if previous_index_path.exists() else {}
    with tempfile.TemporaryDirectory(prefix="dune-screen-captures-") as folder:
        previous_folder = Path(folder) / "previous"
        previous_folder.mkdir()
        previous_captures = []
        for row_id, item in previous_index.get("captured", {}).items():
            if row_id == args.refresh_screen:
                continue
            prior_image = images / item["file"]
            if prior_image.is_file() and has_visible_pixels(prior_image):
                snapshot = previous_folder / f"{row_id}.png"
                shutil.copyfile(prior_image, snapshot)
                previous_captures.append({**item, "row_id": row_id, "source_path": str(snapshot)})
        lookup, titles = make_lookup()
        captures = previous_captures[:]
        for index, result in enumerate(args.xcresults):
            raw = Path(folder) / f"result-{index}"
            subprocess.run(["xcrun", "xcresulttool", "export", "attachments", "--path", str(result),
                            "--output-path", str(raw)], check=True, stdout=subprocess.DEVNULL)
            manifest = json.loads((raw / "manifest.json").read_text())
            found = pair_attachments(manifest, raw, lookup, titles, args.device)
            for capture in found:
                capture["source_path"] = str(raw / capture["image"])
            captures.extend(capture for capture in found if has_visible_pixels(Path(capture["source_path"])))
        if args.refresh_screen and not any(capture["row_id"] == args.refresh_screen for capture in captures):
            parser.error(f"xcresult has no valid capture for {args.refresh_screen}; existing image was retained")
        by_row = defaultdict(list)
        for capture in captures:
            if capture["row_id"]:
                by_row[capture["row_id"]].append(capture)
        for old_image in images.glob("*.png"):
            old_image.unlink()
        chosen = {}
        for row_id, options in by_row.items():
            best = min(options, key=lambda capture: priority(capture, row_id))
            file = f"{row_id}.png"
            shutil.copyfile(best["source_path"], images / file)
            chosen[row_id] = {key: value for key, value in best.items() if key != "source_path"} | {"file": file}
    revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=REPO, text=True).strip()
    source_dirty = bool(subprocess.check_output(
        ["git", "status", "--porcelain", "--untracked-files=normal", "--", "DUNE", "DUNEWatch", "Shared",
         "DUNEUITests", "DUNEWatchUITests"], cwd=REPO, text=True,
    ).strip())
    (destination / "capture-index.json").write_text(json.dumps({"device": args.device, "source_revision": revision,
        "source_worktree_dirty": source_dirty,
        "xcresults": list(dict.fromkeys([path for path in previous_index.get("xcresults", []) if Path(path).exists()]
                                            + [str(path) for path in args.xcresults])),
        "processed_capture_candidates": len(captures), "captured": chosen,
        "unmatched": [{key: value for key, value in capture.items() if key not in {"image", "source_path"}} for capture in captures if not capture["row_id"]]},
        ensure_ascii=False, indent=2) + "\n")
    (destination / "index.html").write_text(render_gallery(ROWS, chosen, args.device))
    render_boards(ROWS, chosen, images, destination, args.device)
    render_portal()
    print(f"{args.device}: {len(chosen)}/{applicable_count(ROWS, args.device)} mapped screens from {len(captures)} actual screenshots")


if __name__ == "__main__":
    main()
