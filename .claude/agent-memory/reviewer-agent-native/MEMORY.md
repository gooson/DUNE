# Agent-Native Reviewer Memory

## Project: Health/Dailve iOS App

### Architecture Patterns
- Swift 6 / SwiftUI / HealthKit / SwiftData
- Clean architecture: Domain → Data ← Presentation
- ViewModels use `@Observable` + `@MainActor`
- Protocol-based service injection (all protocols marked `Sendable`)
- ModelContext operations performed in View layer only

### Validation Patterns
- ViewModels expose `createValidatedRecord() -> Record?`
- Validation errors stored in `validationError: String?`
- `isSaving` flag prevents duplicate operations
- Input validation uses domain-specific ranges

### Error Handling
- Service protocols return throwing functions
- ViewModels catch errors and expose `errorMessage: String?`
- Parallel HealthKit queries use `async let` (2-3 queries) or `withThrowingTaskGroup` (4+)
- Task cancellation checked via `guard !Task.isCancelled`

### Common Issues to Watch
1. Missing Task cancellation before spawning new Task
2. State updates after Task.isCancelled (breaks loading indicators)
3. JSON decoding without fallback (crashes on malformed data)
4. Protocol dependency injection missing in ViewModels
5. SwiftData migration failures without recovery strategy
6. `.task(id:)` string hash collision: `"5-3"` == `"53-"` — use separators that cannot appear in the values (e.g., `"\(a)|\(b)"`)
7. Keyword matching with short tokens like "row" creates false positives (e.g., "elbow row" hits rowing before boxing). Use word-boundary-safe patterns or prefer longer keywords.
8. Plan says tests required for new `infer(from:)` and `resolvedActivityType` — check that `WorkoutActivityTypeTests` and `ExerciseDefinitionTests` actually cover the new code.
9. `buildItems()` duplicated in ExerciseListSection (View) and ExerciseViewModel — plan acknowledged risk but DRY extraction was marked as "선호 접근" yet not done.
10. `ExerciseListSection` hardwires `ExerciseLibraryService.shared` — breaks testability; plan specified protocol injection.
11. `isSaving` reset belongs in View after `modelContext.insert`, via `didFinishSaving()`. Pattern: ViewModel sets `isSaving = true`, returns record, View inserts, View calls `didFinishSaving()`. `WorkoutSessionViewModel` and `CompoundWorkoutViewModel` do this correctly; new ViewModels sometimes omit it.
12. Computed properties that invoke UseCases (even pure/synchronous ones) inside SwiftUI body still run on every render. Cache with `@State` + `onChange(of: count)` when the data source is a `@Query` array.
13. Swift Charts `BarMark`/`AreaMark` with dynamic `.frame(height:)` must add `.clipped()` immediately after — applies even when using `BarMark` (not just `AreaMark`). Correction #70 is not limited to `AreaMark`.
