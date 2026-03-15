---
tags: [ui-test, e2e, todo, backlog, closeout, today, settings]
category: testing
date: 2026-03-16
severity: important
related_files:
  - DUNEUITests/Full/TodaySettingsRegressionTests.swift
  - todos/022-done-p2-e2e-dune-dashboard-view.md
  - todos/027-done-p2-e2e-dune-notification-hub-view.md
  - todos/031-done-p2-e2e-dune-cloud-sync-consent-view.md
  - todos/101-ready-p2-e2e-phase0-page-backlog-index.md
  - todos/107-done-p2-e2e-phase0-completed-surface-index.md
related_solutions:
  - docs/solutions/testing/2026-03-08-e2e-phase2-today-settings-regression.md
  - docs/solutions/testing/2026-03-09-e2e-done-todo-index-consolidation.md
---

# Solution: E2E Phase 2 Today Settings Closeout

## Problem

Today/Settings phase 2 regression은 이미 테스트와 AX contract까지 구현돼 있었지만, phase 0 backlog 문서는 여전히 `022`~`031`을 `ready`로 유지하고 있었다. 그 결과 open backlog를 보면 아직 미구현처럼 보이고, completed index에도 Today/Settings must-have surface가 빠져 있었다.

### Symptoms

- `DUNEUITests/Smoke/DashboardSmokeTests.swift`, `DUNEUITests/Smoke/SettingsSmokeTests.swift`, `DUNEUITests/Full/TodaySettingsRegressionTests.swift`가 존재해도 `todos/101`은 `022`~`031`을 계속 open으로 표시함
- closeout 과정에서 test class 이름을 file path처럼 적으면 TODO evidence가 실제 파일 구조와 어긋남
- 오래된 full regression은 morning briefing overlay와 hittable timing 때문에 다시 돌렸을 때 flaky하게 실패할 수 있음

### Root Cause

phase 2 구현 시점에는 regression suite와 AX contract를 먼저 정리했지만, surface-level TODO closeout과 completed index 동기화가 후속으로 밀렸다. 또한 UI test evidence를 문서화할 때 "클래스 이름"과 "실제 파일 경로"를 구분하지 않으면 traceability가 쉽게 깨진다.

## Solution

phase 2 관련 smoke/full UI tests를 현재 HEAD에서 다시 실행해 closeout 근거를 확보하고, flaky했던 TodaySettings regression을 안정화한 뒤 `022`~`031` TODO를 `done`으로 rename/update 했다. 마지막으로 `todos/101` open backlog와 `todos/107` completed index를 현재 상태에 맞게 다시 맞췄다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNEUITests/Full/TodaySettingsRegressionTests.swift` | morning briefing dismissal + hittable wait + route helper 추가 | closeout 근거가 되는 nightly regression이 현재 환경에서 안정적으로 통과하도록 만들기 위해 |
| `todos/022-done-*.md` ~ `todos/031-done-*.md` | `ready` → `done` rename, regression lane/implementation note 업데이트 | Today/Settings phase 2 surface를 실제 테스트 기준으로 닫기 위해 |
| `todos/101-ready-p2-e2e-phase0-page-backlog-index.md` | `022`~`031` 제거, 완료 수 갱신 | open backlog가 남은 작업만 보여주게 하기 위해 |
| `todos/107-done-p2-e2e-phase0-completed-surface-index.md` | Today/Settings section 추가 | completed surface를 target별로 다시 찾을 수 있게 하기 위해 |

### Key Code

```swift
private func openNotificationHub() {
    dismissMorningBriefingIfNeeded(timeout: 1.5)

    let notificationsButton = app.descendants(matching: .any)[AXID.dashboardToolbarNotifications].firstMatch
    XCTAssertTrue(notificationsButton.waitForExistence(timeout: 5))
    XCTAssertTrue(waitForHittable(notificationsButton, timeout: 5))
    notificationsButton.tap()
}
```

## Prevention

closeout 성격의 e2e 작업도 "문서만 수정"으로 처리하지 말고 현재 HEAD에서 smoke/full regression을 다시 돌려야 한다. 그리고 TODO evidence를 적을 때는 test class 이름만 적지 말고, 실제 file path를 먼저 적고 필요하면 그 안의 class 이름을 덧붙여야 한다.

### Checklist Addition

- [ ] e2e TODO를 `done`으로 전환하기 전에 해당 smoke/full suite를 현재 HEAD에서 재실행했는지 확인
- [ ] TODO `Implementation` 항목은 실제 존재하는 file path인지 확인하고, 클래스 이름은 보조 정보로만 덧붙이기
- [ ] completed index로 이동한 surface는 open backlog index에서 같은 change 안에 제거했는지 확인

### Rule Addition (if applicable)

새 규칙 파일 추가는 보류한다. 같은 종류의 backlog/evidence mismatch가 반복되면 `todo-conventions.md` 또는 testing 규칙으로 승격할 수 있다.

## Lessons Learned

e2e backlog closeout의 핵심은 새 테스트를 더 만드는 것이 아니라 "이미 있는 regression이 지금도 닫히는가"를 다시 확인하는 데 있다. 또한 UI test 문서화에서는 test 이름보다 file path가 더 강한 source of truth다.
