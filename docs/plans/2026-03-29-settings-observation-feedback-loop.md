---
tags: [observation, feedback-loop, swiftui, @Observable, NavigationStack, conditionSparkline, cross-observable]
date: 2026-03-29
category: plan
status: approved
---

# Plan: Fix Settings Entry Observation Tracking Feedback Loop

## Problem

Settings 진입 시 `UIObservationTrackingFeedbackLoopDetected` 반복 → UI 블락.

### Root Cause

`DashboardViewModel.conditionSparkline`이 computed property로 `ScoreRefreshService.conditionSparkline`을 read-through:

```swift
var conditionSparkline: HourlySparklineData {
    scoreRefreshService?.conditionSparkline ?? .empty
}
```

`ScoreRefreshService`는 별도 `@Observable` 객체. DashboardView body에서 `viewModel.conditionSparkline`을 읽으면 SwiftUI observation이 `ScoreRefreshService.conditionSparkline`까지 추적. `ScoreRefreshService`가 sparkline을 업데이트하면 DashboardView가 `@State` ViewModel의 coalescing을 우회하여 직접 invalidate됨.

NavigationStack 전환 중 빠른 sparkline 업데이트 → 연쇄 layout invalidation → feedback loop 감지.

### Prior Fix (weatherAtmosphere)

동일 패턴이 `weatherAtmosphere`에서 발견되어 `@State` 캐시로 수정됨 (commit 9e4ba931). `conditionSparkline`은 `.environment()`가 아닌 body read이므로 당시 감지되지 않음.

## Solution

`conditionSparkline`을 computed → stored property로 변경하여 cross-observable chain을 차단.

## Affected Files

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Dashboard/DashboardViewModel.swift` | `conditionSparkline` computed → stored `private(set) var`, `syncSparklines()` 추가 | Cross-observable read-through 제거 |

## Implementation Steps

### Step 1: Convert conditionSparkline to stored property

`DashboardViewModel.swift`:
- `var conditionSparkline: HourlySparklineData { ... }` → `private(set) var conditionSparkline: HourlySparklineData = .empty`
- Add `syncSparklines()` method: `conditionSparkline = scoreRefreshService?.conditionSparkline ?? .empty`
- Call `syncSparklines()` at end of `loadData()` (after `recordSnapshot()`)

### Verification

- `scripts/build-ios.sh` 성공
- Settings 진입 시 `UIObservationTrackingFeedbackLoopDetected` 미발생
- Hero card sparkline이 정상 표시

## Test Strategy

- 빌드 검증: `scripts/build-ios.sh`
- 기존 DUNETests 통과 확인

## Risks & Edge Cases

| Risk | Mitigation |
|------|-----------|
| Sparkline이 ScoreRefreshService 독립 업데이트 시 즉시 반영되지 않음 | 다음 loadData() 호출 시 sync — 수초 내 반영, hero sparkline에 sub-second 정밀도 불필요 |
| Initial state mismatch | Default `.empty`는 ScoreRefreshService 초기값과 동일 |
