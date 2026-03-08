---
source: brainstorm/e2e-ui-test-plan-all-targets
priority: p2
status: done
created: 2026-03-08
updated: 2026-03-09
---

# E2E Surface: DUNEWatch CarouselHomeView

- Target: `DUNEWatch`
- Source: `DUNEWatch/Views/CarouselHomeView.swift`
- Entry: watch app root
- [x] entry route와 target lane을 정의한다.
- [x] AXID / selector inventory를 고정한다.
- [x] 주요 state와 assertion 범위를 정리한다.
- [x] PR gate / nightly 배치를 확정한다.
- Notes: home root와 card selector는 `WatchWorkoutSurfaceAccessibility.home*`로 통일했고, PR smoke는 `DUNEWatchUITests/Smoke/WatchHomeSmokeTests.swift`에서 유지한다.

## Entry Route / Target Lane

- Launch target: `DUNEWatch`
- Root route: watch app launch → idle root
- Target lane anchor:
  - `watch-home-root`
  - `watch-home-carousel` 또는 `watch-home-empty-state`

## AXID / Selector Inventory

- Stable root/state selectors:
  - `watch-home-root`
  - `watch-home-carousel`
  - `watch-home-empty-state`
- Stable CTA selectors:
  - `watch-home-card-all-exercises`
  - `watch-home-browse-all-link`
- Dynamic card selector:
  - `watch-home-card-{cardID}`
- Selector helper:
  - `WatchWorkoutSurfaceAccessibility.home*`

## State / Assertion Scope

- `watch-home-root`와 `watch-home-carousel`이 함께 보이면 seeded home lane 진입 성공으로 간주한다.
- sync/library가 비어 있는 경우에는 `watch-home-empty-state`를 fallback surface로 허용한다.
- PR 범위에서는 all-exercises CTA 진입까지만 assert 하고, 개별 routine/recent/preferred card 순서나 scroll depth는 고정하지 않는다.

## PR Gate / Nightly Lane

- PR smoke:
  - `DUNEWatchUITests/Smoke/WatchHomeSmokeTests.testHomeRenders`
  - `DUNEWatchUITests/Smoke/WatchHomeSmokeTests.testNavigateToAllExercises`
- Nightly / deferred:
  - multi-card seeded fixture에서 dynamic `watch-home-card-{cardID}` scroll/assert 확장
