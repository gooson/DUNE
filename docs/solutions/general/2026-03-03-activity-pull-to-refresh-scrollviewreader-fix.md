---
tags: [swiftui, activity-tab, pull-to-refresh, scrollviewreader, ui-regression]
category: general
date: 2026-03-03
severity: important
related_files:
  - DUNE/Presentation/Activity/ActivityView.swift
  - DUNE/Presentation/Shared/Components/WaveRefreshIndicator.swift
  - DUNEUITests/Helpers/UITestHelpers.swift
  - DUNEUITests/Smoke/ActivitySmokeTests.swift
related_solutions:
  - docs/solutions/general/2026-02-26-review-fixes-refresh-feedback-doc-sync.md
---

# Solution: Activity 탭 Pull-to-Refresh 미동작 회귀 수정

## Problem

Activity 탭에서 pull-to-refresh 제스처를 내려도 wave indicator가 나타나지 않고, 수동 새로고침 체감이 되지 않는 문제가 발생했다.

### Symptoms

- Activity 화면 상단에서 `swipeDown` 시 refresh 피드백이 보이지 않음
- 동일 `waveRefreshable`을 쓰는 다른 탭 대비 Activity만 동작이 불안정함

### Root Cause

`waveRefreshable` modifier가 실제 스크롤 컨테이너(`ScrollView`)가 아니라 `ScrollViewReader` 레벨에 적용되어, `UIRefreshControl` 연결이 안정적으로 성립하지 않았다.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Activity/ActivityView.swift` | `waveRefreshable`를 outer container에서 inner `ScrollView`로 이동 | pull-to-refresh를 실제 scroll host에 직접 연결 |
| `DUNE/Presentation/Shared/Components/WaveRefreshIndicator.swift` | indicator에 `accessibilityIdentifier("wave-refresh-indicator")` 추가 | UI 테스트에서 refresh 피드백 검증 가능하게 함 |
| `DUNEUITests/Helpers/UITestHelpers.swift` | `AXID.waveRefreshIndicator` 상수 추가 | 테스트 식별자 단일 소스 유지 |
| `DUNEUITests/Smoke/ActivitySmokeTests.swift` | `testPullToRefreshShowsWaveIndicator` 추가 | 회귀 방지용 smoke 시나리오 확보 |

### Verification

- Unit: `ActivityViewModelTests` 통과
- UI: 신규 smoke 테스트는 작성 완료. 단, 실행 환경에서 `CoreSimulatorService/simdiskimaged` 불안정으로 destination lookup 실패가 반복되어 자동 실행 검증은 보류됨.

## Prevention

### Checklist

- [ ] `refreshable`/custom refresh modifier는 반드시 실제 `ScrollView`/`List`에 직접 적용한다.
- [ ] pull-to-refresh 회귀 수정 시 indicator를 UI 테스트에서 탐지 가능한 AXID로 노출한다.
- [ ] UI 테스트 실패 시 assertion 실패와 인프라(CoreSimulator) 실패를 구분해 기록한다.

## Lessons Learned

SwiftUI에서 refresh 동작은 modifier의 **적용 위치**에 민감하다. 동작 자체를 수정할 때는 gesture-trigger 경로와 테스트 관찰성(AXID)을 함께 보강해야 회귀를 안정적으로 막을 수 있다.
