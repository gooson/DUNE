/* Settings hub detail screens. All changes are local to this prototype. */
(function () {
  "use strict";

  const pages = {
    workout: "운동 설정",
    "workout-live": "운동 실시간 현황",
    "workout-exercises": "운동별 기본값",
    "workout-exercise-edit": "운동 기본값 편집",
    "workout-preferred": "즐겨찾는 운동",
    alerts: "알림과 브리핑",
    "alerts-health": "건강 알림",
    "alerts-bedtime": "취침 알림",
    "alerts-other": "운동·생활 알림",
    privacy: "데이터와 개인정보",
    about: "앱 정보",
    "about-whats-new": "새 소식"
  };

  const state = {
    restSeconds: 90,
    setCount: 5,
    bodyWeightKg: 70,
    cardioMetric: "elapsed",
    strengthMetric: "elapsed",
    liveStyle: "gold",
    exercise: "벤치 프레스",
    exerciseDefaults: {
      "벤치 프레스": { weight: 40, reps: 10, manual: false, preferred: true },
      "스쿼트": { weight: 60, reps: 8, manual: false, preferred: false },
      "달리기": { weight: "", reps: "", manual: false, preferred: false }
    },
    health: {
      hrv: true, restingHeartRate: true, sleepRecorded: true, sleepDebt: true,
      steps: true, weight: false, bodyFat: false, bmi: false
    },
    bedtime: true,
    bedtimeLead: "120",
    watchBedtime: true,
    watchBedtimeLead: "60",
    workoutRecords: true,
    dailyDigest: true,
    posture: false,
    morningBriefing: true,
    cloudSync: false
  };

  function escape(value) {
    return String(value).replace(/[&<>"']/g, character => ({
      "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"
    })[character]);
  }

  function group(label, rows, note) {
    return `<section aria-label="${escape(label)}"><h3 class="group-label">${escape(label)}</h3>` +
      `<div class="settings-group">${rows}</div>` +
      (note ? `<p class="pref-note">${escape(note)}</p>` : "") + `</section>`;
  }

  function link(label, route, value = "") {
    return `<button type="button" class="pref-row" data-go="${escape(route)}" aria-label="${escape(label)}${value ? `, ${escape(value)}` : ""}">` +
      `<span>${escape(label)}</span><span class="pref-value">${escape(value)}</span><span class="chevron" aria-hidden="true">›</span></button>`;
  }

  function valueRow(label, value) {
    return `<div class="pref-row"><span>${escape(label)}</span><span class="pref-value">${escape(value)}</span></div>`;
  }

  function toggle(label, key, checked, disabled = false) {
    return `<label class="pref-row"><span>${escape(label)}</span><input type="checkbox" data-setting="${escape(key)}"` +
      `${checked ? " checked" : ""}${disabled ? " disabled" : ""} aria-label="${escape(label)}"></label>`;
  }

  function number(label, key, value, min, max, step, unit) {
    return `<label class="pref-row"><span>${escape(label)}</span><span class="pref-value">` +
      `<input type="number" inputmode="decimal" data-setting="${escape(key)}" value="${escape(value)}"` +
      ` min="${min}" max="${max}" step="${step}" aria-label="${escape(label)} (${unit})"> ${escape(unit)}</span></label>`;
  }

  function select(label, key, value, options, disabled = false) {
    return `<label class="pref-row"><span>${escape(label)}</span><select data-setting="${escape(key)}"` +
      ` aria-label="${escape(label)}"${disabled ? " disabled" : ""}>` +
      options.map(([optionValue, text]) => `<option value="${escape(optionValue)}"${value === optionValue ? " selected" : ""}>${escape(text)}</option>`).join("") +
      `</select></label>`;
  }

  function render(route) {
    if (!Object.prototype.hasOwnProperty.call(pages, route)) return "";
    let content = "";
    switch (route) {
      case "workout":
        content = group("새 운동 기본값",
          number("휴식 시간", "restSeconds", state.restSeconds, 15, 600, 15, "초") +
          number("기본 세트", "setCount", state.setCount, 1, 20, 1, "세트") +
          number("체중", "bodyWeightKg", state.bodyWeightKg, 20, 500, 0.5, "kg"),
          "새 운동을 시작할 때 기본값으로 사용해요.") +
          group("운동별 설정", link("운동별 기본값", "workout-exercises") +
            link("즐겨찾는 운동", "workout-preferred") +
            link("운동 실시간 현황", "workout-live"));
        break;
      case "workout-live":
        content = group("Apple Watch 운동 표시",
          select("유산소 지표", "cardioMetric", state.cardioMetric,
            [["elapsed", "경과 시간"], ["distance", "거리"], ["heart", "심박수"]]) +
          select("근력 지표", "strengthMetric", state.strengthMetric,
            [["elapsed", "경과 시간"], ["weight", "현재 세트 무게"], ["heart", "심박수"]]) +
          select("표시 스타일", "liveStyle", state.liveStyle,
            [["standard", "기본"], ["gold", "Gold Impact"]]),
          "선택한 지표를 사용할 수 없으면 경과 시간을 표시해요.");
        break;
      case "workout-exercises":
        content = group("운동", Object.keys(state.exerciseDefaults).map(name => {
          const entry = state.exerciseDefaults[name];
          const summary = entry.weight ? `${entry.weight} kg · ${entry.reps}회` : "설정 없음";
          return `<button type="button" class="pref-row" data-go="workout-exercise-edit" data-exercise="${escape(name)}"` +
            ` aria-label="${escape(name)} 기본값 편집, ${escape(summary)}"><span>${escape(name)}</span>` +
            `<span class="pref-value">${escape(summary)}</span><span class="chevron" aria-hidden="true">›</span></button>`;
        }).join(""));
        break;
      case "workout-exercise-edit": {
        const entry = state.exerciseDefaults[state.exercise] || state.exerciseDefaults["벤치 프레스"];
        const hasWeight = state.exercise !== "달리기";
        content = group(state.exercise,
          (hasWeight ? number("기본 무게", "exerciseWeight", entry.weight, 0.5, 500, 0.5, "kg") +
            number("기본 반복", "exerciseReps", entry.reps, 0, 1000, 1, "회") :
            valueRow("기본 무게·반복", "해당 없음")) +
          toggle("수동 지정 유지", "exerciseManual", entry.manual) +
          toggle("즐겨찾는 운동", "exercisePreferred", entry.preferred),
          "수동 지정은 저장한 기본값을 유지해요. 즐겨찾는 운동은 빠른 시작에서 위쪽에 표시돼요.");
        break;
      }
      case "workout-preferred":
        content = group("운동", Object.entries(state.exerciseDefaults).map(([name, entry]) =>
          toggle(name, `preferred:${name}`, entry.preferred)).join(""),
          "즐겨찾는 운동은 빠른 시작에서 위쪽에 표시돼요.");
        break;
      case "alerts":
        content = group("앱 시작", toggle("아침 브리핑", "morningBriefing", state.morningBriefing),
          "아침에 앱을 처음 열면 컨디션과 회복 정보를 보여줘요.") +
          group("알림 종류", link("건강 알림", "alerts-health") +
            link("취침 알림", "alerts-bedtime") + link("운동·생활 알림", "alerts-other"));
        break;
      case "alerts-health":
        content = group("건강 알림", [
          ["HRV 변화", "hrv"], ["안정 시 심박수", "restingHeartRate"],
          ["수면 기록", "sleepRecorded"], ["수면 부족", "sleepDebt"],
          ["걸음 수 목표", "steps"], ["체중 업데이트", "weight"],
          ["체지방률 업데이트", "bodyFat"], ["BMI 업데이트", "bmi"]
        ].map(([label, key]) => toggle(label, `health:${key}`, state.health[key])).join(""),
        "건강 알림은 종류별로 하루 최대 한 번 전송돼요. 중복 알림과 정보성 알림에도 전송 제한이 적용돼요.");
        break;
      case "alerts-bedtime":
        content = group("iPhone", toggle("취침 알림", "bedtime", state.bedtime) +
          select("미리 알림", "bedtimeLead", state.bedtimeLead,
            [["30", "30분 전"], ["60", "1시간 전"], ["120", "2시간 전"]], !state.bedtime)) +
          group("Apple Watch", toggle("Watch 취침 알림", "watchBedtime", state.watchBedtime) +
          select("Watch 미리 알림", "watchBedtimeLead", state.watchBedtimeLead,
            [["30", "30분 전"], ["60", "1시간 전"], ["120", "2시간 전"]], !state.watchBedtime),
          state.watchBedtime ? "최근 심박수 데이터에서 Watch 착용이 확인되면 Watch 알림을 건너뛸 수 있어요." : "");
        break;
      case "alerts-other":
        content = group("운동·생활", toggle("운동 기록", "workoutRecords", state.workoutRecords) +
          toggle("일일 요약", "dailyDigest", state.dailyDigest) +
          toggle("자세 알림", "posture", state.posture));
        break;
      case "privacy":
        content = group("iCloud", toggle("iCloud 동기화", "cloudSync", state.cloudSync) +
          valueRow("근처 기기 운동 동기화", "기기별 선택") +
          valueRow("동기화 요청", "앱에서 실행") +
          valueRow("이전 iCloud 백업에서 운동 복구", "앱에서 실행")) +
          group("시스템 권한", valueRow("Apple 건강 권한", "iOS 설정에서 변경") +
            valueRow("위치 접근", "iOS 설정에서 변경"));
        break;
      case "about":
        content = group("DUNE", link("새 소식", "about-whats-new") +
          valueRow("버전", "—") + valueRow("빌드", "—")) +
          group("데이터 출처", valueRow("날씨", "Open-Meteo.com · CC BY 4.0"));
        break;
      case "about-whats-new":
        content = group("새 소식", valueRow("알림함", "앱에서 확인"));
        break;
    }
    return `<div class="settings-detail" data-detail-route="${escape(route)}">${content}</div>`;
  }

  function activate(container, refresh) {
    if (!container || container.dataset.settingsDetailsActive === "true") return;
    container.dataset.settingsDetailsActive = "true";
    container.addEventListener("click", event => {
      const exerciseButton = event.target.closest("[data-exercise][data-go]");
      if (exerciseButton && container.contains(exerciseButton)) {
        state.exercise = exerciseButton.dataset.exercise;
      }
    }, true);
    container.addEventListener("change", event => {
      const control = event.target.closest("[data-setting]");
      if (!control || !container.contains(control)) return;
      const key = control.dataset.setting;
      if (key.startsWith("health:")) {
        state.health[key.slice(7)] = control.checked;
      } else if (key.startsWith("preferred:")) {
        const exercise = key.slice(10);
        if (state.exerciseDefaults[exercise]) state.exerciseDefaults[exercise].preferred = control.checked;
      } else if (key.startsWith("exercise")) {
        const entry = state.exerciseDefaults[state.exercise];
        if (entry) {
          if (key === "exerciseWeight") entry.weight = clamp(control.value, 0.5, 500, 0.5);
          if (key === "exerciseReps") entry.reps = clamp(control.value, 0, 1000, 1);
          if (key === "exerciseManual") entry.manual = control.checked;
          if (key === "exercisePreferred") entry.preferred = control.checked;
        }
      } else if (Object.prototype.hasOwnProperty.call(state, key)) {
        if (control.type === "checkbox") state[key] = control.checked;
        else if (control.type === "number") {
          const ranges = { restSeconds: [15, 600, 15], setCount: [1, 20, 1], bodyWeightKg: [20, 500, 0.5] };
          state[key] = clamp(control.value, ...ranges[key]);
        } else state[key] = control.value;
      }
      if (typeof refresh === "function") refresh();
    });
  }

  function clamp(value, min, max, step) {
    const parsed = Number(value);
    if (!Number.isFinite(parsed)) return min;
    return Math.min(max, Math.max(min, Math.round(parsed / step) * step));
  }

  window.SettingsDetails = { pages, render, activate };
})();
