---
topic: walking-step-count-visibility
date: 2026-03-03
status: draft
confidence: medium
related_solutions: []
related_brainstorms:
  - docs/brainstorms/2026-03-03-walking-step-count-visibility.md
---

# Implementation Plan: Walking Step Count Visibility

## Context

걷기 운동에서 step count를 일관되게 보여주지 못해, 사용자가 핵심 지표(걷기 1회 걸음 수)를 즉시 확인하기 어렵다. 대시보드 걷기 카드 존재 보장, 걷기 상세의 step count 상시 노출, 세션 중 step 표시(iOS/watch), 그리고 운동 1회 기본 + 일/주 범위 조회가 필요하다.

## Requirements

### Functional

- 대시보드 Activity 섹션에 걷기 전용 카드(steps 기반)를 노출한다.
- 걷기 운동 상세에서 step count를 항상 표시한다(데이터 없으면 명시적으로 빈 상태 표시).
- 걷기 운동 상세에서 step 범위를 `Workout / Day / Week`로 전환해 조회한다.
- 세션 중(step live) 걷기 step count를 iOS/watch에서 표시한다.

### Non-functional

- 기존 HealthKit 권한/쿼리 실패 시 앱 크래시 없이 graceful fallback.
- 기존 Dashboard/Workout/Watch 회귀 테스트를 유지한다.
- 데이터 계층/프리젠테이션 계층 경계를 유지한다.

## Approach

- DashboardViewModel에서 걷기 workout을 별도 집계해 `exercise` 카테고리의 걷기 step 카드(아이콘 override: walk)를 추가한다.
- HealthKitWorkoutDetailViewModel에 걷기 step 범위 데이터(`workout/day/week`)를 로드하는 로직을 추가하고, View에서 범위 선택 UI + 상시 step 카드로 렌더링한다.
- iOS CardioSessionViewModel은 걷기 세션일 때 당일 steps 델타(시작 시점 대비 현재)를 주기적으로 계산해 세션중 step 표시를 제공한다.
- watch WorkoutManager는 HKLiveWorkoutBuilder에서 `.stepCount` 통계를 수집해 CardioMetrics/SessionSummary에 노출한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| HKWorkout에 저장된 stepCount만 사용 | 구현 단순 | 세션중/live 표시 불가, 상세 fallback 약함 | 기각 |
| CoreMotion CMPedometer 기반 실시간 steps | iOS 실시간 정확도 높음 | 권한/디바이스 제약 증가, 테스트 복잡도 증가 | 보류 |
| HealthKit steps 델타 기반(iOS) + HKLive builder(watch) | 기존 인프라 재사용, 구현 리스크 낮음 | iOS는 외부 동시 걸음 영향 가능 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| DUNE/Presentation/Dashboard/DashboardViewModel.swift | 수정 | 걷기 전용 steps 카드 생성 로직 추가 |
| DUNE/Presentation/Exercise/HealthKitWorkoutDetailViewModel.swift | 수정 | 걷기 steps 범위(workout/day/week) 로드/노출 로직 추가 |
| DUNE/Presentation/Exercise/HealthKitWorkoutDetailView.swift | 수정 | 걷기 steps 상시 카드 + 범위 선택 UI 추가 |
| DUNE/Presentation/Exercise/CardioSession/CardioSessionViewModel.swift | 수정 | 걷기 세션중 steps 델타 계산 추가 |
| DUNE/Presentation/Exercise/CardioSession/CardioSessionView.swift | 수정 | 걷기 세션중 step metric 표시 |
| DUNEWatch/Managers/WorkoutManager.swift | 수정 | watch live stepCount 수집/상태 보관 |
| DUNEWatch/Views/CardioMetricsView.swift | 수정 | watch cardio 화면 step metric 표시 |
| DUNEWatch/Views/SessionSummaryView.swift | 수정 | watch cardio 요약에 steps 표시 |
| DUNETests/DashboardViewModelTests.swift | 수정 | 걷기 카드 생성 검증 테스트 추가/보정 |
| DUNETests/HealthKitWorkoutDetailViewModelTests.swift | 수정 | 걷기 step range 계산 테스트 추가 |
| DUNETests/CardioSessionViewModelTests.swift | 수정 | 걷기 세션 step 표시/갱신 테스트 추가 |

## Implementation Steps

### Step 1: Dashboard 걷기 카드 추가

- **Files**: `DashboardViewModel.swift`, `DashboardViewModelTests.swift`
- **Changes**:
  - 걷기 workouts를 별도 필터링
  - 운동 1회(stepCount) 기본값 + day/week 집계 기반 delta 계산
  - 기존 per-type exercise 루프에서 중복 걷기 카드 제거
- **Verification**:
  - Activity cards에 `Walking` 카드가 생성되는지 테스트
  - 기존 steps/exercise 카드 테스트 회귀 통과

### Step 2: 걷기 상세 step range 구현

- **Files**: `HealthKitWorkoutDetailViewModel.swift`, `HealthKitWorkoutDetailView.swift`, `HealthKitWorkoutDetailViewModelTests.swift`
- **Changes**:
  - workout/day/week 범위 step 조회 상태 추가
  - 걷기일 때 step 카드 항상 표시 + 범위 Picker UI
  - step 미수집 시 no-data 상태 표시
- **Verification**:
  - 걷기 상세에서 3개 범위 값이 렌더링되는지 단위 테스트
  - 걷기 외 운동의 기존 상세 UI 동작 유지

### Step 3: 세션중 step 표시(iOS/watch)

- **Files**: `CardioSessionViewModel.swift`, `CardioSessionView.swift`, `WorkoutManager.swift`, `CardioMetricsView.swift`, `SessionSummaryView.swift`, 관련 테스트
- **Changes**:
  - iOS: 걷기 세션 시작 시 baseline steps 확보 후 주기적으로 델타 업데이트
  - watch: HKLiveWorkoutBuilder에서 stepCount 수집 및 UI 반영
  - watch summary에 cardio steps 추가
- **Verification**:
  - iOS 걷기 세션에서 step metric 노출 확인
  - watch cardio metrics/sumary에서 step 표시 확인

## Edge Cases

| Case | Handling |
|------|----------|
| 걷기 workout에 stepCount가 비어 있음 | 상세에서 No data 표시, day/week는 별도 조회값 사용 |
| 자정 경계 세션 | 상세 day/week 집계는 workout startDate 기준 캘린더 범위 적용 |
| HealthKit 권한 거부/실패 | 단계별 쿼리 실패 시 nil 처리 후 UI fallback |
| iOS 세션 중 외부 걸음 동시 증가 | 델타 방식 한계 명시, 음수/비정상값은 0으로 보정 |

## Testing Strategy

- Unit tests:
  - Dashboard walking card 생성/중복 제거
  - workout/day/week step range 계산
  - cardio walking step delta 계산
- Integration tests:
  - Dashboard loadData 후 Activity cards 구성 검증
  - Watch WorkoutManager live metrics 반영 검증
- Manual verification:
  - iPhone 걷기 세션 시작 후 step live 증가 확인
  - 걷기 workout 상세에서 range 전환 시 값 변경 확인
  - Watch cardio 화면/요약 steps 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| iOS steps 델타가 세션 외 활동에 영향 | Medium | Medium | 걷기 세션 중만 표시 + 음수 보정 + 후속 CMPedometer 개선 여지 |
| HealthKit 통계 지연으로 상세 값 불안정 | Medium | Low | workout/day/week fallback 분리 + No data 상태 제공 |
| watch 화면 밀도 증가로 가독성 저하 | Low | Medium | metric 배치 간격 조정 및 기존 타이포 유지 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: 기존 HealthKit/Workout 구조를 재사용해 구현 리스크는 낮지만, iOS 세션중 steps는 델타 방식 특성상 외부 활동 영향이 있어 후속 정밀화 여지가 있다.
