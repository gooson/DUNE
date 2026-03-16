---
source: brainstorm/e2e-ui-test-plan-all-targets
priority: p2
status: done
created: 2026-03-08
updated: 2026-03-09
---

# E2E Surface: DUNEWatch QuickStartAllExercisesView

- Target: `DUNEWatch`
- Source: `DUNEWatch/Views/QuickStartAllExercisesView.swift`
- Entry: home all-exercises navigation
- [x] entry route와 target lane을 정의한다.
- [x] AXID / selector inventory를 고정한다.
- [x] 주요 state와 assertion 범위를 정리한다.
- [x] PR gate / nightly 배치를 확정한다.
- Notes: seeded fixture의 recent header와 `ui-test-squat` row까지 PR smoke에서 확인하고, search/filter depth는 nightly lane으로 남긴다.

## Entry Route / Target Lane

- Root route: `CarouselHomeView`에서 `watch-home-card-all-exercises` 또는 `watch-home-browse-all-link` 탭
- Target lane anchor:
  - `watch-quickstart-screen`
  - `watch-quickstart-list` 또는 `watch-quickstart-empty`

## AXID / Selector Inventory

- Stable screen selectors:
  - `watch-quickstart-screen`
  - `watch-quickstart-list`
  - `watch-quickstart-empty`
  - `watch-quickstart-category-picker`
- Stable section selectors:
  - `watch-quickstart-section-recent`
  - `watch-quickstart-section-preferred`
  - `watch-quickstart-section-popular`
- Dynamic row selector:
  - `watch-quickstart-exercise-{exerciseID}`

## State / Assertion Scope

- seeded scenario에서는 `watch-quickstart-list`와 `watch-quickstart-section-recent`, `watch-quickstart-exercise-ui-test-squat` 존재를 기준으로 surface를 닫는다.
- empty scenario는 `watch-quickstart-empty` 존재 여부만 optional lane으로 취급한다.
- category grouping/search/filter 결과의 exhaustive 조합은 이번 범위에서 제외한다.

## PR Gate / Nightly Lane

- PR smoke:
  - `DUNEWatchUITests/Smoke/WatchHomeSmokeTests.testNavigateToAllExercises`
  - `DUNEWatchUITests/Smoke/WatchHomeSmokeTests.testAllExercisesShowsFixtureSurface`
- Nightly / deferred:
  - richer library fixture에서 preferred/popular/filter lane 확장
