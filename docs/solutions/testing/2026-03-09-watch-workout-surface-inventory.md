---
tags: [watchos, ui-test, e2e, accessibility-identifier, surface-contract, smoke-test, workout-flow]
category: testing
date: 2026-03-09
severity: important
related_files:
  - DUNEWatch/Helpers/WatchWorkoutSurfaceAccessibility.swift
  - DUNEWatch/Views/CarouselHomeView.swift
  - DUNEWatch/Views/QuickStartAllExercisesView.swift
  - DUNEWatch/Views/WorkoutPreviewView.swift
  - DUNEWatch/Views/SessionPagingView.swift
  - DUNEWatch/Views/MetricsView.swift
  - DUNEWatch/Views/ControlsView.swift
  - DUNEWatch/Views/RestTimerView.swift
  - DUNEWatch/Views/SetInputSheet.swift
  - DUNEWatch/Views/SessionSummaryView.swift
  - DUNEWatchUITests/Helpers/WatchUITestBaseCase.swift
  - DUNEWatchUITests/Smoke/WatchHomeSmokeTests.swift
  - DUNEWatchUITests/Smoke/WatchWorkoutStartSmokeTests.swift
  - DUNEWatchUITests/Smoke/WatchWorkoutFlowSmokeTests.swift
  - docs/plans/2026-03-09-watch-workout-e2e-surface-inventory.md
related_solutions:
  - docs/solutions/testing/2026-03-03-watch-workout-start-axid-selector-hardening.md
  - docs/solutions/testing/2026-03-08-e2e-phase1-test-infrastructure.md
  - docs/solutions/testing/2026-03-09-e2e-exercise-picker-surface-contract.md
---

# Solution: Watch Workout Surface Inventory

## Problem

watch workout flow는 home 진입부터 quick start, preview, active session, rest timer, set input, summary까지 여러 화면을 오가지만, 기존 PR gate는 시작 지점 일부만 확인하고 있었다.
이 상태에서는 특정 화면의 selector가 빠지거나 lane 전환이 깨져도 todo를 개별적으로 닫기 어려웠다.

### Symptoms

- home, quick start, preview 이후의 session surface가 smoke helper에 고정되어 있지 않았다.
- metrics, controls, rest timer, set input, summary 같은 후반 lane은 화면별 anchor selector가 부족했다.
- workout flow smoke를 추가하려면 매 테스트마다 탐색/스와이프/완료 루프를 다시 작성해야 했다.
- watch simulator pair가 불안정할 때도 최소한 compile-level contract와 deterministic helper는 남겨둘 필요가 있었다.

### Root Cause

기존 watch selector 작업은 시작 경로 중심으로 쪼개져 있었고, workout 전체를 하나의 surface contract로 묶는 공용 inventory가 없었다.
그 결과 뷰별 AXID와 UI test helper가 함께 진화하지 못했고, flow regression을 추가할 때 중복 탐색 로직이 늘어났다.

## Solution

watch workout 전 구간에 대해 중앙 AXID inventory를 도입하고, 각 surface에 대응하는 accessibility identifier를 한 번에 연결했다.
동시에 UI test base helper를 flow 단위 API로 확장해 home 진입, workout 시작, controls 이동, rest skip, summary 도달을 재사용 가능한 smoke lane으로 고정했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNEWatch/Helpers/WatchWorkoutSurfaceAccessibility.swift` | watch workout selector inventory 신설 | surface contract를 앱 코드에서 중앙 관리하기 위해 |
| `DUNEWatch/Views/*.swift` | home/quick start/preview/session/rest/set input/summary AXID 추가 | 전체 watch workout lane을 locale-safe selector로 검증하기 위해 |
| `DUNEWatchTests/WatchWorkoutSurfaceAccessibilityTests.swift` | static/dynamic selector uniqueness 테스트 추가 | selector 충돌과 naming drift를 빠르게 잡기 위해 |
| `DUNEWatchUITests/Helpers/WatchUITestBaseCase.swift` | flow helper와 selector 상수 확장 | smoke test가 탐색 로직을 중복하지 않도록 하기 위해 |
| `DUNEWatchUITests/Smoke/WatchHomeSmokeTests.swift` | quick start fixture surface assert 추가 | seeded watch home → quick start lane을 PR gate에 고정하기 위해 |
| `DUNEWatchUITests/Smoke/WatchWorkoutStartSmokeTests.swift` | start 이후 input/metrics surface assert 추가 | session 진입 후 실제 작업 lane 노출을 검증하기 위해 |
| `DUNEWatchUITests/Smoke/WatchWorkoutFlowSmokeTests.swift` | controls/rest/summary flow smoke 신설 | TODO 075-083을 하나의 regression 묶음으로 닫기 위해 |

### Key Code

```swift
enum WatchWorkoutSurfaceAccessibility {
    static let homeRoot = "watch-home-root"
    static let quickStartScreen = "watch-quickstart-screen"
    static let workoutPreviewScreen = "watch-workout-preview-screen"
    static let sessionPagingRoot = "watch-session-paging-root"
    static let restTimerScreen = "watch-rest-timer-screen"
    static let setInputScreen = "watch-set-input-screen"
    static let sessionSummaryScreen = "watch-session-summary-screen"
}
```

```swift
func completeFixtureStrengthWorkoutToSummary() {
    startFixtureStrengthWorkout()

    for setIndex in 1...fixtureStrengthSetCount {
        dismissSetInputSheetIfNeeded()
        XCTAssertTrue(tapElement(WatchAXID.sessionMetricsCompleteSetButton, timeout: 5))

        if setIndex < fixtureStrengthSetCount {
            XCTAssertTrue(elementExists(WatchAXID.restTimerScreen, timeout: 5))
            skipRestTimer()
        } else {
            XCTAssertTrue(tapElement(WatchAXID.sessionMetricsLastSetFinish, timeout: 5))
        }
    }

    XCTAssertTrue(elementExists(WatchAXID.sessionSummaryScreen, timeout: 8))
}
```

## Prevention

watch E2E TODO를 화면 단위로 닫더라도, 실제 구현은 flow contract 단위로 묶는 편이 유지비가 낮다.
selector inventory와 smoke helper를 분리하지 않고 함께 관리하면 이후 lane 추가 때도 같은 패턴으로 확장할 수 있다.

### Checklist Addition

- [ ] watch view에 새 stateful surface를 추가하면 `WatchWorkoutSurfaceAccessibility`에 selector를 먼저 등록했는가?
- [ ] smoke test helper가 화면 탐색을 재사용 가능한 flow API로 감싸고 있는가?
- [ ] seeded fixture가 flow 종료 조건까지 deterministic하게 유지되는가?
- [ ] selector uniqueness 테스트가 새 static identifier와 dynamic prefix를 함께 커버하는가?
- [ ] simulator pair 장애가 있더라도 unit/build 증빙과 smoke target compile 증빙을 남겼는가?

### Rule Addition (if applicable)

새 rules 파일 추가는 보류한다.
다만 watch workout 관련 E2E 작업은 개별 view selector 추가로 끝내지 말고, flow helper와 smoke coverage를 같은 배치에서 함께 갱신하는 기준을 유지한다.

## Lessons Learned

watch workout처럼 작은 화면이 여러 장으로 이어지는 흐름은 "화면별 todo"보다 "flow contract"가 더 중요하다.
home, preview, session, summary가 따로 보이더라도 테스트 관점에서는 하나의 lane이므로 selector inventory도 중앙에서 관리해야 한다.

또한 UI test helper를 탐색 스크립트가 아니라 도메인 동작 API처럼 다루면 새 smoke를 추가할 때 코드가 훨씬 짧아진다.
이번 배치에서는 `startFixtureStrengthWorkout`, `openControlsPage`, `completeFixtureStrengthWorkoutToSummary` 같은 helper가 그 역할을 맡았다.

마지막으로, watch simulator pair가 `active, disconnected` 상태로 깨질 수 있으므로 로컬 런타임 실패와 코드 회귀를 구분할 증빙이 필요했다.
selector/unit/build 계층을 먼저 고정해 두면 simulator 환경이 흔들려도 구현 자체의 안정성은 별도로 판단할 수 있다.
