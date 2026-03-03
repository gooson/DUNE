---
tags: [stair-climber, flights-climbed, healthkit, cardio, watch]
date: 2026-03-03
category: plan
status: approved
---

# Plan: Stair Climber 운동 강화 + 층수 추적

## 배경

exercises.json에 stair-climber 운동이 이미 `cardioSecondaryUnit: "floors"`로 정의되어 있으나,
실제 HealthKit `flightsClimbed` 수집 및 UI 표시가 구현되지 않음.

## 변경 파일

| # | 파일 | 변경 내용 |
|---|------|----------|
| 1 | `DUNE/Data/Resources/exercises.json` | 한국어 alias 추가 |
| 2 | `DUNEWatch/Managers/WorkoutManager.swift` | flightsClimbed 수집 + 프로퍼티 |
| 3 | `DUNEWatch/Views/CardioMetricsView.swift` | stair 타입 시 층수 표시 |
| 4 | `DUNE/Domain/Models/HealthMetric.swift` | WorkoutSummary에 flightsClimbed 필드 |
| 5 | `DUNE/Data/HealthKit/WorkoutQueryService.swift` | flightsClimbed 추출 |
| 6 | `DUNE/Presentation/Exercise/CardioSession/CardioSessionSummaryView.swift` | 요약에 층수 |
| 7 | `DUNE/Presentation/Exercise/HealthKitWorkout/HealthKitWorkoutDetailView.swift` | 상세에 층수 |
| 8 | `DUNE/Resources/Localizable.xcstrings` | 새 번역 키 |
| 9 | `DUNE/DUNEWatch/Resources/Localizable.xcstrings` | Watch 번역 키 |

## 구현 순서

### Step 1: exercises.json alias 추가
- stair-climber: `"aliases": ["천국의 계단", "스텝밀", "StairMaster"]`
- stair-climber-intervals: `"aliases": ["천국의 계단 인터벌"]`
- stair-climber-endurance: `"aliases": ["천국의 계단 지구력"]`
- stair-climber-recovery: `"aliases": ["천국의 계단 리커버리"]`

### Step 2: WorkoutManager flightsClimbed 수집
- readTypes에 `HKQuantityType(.flightsClimbed)` 추가
- `@Published var floorsClimbed: Double = 0` 프로퍼티 추가
- didCollectDataOf에 flightsClimbed case 추가
- restoreDistanceFromBuilder에 floors 복구 추가

### Step 3: CardioMetricsView 층수 표시
- stair 타입 판별 헬퍼 추가
- distance 대신 floors 표시 (stair 타입 한정)
- 단위: "floors" / "층"

### Step 4: WorkoutSummary + WorkoutQueryService
- `flightsClimbed: Double?` 필드 추가
- toSummary()에서 HKQuantityType(.flightsClimbed) 추출
- 검증: >= 0, isFinite, < 10_000

### Step 5: iOS 요약/상세 UI 층수 표시
- CardioSessionSummaryView: stair 타입 시 floors 표시
- HealthKitWorkoutDetailView: flightsClimbed 표시

### Step 6: Localization
- "Floors Climbed", "floors", "%lld floors" 번역 추가
