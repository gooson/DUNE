---
tags: [watch, strength, calorie, MET, healthkit, watchconnectivity, estimation]
date: 2026-03-30
category: solution
status: implemented
---

# Watch 근력운동 칼로리 미표시 해결

## Problem

Apple Watch에서 근력운동(strength workout) 완료 시 결과 화면에 칼로리가 표시되지 않음.
ExerciseRecord의 calories/estimatedCalories 필드가 모두 nil이며, HealthKit 개별 HKWorkout에도 칼로리 샘플이 누락.

### 증상
- Watch 운동 완료 후 SessionSummaryView에 칼로리 미표시
- iPhone 운동 기록 목록(UnifiedWorkoutRow)에서 칼로리 "--"
- 3/28 이전에는 정상 동작했음

### Root Cause (실제 발생 경위)

**트리거**: WC receiver 연결 수정 (`e10474d4`, 2026-03-28)

1. **이전 (3/28 전)**: `onWorkoutReceived` 콜백이 미연결 → Watch 운동 데이터는 **CloudKit sync**로만 iPhone에 도착
2. CloudKit을 통해 Watch의 ExerciseRecord가 그대로 복제됨 → HK가 strength에서도 HR 기반 activeCalories를 제공하면 `calories` 필드에 값 존재
3. **3/28 수정**: WC receiver 연결 → Watch 운동 완료 즉시 iPhone에 ExerciseRecord 생성
4. **문제**: WC 경로가 CloudKit보다 빠르므로, **calories=nil인 WC 레코드가 먼저 삽입** → CloudKit dedup이 같은 운동의 칼로리 있는 레코드를 중복으로 판단하여 차단
5. 결과: iPhone에 칼로리 없는 레코드만 남음

### 구조적 원인 (WC DTO 결함)

WC receiver 연결이 문제를 트리거했지만, 근본 원인은 `WatchWorkoutUpdate` DTO에 calories 필드가 없었던 것:

1. **WC DTO 칼로리 누락**: `WatchWorkoutUpdate`에 calories/calorieSource 필드 자체가 없음
2. **MET 추정 미사용**: Watch에서 `CalorieEstimationService` 미사용 (iOS에서만 사용)
3. **metValue 미전송**: `WatchExerciseInfo` DTO에 metValue 필드 없어 Watch에서 MET 계산 불가

### iOS vs Watch 비교

| 항목 | iOS | Watch (수정 전) | Watch (수정 후) |
|------|-----|----------------|----------------|
| 칼로리 소스 | CalorieEstimationService (MET) | HKLiveWorkoutBuilder only | MET fallback + HK |
| metValue 접근 | ExerciseDefinition 직접 | 없음 | WatchExerciseInfo.metValue |
| calorieSource | .met | .manual | .met (MET fallback 시) |
| 결과 | estimatedCalories 저장 | calories = nil | estimatedCalories 저장 |

## Solution

### Strategy: Watch에서 MET 기반 칼로리 추정 도입

HK activeCalories가 0일 때 iOS와 동일한 CalorieEstimationService MET 공식으로 fallback.

### Changes

| File | Change |
|------|--------|
| `WatchConnectivityModels.swift` | WatchExerciseInfo에 `metValue: Double?`, WatchWorkoutUpdate에 `calories/calorieSourceRaw` |
| `WatchExerciseLibraryPayloadBuilder.swift` | `ExerciseDefinition.metValue` → `WatchExerciseInfo.metValue` 전달 |
| `SessionSummaryView.swift` | `estimatedSessionCaloriesMET()` MET fallback + CalorieEstimationService 위임 |
| `SessionSummaryView.swift` | statsGrid에 "Calories" stat 추가 (~ prefix for estimates) |
| `SessionSummaryView.swift` | ExerciseRecord에 estimatedCalories/.met 저장 |
| `DUNEApp.swift` | WC 수신 시 calories/calorieSource 반영 + 범위 검증 (0-10000) |
| `project.yml` | CalorieEstimationService.swift Watch 타겟 공유 |
| Watch xcstrings | "Calories" en/ko/ja 번역 |

### Key Design Decisions

| 결정 | 이유 |
|------|------|
| CalorieEstimationService 재사용 | iOS와 동일 MET 공식으로 플랫폼 간 일관성 보장 |
| defaultBodyWeightKg 사용 | Watch에서 사용자 체중 접근 경로 미확보 — 추후 개선 가능 |
| HK 칼로리 우선 | activeCalories > 0이면 HK 값 사용, MET은 fallback only |
| ~prefix로 추정값 표시 | 사용자에게 추정값임을 명시 |
| 범위 검증 0-10000 | WC 전달 시 비정상 값 차단 |

## Prevention

### 재발 방지 체크리스트

Watch 운동 관련 변경 시 반드시 확인:
1. ExerciseRecord에 `calories` 또는 `estimatedCalories`가 저장되는지
2. `calorieSource`가 올바르게 설정되는지 (.healthKit / .met / .manual)
3. HKWorkout에 칼로리 샘플이 포함되는지
4. WatchWorkoutUpdate DTO에 칼로리 정보가 전달되는지
5. iPhone WC 수신자에서 칼로리가 ExerciseRecord에 반영되는지
6. UI에 칼로리가 표시되는지

### 새 운동 타입 추가 시

- exercises.json에 `metValue` 반드시 포함
- WatchExerciseLibraryPayloadBuilder가 metValue를 전달하는지 확인
- Watch SessionSummaryView의 MET fallback이 새 타입에서도 동작하는지 확인

## Lessons Learned

1. **iOS/Watch 칼로리 경로 비대칭**: iOS는 MET 추정을 사용하지만 Watch는 HK 의존 — 새 기능 추가 시 양 플랫폼 데이터 경로를 함께 검증해야 함
2. **WC DTO 필드 누락은 silent failure**: 칼로리 없이도 빌드/테스트 통과 — 데이터 완전성 체크리스트 필요
3. **CalorieEstimationService 공유**: Domain 서비스를 Watch 타겟에 공유하면 로직 중복 방지 + 단일 진실 소스 유지
