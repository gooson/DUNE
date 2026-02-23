---
tags: [detail-view, dependency-inversion, sendable-types, gradient-caching, chart-performance, training-readiness, weekly-stats, ipad-layout, task-cancellation]
category: architecture
date: 2026-02-23
severity: important
related_files:
  - Dailve/Presentation/Activity/TrainingReadiness/TrainingReadinessDetailView.swift
  - Dailve/Presentation/Activity/TrainingReadiness/TrainingReadinessDetailViewModel.swift
  - Dailve/Presentation/Activity/WeeklyStats/WeeklyStatsDetailView.swift
  - Dailve/Presentation/Activity/WeeklyStats/WeeklyStatsDetailViewModel.swift
  - Dailve/Presentation/Activity/ActivityViewModel.swift
  - Dailve/Presentation/Shared/Models/DailySample.swift
related_solutions:
  - architecture/2026-02-23-activity-detail-navigation-pattern.md
  - performance/2026-02-19-swiftui-color-static-caching.md
  - performance/2026-02-16-review-triage-task-cancellation-and-caching.md
---

# Solution: Activity Detail View v2 — Data Flow, Dependency Inversion, Chart Performance

## Problem

### Symptoms

1. **TrainingReadinessDetailView** accepted the parent `ActivityViewModel` directly — tight coupling, untestable, breaks Dependency Inversion
2. **ViewModel public API used unnamed tuples** like `(date: Date, value: Double)` — violates Sendable requirements (Correction #90)
3. **WeeklyStatsDetailViewModel** accepted `[ExerciseRecord]` (SwiftData @Model) — violates layer boundary (ViewModel must not import SwiftData)
4. **Gradient/Color allocations in chart body** — `LinearGradient(colors: [DS.Color.activity.opacity(0.6)])` created per render in Charts ForEach
5. **`Dictionary(uniqueKeysWithValues:)` crash risk** — duplicate date keys from overlapping HRV/RHR data could crash at runtime
6. **`isLoading` stuck on Task cancellation** — cancelled tasks returned early without resetting `isLoading = false`

### Root Cause

- Detail views were designed as "children" of the parent ViewModel rather than independent modules receiving data
- Tuple types are convenient but cannot conform to `Sendable` protocol
- SwiftUI Charts re-evaluate the entire closure per data point, so allocations inside Chart body are O(N) per render
- `Dictionary(uniqueKeysWithValues:)` crashes on duplicate keys — common with date-based grouping

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DailySample.swift` | Created `DailySample` + `SleepDailySample` Sendable structs | Replace unnamed tuples per Correction #90 |
| `ActivityViewModel.swift` | Expose `hrvDailyAverages: [DailySample]`, `rhrDailyData`, `sleepDailyData` | Provide pre-fetched data for detail views |
| `TrainingReadinessDetailView.swift` | Accept individual data properties instead of ViewModel | Dependency Inversion — detail view is independently testable |
| `TrainingReadinessDetailViewModel.swift` | Use `Dictionary(_:uniquingKeysWith:)` | Prevent crash on duplicate date keys |
| `WeeklyStatsDetailViewModel.swift` | Accept `[ManualExerciseSnapshot]` instead of `[ExerciseRecord]` | Layer boundary — VM doesn't import SwiftData |
| `WeeklyStatsDetailView.swift` | Convert `ExerciseRecord → ManualExerciseSnapshot` in `.task(id:)` | View owns SwiftData conversion |
| `DailyVolumeChartView.swift` | Hoist `LinearGradient` to `private enum Gradients` | Eliminate O(N) allocation per render |
| `ReadinessTrendChartView.swift` | Hoist `LinearGradient` to `private enum Gradients` | Same — static gradient cache |
| `SubScoreTrendChartView.swift` | Extract `areaGradient` computed property | Dynamic `color` param → computed once per body |

### Key Code

**Pattern 1: Detail View receives data, not parent ViewModel**

```swift
// GOOD: Independent data properties
struct TrainingReadinessDetailView: View {
    let readiness: TrainingReadiness?
    let hrvDailyAverages: [DailySample]
    let rhrDailyData: [DailySample]
    let sleepDailyData: [SleepDailySample]
    @State private var detailVM = TrainingReadinessDetailViewModel()
}

// Navigation destination passes data
case .trainingReadiness:
    TrainingReadinessDetailView(
        readiness: viewModel.trainingReadiness,
        hrvDailyAverages: viewModel.hrvDailyAverages,
        rhrDailyData: viewModel.rhrDailyData,
        sleepDailyData: viewModel.sleepDailyData
    )
```

**Pattern 2: Named Sendable structs replace tuples**

```swift
struct DailySample: Sendable, Hashable {
    let date: Date
    let value: Double
}

struct SleepDailySample: Sendable, Hashable {
    let date: Date
    let minutes: Double
}
```

**Pattern 3: View converts @Model → Domain DTO before passing to VM**

```swift
// View (owns SwiftData)
.task(id: viewModel.selectedPeriod) {
    let snapshots = recentRecords.map { record in
        ManualExerciseSnapshot(
            date: record.date,
            exerciseType: record.exerciseType,
            categoryRawValue: ActivityCategory.strength.rawValue,
            duration: record.duration,
            calories: record.estimatedCalories ?? record.calories ?? 0,
            totalVolume: record.totalVolume
        )
    }
    await viewModel.loadData(manualSnapshots: snapshots)
}
```

**Pattern 4: Dictionary with uniquingKeysWith**

```swift
// CRASH: duplicate date keys
let hrvByDay = Dictionary(uniqueKeysWithValues: hrv.map { ... })

// SAFE: last value wins on collision
let hrvByDay = Dictionary(
    hrv.map { (calendar.startOfDay(for: $0.date), $0.value) },
    uniquingKeysWith: { _, last in last }
)
```

**Pattern 5: Static gradient cache for Charts**

```swift
// Static — DS.Color.activity is constant
private enum Gradients {
    static let area = LinearGradient(
        colors: [DS.Color.activity.opacity(0.15), DS.Color.activity.opacity(0.02)],
        startPoint: .top, endPoint: .bottom
    )
}

// Dynamic — color is a property, compute once per body
private var areaGradient: LinearGradient {
    LinearGradient(
        colors: [color.opacity(0.2), color.opacity(0.02)],
        startPoint: .top, endPoint: .bottom
    )
}
```

**Pattern 6: isLoading reset on Task cancellation**

```swift
func loadData(...) async {
    loadTask?.cancel()
    isLoading = true

    do {
        let workouts = try await workoutService.fetchWorkouts(days: period.fetchDays)
        guard !Task.isCancelled else {
            isLoading = false  // MUST reset
            return
        }
        // ... process ...
    } catch {
        errorMessage = "Unable to load data."
    }
    isLoading = false
}

private func triggerReload() {
    loadTask?.cancel()
    comparison = nil
    summaryStats = []
    isLoading = false  // Reset for immediate UI feedback
}
```

## Prevention

### Checklist Addition

- [ ] Detail view는 parent ViewModel 참조 금지 — 필요한 데이터만 개별 프로퍼티로 전달
- [ ] ViewModel public API에 unnamed tuple 사용 시 named Sendable struct로 교체
- [ ] `Dictionary(uniqueKeysWithValues:)` 사용 금지 — 항상 `uniquingKeysWith` 사용
- [ ] Chart body 내 `LinearGradient`, `Color.opacity()` 호출은 stored property로 호이스트
- [ ] Task cancel 가능 경로에서 반드시 `isLoading = false` 리셋

### Rule Addition

기존 Correction Log #90 (Sendable tuple 금지)와 #17 (Task.isCancelled + isLoading) 확장 적용.

새 패턴:
- **Detail View Data Flow**: Parent VM이 raw data를 프로퍼티로 노출 → Navigation destination에서 개별 프로퍼티로 전달 → Detail VM이 가공
- **Chart Gradient Cache**: constant color → `private enum Gradients { static let }`, dynamic color → `private var gradient: LinearGradient`

## Lessons Learned

1. **Detail view는 parent ViewModel을 알면 안 된다**: 데이터 구조체(struct)만 전달하면 프리뷰, 테스트, 재사용성 모두 향상
2. **SwiftData 타입은 View 경계를 넘지 않아야 한다**: `@Model` → Domain DTO 변환은 View의 `.task(id:)` 에서 수행
3. **Dictionary 초기화 시 중복 키를 항상 가정**: HealthKit 데이터는 시간대, 수동 입력 등으로 같은 날짜에 복수 값 가능
4. **Chart body 내부는 hot path**: Swift Charts는 데이터 포인트마다 클로저 실행. allocation-free 원칙 적용
5. **iPad layout 추출 패턴**: `if isRegular { HStack { sectionA; sectionB } } else { sectionA; sectionB }` — 섹션을 computed property로 추출하면 중복 최소화
