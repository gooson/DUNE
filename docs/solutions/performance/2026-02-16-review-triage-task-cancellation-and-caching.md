---
tags: [task-cancellation, race-condition, isLoading, caching, computed-property, didSet, invalidation, swift-concurrency]
category: performance
date: 2026-02-16
severity: important
related_files:
  - Dailve/Presentation/Shared/Detail/MetricDetailViewModel.swift
  - Dailve/Presentation/Dashboard/ConditionScoreDetailViewModel.swift
  - Dailve/Presentation/Activity/ActivityViewModel.swift
  - Dailve/Presentation/Shared/Detail/AllDataViewModel.swift
related_solutions: []
---

# Solution: Task 취소 패턴 + isLoading Race Condition + Computed Property 캐싱

## Problem

### Symptoms

1. **triggerReload() 중복 실행**: 기간 변경 시 이전 Task가 계속 실행되어 stale 데이터가 최종 반영
2. **isLoading race**: 취소된 Task가 완료 시 `isLoading = false`로 리셋 → 새 Task 실행 중인데 로딩 표시 사라짐
3. **Computed property O(n)**: `exerciseTotals`, `trendLineData`가 매 SwiftUI body에서 재계산

### Root Cause

1. `triggerReload()`이 이전 Task를 취소하지 않고 새 Task만 생성
2. `loadData()`가 `defer { isLoading = false }` 없이 항상 false로 리셋 — 취소 여부 무관
3. 정렬/필터 포함 computed property가 scroll 이벤트마다 호출

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `MetricDetailViewModel` | `reloadTask?.cancel()` + `Task.isCancelled` guard | 이전 로드 취소 + stale 결과 무시 |
| `ConditionScoreDetailViewModel` | 동일 패턴 | 동일 문제 |
| `ActivityViewModel` | `loadTask?.cancel()` + `Task.isCancelled` guard | 동일 문제 |
| `AllDataViewModel` | `pageTask?.cancel()` + `Task.isCancelled` guard | Pagination overlap 방지 |
| `MetricDetailViewModel` | `exerciseTotals`/`cachedTrendLine` → `private(set) var` + `didSet { invalidateScrollCache() }` | 반복 계산 제거 |

### Key Code

```swift
// Pattern 1: Cancel-before-spawn
private var reloadTask: Task<Void, Never>?

private func triggerReload() {
    reloadTask?.cancel()
    reloadTask = Task { await loadData() }
}

// Pattern 2: Cancellation-aware state reset
func loadData() async {
    guard !isLoading else { return }
    isLoading = true
    do {
        try await loadActualData()
        guard !Task.isCancelled else {
            isLoading = false
            return
        }
        // ... update state only if not cancelled
    } catch { ... }
    isLoading = false
}

// Pattern 3: didSet invalidation caching (correction log #8)
var scrollPosition: Date = .now {
    didSet { invalidateScrollCache() }
}
var chartData: [ChartDataPoint] = [] {
    didSet { invalidateScrollCache() }
}
private(set) var exerciseTotals: ExerciseTotals?
private(set) var cachedTrendLine: [ChartDataPoint]?

private func invalidateScrollCache() {
    recomputeExerciseTotals()
    recomputeTrendLine()
}
```

## Prevention

### Checklist Addition

- [ ] `Task { await loadData() }` 패턴이 있으면 이전 Task 취소 확인
- [ ] `isLoading = false` 전에 `Task.isCancelled` 체크 여부 확인
- [ ] SwiftUI body에서 접근되는 computed property에 정렬/필터가 있으면 캐싱 고려

### Rule Addition (if applicable)

`.claude/rules/swift-concurrency.md` 신규 생성 고려:
- "reload trigger는 cancel-before-spawn 패턴 필수"
- "isLoading 리셋 전 Task.isCancelled 검사"

## Lessons Learned

- `Task.isCancelled`는 cooperative — await 지점에서만 체크됨. 긴 async 작업 후 결과 반영 전 체크가 핵심
- Computed property 캐싱은 `didSet` 트리거로 구현하면 SwiftUI의 `@Observable` 변경 추적과 자연스럽게 통합됨
- Pagination에서도 동일한 race가 발생 — 빠른 스크롤로 `loadNextPage()`가 중복 호출될 수 있음
