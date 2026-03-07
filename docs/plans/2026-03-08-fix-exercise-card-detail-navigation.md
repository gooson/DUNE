---
tags: [bugfix, localization, navigation, exercise, dashboard]
date: 2026-03-08
category: plan
status: draft
---

# Fix: 투데이탭 운동 카드 → 상세 화면 연결 버그

## Problem Statement

투데이탭 활동 섹션에서 개별 운동 카드(사이클, 웨이트 트레이닝 등)를 탭하면 해당 운동의 상세가 아닌 전체 Exercise 상세 화면이 표시됨. 차트 데이터가 비어 있고 하이라이트에 "최고 0 min / 최저 0 min"이 표시됨.

## Root Cause

`DashboardViewModel.fetchExerciseData()` (line 782)에서 `HealthMetric.name`에 **로컬라이즈된** `displayName` (예: "사이클")을 저장.
`MetricDetailView` (line 154)에서 이 로컬라이즈된 이름을 `workoutTypeName`으로 `MetricDetailViewModel`에 전달.
`MetricDetailViewModel` (line 426)에서 `WorkoutSummary.type` (항상 영어, 예: "Cycling")과 비교 → 매칭 실패 → 필터 결과 빈 배열 → 전체 Exercise 집계로 폴백.

추가로 `isDistanceBased` (line 610)도 로컬라이즈된 이름으로 비교하여 거리 기반 운동(cycling 등)이 거리 대신 시간으로 표시됨.

## Solution

`HealthMetric`에 `workoutTypeKey: String?` 필드를 추가하여 영어 타입 키를 로컬라이즈된 표시 이름과 분리.

## Affected Files

| File | Change | Risk |
|------|--------|------|
| `DUNE/Domain/Models/HealthMetric.swift` | `workoutTypeKey: String?` 필드 추가 | Low — Optional 필드, 기존 코드 영향 없음 |
| `DUNE/Presentation/Dashboard/DashboardViewModel.swift` | 메트릭 생성 시 `workoutTypeKey: type` 설정 | Low |
| `DUNE/Presentation/Shared/Detail/MetricDetailView.swift` | `metric.workoutTypeKey` 전달 | Low |
| `DUNETests/MetricDetailViewModelTests.swift` | 기존 테스트에 workoutTypeKey 반영 확인 | Low |

## Implementation Steps

### Step 1: HealthMetric에 workoutTypeKey 추가
- `HealthMetric` struct에 `var workoutTypeKey: String? = nil` 필드 추가
- 기본값 nil이므로 기존 HealthMetric 생성 코드는 변경 불필요

### Step 2: DashboardViewModel에서 workoutTypeKey 설정
- `fetchExerciseData()` 내 per-type 메트릭 생성 시 `workoutTypeKey: type` 전달
- `type`은 `Dictionary(grouping: workouts, by: \.type)`의 키 = 영어 타입명

### Step 3: MetricDetailView에서 workoutTypeKey 사용
- `workoutTypeName: metric.iconOverride != nil ? metric.name : nil` →
  `workoutTypeName: metric.workoutTypeKey`
- `workoutTypeKey`가 nil이면 per-type 카드가 아님 (기존 로직과 동일)

### Step 4: 테스트 검증
- 기존 `MetricDetailViewModelTests` 통과 확인
- 빌드 검증

## Test Strategy

- 빌드 통과 확인 (`scripts/build-ios.sh`)
- 기존 테스트 통과 확인
- 수동 검증: 한국어 locale에서 사이클 카드 탭 → Cycling 상세 데이터 표시

## Risks & Edge Cases

- `workoutTypeKey`는 `HealthKitWorkoutTitle.resolveTitle`이 반환하는 값과 동일한 영어 문자열이므로 필터 매칭 보장
- 기존 `HealthMetric` 생성 코드에서 `workoutTypeKey`를 설정하지 않는 곳은 `nil` → 기존 동작 유지
- `isDistanceBased`는 `workoutTypeName`이 이제 영어이므로 `.lowercased()`가 올바르게 작동
