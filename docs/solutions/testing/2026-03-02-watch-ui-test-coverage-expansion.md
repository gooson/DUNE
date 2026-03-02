---
tags: [watchos, ui-test, ci, regression, xcodegen]
date: 2026-03-02
category: solution
status: implemented
---

# Solution: Watch UI Test 커버리지 확장

## Problem

- 기존 자동 UI 테스트는 iOS `DUNEUITests`만 실행되어 watchOS UI 회귀를 탐지하지 못했다.
- 워치 홈/탐색 흐름에 테스트용 접근성 식별자가 부족해 안정적인 selector 기반 테스트 작성이 어려웠다.

## Solution

### 1. watchOS UI 테스트 타깃 추가

- `DUNE/project.yml`에 `DUNEWatchUITests`(watchOS `bundle.ui-testing`) 타깃 및 스킴 추가
- 생성 산출물:
  - `DUNE/DUNE.xcodeproj/xcshareddata/xcschemes/DUNEWatchUITests.xcscheme`
  - `DUNE/DUNE.xcodeproj/project.pbxproj` 갱신

### 2. 워치 스모크 테스트 추가

- `DUNEWatchUITests/Helpers/WatchUITestBaseCase.swift`
- `DUNEWatchUITests/Smoke/WatchHomeSmokeTests.swift`
- `DUNEWatchUITests/WatchUITests-CI.xctestplan`

검증 시나리오:
- 앱 런치 후 홈(캐러셀/빈 상태) 렌더링
- 홈에서 All Exercises 진입 후 리스트/빈 상태 렌더링

### 3. 워치 뷰 AXID 보강

- `DUNEWatch/Views/CarouselHomeView.swift`
  - `watch-home-carousel`
  - `watch-home-empty-state`
  - `watch-home-card-all-exercises`
  - `watch-home-browse-all-link`
- `DUNEWatch/Views/QuickStartAllExercisesView.swift`
  - `watch-quickstart-list`
  - `watch-quickstart-empty`

### 4. 실행 스크립트/CI 확장

- 스크립트 추가: `scripts/test-watch-ui.sh`
- 기존 워크플로 확장:
  - `.github/workflows/test-ui.yml`: iOS + watchOS job 병렬 실행
  - `.github/workflows/test-ui-nightly.yml`: nightly iOS + nightly watchOS job
- `scripts/hooks/pre-commit.sh`:
  - `DUNEWatchUITests/` 변경도 빌드 체크 트리거 대상에 포함

## Prevention

- 새 워치 UI 흐름 추가 시 AXID를 먼저 정의하고, 스모크 테스트를 최소 1개 동반한다.
- iOS와 watchOS UI 테스트는 각각 독립 job/log artifact를 유지해 실패 범위를 즉시 분리한다.

## Files

| File | Change |
|------|--------|
| `DUNE/project.yml` | `DUNEWatchUITests` 타깃/스킴 추가 |
| `DUNEWatchUITests/` | watch UI 스모크 테스트 추가 |
| `scripts/test-watch-ui.sh` | watch UI 테스트 실행 스크립트 추가 |
| `.github/workflows/test-ui.yml` | PR-merge UI 테스트에 watch job 추가 |
| `.github/workflows/test-ui-nightly.yml` | nightly UI 테스트에 watch job 추가 |
| `DUNEWatch/Views/CarouselHomeView.swift` | 홈 AXID 추가 |
| `DUNEWatch/Views/QuickStartAllExercisesView.swift` | quickstart AXID 추가 |
| `scripts/hooks/pre-commit.sh` | `DUNEWatchUITests/` 빌드 체크 대상 추가 |
