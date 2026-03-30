---
tags: [watch, strength, calorie, MET, healthkit, watchconnectivity]
date: 2026-03-30
category: plan
status: approved
---

# Watch 근력운동 칼로리 미표시 버그 수정

## Problem Statement

Apple Watch에서 근력운동(strength workout) 완료 시 결과 화면에 칼로리가 표시되지 않음.
- ExerciseRecord의 `calories` 필드가 nil
- HealthKit 개별 HKWorkout에도 칼로리 샘플이 누락
- iPhone의 운동 기록 목록(UnifiedWorkoutRow)에서도 칼로리 "--" 표시

## Root Cause Analysis

### 데이터 흐름 분석

```
Watch Strength Workout:
1. HKWorkoutSession + HKLiveWorkoutBuilder 시작 (.traditionalStrengthTraining)
2. workoutBuilder(_:didCollectDataOf:) 콜백에서 activeEnergyBurned 수집
3. 근력운동은 Apple Watch 모션 센서의 칼로리 추정 정확도가 낮아 activeCalories ≈ 0
4. Session 종료 → builder.discardWorkout() (개별 HKWorkout 생성을 위해)
5. SessionSummaryView에서 perExerciseAllocation() 호출
6. activeCalories > 0 ? activeCalories / activeCount : nil → nil 반환
7. ExerciseRecord(calories: nil), HKWorkout에도 칼로리 샘플 미추가
```

### 핵심 원인

| # | 원인 | 위치 | 설명 |
|---|------|------|------|
| 1 | HK 칼로리 미수집 | WorkoutManager.swift:1189 | 근력운동에서 activeCalories ≈ 0 |
| 2 | nil 반환 조건 | SessionSummaryView.swift:403 | `activeCalories > 0 ? ... : nil` |
| 3 | MET 추정 미사용 | Watch 전체 | CalorieEstimationService가 iOS에서만 사용됨 |
| 4 | metValue 미전송 | WatchExerciseInfo | Watch로 동기화되는 DTO에 metValue 필드 없음 |
| 5 | WC DTO 칼로리 누락 | WatchWorkoutUpdate | iPhone 전송 시 calories 필드 없음 |

### iOS 대비 Watch의 차이

| 항목 | iOS (WorkoutSessionViewModel) | Watch (SessionSummaryView) |
|------|------|------|
| 칼로리 소스 | CalorieEstimationService (MET 기반) | HKLiveWorkoutBuilder (모션 기반) |
| metValue 접근 | ExerciseDefinition.metValue 직접 접근 | 없음 (WatchExerciseInfo에 metValue 없음) |
| bodyWeight 접근 | WorkoutSettingsStore.shared.bodyWeightKg | 없음 |
| calorieSource | `.met` | `.manual` (activeCalories 없을 때) |
| 결과 | estimatedCalories 필드에 MET 계산값 | calories = nil |

## Solution Design

### Strategy: Watch에서 MET 기반 칼로리 추정 도입

iOS와 동일한 `CalorieEstimationService` MET 공식을 Watch에서도 사용.
근력운동의 경우 HKLiveWorkoutBuilder의 activeCalories가 0이면 MET 기반으로 추정.

### Step 1: WatchExerciseInfo에 metValue 추가

**파일**: `DUNE/Domain/Models/WatchConnectivityModels.swift`

- `WatchExerciseInfo`에 `let metValue: Double?` 추가
- init에 metValue 파라미터 추가

### Step 2: WatchExerciseLibraryPayloadBuilder에서 metValue 전달

**파일**: `DUNE/Data/WatchConnectivity/WatchExerciseLibraryPayloadBuilder.swift`

- `makePayload()` 내부에서 `ExerciseDefinition.metValue` → `WatchExerciseInfo.metValue`로 전달

### Step 3: Watch SessionSummaryView에서 MET 칼로리 추정

**파일**: `DUNEWatch/Views/SessionSummaryView.swift`

- `perExerciseAllocation()` 수정:
  - activeCalories > 0이면 HK 칼로리 사용 (기존)
  - activeCalories == 0이면 MET 기반 추정 사용
- MET 추정에 필요한 데이터:
  - `metValue`: WorkoutManager의 templateSnapshot → entries에서 추출
  - `bodyWeightKg`: `CalorieEstimationService.defaultBodyWeightKg` (70kg) 사용
  - `durationSeconds`: 세션 시간
  - `restSeconds`: 세트 수 × 기본 휴식 시간으로 추정

### Step 4: Watch statsGrid에 칼로리 표시

**파일**: `DUNEWatch/Views/SessionSummaryView.swift`

- 근력운동 statsGrid에 "Calories" stat 추가 (현재 Duration, Volume, Sets, Avg HR만 표시)
- 카디오는 기존 HK activeCalories 표시 (변경 없음)

### Step 5: ExerciseRecord에 estimatedCalories 저장

**파일**: `DUNEWatch/Views/SessionSummaryView.swift`

- MET 추정 칼로리를 `estimatedCalories` 필드에 저장
- `calorieSource`를 `.met`으로 설정
- HK 개별 워크아웃에도 MET 칼로리 전달

### Step 6: WatchWorkoutUpdate에 calories/calorieSource 추가

**파일**: `DUNE/Domain/Models/WatchConnectivityModels.swift`

- `WatchWorkoutUpdate`에 `var calories: Double?`와 `var calorieSource: String?` 추가
- Watch → iPhone 전송 시 칼로리 정보 포함

### Step 7: iPhone 수신 측에서 calories 처리

**파일**: `DUNE/Data/WatchConnectivity/WatchSessionManager.swift`

- `handleWorkoutCompletion()` (또는 관련 receiver)에서 WC DTO의 calories 반영

### Step 8: 유닛 테스트

- CalorieEstimationService 기존 테스트 확인 (이미 존재)
- MET 추정 fallback 로직 테스트 추가
- WatchExerciseInfo metValue 직렬화 테스트 추가

## Affected Files

| File | Change |
|------|--------|
| `DUNE/Domain/Models/WatchConnectivityModels.swift` | WatchExerciseInfo에 metValue, WatchWorkoutUpdate에 calories/calorieSource 추가 |
| `DUNE/Data/WatchConnectivity/WatchExerciseLibraryPayloadBuilder.swift` | metValue 전달 |
| `DUNEWatch/Views/SessionSummaryView.swift` | MET fallback 칼로리 추정 + statsGrid 칼로리 표시 |
| `DUNEWatch/Managers/WatchWorkoutWriter.swift` | MET 칼로리를 HKWorkout에 포함 (변경 없음 - 이미 calories 파라미터 지원) |
| `DUNE/Data/WatchConnectivity/WatchSessionManager.swift` | WC 수신 시 calories 반영 |
| `DUNETests/` | 유닛 테스트 추가 |

## Test Strategy

### Unit Tests
- `CalorieEstimationService`: 이미 존재 (CalorieEstimationTests.swift)
- WatchExerciseInfo Codable: metValue 포함 직렬화 검증
- MET fallback: activeCalories=0일 때 MET 추정이 사용되는지

### Integration Verification
- Watch 시뮬레이터에서 근력운동 완료 후 SessionSummaryView에 칼로리 표시 확인
- iPhone에서 Watch 운동 기록의 칼로리가 UnifiedWorkoutRow에 표시되는지 확인
- HealthKit에 개별 HKWorkout에 칼로리 샘플이 포함되는지 확인

## Risks & Edge Cases

| Risk | Mitigation |
|------|-----------|
| Watch에서 exercise library 미수신 시 metValue nil | metValue nil이면 칼로리 추정 스킵 (기존 동작 유지) |
| MET 추정 정확도 | iOS와 동일한 공식 사용, ~를 붙여 추정값 표시 |
| bodyWeight 설정 미동기화 | Watch에서는 defaultBodyWeightKg(70kg) 사용 — 추후 설정 동기화로 개선 가능 |
| 기존 WC DTO 호환성 | 새 필드는 Optional이므로 이전 버전 iPhone과 호환 |
| HK activeCalories가 양수인 경우 중복 | HK 칼로리 > 0이면 HK 우선 사용, MET 무시 |

## Localization

- "Calories" 라벨: Watch statsGrid에 새 추가 → xcstrings 등록 필요 (en/ko/ja)
- "~{N} kcal" 형식: 추정값 표시 패턴 → xcstrings 등록 필요

## Prevention

- Watch 운동 관련 변경 시 칼로리 흐름 체크리스트:
  1. ExerciseRecord에 calories 또는 estimatedCalories가 저장되는지
  2. HKWorkout에 칼로리 샘플이 포함되는지
  3. WC DTO에 칼로리 정보가 전달되는지
  4. UI에 칼로리가 표시되는지
