"""Audit SwiftUI screen declarations and write the route inventory.

Actual design-map images are exported from simulator screenshots by
collect-real-captures.py. This script never draws interface images.
"""

from pathlib import Path
import re
import runpy


HERE = Path(__file__).resolve().parent
REPO = next(p for p in HERE.parents if (p / "DUNE").is_dir())
DATA = runpy.run_path(str(HERE / "screen-catalog.py"))
GROUPS = DATA["GROUPS"]
INLINE = DATA["INLINE"]
PREFIXES = ["T", "A", "W", "H", "P", "L", "S"]


def sources():
    result = {}
    for folder in (REPO / "DUNE/App", REPO / "DUNE/Presentation"):
        for path in folder.rglob("*.swift"):
            body = path.read_text(encoding="utf-8", errors="ignore")
            for match in re.finditer(
                r"(?m)^[ \t]*(?:private[ \t]+)?struct[ \t]+([A-Za-z_]\w*)[ \t]*:[ \t]*View\b",
                body,
            ):
                result[match.group(1)] = (path.relative_to(REPO), body.count("\n", 0, match.start()) + 1)
    return result


def catalog(index):
    rows = []
    for (group, definitions), prefix in zip(GROUPS.items(), PREFIXES):
        for number, raw in enumerate(definitions, 1):
            view_type, title, parent, kind, anatomy = raw.split("|")
            if view_type not in index:
                raise ValueError(f"missing SwiftUI View: {view_type}")
            path, line = index[view_type]
            rows.append(dict(id=f"{prefix}{number:02d}", group=group, title=title,
                             parent=parent, kind=kind, anatomy=anatomy,
                             type=view_type, source=str(path), line=line))
    for number, (group, title, filename, parent, kind, anatomy) in enumerate(INLINE, 1):
        matches = list((REPO / "DUNE/Presentation").rglob(filename))
        if len(matches) != 1:
            raise ValueError(f"inline screen source not unique: {filename}")
        rows.append(dict(id=f"W{len(GROUPS['운동 · 계획 · 기록']) + number:02d}", group=group,
                         title=title, parent=parent, kind=kind, anatomy=anatomy,
                         type="inline presentation", source=str(matches[0].relative_to(REPO)), line=None))
    ids = [r["id"] for r in rows]
    if len(ids) != len(set(ids)):
        raise ValueError("duplicate screen ID")
    return rows


def audit_presentations(known):
    """Check named targets in every navigation and presentation closure."""
    found = set()
    for folder in (REPO / "DUNE/App", REPO / "DUNE/Presentation"):
        for path in folder.rglob("*.swift"):
            lines = path.read_text(encoding="utf-8", errors="ignore").splitlines()
            for i, line in enumerate(lines):
                if re.search(r"\.(?:sheet|fullScreenCover|popover|inspector|navigationDestination)\s*\(", line) \
                        or re.search(r"\bNavigationLink\s*\{", line):
                    block = " ".join(lines[i:i + 12])
                    found.update(re.findall(r"\b([A-Z][A-Za-z0-9_]*(?:View|Sheet))\s*\(", block))
    # Type-erasing wrappers do not introduce a screen of their own.
    # The health-query wrapper resolves to the existing app/HealthKit record detail screens.
    system = {"AnyView", "ContentUnavailableView", "ProgressView", "ScrollView", "HealthQueryRecordDetailView"}
    missing = found - known - system
    if missing:
        raise ValueError("unmapped presentation targets: " + ", ".join(sorted(missing)))


def device_rule(device, row):
    kind = row["kind"]
    kinds = set(kind.split("/"))
    name = row["type"]
    if name == "WorkoutInsightsWindowView":
        return "별도 읽기 전용 창" if device == "ipad" else "운동 분석 시트로 대체"
    if kind == "launch":
        return "앱 시작 · 준비 상태"
    if device == "regular":
        if "push" in kinds and "inspector" in kinds: return "상세 push · 선택 상태"
        if "push" in kinds and "sheet" in kinds: return "상세 push 또는 시트"
        return {"root": "하단 탭 · 한 열", "push": "상세 push · 한 열",
                "inspector": "좁은 폭에서는 시트", "cover": "전체 화면 흐름",
                "window": "시트 대체", "state": "현재 흐름 내부"}.get(kind, "화면 내 시트")
    if device == "ipad":
        if "push" in kinds and "inspector" in kinds: return "push 또는 선택 상세 inspector"
        if "push" in kinds and "sheet" in kinds: return "상세 push 또는 시트"
        if name == "WorkoutSessionView": return "넓은 폭: 기록 + 입력 병렬"
        if name in {"WeeklyWorkoutPlanView", "PostureComparisonView", "MuscleMapDetailView"}:
            return "적응형 두 pane"
        return {"root": "사이드바 · 넓은 콘텐츠", "push": "상세 콘텐츠", "inspector": "선택 상세 inspector",
                "cover": "전체 화면 흐름", "window": "별도 창", "state": "세션 내부"}.get(kind, "시트 · 보조 패널")
    if name == "WorkoutSessionView": return "닫힘 한 열 → 내부 병렬"
    if "push" in kinds and "inspector" in kinds: return "닫힘 push → 내부 선택 상세"
    if "push" in kinds and "sheet" in kinds: return "push 또는 시트 · 상태 유지"
    if name in {"WeeklyWorkoutPlanView", "PostureComparisonView", "MuscleMapDetailView"}:
        return "접힘 후 pane 재배치"
    return {"root": "외부 한 열 → 내부 확장", "push": "선택·스크롤 유지", "inspector": "닫힘 시트 → 내부 보조",
            "cover": "촬영·세션 상태 유지", "window": "시트 대체", "state": "초안·타이머 유지"}.get(kind, "닫힘/내부 시트")


def inventory(rows):
    lines = ["---", "tags: [ios, ipados, iphone-duo, design-system, screen-inventory]",
             "date: 2026-10-12", "category: plan", "status: draft", "---", "",
             "# 폰 계열 전체 화면 인벤토리", "",
             f"SwiftUI View와 인라인 프레젠테이션 **{len(rows)}개**를 화면 단위로 대조한다. "
             "W17·W18은 소스에 남아 있지만 현재 앱에서 호출하는 곳이 없어 캡처 대상 수에서 제외한다. "
             "차트·카드·버튼 같은 내부 컴포넌트는 별도 화면이 아니다.", ""]
    for group in GROUPS:
        group_rows = [r for r in rows if r["group"] == group]
        lines += [f"## {group} ({len(group_rows)})", "", "| ID | 화면 | 진입 | 표시 방식 | 일반 iPhone | iPad | Duo | 코드 |", "|---|---|---|---|---|---|---|---|"]
        for r in group_rows:
            line = f":{r['line']}" if r["line"] else ""
            route_title = r["title"] + (" (현재 진입 경로 없음)" if r["id"] in {"W17", "W18"} else "")
            lines.append(f"| {r['id']} | {route_title} | {r['parent']} | {r['kind']} | "
                         f"{device_rule('regular', r)} | {device_rule('ipad', r)} | {device_rule('duo', r)} | "
                         f"`{r['source']}{line}` |")
        lines.append("")
    (HERE / "screen-inventory.md").write_text("\n".join(lines), encoding="utf-8")


def main():
    """Keep the source-backed route inventory; actual images come from XCTest."""
    index = sources()
    rows = catalog(index)
    audit_presentations({r["type"] for r in rows})
    inventory(rows)
    print(f"Audited {len(rows)} source entries; {len(rows) - 2} have current app routes. Actual images use collect-real-captures.py.")


if __name__ == "__main__":
    main()
