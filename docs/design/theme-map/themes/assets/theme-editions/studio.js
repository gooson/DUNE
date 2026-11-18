"use strict";

const editions = {
  dune: {
    name: "Dune",
    artist: "조지아 오키프",
    motif: "모래 능선",
    ground: ["#faf2e5", "#26201d"],
    surface: ["#fff9ee", "#322a25"],
    ink: ["#3a2c24", "#fff2e1"],
    accent: ["#87502f", "#edb475"],
    hero: "#413026",
    hi: "#edc486",
    rim: ["#deceba", "#5a4637"],
  },
  ocean: {
    name: "Ocean",
    artist: "가쓰시카 호쿠사이",
    motif: "쪽빛 파도와 흰 포말",
    ground: ["#edf7f7", "#101e28"],
    surface: ["#f9fcfa", "#182c37"],
    ink: ["#1a3541", "#edf8f5"],
    accent: ["#13667b", "#83d6e1"],
    hero: "#112e3e",
    hi: "#94e1e3",
    rim: ["#b5d2d6", "#385564"],
  },
  forest: {
    name: "Forest",
    artist: "우타가와 히로시게",
    motif: "안개 속 소나무",
    ground: ["#f1f2e6", "#172720"],
    surface: ["#fafaf1", "#23362b"],
    ink: ["#223d31", "#f3f4e7"],
    accent: ["#376348", "#a8cda8"],
    hero: "#203c30",
    hi: "#e6d393",
    rim: ["#c9d0bc", "#465c49"],
  },
  sakura: {
    name: "Sakura",
    artist: "사카이 호이쓰",
    motif: "만개한 꽃가지",
    ground: ["#fcf1ed", "#2b2029"],
    surface: ["#fff8f1", "#382936"],
    ink: ["#4a313d", "#fff2ec"],
    accent: ["#944b62", "#eeb1bd"],
    hero: "#49313e",
    hi: "#f2c4bd",
    rim: ["#e4cad1", "#614556"],
  },
  arctic: {
    name: "Arctic",
    artist: "로렌 해리스",
    motif: "빙하와 오로라",
    ground: ["#eaf3f7", "#142235"],
    surface: ["#f7fbfe", "#203148"],
    ink: ["#233d54", "#edf7ff"],
    accent: ["#39677f", "#91dcd4"],
    hero: "#243750",
    hi: "#a6e4d5",
    rim: ["#bacedb", "#465970"],
  },
  solar: {
    name: "Solar",
    artist: "빈센트 반 고흐",
    motif: "해를 두르는 붓질",
    ground: ["#fcf1dc", "#2c2524"],
    surface: ["#fff8e9", "#393132"],
    ink: ["#473124", "#fff3d8"],
    accent: ["#934a27", "#edb477"],
    hero: "#40313a",
    hi: "#ffd677",
    rim: ["#e6c998", "#644b43"],
  },
  contour: {
    name: "Contour",
    artist: "파울 클레",
    motif: "등고선과 색면",
    ground: ["#f0efdf", "#262a22"],
    surface: ["#faf8e9", "#34382d"],
    ink: ["#374035", "#f3f0d9"],
    accent: ["#526638", "#c3d18f"],
    hero: "#373f32",
    hi: "#cdde91",
    rim: ["#c8c9ad", "#515c46"],
  },
  "water-lilies": {
    name: "Water Lilies",
    artist: "클로드 모네",
    motif: "수련과 물빛 반사",
    ground: ["#eaf1ec", "#202b31"],
    surface: ["#f7f9f2", "#2b373f"],
    ink: ["#2c474a", "#edf3ef"],
    accent: ["#4e667e", "#b8bddf"],
    hero: "#2c424b",
    hi: "#d6c2e1",
    rim: ["#c3cfc9", "#495c64"],
  },
  patisserie: {
    name: "Pâtisserie",
    artist: "웨인 티보",
    motif: "크림색 정물과 푸른 그림자",
    ground: ["#fbf1e6", "#2b2832"],
    surface: ["#fff9ee", "#37323d"],
    ink: ["#463341", "#fff1dd"],
    accent: ["#855161", "#e9b2bc"],
    hero: "#48445a",
    hi: "#ffe2b5",
    rim: ["#dfcfd0", "#62566b"],
  },
};

const tabs = {
  today: { name: "Today", icon: "today", detail: "condition" },
  activity: { name: "Activity", icon: "activity", detail: "readiness" },
  wellness: { name: "Wellness", icon: "wellness", detail: "wellness-score" },
  life: { name: "Life", icon: "life", detail: "habits" },
};
const details = {
  condition: {
    name: "Condition Score",
    label: "컨디션 상세",
    tab: "today",
    score: 82,
    badge: "컨디션",
    status: "좋음",
    note: "회복 지표가 평소 범위에 있어요.",
    metrics: [["HRV", "48 ms"], ["안정시 심박수", "56 bpm"]],
    chart: "컨디션 추세",
  },
  readiness: {
    name: "Training Readiness",
    label: "운동 준비도",
    tab: "activity",
    score: 74,
    badge: "운동 준비도",
    status: "보통",
    note: "회복과 최근 운동량을 반영했어요.",
    metrics: [["회복", "79점"], ["최근 운동량", "68점"]],
    chart: "운동 준비도 추세",
  },
  workout: {
    name: "Workout Detail",
    label: "운동 기록",
    tab: "activity",
    badge: "야외 걷기",
    value: "38분",
    status: "4.2 km",
    note: "오늘 오전에 기록한 운동",
    metrics: [["평균 심박수", "112 bpm"], ["평균 페이스", "9′03″ /km"]],
    chart: "운동 중 심박수",
  },
  "wellness-score": {
    name: "Wellness Score",
    label: "웰니스 점수",
    tab: "wellness",
    score: 86,
    badge: "웰니스",
    status: "좋음",
    note: "수면과 신체 지표가 안정적이에요.",
    metrics: [["수면", "88점"], ["컨디션", "82점"]],
    chart: "웰니스 추세",
  },
  sleep: {
    name: "Sleep",
    label: "수면 상세",
    tab: "wellness",
    badge: "최근 수면",
    value: "7시간 20분",
    status: "수면 시간",
    note: "어젯밤 23:10 – 오늘 06:30",
    metrics: [["깊은 수면", "1시간 18분"], ["렘 수면", "1시간 42분"]],
    chart: "최근 7일 수면",
  },
  habits: {
    name: "Weekly Report",
    label: "습관 주간 보고서",
    tab: "life",
    badge: "이번 주 습관",
    value: "14회",
    status: "기록한 실천",
    note: "지난 7일 동안 완료한 습관이에요.",
    metrics: [["계획한 실천", "21회"], ["달성률", "67%"]],
    chart: "일별 습관 완료",
  },
};
const icons = {
  today: "M5 6h14v14H5z M8 3v5m8-5v5M8 12h8m-8 4h5",
  activity: "M2 13h5l3-9 4 16 3-9 2 2h3",
  wellness: "M4 5c10-2 16 4 15 13C9 20 3 15 4 5zm2 2 11 10",
  life: "m3 6 2 2 3-4m3 3h10M3 14l2 2 3-4m3 3h10",
  back: "m14 4-8 8 8 8",
  add: "M12 4v16M4 12h16",
  chart: "M4 3v17h17M7 14l4-5 4 2 5-7",
  bell: "M5 16c2-2 2-3 2-7a5 5 0 0 1 10 0c0 4 0 5 2 7zm5 3a2 2 0 0 0 4 0",
};
function icon(id) {
  return '<svg class="glyph" viewBox="0 0 24 24" aria-hidden="true"><path d="' +
    icons[id] + '"/></svg>';
}
const root = document.documentElement,
  panels = document.querySelector("#panels"),
  themeSelect = document.querySelector("#theme"),
  tabSelect = document.querySelector("#tab"),
  sceneSelect = document.querySelector("#scene");
const params = new URLSearchParams(location.search),
  reduced = matchMedia("(prefers-reduced-motion:reduce)"),
  dark = matchMedia("(prefers-color-scheme:dark)");
const has = (collection, key) => Object.hasOwn(collection, key);
const state = {
  theme: has(editions, params.get("theme")) ? params.get("theme") : "ocean",
  tab: has(tabs, params.get("tab")) ? params.get("tab") : "wellness",
  view: params.get("view") === "focus" || params.has("embed") ? "focus" : "all",
  mode: ["dark", "light"].includes(params.get("mode"))
    ? params.get("mode")
    : (dark.matches ? "dark" : "light"),
  play: !reduced.matches,
  scene: "root",
};
if (has(details, params.get("scene"))) {
  state.scene = params.get("scene");
  state.tab = details[state.scene].tab;
}
root.dataset.embed = String(params.has("embed"));
function options(el, entries) {
  el.replaceChildren(
    ...entries.map(([value, label]) => new Option(label, value)),
  );
}
options(
  themeSelect,
  Object.entries(editions).map(([id, e]) => [id, e.name + " · " + e.artist]),
);
options(tabSelect, Object.entries(tabs).map(([id, t]) => [id, t.name]));
function imageFor(id) {
  return "assets/theme-editions/" + id + (id === "ocean" ? ".svg" : ".webp");
}
function styleFor(id) {
  const d = editions[id], idx = state.mode === "light" ? 0 : 1;
  const pairs = {
    ground: d.ground[idx],
    surface: d.surface[idx],
    ink: d.ink[idx],
    accent: d.accent[idx],
    hero: d.hero,
    hi: d.hi,
    rim: d.rim[idx],
  };
  const vars = Object.entries(pairs).map(([k, v]) => "--" + k + ":" + v);
  vars.push(
    "--secondary:color-mix(in srgb,var(--ink) 76%,var(--ground))",
    "--image:url('" + new URL(imageFor(id), document.baseURI).href + "')",
  );
  return vars.join(";");
}
function art() {
  return '<div class="print" aria-hidden="true"><div class="print-photo"></div><div class="air"></div><div class="petals"><i></i><i></i><i></i></div></div>';
}
function ring(n) {
  return '<span class="ring"><svg viewBox="0 0 42 42" aria-hidden="true"><circle class="track" cx="21" cy="21" r="18" fill="none" stroke-width="3"/><circle class="value" cx="21" cy="21" r="18" fill="none" stroke-linecap="round" stroke-width="3" pathLength="100" stroke-dasharray="' +
    n + ' 100"/></svg><b>' + n + "</b></span>";
}
function chart(kind = "line", variant = "condition") {
  const series = {
    condition: [57, 68, 62, 77, 69, 80, 82],
    activity: [53, 61, 78, 60, 71, 66, 74],
    sleep: [74, 62, 83, 71, 77, 65, 86],
    habits: [30, 67, 33, 67, 100, 100, 67],
    workout: [44, 64, 82, 75, 83, 68, 65],
    wellness: [71, 77, 70, 83, 79, 85, 86],
  };
  const nums = series[variant] || series.condition;
  const grid = '<path class="grid" fill="none" d="M0 13H204 M0 32H204"/>';
  let shapes;
  if (kind === "bars") {
    shapes = nums.map((v, i) =>
      '<rect x="' + (i * 29 + 4) + '" y="' + (40 - v * .36) +
      '" width="17" height="' + (v * .36) +
      '" rx="3" fill="currentColor" opacity="' + (i === 6 ? 1 : .45 + i * .04) +
      '"/>'
    ).join("");
  } else {
    const pts = nums.map((v, i) => [3 + i * 33, 44 - v * .43]);
    const line = pts.map(([x, y], i) => (i ? "L" : "M") + x + " " + y).join(
      " ",
    );
    const end = pts.at(-1);
    shapes = '<path d="' + line +
      ' L201 42H3Z" fill="currentColor" opacity=".10"/><path d="' + line +
      '" stroke="currentColor" stroke-width="2.1" fill="none" stroke-linejoin="round"/><circle cx="' +
      end[0] + '" cy="' + end[1] + '" r="2.6" fill="currentColor"/>';
  }
  return '<svg class="chart" viewBox="0 0 204 44" preserveAspectRatio="none" aria-hidden="true">' +
    grid + shapes + "</svg>";
}
function jump(label, dest) {
  return '<button class="jump" data-detail="' + dest + '">' + label +
    "</button>";
}
function heading(left, right = "") {
  return '<div class="card-heading"><span>' + left + "</span><small>" + right +
    "</small></div>";
}
function trend(title, variant, kind = "line") {
  const endpoints = variant === "workout"
    ? ["시작", "38분"]
    : ["7일 전", "오늘"];
  return '<div class="card">' + heading(title) + chart(kind, variant) +
    '<div class="chart-dates"><span>' + endpoints[0] + "</span><span>" +
    endpoints[1] + "</span></div></div>";
}
function meter(label, n, color) {
  return '<div class="metric-row"><span class="metric-name">' + label +
    '</span><span class="meter"><i style="width:' + n + "%;--metric:" + color +
    '"></i></span><b>' + n + "</b></div>";
}
function hero(badge, score, status, note, extra = "") {
  return '<div class="hero">' + heading(badge) + '<div class="hero-line">' +
    ring(score) + "<div><h4>" + status + "</h4><p>" + note +
    "</p></div></div>" + extra + "</div>";
}
function twoStats(metrics) {
  return '<div class="split">' +
    metrics.map(([label, value]) =>
      '<div class="card">' + heading(label) + '<div class="big">' + value +
      "</div></div>"
    ).join("") + "</div>";
}
function simpleCard(title, value, caption) {
  return '<div class="card">' + heading(title) + '<div class="big">' + value +
    '</div><span class="sub">' + caption + "</span></div>";
}
function rootBody(tab) {
  switch (tab) {
    case "today":
      return hero(
        jump("컨디션", "condition"),
        82,
        "좋음",
        "평소의 회복 리듬을 유지하고 있어요.",
        chart(),
      ) + twoStats([["최근 수면", "7시간 20분"], ["걸음", "6,420"]]) +
        trend("최근 7일 컨디션", "condition");
    case "activity":
      return hero(
        jump("운동 준비도", "readiness"),
        74,
        "보통",
        "최근 운동량과 회복을 함께 봐요.",
        meter("회복", 79, "#97c8a4") + meter("운동량", 68, "#d9ae7e"),
      ) +
        simpleCard(jump("최근 운동", "workout"), "야외 걷기", "38분 · 4.2 km") +
        trend("주간 운동량", "activity", "bars");
    case "wellness":
      return hero(
        jump("웰니스", "wellness-score"),
        86,
        "좋음",
        "수면과 신체 지표가 안정적이에요.",
        meter("수면", 88, "#b4a6d5") + meter("컨디션", 82, "var(--hi)") +
          meter("신체", 84, "#a3c8a6") + meter("자세", 90, "#a0bec6"),
      ) + '<div class="card">' + heading(jump("최근 수면", "sleep"), "지난밤") +
        '<div class="big">7시간 20분</div>' + chart("bars", "sleep") +
        "</div>" + twoStats([["HRV", "48 ms"], ["안정시 심박수", "56 bpm"]]);
    case "life":
      return '<div class="hero">' + heading("오늘의 습관") +
        '<div class="hero-line"><span class="habit-count">2<small>/3</small></span><div><h4>두 가지 완료</h4><p>오늘 한 가지 습관이 남았어요.</p></div></div></div><div class="card">' +
        heading("오늘의 실천") +
        ["아침 산책", "물 마시기", "가벼운 스트레칭"].map((name, i) =>
          '<div class="habit"><span class="check">' + (i < 2 ? "✓" : "○") +
          "</span>" + name + "<small>" + (i < 2 ? "완료" : "예정") +
          "</small></div>"
        ).join("") + "</div>" +
        trend(jump("주간 보고서", "habits"), "habits", "bars");
  }
}
function detailBody(id) {
  const d = details[id];
  const top = d.score
    ? hero(d.badge, d.score, d.status, d.note)
    : '<div class="hero">' + heading(d.badge) +
      '<div class="hero-line"><div><h4>' + d.value + "</h4><p>" + d.note +
      "</p></div></div></div>";
  const narrative = id === "condition"
    ? '<div class="card">' + heading("오늘의 인사이트") +
      '<p class="sub">최근 일주일과 비슷한 회복 흐름이에요.</p></div>'
    : "";
  return top + twoStats(d.metrics) + narrative +
    trend(
      d.chart,
      id === "sleep"
        ? "sleep"
        : id === "habits"
        ? "habits"
        : id === "workout"
        ? "workout"
        : id === "wellness-score"
        ? "wellness"
        : "condition",
      ["sleep", "habits"].includes(id) ? "bars" : "line",
    );
}
function mockup(id, tab, scene) {
  const d = details[scene], title = d ? d.name : tabs[tab].name;
  return '<div class="device" data-theme="' + id + '" data-screen="' + scene +
    '" style="' + styleFor(id) + '"><div class="header">' + art() +
    '<div class="time" aria-hidden="true"><span>9:41</span><span>▮▮▮ &nbsp; ▰</span></div><div class="screen-nav">' +
    (d
      ? '<button class="tool-icon" data-back aria-label="탭으로 돌아가기">' +
        icon("back") + "</button>"
      : "<span></span>") +
    '<span class="tools" aria-hidden="true">' +
    (d
      ? ""
      : '<span class="tool-icon">' + icon(tab === "today" ? "bell" : "chart") +
        "</span>") +
    "</span></div><h3>" + title + '</h3></div><div class="content">' +
    (d ? detailBody(scene) : rootBody(tab)) +
    '</div><nav class="tabbar" aria-label="' + editions[id].name + ' 탭">' +
    Object.entries(tabs).map(([key, t]) =>
      '<button data-tab="' + key + '" ' +
      (key === tab ? 'aria-current="page"' : "") + ">" + icon(t.icon) +
      "<span>" + t.name + "</span></button>"
    ).join("") + "</nav></div>";
}
function edition(id, tab, scene, focus) {
  const d = editions[id];
  const title = focus
    ? (scene === "root" ? tabs[tab].name : details[scene].label)
    : d.name;
  const subtitle = focus
    ? d.name + " · " + d.artist
    : d.artist + " · " + d.motif;
  return '<section class="edition"><header class="plate-title"><div><h2>' +
    title + "</h2><small>" + subtitle + "</small></div>" +
    (focus
      ? ""
      : '<button class="inspect" data-focus="' + id + '" aria-label="' +
        d.name + ' 테마 확대">확대 ↗</button>') +
    "</header>" + mockup(id, tab, scene) + "</section>";
}
function render(updateUrl = true) {
  root.dataset.mode = state.mode;
  root.dataset.play = state.play ? "playing" : "paused";
  document.querySelectorAll("[data-view]").forEach((b) =>
    b.setAttribute("aria-pressed", String(b.dataset.view === state.view))
  );
  document.querySelectorAll("[data-mode]").forEach((b) => {
    if (b.matches("button")) {
      b.setAttribute("aria-pressed", String(b.dataset.mode === state.mode));
    }
  });
  document.querySelector("#motion").textContent = state.play
    ? "움직임 멈추기"
    : "움직임 재생";
  themeSelect.value = state.theme;
  tabSelect.value = state.tab;
  document.querySelector("#theme-label").hidden = state.view !== "focus";
  options(sceneSelect, [
    ["root", "탭 첫 화면"],
    ...Object.entries(details).filter(([, d]) => d.tab === state.tab).map((
      [id, d],
    ) => [id, d.label]),
  ]);
  sceneSelect.value = state.scene;
  const focus = state.view === "focus";
  panels.classList.toggle("focus", focus);
  panels.innerHTML = focus
    ? edition(state.theme, state.tab, "root", true) +
      edition(
        state.theme,
        state.tab,
        state.scene === "root" ? tabs[state.tab].detail : state.scene,
        true,
      )
    : Object.keys(editions).map((id) =>
      edition(id, state.tab, state.scene, false)
    ).join("");
  if (updateUrl) {
    const query = new URLSearchParams({
      theme: state.theme,
      tab: state.tab,
      scene: state.scene,
      view: state.view,
      mode: state.mode,
    });
    if (params.has("embed")) query.set("embed", "1");
    try {
      history.replaceState(null, "", "?" + query + location.hash);
    } catch {}
  }
}
function setTab(tab) {
  state.tab = tab;
  state.scene = "root";
  render();
}
document.addEventListener("click", (e) => {
  const b = e.target.closest("button");
  if (!b) return;
  if (b.hasAttribute("data-mode")) {
    state.mode = b.dataset.mode;
    render();
  } else if (b.hasAttribute("data-view")) {
    state.view = b.dataset.view;
    render();
  } else if (b.hasAttribute("data-focus")) {
    state.theme = b.dataset.focus;
    state.view = "focus";
    render();
    document.querySelector(".toolbar").scrollIntoView({ block: "start" });
  } else if (b.hasAttribute("data-tab")) setTab(b.dataset.tab);
  else if (b.hasAttribute("data-detail")) {
    state.scene = b.dataset.detail;
    state.tab = details[state.scene].tab;
    state.theme = b.closest(".device").dataset.theme;
    state.view = "focus";
    render();
    panels.lastElementChild.scrollIntoView({ block: "nearest" });
  } else if (b.hasAttribute("data-back")) {
    state.scene = "root";
    render();
    panels.firstElementChild.scrollIntoView({ block: "nearest" });
  } else if (b.id === "motion") {
    state.play = !state.play;
    root.dataset.play = state.play ? "playing" : "paused";
    b.textContent = state.play ? "움직임 멈추기" : "움직임 재생";
  }
});
themeSelect.onchange = () => {
  state.theme = themeSelect.value;
  render();
};
tabSelect.onchange = () => setTab(tabSelect.value);
sceneSelect.onchange = () => {
  state.scene = sceneSelect.value;
  render();
};
reduced.addEventListener("change", () => {
  state.play = !reduced.matches;
  render(false);
});
render(false);
