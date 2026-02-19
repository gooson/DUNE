# Architecture Reviewer Memory

## Project: Health (Dailve)

Layer boundary: App → Presentation → Domain ← Data
- Domain imports: Foundation, HealthKit only
- ViewModel: no SwiftUI, no ModelContext, no SwiftData
- SwiftData CRUD: View only via @Environment(\.modelContext)

## Confirmed Patterns

### App-level constants
- Bundle ID and other app-wide config belong in `App/AppConfiguration.swift`
- Use `Bundle.main.bundleIdentifier ?? "fallback"` — never hardcode bundle ID strings in Presentation
- Pattern: `enum AppConfiguration { static let bundleIdentifier = Bundle.main.bundleIdentifier ?? "..." }`

### Filtering logic placement
- "Which workouts belong to this app?" is a domain/data boundary rule, not a Presentation rule
- Prefer resolving at `WorkoutQueryService.toSummary()` or via a Domain protocol method
- If filter must stay in Presentation, consolidate to ViewModel only — Views receive already-filtered data as parameters

### Domain model purity
- Infrastructure strings (e.g., `sourceBundleIdentifier`) should not appear on Domain models
- Replace with intent-bearing booleans (`isFromThisApp: Bool`) resolved at the Data→Domain boundary
- See: `WorkoutSummary.sourceBundleIdentifier` anti-pattern (feature/watch-first-workout review)

### DRY threshold
- 2 locations: allowed but flag for extraction
- 3+ locations: mandatory extraction per project Correction Log rule #37
- Collection extension location: `Presentation/Shared/Extensions/{DomainType}+Filtering.swift`

### Cross-ViewModel references
- Views must never reference a sibling ViewModel to access constants or state
- Symptom: `ExerciseListSection` referencing `ExerciseViewModel.appBundleIdentifier`
- Fix: shared App-layer config or pass the value as a View parameter

### Shared Presentation model co-location
- A DTO used by shared components (UnifiedWorkoutRow) and multiple feature layers must NOT live inside a single ViewModel file
- `ExerciseListItem` currently in `ExerciseViewModel.swift` — should live in `Presentation/Shared/Models/ExerciseListItem.swift`
- Pattern: shared Presentation models go in `Presentation/Shared/Models/`

### Record→DTO mapping duplication
- `WorkoutSummary/ExerciseRecord → ExerciseListItem` mapping logic must not be duplicated in both ViewModel and View
- `ExerciseListSection.buildItems()` is a structural duplicate of `ExerciseViewModel.invalidateCache()` without PR enrichment — behavioral inconsistency risk
- Fix: View receives pre-built `[ExerciseListItem]` as a parameter; mapping lives in ViewModel only
- NOTE (feature/unified-workout-row): This duplication was identified as a P1 finding but NOT fixed in this PR — still present in ExerciseListSection.swift:95

### ExerciseListItem co-location (unresolved as of feature/unified-workout-row)
- `ExerciseListItem` struct is still defined inside `ExerciseViewModel.swift:167`
- `UnifiedWorkoutRow` is now a shared component in `Presentation/Shared/Components/` but depends on `ExerciseListItem` which lives in a feature-specific ViewModel file
- Rule: shared Presentation DTOs must live in `Presentation/Shared/Models/ExerciseListItem.swift`

### task(id:) fragility with string interpolation
- `ExerciseListSection` uses `.task(id: "\(workouts.count)-\(exerciseRecords.count)")` — this misses updates when content changes but counts stay the same (e.g., a workout is replaced by another on the same day)
- Prefer `.task(id: workouts.map(\.id).sorted().joined())` or pass pre-built items from ViewModel

### WorkoutActivityType.infer — missing coverage
- `infer(from:)` in Domain returns nil for strength exercises (bench press, squat, deadlift) — these fall back to category-level default, which is correct, but `DashboardViewModel` calls `infer(from: type)?.iconName ?? fallback` directly on workout type strings (not exercise names), which can miss coverage for HK workout type strings that don't match keywords

### Dependency injection in Views
- Views that embed service dependencies (`ExerciseLibraryService.shared` hardcoded) violate DI patterns used elsewhere
- All service access should flow from ViewModel injection or be passed as View parameters

### ViewModel holding @Model references without import SwiftData
- A ViewModel can reference a SwiftData `@Model` class without `import SwiftData` because the module resolves it transitively — this creates a false impression of a clean boundary
- Symptom: `var editingRecord: InjuryRecord?` on `InjuryViewModel` with no SwiftData import
- Detection: grep for `@Model` class names in Presentation/ViewModel files even when `import SwiftData` is absent
- Fix: ViewModels should use only Domain DTOs (e.g., `InjuryInfo`); mutation returns a value-type update struct the View applies via `modelContext`

### Pure use-case methods should not require a ViewModel intermediary
- If a View calls `someViewModel.method()` where that method is a one-liner wrapping a Domain use case, inject the use case directly
- Symptom: `ActivityView` instantiating `InjuryViewModel` only to call `checkConflicts()`, which wraps `CheckInjuryConflictUseCase`
- Fix: `let conflictUseCase = CheckInjuryConflictUseCase()` directly on the View or pass computed `[InjuryConflict]` as a parameter

### Data layer durationDays duplicating Domain logic
- `InjuryRecord.durationDays` is identical to `InjuryInfo.durationDays` — the Data layer should delegate: `var durationDays: Int { toInjuryInfo().durationDays }`
- General rule: when a Data `@Model` already has a `toDomain()` method, computed properties that mirror Domain logic should delegate rather than duplicate

## Key Files
- Domain models: `Dailve/Domain/Models/HealthMetric.swift` (WorkoutSummary, HRVSample, SleepStage, HealthMetric)
- Workout data boundary: `Dailve/Data/HealthKit/WorkoutQueryService.swift`
- Exercise ViewModel: `Dailve/Presentation/Exercise/ExerciseViewModel.swift`
- Shared extensions: `Dailve/Presentation/Shared/Extensions/`
- ExerciseListItem (currently misplaced): `Dailve/Presentation/Exercise/ExerciseViewModel.swift:167`
