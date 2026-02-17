---
topic: healthkit-dedup
date: 2026-02-18
status: draft
confidence: high
related_solutions: [performance/2026-02-15-healthkit-query-parallelization]
related_brainstorms: [2026-02-18-healthkit-dedup-strategy]
---

# Implementation Plan: HealthKit Workout 중복 제거

## Context

앱에서 운동을 기록하면 SwiftData(상세)와 HealthKit(요약)에 동시 저장된다. 현재 UI에서 양쪽 데이터를 모두 표시하므로 **같은 운동이 2번 나타나는 중복 문제**가 발생한다.

`ExerciseRecord.healthKitWorkoutID` 필드가 이미 존재하고 값도 채워지지만, 화면 표시 시 **필터링에 사용되지 않는 것**이 근본 원인이다.

## Requirements

### Functional

1. **Exercise 탭**: 앱에서 기록한 운동(SwiftData) + 외부 HealthKit 운동이 중복 없이 하나의 리스트로 표시
2. **Activity 탭**: 최근 운동 섹션에서 앱 운동(상세)과 외부 운동(요약)이 중복 없이 표시
3. **앱 운동 우선**: 같은 운동이 SwiftData와 HealthKit에 모두 있으면 SwiftData 버전(상세 데이터)만 표시
4. **외부 운동 구분**: Watch Workout 앱 등 외부 운동은 HealthKit 아이콘으로 구분

### Non-functional

- 기존 `healthKitWorkoutID` 인프라 최대 활용 (새 필드/스키마 변경 없음)
- HealthKit 쓰기 실패 시에도 중복 방지 (bundleIdentifier fallback)
- Steps는 `HKStatisticsQuery` 사용 중이므로 자동 중복 제거 확인만

## Approach

**`healthKitWorkoutID` 매칭 + `bundleIdentifier` predicate 필터링**

1. ExerciseViewModel의 `invalidateCache()`에서 SwiftData 레코드의 `healthKitWorkoutID` 목록을 수집
2. HealthKit 운동 목록에서 해당 ID를 가진 항목을 제외
3. WorkoutQueryService에 자체 앱 번들ID 제외 옵션 추가 (fallback)

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| **A. ViewModel에서 ID 매칭 필터링** | 인프라 있음, 정확함, 변경 최소 | HK 쓰기 실패 시 ID 없음 | **채택 (주 전략)** |
| B. HK 쿼리에서 bundleID predicate | 쿼리 시점 필터, 효율적 | 외부 운동도 보여야 하므로 완전 제외 불가 | 보조 전략으로 활용 |
| C. 시간+타입 겹침 체크 | 추가 필드 불필요 | 오탐 가능 (같은 시간 다른 운동) | 기각 |
| D. HK 쓰기 완전 제거 | 중복 원천 차단 | Apple Health 연동 목적 상실 | 기각 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `Presentation/Exercise/ExerciseViewModel.swift` | **Modify** | `invalidateCache()`에 중복 필터링 추가 |
| `Presentation/Activity/Components/ExerciseListSection.swift` | **Modify** | HealthKit 목록에서 앱 운동 ID 제외 |
| `Data/HealthKit/WorkoutQueryService.swift` | **Modify** | 자체 앱 운동 제외 predicate 옵션 추가 |
| `DailveTests/ExerciseViewModelTests.swift` | **Create** | 중복 필터링 유닛 테스트 |

## Implementation Steps

### Step 1: ExerciseViewModel에 중복 필터링 추가

- **Files**: `Presentation/Exercise/ExerciseViewModel.swift`
- **Changes**:
  - `invalidateCache()`에서 `manualRecords`의 `healthKitWorkoutID` Set 구성
  - `healthKitWorkouts` 순회 시 해당 Set에 포함된 ID 스킵
  - 자체 앱 bundleIdentifier 기반 추가 필터링 (healthKitWorkoutID가 nil인 앱 운동 대비)
- **Logic**:
  ```swift
  private func invalidateCache() {
      // 1. 앱 운동의 HealthKit ID 수집
      let appWorkoutIDs: Set<String> = Set(
          manualRecords.compactMap(\.healthKitWorkoutID)
      )

      // 2. HealthKit 목록에서 앱 운동 제외
      let externalWorkouts = healthKitWorkouts.filter { workout in
          !appWorkoutIDs.contains(workout.id)
      }

      // 3. 외부 운동만 리스트에 추가
      var items: [ExerciseListItem] = []
      for workout in externalWorkouts { ... }  // source: .healthKit
      for record in manualRecords { ... }       // source: .manual
      allExercises = items.sorted { $0.date > $1.date }
  }
  ```
- **Verification**: 앱 운동 기록 후 Exercise 탭에서 중복 없이 1건만 표시 확인

### Step 2: ExerciseListSection 중복 필터링

- **Files**: `Presentation/Activity/Components/ExerciseListSection.swift`
- **Changes**:
  - `exerciseRecords`의 `healthKitWorkoutID` Set 구성
  - `workouts`(HealthKit) 중 해당 ID 제외 후 표시
  - 기존 로직: setRecords 먼저 → 남은 슬롯에 HealthKit → **변경 없이 필터만 추가**
- **Logic**:
  ```swift
  private var filteredWorkouts: [WorkoutSummary] {
      let appWorkoutIDs = Set(exerciseRecords.compactMap(\.healthKitWorkoutID))
      return workouts.filter { !appWorkoutIDs.contains($0.id) }
  }
  ```
  - `body`에서 `workouts` 대신 `filteredWorkouts` 사용
- **Verification**: Activity 탭 "Recent Workouts"에서 앱 운동이 SwiftData 버전으로만 표시

### Step 3: WorkoutQueryService에 자체 앱 제외 옵션 (선택적 최적화)

- **Files**: `Data/HealthKit/WorkoutQueryService.swift`
- **Changes**:
  - `fetchWorkouts(days:excludeOwnApp:)` 파라미터 추가
  - `excludeOwnApp = true` 시 `NSCompoundPredicate`로 자체 bundleIdentifier(`com.raftel.dailve`) 제외
  - 기본값은 `false`로 기존 동작 유지
- **Purpose**: healthKitWorkoutID가 nil인 경우(HK 쓰기 실패)에도 중복 방지
- **주의**: 이 최적화는 Step 1의 ID 매칭이 커버하지 못하는 엣지 케이스용
- **Verification**: HealthKit에 앱 운동이 있어도 `excludeOwnApp=true`로 호출 시 결과에 포함되지 않음

### Step 4: 유닛 테스트

- **Files**: `DailveTests/ExerciseViewModelTests.swift` (신규)
- **Test Cases**:
  1. 동일 ID의 SwiftData + HealthKit 운동 → 1건만 표시 (SwiftData 버전)
  2. 외부 HealthKit 운동 → 정상 표시 (.healthKit source)
  3. healthKitWorkoutID가 nil인 SwiftData 운동 → 중복 없이 표시
  4. 빈 데이터 → 빈 리스트
  5. 날짜 정렬 유지 확인

## Edge Cases

| Case | Handling |
|------|----------|
| HealthKit 쓰기 실패 (healthKitWorkoutID = nil) | Step 3의 bundleIdentifier 필터가 fallback. 최악의 경우 중복 1건 표시 (치명적이지 않음) |
| HealthKit 읽기 권한 거부 | healthKitWorkouts = [] → SwiftData 레코드만 표시 (현재와 동일) |
| 같은 시간에 다른 운동 2개 | ID 기반 매칭이므로 오탐 없음 |
| 앱 삭제 후 재설치 | CloudKit에서 SwiftData 복원 → healthKitWorkoutID 유지 → 정상 동작 |
| 아주 오래된 운동 (30일+) | ExerciseViewModel은 30일만 HealthKit 조회. SwiftData는 전체. 30일 넘은 건 SwiftData만 표시 |

## Testing Strategy

- **Unit tests**: ExerciseViewModel의 `invalidateCache()` 필터링 로직 (Step 4)
- **Manual verification**:
  1. 앱에서 운동 기록 → Exercise 탭에서 1건만 확인
  2. Watch Workout 앱에서 운동 기록 → Activity 탭에서 ❤️ 아이콘과 함께 표시
  3. Activity 탭 "Recent Workouts"에서 중복 없이 표시
- **Steps 확인**: `StepsQueryService`가 `HKStatisticsQuery(.cumulativeSum)` 사용 중 → Apple 자동 중복 제거 확인 완료 (변경 불필요)

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| HealthKit 쓰기 실패로 ID 없는 운동 존재 | Low | Low (중복 1건 표시) | Step 3 bundleIdentifier fallback |
| ExerciseListSection 필터로 빈 리스트 | Very Low | Medium | `filteredWorkouts.isEmpty && setRecords.isEmpty` 조건으로 empty state 표시 |
| 성능 (대량 운동 기록 시 Set 생성) | Very Low | Low | Set<String> lookup은 O(1), 운동 수는 현실적으로 1000건 미만 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**:
  - `healthKitWorkoutID` 인프라가 이미 존재하고 값이 채워지고 있음
  - 변경 범위가 ViewModel의 필터링 로직에 한정됨
  - 스키마 변경 없음 → CloudKit 호환성 위험 없음
  - Steps는 이미 `HKStatisticsQuery` 사용 중으로 변경 불필요 확인됨
