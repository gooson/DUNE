#!/usr/bin/env python3
"""Render the Desert Horizon review from indexed, existing capture files only."""

from __future__ import annotations

import json
from pathlib import Path


HERE = Path(__file__).resolve().parent
SCREENS = {"T03": "Today", "A01": "Activity", "H01": "Wellness", "L01": "Life"}
DEVICES = {"regular": "iPhone", "ipad": "iPad", "duo": "Duo 접힘", "duo-open": "Duo 펼침"}


def existing_file(relative: str) -> str | None:
    path = (HERE / relative).resolve()
    if path.is_relative_to(HERE) and path.is_file():
        return path.relative_to(HERE).as_posix()
    return None


def capture_data() -> dict:
    actual: dict[str, dict[str, dict[str, dict]]] = {}
    for device in DEVICES:
        index_path = HERE / device / "capture-index.json"
        if not index_path.is_file():
            continue
        index = json.loads(index_path.read_text(encoding="utf-8"))
        for item in index.get("captures", {}).values():
            screen = item.get("screen_id")
            appearance = item.get("appearance")
            if screen not in SCREENS or appearance not in {"light", "dark"}:
                continue
            relative = existing_file(f"{device}/{item.get('file', '')}")
            if not relative:
                continue
            actual.setdefault(device, {}).setdefault(screen, {})[appearance] = {
                "file": relative,
                "source": item.get("source_revision", "기록 없음"),
                "test": item.get("test_identifier", "기록 없음"),
                "device": item.get("device", {}).get("model_name", DEVICES[device]),
                "udid": item.get("device", {}).get("identifier", "기록 없음"),
            }

    ax_index = HERE / "accessibility-capture-index.json"
    if ax_index.is_file():
        for tab, item in json.loads(ax_index.read_text(encoding="utf-8")).items():
            screen = next((key for key, name in SCREENS.items() if name == tab), None)
            relative = existing_file(item.get("file", ""))
            if not screen or not relative:
                continue
            device = relative.split("/", 1)[0]
            if device not in DEVICES:
                continue
            actual.setdefault(device, {}).setdefault(screen, {})["ax"] = {
                "file": relative,
                "source": item.get("source_revision", "기록 없음"),
                "test": item.get("test", "기록 없음"),
                "device": item.get("deviceName", DEVICES[device]),
                "udid": item.get("deviceId", "기록 없음"),
            }

    before: dict[str, dict] = {}
    before_index = HERE / "before" / "capture-index.json"
    if before_index.is_file():
        for screen, item in json.loads(before_index.read_text(encoding="utf-8")).items():
            if screen not in SCREENS:
                continue
            relative = existing_file(f"before/{item.get('file', '')}")
            if relative:
                before[screen] = {
                    "file": relative,
                    "source": item.get("source_revision", "이전 기준 인덱스 참조"),
                    "test": item.get("test", "기록 없음"),
                    "device": item.get("device", "이전 iPhone 기준 화면"),
                }
    return {"actual": actual, "before": before, "devices": DEVICES, "screens": SCREENS}


PAGE = r'''<!doctype html>
<html lang="ko">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>DESERT HORIZON · 실제 화면 전후 비교</title>
  <style>
    :root { color-scheme: dark; font-family: -apple-system, BlinkMacSystemFont, sans-serif; background: #101819; color: #f5f2eb; }
    * { box-sizing: border-box; }
    body { margin: 0; }
    main { max-width: 1440px; margin: auto; padding: clamp(18px, 4vw, 48px); }
    h1 { margin: 10px 0; font-size: clamp(1.75rem, 4vw, 3rem); }
    h2 { font-size: 1.1rem; margin: 0 0 12px; }
    p { color: #c6d0cb; line-height: 1.55; }
    a { color: #e8bf94; }
    .eyebrow { color: #e8bf94; text-transform: uppercase; letter-spacing: .12em; font-size: .8rem; }
    .notice { border-left: 3px solid #d7a978; padding: 12px 16px; background: #1b292b; border-radius: 0 10px 10px 0; }
    .controls { display: flex; flex-wrap: wrap; align-items: end; gap: 18px; margin: 28px 0; }
    .control { display: grid; gap: 8px; }
    .control strong { font-size: .83rem; color: #c6d0cb; }
    .segments { display: flex; flex-wrap: wrap; gap: 6px; }
    button, select { border: 1px solid #526360; border-radius: 9px; background: #1b292b; color: inherit; padding: 10px 14px; font: inherit; cursor: pointer; }
    button[aria-pressed="true"] { background: #e8bf94; color: #152021; border-color: #e8bf94; font-weight: 700; }
    button:focus-visible, select:focus-visible, a:focus-visible { outline: 3px solid #e8bf94; outline-offset: 3px; }
    .comparison { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 20px; }
    .panel { min-width: 0; border: 1px solid #405153; border-radius: 16px; overflow: hidden; background: #1b292b; }
    .panel-head { padding: 16px; border-bottom: 1px solid #405153; }
    .panel-head p { margin: 4px 0 0; font-size: .9rem; }
    .image-wrap { display: grid; place-items: center; min-height: 280px; background: #0b1112; }
    .image-wrap img { display: block; max-width: 100%; max-height: min(70vh, 820px); object-fit: contain; image-orientation: from-image; }
    .empty { padding: 44px 16px; text-align: center; color: #c6d0cb; }
    .meta { padding: 14px 16px; font-size: .82rem; color: #c6d0cb; overflow-wrap: anywhere; }
    .prototype { margin-top: 28px; padding: 20px; border: 1px solid #6d5b4c; border-radius: 16px; background: #29251f; }
    .prototype p { margin-bottom: 0; }
    @media (max-width: 720px) { .comparison { grid-template-columns: 1fr; } .image-wrap img { max-height: 65vh; } }
  </style>
</head>
<body><main>
  <div class="eyebrow">DUNE · 2026-10-24 review</div>
  <h1>DESERT HORIZON 실제 화면 비교</h1>
  <p>4탭의 이전 기준 화면과 현재 앱 캡처를 나란히 봅니다. 큰 글씨 화면도 선택할 수 있습니다.</p>
  <p class="notice">오른쪽 이미지는 각 캡처 인덱스에 기록된 실제 앱 화면입니다. iPhone의 밝음·어두움 8장과 최대 접근성 글씨 4장은 소스 <code>3d9ba7e7</code>의 개별 ThemeMatrix 테스트에서 수집했습니다. 첫 묶음 전체에는 다른 UI 테스트 실패 5건이 있어 최종 검증은 진행 중입니다. 왼쪽의 이전 화면은 밝은 모드 기준이며 기기와 시점이 다를 수 있습니다.</p>
  <p><a href="README.md">캡처 출처와 갱신 방법</a> · <a href="../../../phone-design-map/actual/index.html">통합 실제 화면맵</a></p>
  <div class="controls">
    <div class="control"><strong>화면</strong><div class="segments" id="screens" aria-label="4탭 화면 선택"></div></div>
    <div class="control"><strong>화면 상태</strong><div class="segments" id="states" aria-label="화면 상태 선택"></div></div>
    <label class="control"><strong>기기</strong><select id="device" aria-label="기기 선택"></select></label>
  </div>
  <div class="comparison" aria-live="polite">
    <section class="panel"><div class="panel-head"><h2>이전 기준 · 실제 앱 화면</h2><p id="before-note"></p></div><div class="image-wrap" id="before-image"></div><div class="meta" id="before-meta"></div></section>
    <section class="panel"><div class="panel-head"><h2>현재 구현 · 실제 앱 화면</h2><p id="actual-note"></p></div><div class="image-wrap" id="actual-image"></div><div class="meta" id="actual-meta"></div></section>
  </div>
  <aside class="prototype"><h2>방향 시안 · 실제 앱 화면 아님</h2><a href="../../../theme-map/themes/dune-final-four-tab.html">DESERT HORIZON 4탭 시안 열기 ↗</a><p>시안의 수치와 그래프는 예시입니다. 위 비교 이미지의 출처나 검증 결과로 사용하지 않습니다.</p></aside>
</main>
<script>
const DATA = __DATA__;
const stateNames = {light: "밝음", dark: "어두움", ax: "큰 글씨 · XXXL"};
const selected = {screen: "T03", state: "light", device: "regular"};
function showImage(target, entry, alt) {
  target.replaceChildren();
  if (!entry) { const empty = document.createElement("div"); empty.className = "empty"; empty.textContent = "이 조합의 실제 캡처가 아직 없습니다."; target.append(empty); return; }
  const link = document.createElement("a"); link.href = entry.file; link.title = "원본 PNG 열기";
  const img = document.createElement("img"); img.src = entry.file; img.alt = alt; img.loading = "lazy";
  link.append(img); target.append(link);
}
function render() {
  const before = DATA.before[selected.screen];
  const actual = DATA.actual[selected.device]?.[selected.screen]?.[selected.state];
  const name = DATA.screens[selected.screen];
  document.querySelectorAll("[data-screen]").forEach(button => button.setAttribute("aria-pressed", button.dataset.screen === selected.screen));
  document.querySelectorAll("[data-state]").forEach(button => button.setAttribute("aria-pressed", button.dataset.state === selected.state));
  document.getElementById("before-note").textContent = selected.state === "light" ? `${name} · 이전 밝은 화면` : `${name} · 이전 밝은 화면 (선택한 상태와 다름)`;
  document.getElementById("actual-note").textContent = `${DATA.devices[selected.device]} · ${name} · ${stateNames[selected.state]}`;
  showImage(document.getElementById("before-image"), before, `${name} 이전 실제 앱 화면`);
  showImage(document.getElementById("actual-image"), actual, `${name} ${stateNames[selected.state]} 현재 실제 앱 화면`);
  document.getElementById("before-meta").textContent = before ? `출처: ${before.test} · 소스: ${before.source} · ${before.device}` : "이전 화면 없음";
  document.getElementById("actual-meta").textContent = actual ? `출처: ${actual.test} · 소스: ${actual.source} · ${actual.device} · UDID: ${actual.udid}` : "이 조합은 아직 수집되지 않았습니다. 기존 기기의 캡처로 대신 표시하지 않습니다.";
}
for (const [screen, name] of Object.entries(DATA.screens)) {
  const button = document.createElement("button"); button.type = "button"; button.dataset.screen = screen; button.textContent = `${name} · ${screen}`;
  button.addEventListener("click", () => { selected.screen = screen; render(); }); document.getElementById("screens").append(button);
}
for (const [state, name] of Object.entries(stateNames)) {
  const button = document.createElement("button"); button.type = "button"; button.dataset.state = state; button.textContent = name;
  button.addEventListener("click", () => { selected.state = state; render(); }); document.getElementById("states").append(button);
}
for (const [device, name] of Object.entries(DATA.devices)) {
  if (!DATA.actual[device]) continue;
  const option = document.createElement("option"); option.value = device; option.textContent = name; document.getElementById("device").append(option);
}
document.getElementById("device").addEventListener("change", event => { selected.device = event.target.value; render(); });
render();
</script></body></html>
'''


def main() -> None:
    data = capture_data()
    page = PAGE.replace("__DATA__", json.dumps(data, ensure_ascii=False).replace("</", "<\\/"))
    (HERE / "index.html").write_text(page, encoding="utf-8")
    count = sum(len(states) for screens in data["actual"].values() for states in screens.values())
    print(f"Rendered {count} indexed actual captures from {len(data['actual'])} device(s)")


if __name__ == "__main__":
    main()
