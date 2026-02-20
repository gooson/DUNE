# Performance Reviewer Memory

## Common SwiftUI Performance Antipatterns

### Multiple @Query on Same Entity
- When multiple views query `@Query<ExerciseRecord>`, SwiftData creates separate observation contexts
- Each view registers its own change observers
- Pattern: ActivityView has `@Query recentRecords`, MuscleMapSummaryCard has `@Query records` (both ExerciseRecord)
- Risk: Redundant database reads, duplicate change notifications on insert/update

### Computed Properties in SwiftUI Body
- SwiftUI body is called on every render (state change, parent update, environment change)
- Computed properties without caching recalculate on every access
- Pattern: `weeklyVolume`, `topMuscles`, `maxVolume`, `hasData` in MuscleMapSummaryCard
- Chain reaction: `hasData` depends on `topMuscles`, which depends on `weeklyVolume`
- Impact: O(N) filter + O(N log N) sort + O(N) map on EVERY render

### Relationship Access in Loops
- `record.completedSets` is computed property: `(sets ?? []).filter(\.isCompleted).sorted`
- Called inside loop over all records
- Pattern: `for record in recentRecords { let setCount = record.completedSets.count }`
- Impact: N records × (M sets × filter + M log M sort) = O(N × M log M)

### .onChange on @Query Collections
- SwiftUI calls onChange for EVERY SwiftData mutation (insert/update/delete)
- Pattern: `.onChange(of: recentRecords)` triggers `updateSuggestion(records:)`
- Impact: Snapshot mapping + recommendation service on every workout set completion during active session

## Caching Patterns

### @State Cache with didSet Invalidation
```swift
@State private var cachedVolume: [MuscleGroup: Int]?
private var weeklyVolume: [MuscleGroup: Int] {
    if let cached = cachedVolume { return cached }
    let computed = /* expensive calculation */
    cachedVolume = computed
    return computed
}
```
Invalidate on data change: `.onChange(of: records.count) { cachedVolume = nil }`

### Lazy Computed Property Pattern (Correction Log #8)
```swift
private(set) var topMuscles: [(MuscleGroup, Int)] = []
private func recalculateTopMuscles() {
    topMuscles = weeklyVolume.sorted...
}
```
Call recalculate in .task and .onChange, not in body

## Project-Specific Patterns

### ExerciseRecord.completedSets
- NOT a stored property — it's a computed filter+sort
- Always accessed in loops → high cost multiplier
- Optimization: pre-compute set counts in upstream snapshot conversion

### Dual MuscleMapView + MuscleMapSummaryCard
- Both compute identical `weeklyVolume` from same @Query
- User navigates ActivityView (summary) → MuscleMapView (full) → duplicate computation
- Mitigation: Extract volume calculation to shared service with @Observable cache

## ExerciseListSection / ExerciseViewModel Snapshot Patterns

### .task(id:) with string interpolation key
- `ExerciseListSection` uses `.task(id: "\(workouts.count)-\(exerciseRecords.count)")` to rebuild items
- String interpolation ID is correct (Correction #78) but creates a new String on every body evaluation
- Prefer using a tuple-based stable key or a numeric hash when both count values fit in a struct

### completedSets inside invalidateCache() / buildItems()
- `record.completedSets` is the expensive computed filter+sort (see Relationship Access in Loops)
- `ExerciseViewModel.invalidateCache()` calls `record.completedSets` once per record when building ExerciseListItem — this is **acceptable** because it is outside the SwiftUI body and runs only on data change
- `ExerciseListSection.buildItems()` also calls `record.completedSets` once per record — also in .task, not in body — acceptable
- `ExerciseView.updateSuggestion()` calls `record.completedSets.count` inside a `.map` over ALL manualRecords every time `.onChange(of: manualRecords)` fires — this IS a hot path concern

### .onChange(of: manualRecords) — full array comparison
- ExerciseView line 185: `.onChange(of: manualRecords) { _, newValue in rebuildRecordIndex(); viewModel.manualRecords = newValue; updateSuggestion() }`
- Correction #47: use `.onChange(of: manualRecords.count)` when the full collection diff is not needed
- `updateSuggestion()` snapshots ALL records including `.completedSets.count` — fires on every set completion

### item.activityType.color.opacity(0.12) inside ForEach muscleBadges
- UnifiedWorkoutRow.muscleBadges: `item.activityType.color.opacity(0.12)` evaluated per muscle badge in inner ForEach
- `.color` is a computed property (switch on category) — not expensive, but `.opacity()` creates a new Color value
- Called up to 3× per row on every render. Not a P1, but worth hoisting to a local let.
- Fix: `let badgeColor = item.activityType.color` before the ForEach, use `badgeColor.opacity(0.12)` and `badgeColor` inside.

### DashboardViewModel: WorkoutActivityType.infer(from:) called per workout type in hot path
- `DashboardViewModel` calls `WorkoutActivityType.infer(from: type)` inside a loop over workout types
- `infer(from:)` calls `.lowercased()` + 15 `.contains()` checks per invocation
- Called every time `calculateExerciseMetrics()` runs (on every HealthKit refresh)
- Pattern introduced in this PR: replaces `WorkoutSummary.iconName(for:)` (same hot-path risk)
- Fix: the result is stable for a given type string — cache in a `[String: WorkoutActivityType]` dictionary

### activityIcon(size:) evaluates style == .compact on every render
- `UnifiedWorkoutRow.activityIcon(size:)` computes `.font(style == .compact ? .body : .title3)` on every body evaluation
- This is a value-type enum comparison — cheap, but the font + color are recomputed on every render
- With a list of 50+ exercise rows scrolling, both `activityType.iconName` and `activityType.color` (switch statements) fire per row per frame
- Fix: hoist font and color to stored properties on init, or use `@ViewBuilder` style split

### formattedPace in UnifiedWorkoutRow — String(format:) hot path
- `formattedPace(_:)` calls `String(format: "%02d", seconds)` — allocates a new String per row per render
- Appears in `metricsRow` (full style) for running/cycling workouts
- Fix: cache via `item.formattedPace` on ExerciseListItem (computed once at build time, not per render)

## Canvas Rendering Performance

### Color Computation in Canvas Body
- Canvas `draw()` functions called on EVERY SwiftUI render cycle
- Computing `DS.Color.activity.opacity(0.15)` inside draw function = recomputation per frame
- Pattern: `EquipmentIllustrationView` line 25-26
- Impact: 8 equipment types × ~20 shapes each = 160 Color computations per scroll frame
- Fix: Hoist to init or stored property: `private let fillColor = DS.Color.activity.opacity(0.15)`

### Path Allocations in Drawing Loops
- `var path = Path()` inside `for` loop allocates on heap
- Pattern: Drawing barbell plates, machine weight stack (4-5 paths per equipment)
- Impact: With List showing 10 exercise rows × EquipmentIllustrationView = 40-50 Path allocations
- Fix: Reuse single Path with `.removeAllPoints()` between iterations

### Nested TaskGroup — Sleep Weekly Pattern
- `fetchAllData()` spawns a `group.addTask` for sleep weekly, which itself spawns `withThrowingTaskGroup` with 7 inner tasks
- 7 separate HealthKit queries for individual days when a single date-ranged query would suffice
- Each inner task calls `sleepService.fetchSleepStages(for:)` — if that method uses an `HKSampleQueryDescriptor` per call, this is 7 serial HK round-trips hidden inside parallel tasks
- Fix: use a single `fetchSleepStages(from: start, to: end)` range query; split results by day in memory

### Calendar.current in SwiftUI Body (VitalCard staleLabel)
- `VitalCard.staleLabel` is a `var` (not @ViewBuilder func), evaluated every render
- Calls `Calendar.current.dateComponents([.day], from: data.lastUpdated, to: Date())` per card per render
- With 8–10 visible VitalCards in LazyVGrid: 8–10 Calendar computations per scroll frame
- Fix: pre-compute `daysSinceUpdate: Int` on `VitalCardData` at build time (in `buildCard()`)

### color.opacity() in MiniSparklineView body
- `MiniSparklineView.body` calls `color.opacity(0.15)`, `color.opacity(0.02)`, `color.opacity(0.6)` on every render
- These create new Color values per render call
- With 8–10 VitalCards each containing a sparkline, = 24–30 Color allocations per scroll frame
- Fix: hoist to stored `let` properties initialized from the passed `color` parameter

### ProgressRingView color.opacity() in body during animation
- `ProgressRingView.body` calls `ringColor.opacity(0.15)` and `ringColor.opacity(0.6)` inside the animation loop
- During the score count-up animation (~20–30 frames at 60fps), these are recomputed every frame
- Fix: precompute `private let trackColor: Color` and `private let arcColorDim: Color` in init

### Path Template Caching
- Path construction with CGRect is expensive (addEllipse, addRoundedRect)
- Creating `bodyOutline(width:height:)` on every GeometryReader layout = repeated allocation
- Pattern: `MuscleMapData.bodyOutline()` called in ExerciseMuscleMapView + MuscleMapView
- Fix: Store normalized path as static, apply scale transform:
  ```swift
  private static let template = /* normalized path */
  static func outline(width: CGFloat, height: CGFloat) -> Path {
      var p = template
      p.apply(.init(scaleX: width, y: height))
      return p
  }
  ```
- Alternative: Use Canvas symbols for GPU-side caching
