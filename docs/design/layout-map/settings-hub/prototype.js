/* Interactive layout study. Prototype state lives only for the current page session. */
(() => {
  "use strict";

  const resources = "../../../../DUNE/Resources/";
  const captures = "../../phone-design-map/actual/artist-themes/";
  const themes = [
    ["desertWarm", "Desert Warm"], ["oceanCool", "Ocean Cool"], ["forestGreen", "Forest Green"],
    ["sakuraCalm", "Sakura Calm"], ["arcticDawn", "Arctic Dawn"], ["solarPop", "Solar Pop"],
    ["contourAtlas", "컨투어 아틀라스"], ["waterLilies", "수련"], ["patisserie", "파티스리"]
  ];
  const themeName = Object.fromEntries(themes);
  // Accent values from the bundled ArtistEditions palettes.
  const accents = {
    arcticDawn: ["#39677f","#91dcd4"],
    contourAtlas: ["#526638","#c3d18f"],
    desertWarm: ["#87502f","#edb475"],
    forestGreen: ["#376348","#a8cda8"],
    oceanCool: ["#13667b","#83d6e1"],
    patisserie: ["#855161","#e9b2bc"],
    sakuraCalm: ["#944b62","#eeb1bd"],
    solarPop: ["#934a27","#edb477"],
    waterLilies: ["#4e667e","#b8bddf"],
  };
  const icons = { interleave: "인터리브", ocean: "오션 글라스", flow: "네거티브 플로" };
  const categories = [
    ["workout", "dumbbell", "운동 설정", "휴식 시간, 운동별 기본값"],
    ["alerts", "bell", "알림과 브리핑", "건강 알림, 취침 알림"],
    ["privacy", "hand.raised", "데이터와 개인정보", "iCloud 동기화, 접근 권한"],
    ["about", "info.circle", "앱 정보", "새 소식, 버전"]
  ];
  const titles = { home: "설정", gallery: "테마", preview: "미리보기", icons: "앱 아이콘", search: "설정 검색", ...SettingsDetails.pages };
  const symbols = ["magnifyingglass","dumbbell","bell","hand.raised","info.circle","chevron.right","chevron.left","square.grid.2x2","checkmark","iphone","ipad.landscape","moon","sun.max","textformat.size","xmark","battery.100percent","wifi","cellularbars","circle.lefthalf.filled","slider.horizontal.3","arrow.up.right","app.dashed","timer"];
  const state = { theme: "desertWarm", icon: "interleave" };
  const panes = [];
  let layout = "phone";

  function symbol(name) {
    const position = 100 * symbols.indexOf(name) / (symbols.length - 1);
    return '<span aria-hidden="true" class="symbol" style="--pos:' + position + '%"></span>';
  }
  function themeArt(key) { return resources + "ArtistEditions/" + key + ".jpg"; }
  function iconArt(style, launch = false) {
    const asset = launch ? "LaunchBrand" : "AppIconPreview";
    const file = launch ? "LaunchBrand.png" : "Preview.png";
    return resources + "Assets.xcassets/" + asset + "-" + style + "-" + state.theme + ".imageset/" + file;
  }
  function statusBar() {
    return '<div class="status" aria-hidden="true"><span>9:41</span><div class="status-icons">' +
      symbol("cellularbars") + symbol("wifi") + '<span class="battery">' + symbol("battery.100percent") + "</span></div></div>";
  }
  function heading(title, extra = "", long = false) {
    return '<div class="heading' + (long ? " long" : "") + '"><h2 tabindex="-1">' + title + "</h2>" + extra + "</div>";
  }
  function setAccent(el, key) {
    el.style.setProperty("--theme-light", accents[key][0]);
    el.style.setProperty("--theme-dark", accents[key][1]);
  }
  function markSidebar() {
    const current = detail.history.at(-1);
    const root = current === "preview" ? "gallery" : current.split("-")[0];
    document.querySelectorAll("#sidebar [data-go]").forEach(button => {
      if (button.dataset.go === root) button.setAttribute("aria-current", "page");
      else button.removeAttribute("aria-current");
    });
  }
  function home() {
    const searchButton = '<button class="search-short" data-go="search" aria-label="설정 검색">' + symbol("magnifyingglass") + "</button>";
    return heading("Settings", searchButton) +
      '<button class="hero" data-go="gallery" aria-label="테마 변경, 현재 ' + themeName[state.theme] + '">' +
      '<img src="' + themeArt(state.theme) + '" alt=""><span class="hero-foot"><span><small>현재 테마</small><strong class="hero-title">' +
      themeName[state.theme] + '</strong></span><span class="hero-action">테마 변경' + symbol("chevron.right") + "</span></span></button>" +
      '<button class="icon-entry" data-go="icons"><img src="' + iconArt(state.icon) + '" alt=""><strong>앱 아이콘</strong><span class="tail">' +
      icons[state.icon] + symbol("chevron.right") + '</span></button><nav class="menu" aria-label="설정 범주">' +
      categories.map(([route, pictogram, title, sub]) => '<button class="menu-row" data-go="' + route + '"><span class="menu-icon">' +
        symbol(pictogram) + '</span><span class="row-copy"><strong>' + title + "</strong><small>" + sub + "</small></span>" +
        symbol("chevron.right") + "</button>").join("") + "</nav>";
  }
  function gallery() {
    return heading("Themes") + '<div class="section-line"><h3>테마 컬렉션</h3><small>9개</small></div><div class="gallery">' +
      themes.map(([key, name]) => {
        const active = key === state.theme;
        return '<button class="thumb' + (active ? " active" : "") + '" aria-label="' + name + (active ? ", 사용 중" : "") +
          ', 미리보기" data-theme="' + key + '"><span class="thumb-pic"><img alt="" src="' + themeArt(key) + '">' +
          (active ? '<span class="mark">' + symbol("checkmark") + "</span>" : "") + "</span><span>" + name + "</span></button>";
      }).join("") + '</div><p class="gallery-note">' + symbol("checkmark") + "사용 중인 테마 · " + themeName[state.theme] + "</p>";
  }
  function preview(pane) {
    const name = themeName[pane.candidate];
    const picture = captures + pane.candidate + "/regular/" + pane.appearance + "/T03.png";
    return heading(name) + '<div class="mode-pick" role="group" aria-label="Today 미리보기 밝기">' +
      [["light","sun.max","밝게"],["dark","moon","어둡게"]].map(([mode, icon, label]) =>
        '<button data-appearance="' + mode + '" aria-pressed="' + (mode === pane.appearance) + '">' + symbol(icon) + label + "</button>").join("") +
      '</div><figure class="today-sample"><img alt="' + name + ' 테마의 Today 화면 예시. 컨디션 링과 추세 그래프." src="' + picture + '"></figure>' +
      '<div class="sample-label"><b>Today 미리보기</b><span>예시 데이터</span></div>';
  }
  function appIcons() {
    return heading("App Icon") + '<div class="settings-group">' + Object.entries(icons).map(([key, name]) =>
      '<button class="pref-row choose-icon" data-icon="' + key + '" aria-pressed="' + (key === state.icon) + '"><img src="' +
      iconArt(key) + '" alt=""><strong>' + name + "</strong>" + (key === state.icon ? symbol("checkmark") : "") + "</button>").join("") +
      '</div><p class="pref-note">아이콘 색상은 ' + themeName[state.theme] + ' 테마를 따라요.</p><h3 class="group-label">시작 화면</h3>' +
      '<div class="launch"><img alt="' + icons[state.icon] + ' 시작 화면 로고" src="' + iconArt(state.icon, true) + '"></div>';
  }

  // Each keyword opens the screen that contains its control.
  const searchGroups = [
    ["gallery", "꾸미기", ["테마"]],
    ["icons", "꾸미기", ["앱 아이콘", "시작 화면"]],
    ["workout", "운동 설정", ["휴식 시간", "기본 세트", "체중"]],
    ["workout-exercises", "운동 설정", ["운동별 기본값"]],
    ["workout-preferred", "운동 설정", ["즐겨찾는 운동"]],
    ["workout-live", "운동 실시간 현황", ["유산소 지표", "근력 지표", "Live Activity 표시 스타일"]],
    ["alerts-health", "건강 알림", ["HRV 변화", "안정 시 심박수", "수면 기록", "수면 부족", "걸음 수 목표", "체중 업데이트", "체지방률 업데이트", "BMI 업데이트"]],
    ["alerts-bedtime", "취침 알림", ["취침 알림", "Watch 취침 알림", "미리 알림 시간"]],
    ["alerts-other", "운동·생활 알림", ["운동 기록", "일일 요약", "자세 알림"]],
    ["alerts", "알림과 브리핑", ["아침 브리핑"]],
    ["privacy", "데이터와 개인정보", ["iCloud 동기화", "동기화 요청", "Apple 건강 권한", "위치 접근"]],
    ["about", "앱 정보", ["버전", "빌드", "날씨 데이터"]], ["about-whats-new", "앱 정보", ["새 소식"]]
  ];
  const searchItems = [
    ...searchGroups.flatMap(([route, group, labels]) => labels.map(name => ({route, group, name}))),
    ...categories.map(([route, , name]) => ({route, group: "설정", name})),
    ...themes.map(([key, name]) => ({route:"preview", group:"테마", name, key}))
  ];
  function normalized(text) { return text.replace(/\s/g, "").toLowerCase(); }
  function results(query) {
    const needle = normalized(query);
    const items = needle ? searchItems.filter(item =>
      normalized(item.name + item.group + (item.key || "")).includes(needle)) :
      ["휴식 시간", "취침 알림", "앱 아이콘", "iCloud 동기화"].map(label => searchItems.find(item => item.name === label));
    if (!items.length) return '<p class="empty" role="status">검색 결과가 없어요. 다른 설정 이름을 입력해 보세요.</p>';
    return '<div class="section-line"><h3>' + (needle ? "검색 결과" : "바로 찾기") + '</h3><small>' + items.length + '개</small></div><div class="settings-group">' +
      items.map(item => '<button class="pref-row" ' + (item.key ? 'data-theme="' + item.key : 'data-go="' + item.route) +
      '"><span class="row-copy"><strong>' + item.name + "</strong><small>" + item.group + "</small></span>" + symbol("chevron.right") + "</button>").join("") + "</div>";
  }
  function search() {
    return heading("Search") + '<input type="search" aria-label="설정 이름 검색" class="search-field" placeholder="설정 이름 검색">' +
      '<div class="search-results"></div>';
  }
  function screen(route, pane) {
    switch (route) {
      case "home": return home();
      case "gallery": return gallery();
      case "preview": return preview(pane);
      case "icons": return appIcons();
      case "search": return search();
      default: return heading(titles[route], "", true) + SettingsDetails.render(route);
    }
  }

  function render(pane, focus = false) {
    const route = pane.history.at(-1);
    const oldScroll = pane.el.querySelector(".sheet-scroll")?.scrollTop || 0;
    const backLabel = titles[pane.history.at(-2)] || "설정";
    const back = route === "home" ? "" : '<button class="back" data-back>' + symbol("chevron.left") + backLabel + "</button>";
    const applied = state.theme === pane.candidate;
    const footer = route === "preview" ? '<div class="apply-bar"><button class="apply" data-apply ' +
      (applied ? "disabled" : "") + ">" + (applied ? "사용 중인 테마" : "이 테마 적용") + "</button></div>" : "";
    pane.el.dataset.route = route;
    setAccent(pane.el, route === "preview" ? pane.candidate : state.theme);
    const caption = pane.el.closest(".panel")?.querySelector(".caption h2");
    if (caption) caption.textContent = ({home:"설정 홈", gallery:"테마 갤러리", preview:"적용 전 미리보기"})[route] || titles[route];
    pane.el.innerHTML = '<div class="pane-body"><div class="sheet-scroll">' + back + screen(route, pane) + "</div>" + footer + "</div>";
    if (route === "search") {
      pane.el.querySelector("input").value = pane.query;
      pane.el.querySelector(".search-results").innerHTML = results(pane.query);
    }
    if (document.querySelector("#detail")?.dataset.initialized) markSidebar();
    if (focus) {
      const target = pane.el.querySelector(route === "search" ? "input" : "h2");
      target?.focus({preventScroll:true});
    } else {
      pane.el.querySelector(".sheet-scroll").scrollTop = oldScroll;
    }
  }

  function outlet(source) { return source.el.id === "sidebar" ? detail : source; }
  function open(source, route, candidate) {
    const pane = outlet(source);
    if (source !== pane) pane.history = ["home"];
    if (candidate) { pane.candidate = candidate; pane.appearance = document.body.classList.contains("dark") ? "dark" : "light"; }
    if (route === "search") pane.query = "";
    pane.history.push(route);
    if (pane === detail) document.querySelector("#tablet").classList.add("drilled");
    render(pane, true);
  }
  function back(pane) {
    if (pane.history.length > 1) pane.history.pop();
    if (pane === detail && pane.history.at(-1) === "home") {
      document.querySelector("#tablet").classList.remove("drilled");
      pane.history = ["home","gallery"];
      const target = document.querySelector("#sidebar .hero");
      if (target?.getClientRects().length) target.focus({preventScroll:true});
      render(pane);
      return;
    }
    render(pane, true);
  }
  function refreshOthers(source) {
    for (const pane of panes) if (pane !== source && ["home","icons","gallery","preview"].includes(pane.history.at(-1))) render(pane);
  }
  function announce(text) { document.querySelector("#announcement").textContent = text; }
  function makePane(el, history, candidate = "oceanCool") {
    const pane = {el, history, candidate, appearance:"light", query:""};
    panes.push(pane);
    SettingsDetails.activate(el, () => {
      const key = document.activeElement?.dataset.setting;
      render(pane);
      if (key) el.querySelector('[data-setting="' + CSS.escape(key) + '"]')?.focus({preventScroll:true});
    });
    el.addEventListener("click", event => {
      const button = event.target.closest("button");
      if (!button) return;
      const data = button.dataset;
      if (data.go) open(pane, data.go);
      else if (data.theme) open(pane, "preview", data.theme);
      else if ("back" in data) back(pane);
      else if (data.appearance) {
        pane.appearance = data.appearance; render(pane);
        el.querySelector('[data-appearance="' + pane.appearance + '"]').focus({preventScroll:true});
      } else if (data.icon) {
        state.icon = data.icon; render(pane); refreshOthers(pane);
        el.querySelector('[data-icon="' + state.icon + '"]').focus({preventScroll:true});
        announce(icons[state.icon] + " 아이콘 선택");
      } else if ("apply" in data) {
        state.theme = pane.candidate;
        pane.history = ["home","gallery"];
        render(pane, true); refreshOthers(pane);
        announce(themeName[state.theme] + " 테마를 적용했어요.");
      }
    });
    el.addEventListener("input", event => {
      if (!event.target.matches("input[type=search]")) return;
      pane.query = event.target.value; el.querySelector(".search-results").innerHTML = results(pane.query);
    });
    el.addEventListener("keydown", event => {
      if (event.key === "Escape" && pane.history.length > 1) { event.preventDefault(); back(pane); }
    });
    render(pane);
    return pane;
  }

  document.querySelectorAll("[data-symbol]").forEach(el => {el.innerHTML = symbol(el.dataset.symbol);});
  const strip = document.querySelector("#phone-strip");
  for (const [caption, stack] of [["설정 홈",["home"]],["테마 갤러리",["home","gallery"]],["적용 전 미리보기",["home","gallery","preview"]]]) {
    const panel = document.createElement("section");
    panel.className = "panel"; panel.setAttribute("aria-label", caption);
    panel.innerHTML = '<div class="caption"><h2>' + caption + '</h2></div><div class="device">' + statusBar() +
      '<div class="pane"></div><div class="homebar" aria-hidden="true"></div></div>';
    strip.append(panel);
    makePane(panel.querySelector(".pane"), stack);
  }
  document.querySelector(".tablet-status").innerHTML = statusBar();
  makePane(document.querySelector("#sidebar"), ["home"]);
  const detail = makePane(document.querySelector("#detail"), ["home","gallery"]);
  detail.el.dataset.initialized = "true";
  markSidebar();
  document.querySelectorAll("[data-mode]").forEach(button => button.addEventListener("click", () => {
    layout = button.dataset.mode;
    document.querySelector("#phones").hidden = layout !== "phone";
    document.querySelector("#tablet").hidden = layout !== "tablet";
    document.querySelectorAll("[data-mode]").forEach(b => b.setAttribute("aria-pressed", b.dataset.mode === layout));
  }));
  for (const name of ["dark","large"]) {
    const button = document.getElementById(name);
    button.addEventListener("click", () => {
      const active = document.body.classList.toggle(name); button.setAttribute("aria-pressed", active);
      if (name === "dark") for (const pane of panes) {
        pane.appearance = active ? "dark" : "light"; if (pane.history.at(-1) === "preview") render(pane);
      }
    });
  }
})();
