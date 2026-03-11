---
tags: [testing, ci, ai-prompt, healthkit, watchos, rpe]
date: 2026-03-12
category: plan
status: draft
---

# Plan: CI Nightly Test Failures Fix (Run #22971198790)

## Problem Summary

CI nightly run에서 2개 job이 실패:
1. **nightly-ios-unit-tests**: 1791 tests 중 2건 실패
2. **nightly-watch-ui-tests**: 8 tests 중 4건 실패

## Root Cause Analysis

### iOS Failure 1: AIWorkoutTemplateGeneratorTests (line 101)

- **Test**: "Summarizes frequent recent exercises and recovered muscles"
- **Expectation**: `lines.contains { $0.contains("Push Up") }`
- **Root Cause**: `topRecentExercises()` in `AIWorkoutTemplateGenerator.swift:238`이 `definition.localizedName`("푸시업")을 반환. AI 프롬프트 생성 컨텍스트에서는 영어 canonical `name`("Push Up")을 사용해야 함.
- **Fix**: `definition.localizedName` → `definition.name` in `topRecentExercises()`

### iOS Failure 2: DashboardViewModelTests (line 412)

- **Test**: "Deferred HealthKit gate skips protected queries until launch authorization completes"
- **Expectation**: `vm.sortedMetrics.contains { $0.category == .hrv }`
- **Root Cause**: 테스트가 `CountingDashboardSharedHealthDataService(snapshot: makeEmptySharedSnapshot())`를 주입. `canLoadHealthKitData: true`일 때 `safeHRVFetch()`가 비어있는 snapshot을 받아 빈 metrics를 반환. MockHRVService의 sample data에 도달하지 못함.
- **Fix**: 테스트의 shared snapshot에 HRV 데이터를 포함시킴 (테스트 의도: gate mechanism + fetch count 검증이므로 snapshot 경로를 사용하는 것이 맞음)

### Watch UI Failures (4건)

- **공통 원인**: 최근 RPE visibility 변경으로 `SetInputSheet`에 `WatchSetRPEPickerView`가 추가됨. 세로 콘텐츠가 watch 화면을 초과하여 하단 요소가 접근 불가.
- **testStrengthWorkoutShowsInputAndMetricsSurfaces**: RPE 컨트롤이 SetInputSheet에서 off-screen
- **testControlsSurfaceIsReachableDuringStrengthWorkout**: SetInputSheet 문제로 인해 세션 네비게이션 실패 가능성
- **testRestTimerAppearsAfterCompletingFirstSet**: Rest timer skip 버튼 미발견
- **testSingleExerciseWorkoutCanReachSummarySurface**: Rest timer skip 실패로 summary 도달 불가
- **Fix**: SetInputSheet 콘텐츠를 `ScrollView`로 감싸서 모든 요소 접근 가능하게 함. Rest timer 테스트는 별도 원인 여부 빌드 후 확인.

## Affected Files

| File | Change | Risk |
|------|--------|------|
| `DUNE/Data/Services/AIWorkoutTemplateGenerator.swift` | `localizedName` → `name` in `topRecentExercises()` | Low — AI 프롬프트 전용 코드 |
| `DUNETests/DashboardViewModelTests.swift` | 테스트 snapshot에 HRV 데이터 추가 | Low — 테스트 코드만 변경 |
| `DUNEWatch/Views/SetInputSheet.swift` | VStack → ScrollView 래핑 | Medium — watch UI 레이아웃 변경 |

## Implementation Steps

1. `AIWorkoutTemplateGenerator.topRecentExercises()` 수정
2. `DashboardViewModelTests.deferredHealthKitGateSkipsProtectedQueriesUntilEnabled()` 수정
3. `SetInputSheet` ScrollView 래핑
4. 빌드 검증
5. 테스트 실행 검증

## Test Strategy

- iOS unit tests: `xcodebuild test -project DUNE/DUNE.xcodeproj -scheme DUNETests` 로 2건 수정 확인
- Watch UI: CI에서 확인 (로컬 watch simulator 테스트는 CI와 환경 차이 가능)

## Risks

- SetInputSheet에 ScrollView 추가 시 Digital Crown rotation과 충돌 가능성 → `.focusable` + `.digitalCrownRotation` 이 ScrollView 내에서도 작동하는지 확인 필요
- Rest timer 테스트는 CI simulator 타이밍 이슈일 수 있음 → SetInputSheet 수정 후에도 실패하면 timeout 증가 필요
