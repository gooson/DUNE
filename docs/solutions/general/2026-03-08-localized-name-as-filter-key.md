---
tags: [localization, navigation, exercise, filter, dashboard, i18n-bug]
date: 2026-03-08
category: solution
status: implemented
---

# 로컬라이즈된 이름을 필터 키로 사용한 버그

## Problem

투데이탭 활동 섹션에서 개별 운동 카드(사이클, 달리기 등)를 탭하면 해당 운동 상세가 아닌 전체 Exercise 상세가 표시됨. 차트 데이터 비어 있고 하이라이트 0 min 표시.

### 원인

`DashboardViewModel.fetchExerciseData()`에서 `HealthMetric.name`에 **로컬라이즈된** `displayName` (예: "사이클")을 저장. 이 값이 `MetricDetailViewModel`로 전달되어 `WorkoutSummary.type` (항상 영어, 예: "Cycling")과 비교됨. 한국어/일본어 환경에서 매칭 실패 → 빈 결과.

추가로 `isDistanceBased` 판정도 로컬라이즈된 이름으로 수행되어 거리 기반 운동이 거리 대신 시간으로 표시됨.

## Solution

`HealthMetric`에 `workoutTypeKey: String?` 필드를 추가하여 영어 타입 키를 UI 표시용 로컬라이즈된 `name`과 분리.

### 변경 파일

| File | Change |
|------|--------|
| `HealthMetric.swift` | `var workoutTypeKey: String? = nil` 추가 |
| `DashboardViewModel.swift` | 메트릭 생성 시 `workoutTypeKey: type` 설정 (영어 그룹핑 키) |
| `MetricDetailView.swift` | `metric.workoutTypeKey` 전달 (기존: `metric.name`) |

## Prevention

### 패턴: 필터 키 vs 표시 이름 분리

로컬라이즈된 문자열을 데이터 필터/매칭 키로 사용하면 안 됨. 항상 분리:

```swift
// BAD: 표시 이름을 필터 키로 사용
name: activityType.displayName  // "사이클" (localized)
// ... later ...
workouts.filter { $0.type == name }  // "Cycling" != "사이클" → 실패

// GOOD: 별도 키 필드
name: activityType.displayName  // "사이클" (for UI)
workoutTypeKey: type            // "Cycling" (for filtering)
```

### 체크리스트

- [ ] 문자열 비교가 있는 곳에서 비교 대상이 동일한 locale인지 확인
- [ ] `displayName`이 데이터 필터/매칭에 사용되지 않는지 확인
- [ ] `String(localized:)` 반환값을 비교 키로 사용하지 않는지 확인
