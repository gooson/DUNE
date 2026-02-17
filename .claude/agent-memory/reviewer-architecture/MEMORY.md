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

## Key Files
- Domain models: `Dailve/Domain/Models/HealthMetric.swift` (WorkoutSummary, HRVSample, SleepStage, HealthMetric)
- Workout data boundary: `Dailve/Data/HealthKit/WorkoutQueryService.swift`
- Exercise ViewModel: `Dailve/Presentation/Exercise/ExerciseViewModel.swift`
- Shared extensions: `Dailve/Presentation/Shared/Extensions/`
