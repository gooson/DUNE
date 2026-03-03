---
tags: [walking, steps, dashboard, watchos, healthkit]
category: general
date: 2026-03-03
severity: important
related_files:
  - DUNE/Presentation/Dashboard/DashboardViewModel.swift
  - DUNE/Presentation/Exercise/HealthKitWorkoutDetailView.swift
  - DUNE/Presentation/Exercise/HealthKitWorkoutDetailViewModel.swift
  - DUNE/Presentation/Exercise/CardioSession/CardioSessionViewModel.swift
  - DUNEWatch/Managers/WorkoutManager.swift
related_solutions: []
---

# Solution: Walking Step Count Visibility Parity (iOS + watchOS)

## Problem

걷기 운동에서 step count 노출이 화면/플랫폼별로 분산되어 있었다. 대시보드에서 걷기 전용 카드가 보장되지 않았고, 걷기 상세에서는 step range(운동 1회/일/주)를 전환해 볼 수 없었으며, 세션 중 실시간 step 확인도 제한적이었다.

### Symptoms

- 대시보드에 걷기 카드가 누락되거나 거리 기반 카드로 대체됨
- 걷기 상세에서 step count가 조건부로만 표시됨
- 세션 중(step live) 확인이 어려움 (특히 watch/iOS 간 UX 차이)

### Root Cause

- Dashboard 집계가 category 중심(`steps`, `exercise`)으로만 구성되어 걷기 전용 step 카드 정책이 없었음
- HealthKit workout 상세에서 step 데이터를 단일 값(있을 때만)으로만 렌더링
- 세션 매니저에서 `.stepCount` live statistics를 일관되게 수집/노출하지 않음

## Solution

걷기 경험을 `대시보드 카드` → `운동 상세` → `세션중` 흐름으로 통일했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Dashboard/DashboardViewModel.swift` | 걷기 전용 step 카드(`exercise-walking-steps`) 추가, 기존 거리 기반 walking 카드 중복 제거 | 대시보드에서 걷기 카드 존재 보장 |
| `DUNE/Presentation/Exercise/HealthKitWorkoutDetailViewModel.swift` | `StepRange(workout/day/week)` + 범위별 step 조회 추가 | 운동 1회 기본 + 일/주 범위 요구 반영 |
| `DUNE/Presentation/Exercise/HealthKitWorkoutDetailView.swift` | 걷기 상세에서 step 카드 상시 노출 + segmented picker 추가 | 걷기 상세에서 step count 항상 표시 |
| `DUNE/Presentation/Exercise/CardioSession/CardioSessionViewModel.swift` | 걷기 세션 시 당일 step baseline 대비 델타 계산 | iOS 세션 중 step 노출 |
| `DUNEWatch/Managers/WorkoutManager.swift` | HKLiveWorkoutBuilder `.stepCount` 수집 추가 | watch 세션 중 실시간 steps 반영 |
| `DUNEWatch/Views/CardioMetricsView.swift`, `DUNEWatch/Views/SessionSummaryView.swift` | watch 실시간/요약 UI에 steps 노출 | watch UX parity 확보 |
| `DUNE/Presentation/Wellness/Components/VitalCard.swift` | `resolvedIconName` 사용 | 걷기 카드 아이콘 정확성 확보 |
| `DUNETests/*` | 대시보드 걷기 카드/step range/walking session delta 테스트 추가 | 회귀 보호 |

### Key Code

```swift
// Walking detail: range-based step source
switch selectedStepRange {
case .workout: workout.stepCount ?? workoutStepCount
case .day: dayStepCount
case .week: weekStepCount
}
```

## Prevention

### Checklist Addition

- [ ] 걷기 기능 변경 시 대시보드/상세/세션중(iOS+watch) 3지점 모두에서 step 노출 일관성 확인
- [ ] HKWorkout 기반 지표는 단일값뿐 아니라 범위(workout/day/week) 요구 여부를 함께 검토

### Rule Addition (if applicable)

- 신규 rule 추가 없음 (기존 HealthKit/query pattern 범위 내 해결)

## Lessons Learned

걷기 지표는 단일 화면 개선보다 사용자 흐름 단위(요약→상세→실시간)로 정의해야 기대치와 실제 UX가 맞는다. 또한 watch와 iOS 간 parity 항목은 데이터 수집 지점(HKLiveWorkoutBuilder)부터 통일해야 후속 화면 구현이 단순해진다.
