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

### Self-contained score detail ViewModels — HealthKit fetch duplication
- Pattern introduced in this PR: `TrainingReadinessDetailViewModel` and `WellnessScoreDetailViewModel` each own full HealthKit fetch + HRV daily averaging + trend approximation + scroll/period state
- `buildHRVDailyAverages` is byte-for-byte identical in both files — crosses the 3-location DRY threshold when combined with `ConditionScoreDetailViewModel.buildSubScoreTrends`
- Rule: extract to `HealthDataAggregator.buildHRVDailyAverages(from:start:end:calendar:) -> [ChartDataPoint]` (already has `aggregateByAverage`, `computeSummary`, `previousPeriodRange`)
- Scroll/period state boilerplate (`resetScrollPosition`, `triggerReload`, `extendedRange`, `scrollDomain`, `visibleRangeLabel`, `trendLineData`) is also triplicated — candidate for a shared `ScoreDetailChartState` or base class in a future PR

### ScoreCompositionCard.Component.label type
- `ScoreCompositionCard.Component.label` is typed as `String`, not `LocalizedStringKey`
- Callsites in `TrainingReadinessDetailView` use `String(localized:)` correctly; `WellnessScoreDetailView` uses `Labels.*` which are also `String(localized:)` — so localization is correct at callsite
- Risk: future callsite may pass a bare String literal and silently bypass localization
- Preferred fix: type `label` as `LocalizedStringKey` so the compiler enforces localization at the call site; or at minimum document the invariant

### ViewModel exposing Data-layer service as public property
- `captureService: PostureCaptureService` declared `let` (public) on `PostureAssessmentViewModel`
- Views reach through it (`viewModel.captureService.captureSession`) bypassing the ViewModel abstraction
- Rule: service dependencies on ViewModels must be `private`; expose only what the View needs (e.g., `var captureSession: AVCaptureSession`)

### ViewModel returning UIKit types (dead code pattern)
- `var previewLayer: AVCaptureVideoPreviewLayer` on `PostureAssessmentViewModel` returns a UIKit CALayer subclass — violates ViewModel purity
- Additionally was dead code — View never called it, accessed session directly
- Detection: grep ViewModel files for `AVCaptureVideoPreviewLayer`, `UIView`, `UIImage`, `CALayer` return types

### Domain weighted-score calculation duplication
- `PostureAssessment.overallScore`, `CombinedPostureAssessment.overallScore`, and `PostureAnalysisService.calculateOverallScore` contain the same weighted-sum loop
- Only `calculateOverallScore` clamps to `max(0, min(100,...))` — the Domain model computed properties do not, causing behavioral drift
- Fix: extract to `static func overallScore(from: [PostureMetricResult]) -> Int` and delegate from the computed properties

### ScoreRefreshService passed through View layer (Data→Presentation boundary violation)
- `ScoreRefreshService` (Data layer) is stored as a `let` property on `ActivityView` and `WellnessView` and forwarded directly to child detail Views
- Views then pass it to ViewModels at init time — creating a Presentation→Data direct dependency visible in View code
- Rule: Data-layer services must not be stored or forwarded by Views; inject via ViewModel constructor only, and ViewModel receives it from App-layer composition root (e.g., `ContentView` or environment)
- Established pattern (feature/wellness-readiness-hourly): P2 finding — acceptable for now as no alternative injection mechanism exists, but blocks if a 4th detail view or refactor is needed

### rollingWindowSeconds triplication
- `private static let rollingWindowSeconds: TimeInterval = 24 * 60 * 60` now exists in `ConditionScoreDetailViewModel`, `WellnessScoreDetailViewModel`, and `TrainingReadinessDetailViewModel` (3 locations → DRY threshold crossed)
- Also `ScoreRefreshService.loadTodaySparklines()` and `ScoreRefreshService.fetchRolling24hSnapshots()` each inline `24 * 60 * 60` (2 more locations)
- Rule: extract to a shared constant, e.g., `ScoreDetailConstants.rollingWindowSeconds` or `HourlyScoreSnapshot.rollingWindowDuration`

### fetchRolling24hSnapshots duplicates loadTodaySparklines fetch logic
- `ScoreRefreshService.fetchRolling24hSnapshots()` (line 170) is a near-verbatim copy of the fetch descriptor in `loadTodaySparklines()` (line 127) — same predicate, same fetchLimit=48, same sort
- Should be extracted to a private `fetchRolling24hDescriptor()` helper and reused by both callers

### ZoomableImageItem co-location (unresolved as of feature/posture-zoom)
- `ZoomableImageItem` struct is defined in `PostureDetailView.swift:266` but used by 3 Views: `PostureDetailView`, `PostureComparisonView`, `PostureResultView`
- Rule: shared Presentation DTOs must live in `Presentation/Shared/Models/` (same rule as `ExerciseListItem`)
- Should be: `DUNE/Presentation/Posture/Models/ZoomableImageItem.swift` or `Presentation/Shared/Models/ZoomableImageItem.swift`

### ZoomableImageItem.label type inconsistency
- `ZoomableImageItem.label` is typed as `String`, not `LocalizedStringKey`
- Callsites use `String(localized:)` correctly, but there is no compiler enforcement
- Same pattern as `ScoreCompositionCard.Component.label` anti-pattern — risk of future bare String literal bypassing localization
- Fix: type `label` as `LocalizedStringKey`

### ZoomablePostureImageView sheet block triplication
- `.sheet(item: $zoomImage) { ZoomablePostureImageView(...) }` appears verbatim in `PostureDetailView`, `PostureComparisonView`, and `PostureResultView` (3 locations → DRY threshold crossed)
- Extract to a ViewModifier: `PostureImageZoomModifier(zoomImage: Binding<ZoomableImageItem?>)`
- Usage: `.postureImageZoom($zoomImage)` on each View

### PostureHistoryView.recordRow duplicate modifiers
- After the `@ViewBuilder` refactor, `.background(.ultraThinMaterial...)` and `.contextMenu { Button(role: .destructive) {...} }` are duplicated in both branches of the `if isCompareMode` block
- Shared modifiers should be applied after the branch, not inside each branch

### Canonical layout verbatim repetition in Views
- The sizeClass-split Summary Stats + Highlights block (iPad HStack / iPhone VStack) appears verbatim in all 3 detail views
- Not yet extracted; a shared `AdaptiveScoreDetailSection` view wrapping this pattern would eliminate the repetition
- Current state is acceptable but is a P3 extraction target if a 4th detail view is added

## Chart Gesture Patterns
- Chart selection: `.simultaneousGesture(selectionDragGesture)` with **default `.all` mask** (not `.subviews`)
- `.subviews` mask (per Apple docs) means "enable subview gestures but *disable* the added gesture" — anti-pattern for selection
- All 12 chart views (Shared + Activity feature variants) use identical pattern: Rectangle overlay with DragGesture
- Gesture state machine in `ChartSelectionInteraction` handles hold-to-activate + scroll restoration
- UI regression test `ChartInteractionRegressionUITests.testWeeklyStatsLongPressKeepsPeriodAndActivatesSelection()` verifies:
  - Period picker unchanged during long-press
  - Selection probe transitions from "none" to active (positive signal, not just "no crash")
  - Long-press does NOT trigger period scroll as side effect
- Risk assessment: NO risk of gesture conflict — only one gesture added per chart, no other sibling gestures present

## Key Files
- Domain models: `Dailve/Domain/Models/HealthMetric.swift` (WorkoutSummary, HRVSample, SleepStage, HealthMetric)
- Workout data boundary: `Dailve/Data/HealthKit/WorkoutQueryService.swift`
- Exercise ViewModel: `Dailve/Presentation/Exercise/ExerciseViewModel.swift`
- Shared extensions: `Dailve/Presentation/Shared/Extensions/`
- ExerciseListItem (currently misplaced): `Dailve/Presentation/Exercise/ExerciseViewModel.swift:167`
- Chart selection: `Presentation/Shared/Charts/ChartSelectionInteraction.swift`
- Regression tests: `DUNEUITests/Regression/ChartInteractionRegressionUITests.swift`
