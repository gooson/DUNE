---
tags: [healthkit, cardio, iphone, apple-watch, workout-detail, activity-type, no-data-ux]
category: general
date: 2026-03-02
severity: important
related_files:
  - DUNE/Presentation/Exercise/HealthKitWorkoutDetailView.swift
  - DUNE/Presentation/Exercise/HealthKitWorkoutDetailViewModel.swift
  - DUNE/Presentation/Exercise/CardioSession/CardioSessionSummaryView.swift
  - DUNE/Presentation/Exercise/WorkoutSessionView.swift
  - DUNE/Presentation/Exercise/CompoundWorkoutView.swift
  - DUNE/Data/HealthKit/ExerciseCategory+HealthKit.swift
  - DUNETests/HealthKitWorkoutDetailViewModelTests.swift
  - DUNETests/WorkoutWriteServiceTests.swift
related_solutions:
  - healthkit/ios-cardio-live-tracking.md
  - architecture/2026-03-02-ios-cardio-live-tracking.md
---

# Solution: Phone/Watch Cardio Detail Parity and HealthKit Type Consistency

## Problem

iPhone에서 앱 내부 시작으로 생성된 유산소 기록 상세 화면이 워치/Apple Fitness 대비 빈약하게 보이는 케이스가 있었다.

### Symptoms

- 달리기 상세에서 거리(km), 심박, 페이스 카드가 통째로 사라지는 경우 발생
- 데이터가 없는 상태가 "카드 숨김"으로 표현되어 운동별/기기별 레이아웃이 달라 보임
- HealthKit write 입력에서 activity type이 명시되지 않아 추론 품질에 의존

### Root Cause

- `HealthKitWorkoutDetailView`가 핵심 지표를 `if let` 기반으로만 렌더링해 누락 시 UI 자체가 제거됨
- 헤더 거리 표시도 `distance > 0` 조건에 종속되어 0/누락 세션에서 사라짐
- 저장 경로 일부(`CardioSessionSummaryView`, `WorkoutSessionView`, `CompoundWorkoutView`)에서 `WorkoutWriteInput.activityType` 전달이 일관되지 않음

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `HealthKitWorkoutDetailView.swift` | 거리 기반 활동은 헤더 km 고정 노출, 핵심 카드 no-data 카드 추가 | 거리/심박/페이스 누락 시에도 레이아웃 정합성 유지 |
| `HealthKitWorkoutDetailViewModel.swift` | `heartRateAverage(for:)`, `heartRateMax(for:)` fallback 추가 | workout summary 값 누락 시 로드된 HR summary를 카드에 재사용 |
| `CardioSessionSummaryView.swift` | HealthKit write 시 `activityType` 전달 | iPhone cardio 저장 타입 정합성 강화 |
| `WorkoutSessionView.swift` | cardio(`durationDistance`)인 경우 `activityType` + 거리 전달 | manual cardio write 정합성 보강, 비-cardio 부작용 방지 |
| `CompoundWorkoutView.swift` | cardio 항목에 한해 `activityType` + 거리 전달 | compound 저장 시 cardio type/distance 품질 개선 |
| `ExerciseCategory+HealthKit.swift` | 한국어 운동명 키워드 매핑 추가 | 로컬라이즈 이름 입력에서도 안정적 activity type 추론 |
| `HealthKitWorkoutDetailViewModelTests.swift` | 신규 테스트 추가 | HR 카드 fallback 로직 회귀 방지 |
| `WorkoutWriteServiceTests.swift` | 한국어 매핑 테스트 추가 | 이름 기반 type 추론 회귀 방지 |

### Key Code

```swift
let hrAvg = viewModel.heartRateAverage(for: workout)
if let hrAvg {
    statCard(..., value: Int(hrAvg).formattedWithSeparator, unit: "bpm")
} else if workout.activityType.isDistanceBased {
    noDataStatCard(icon: "heart.fill", iconColor: .red, title: "Avg Heart Rate")
}
```

```swift
let input = WorkoutWriteInput(
    startDate: data.startDate,
    duration: data.duration,
    category: data.category,
    exerciseName: data.exerciseName,
    estimatedCalories: data.estimatedCalories,
    isFromHealthKit: false,
    distanceKm: data.distanceKm,
    activityType: viewModel.activityType
)
```

## Prevention

### Checklist Addition

- [ ] HealthKit workout detail에서 핵심 지표는 값 누락 시 "카드 숨김" 대신 안내 UI를 제공하는지 확인
- [ ] iPhone workout write 경로에서 cardio activity type이 명시 전달되는지 확인
- [ ] 로컬라이즈 운동명(ko/en)에서 type 추론 테스트가 존재하는지 확인

### Rule Addition (if applicable)

현재 규칙 추가는 불필요. 다만 HealthKit detail UI 리뷰 시 "값 누락 시 카드 제거 금지"를 리뷰 체크리스트로 유지한다.

## Lessons Learned

- 데이터 신뢰성과 UX 일관성은 별개 문제다. 센서 데이터가 없어도 레이아웃 일관성을 유지하면 사용자는 상태를 더 잘 이해한다.
- cardio write에서 `activityType`를 명시 전달하면 downstream query/표시 품질이 안정된다.
- 이름 기반 추론은 로컬라이즈 언어(한국어/영어) 테스트를 함께 고정해야 회귀를 막을 수 있다.
