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
