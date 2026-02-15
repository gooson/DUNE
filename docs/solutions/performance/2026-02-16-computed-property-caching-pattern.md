---
tags: [computed-property, caching, didSet, invalidation, observable, sorting, reserveCapacity]
category: performance
date: 2026-02-16
severity: important
related_files:
  - Dailve/Presentation/Exercise/ExerciseViewModel.swift
related_solutions: []
---

# Solution: Computed Property Caching with didSet Invalidation

## Problem

### Symptoms

- `allExercises` computed property가 SwiftUI body에서 매 접근 시 O(n log n) 재계산
- 두 배열(healthKitWorkouts + manualRecords)을 합산 후 정렬하는 비용이 매 렌더링마다 발생

### Root Cause

`allExercises`가 computed property(`var allExercises: [T] { ... }`)로 선언되어 매 접근 시 전체 배열 합산 + 정렬 수행. SwiftUI의 `@Observable` 트래킹은 computed property 내부의 저장 프로퍼티 접근을 감지하여 불필요한 재계산 트리거.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `ExerciseViewModel.swift` | `var allExercises` → `private(set) var allExercises` (stored) | 캐싱 |
| `ExerciseViewModel.swift` | `invalidateCache()` private 메서드 추가 | 재계산 로직 분리 |
| `ExerciseViewModel.swift` | `healthKitWorkouts`, `manualRecords`에 `didSet { invalidateCache() }` | 소스 변경 시만 갱신 |
| `ExerciseViewModel.swift` | `items.reserveCapacity(count)` 추가 | 배열 재할당 방지 |

### Key Code

```swift
// Before: computed property - O(n log n) every access
var allExercises: [ExerciseListItem] {
    var items: [ExerciseListItem] = []
    // ... build items ...
    return items.sorted { $0.date > $1.date }
}

// After: cached stored property - O(1) access, O(n log n) only on mutation
var healthKitWorkouts: [WorkoutSummary] = [] { didSet { invalidateCache() } }
var manualRecords: [ExerciseRecord] = [] { didSet { invalidateCache() } }
private(set) var allExercises: [ExerciseListItem] = []

private func invalidateCache() {
    var items: [ExerciseListItem] = []
    items.reserveCapacity(healthKitWorkouts.count + manualRecords.count)
    // ... build items ...
    allExercises = items.sorted { $0.date > $1.date }
}
```

## Prevention

### Checklist Addition

- [ ] Computed property 내에서 정렬/필터/매핑이 있으면 캐싱 고려
- [ ] SwiftUI에서 여러 번 접근되는 derived data는 stored property + invalidation 패턴 사용
- [ ] `reserveCapacity`로 배열 예상 크기 사전 할당

### Pattern: didSet Invalidation

```swift
// 소스 프로퍼티에 didSet으로 캐시 갱신 트리거
var sourceData: [T] = [] { didSet { rebuildDerivedData() } }
private(set) var derivedData: [U] = []

private func rebuildDerivedData() {
    derivedData = sourceData.map { ... }.sorted { ... }
}
```

**적용 조건:**
- Derived data가 2개 이상의 소스에서 합산됨
- 정렬/필터 등 O(n log n) 이상의 연산 포함
- SwiftUI body에서 여러 번 접근됨

**비적용 조건:**
- 단순 변환 (O(1) 또는 O(n) 미만)
- 접근 빈도가 낮음 (설정 화면 등)

## Lessons Learned

1. **`@Observable` + computed property 함정**: `@Observable`은 computed property 내부에서 접근하는 stored property를 추적하여, 소스 변경 시 computed property를 참조하는 모든 View를 갱신한다. 이때 재계산 비용이 크면 성능 문제 발생.
2. **didSet은 `@Observable`에서도 동작**: `@Observable` 매크로가 property wrapper를 생성하지만, didSet은 정상 호출된다.
3. **reserveCapacity**: 두 배열을 합산할 때 예상 크기를 미리 할당하면 재할당 횟수를 줄일 수 있다.
