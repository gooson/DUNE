---
tags: [linear-regression, trend-slope, ui-test, stale-test, dedup, tab-navigation, accessibility-identifier]
date: 2026-02-27
category: testing
status: implemented
---

# 13건 테스트 실패 일괄 수정

## Problem

### 증상
- Unit test 5건 실패 (CalculateTrainingReadinessUseCaseTests 3건, ExerciseViewModelTests 2건)
- UI test 8건 실패 (BodyCompositionUITests 5건, DailveUITests 1건, ExerciseUITests 2건)

### 근본 원인

**1. HRV Trend 기울기 반전 (Production Bug)**
`computeTrendBonus()`에서 `dailyAverages`가 newest-first 정렬인데,
선형 회귀의 x축(index)이 0=newest로 매핑됨.
결과: 개선 중인 HRV(최근값 > 과거값)가 음의 기울기로 계산됨.

```
dailyAverages: [52(today), 50, 48, 46, 44, 42, 40(7days ago)]
index:          0          1   2   3   4   5   6
→ values decrease as index increases → negative slope
→ 실제로는 HRV가 개선 중이므로 positive slope이어야 함
```

**2. Fatigue 재현성 가중치 테스트 설계 오류 (Test Bug)**
단일 근육으로 recency 가중치 테스트 시 `weightedSum / totalWeight = rawValue` 항상 성립.
가중치가 분자/분모 모두에 적용되어 상쇄됨.

**3. Dedup 테스트 type 불일치 (Test Bug)**
Correction #130 이후 fallback dedup에 `exerciseType == activityType.rawValue` 조건 추가.
테스트가 `exerciseType: "Deadlift"` vs `activityType: .other`로 불일치.

**4. UI 탭 구조 변경 미반영 (Test Bug)**
4탭(Today/Activity/Sleep/Body) → 3탭(Today/Activity/Wellness) 전환 후 UI 테스트 미갱신.
BodyCompositionUITests가 존재하지 않는 "Body" 탭을 탭하려 시도.
ExerciseUITests가 push 대상인 ExerciseView의 `exercise-add-button`을
Activity 탭 루트에서 직접 찾으려 시도.

## Solution

### 1. Trend slope fix (production)
`CalculateTrainingReadinessUseCase.swift` line 211:
```swift
// BEFORE:
let recent = Array(dailyAverages.prefix(7).map(\.value))

// AFTER:
// Reverse to oldest-first so index increases with time (positive slope = improving)
let recent = Array(dailyAverages.prefix(7).map(\.value).reversed())
```

### 2. Fatigue test fix
두 근육(chest + back)을 사용하여 recency 가중치가 평균에 영향을 주도록 변경:
```swift
let recentHigh = [
    makeFatigueState(muscle: .chest, hoursAgo: 12, fatigueRawValue: 8),
    makeFatigueState(muscle: .back, hoursAgo: 12, fatigueRawValue: 2),
]
```

### 3. Dedup test fix
`exerciseType`과 `activityType`을 일치시킴:
```swift
exerciseType: WorkoutActivityType.traditionalStrengthTraining.rawValue
activityType: .traditionalStrengthTraining
```

### 4. UI test fixes
- **DailveUITests**: `["Today", "Activity", "Wellness"]`로 탭 목록 갱신
- **BodyCompositionUITests**: Wellness 탭 → "Add record" 메뉴 → "Body Record" 경로로 재작성
- **ExerciseUITests**: `activity-add-button` (Activity 탭 루트)으로 변경, ExercisePickerView의 "Cancel" 버튼으로 sheet 검증

## Prevention

1. **선형 회귀 입력 정렬 검증**: time-series 데이터를 regression에 넣기 전 x축 방향(oldest→newest) 확인. 주석으로 정렬 순서 명시
2. **가중 평균 테스트는 최소 2개 데이터 포인트**: 단일 데이터에서는 가중치가 상쇄되므로, 가중치 차이가 결과에 영향을 주는 시나리오 구성
3. **Dedup 테스트에 실제 매칭 조건 반영**: Correction #130 변경 시 관련 테스트도 동시 갱신
4. **UI 구조 변경 시 UI 테스트 동시 갱신**: 탭/네비게이션 구조 변경 커밋에 UI 테스트 수정 포함

## Lessons Learned

- 시계열 데이터의 정렬 순서는 계산 결과에 치명적. 정렬 방향을 코드 주석으로 명시해야 함
- 가중 평균 테스트에서 "가중치가 효과를 발휘하는" 입력 설계가 필요
- UI 리팩토링(탭 통합)과 UI 테스트는 같은 PR에서 함께 갱신해야 stale test 축적 방지
