# Code Simplicity Reviewer - Project Memory

## Duplication Patterns Observed

### Weekly Muscle Volume Calculation (3 occurrences - EXTRACT REQUIRED)
- **Pattern**: Filter records by date window → loop → accumulate primary/secondary muscles with weighting
- **Locations**:
  1. `MuscleMapSummaryCard.swift` (lines 10-24)
  2. `MuscleMapView.swift` (lines 10-24)
  3. `WorkoutRecommendationService.swift` (lines ~150-165)
- **Rule**: Secondary muscles get half weight (`max(setCount / 2, 1)`)
- **Risk**: Domain rule embedded in 3 places — MUST extract per Correction Log #37
- **Action Required**: Extract to shared function or extension

### ExerciseRecord → ExerciseRecordSnapshot Transformation (2 occurrences)
- **Pattern**: Map records to snapshots with date/ID/muscles/setCount
- **Locations**: `ActivityViewModel.updateSuggestion()`, `ExerciseView.updateSuggestion()`
- **Status**: 2 occurrences OK per Correction Log #37. Monitor for 3rd.

### Previous Set Info Display Logic (2 occurrences)
- **Pattern**: Format previous set weight/reps/duration for display in UI
- **Locations**: `SetRowView.swift` (lines 65-80), `WorkoutSessionViewModel.fillSetFromPrevious()` (lines 193-208)
- **Status**: 2 occurrences OK. Monitor for 3rd.

## Common Anti-Patterns to Watch For

### Single-Use Computed Properties
- `hasData: Bool { !collection.isEmpty }` — adds indirection without semantic value
- **Rule**: Only extract if name adds domain meaning beyond the expression itself
- **Example Found**: `MuscleMapSummaryCard.hasData` - acceptable as it clarifies intent for empty state

### Magic Numbers in View Logic
- Limits like `.prefix(6)` for "top N items" should have named constants with rationale
- Ask: Is this a design constraint or arbitrary? If arbitrary, consider dynamic sizing.

### rawValue Direct Display in UI
- **NEVER** display `enum.rawValue` directly in user-facing text
- **ALWAYS** use `.displayName` computed property in `Presentation/Shared/Extensions/{Type}+View.swift`
- **Common violations**: Formula names, metric names, category names

### Inconsistent Dependency Injection Patterns
- Mix of optional-with-nil-coalescing and direct-default-value confuses readers
- Prefer: All direct defaults in signature if no side effects, OR all optional if conditionally injected

## Project-Specific Rules

### DRY Threshold (from Correction Log #37)
- **2 occurrences**: Allowed. Monitor.
- **3 occurrences**: Must extract immediately.
- **Complex logic (10+ lines)**: Consider extracting at 2 occurrences if domain rule embedded.

### Layer Boundaries (from swift-layer-boundaries.md)
- ViewModel should NOT import SwiftUI or SwiftData
- Domain models should NOT have UI types
- Presentation extensions in `{Type}+View.swift` pattern

## Recent Review Findings

### 2026-02-19: Unified Workout Row Review (FINAL)
- **ExerciseListItem construction (P1 DRY)**: `ExerciseRecord`→`ExerciseListItem` mapping (resolve definition, infer activityType, check HK link, ~15 lines) is duplicated verbatim in `ExerciseListSection.buildItems()` (lines 122-148) and `ExerciseViewModel.invalidateCache()` (lines 72-96). Correction Log #37: 3 occurrences = must extract. Target: `ExerciseListItem.fromManualRecord(_:library:)` static factory on `ExerciseListItem`.
- **`infer(from:)` switch pattern (P2)**: 15 `case let n where n.contains(...)` arms are more verbose than a direct `if/else` or dictionary-based lookup. A `[(String, WorkoutActivityType)]` keyword table is easier to extend and avoids the `n` rebinding boilerplate. Not a correctness issue.
- **`activityIcon(size:)` style-conditional font (P2)**: Font resolved via ternary on `style` inside a helper that already receives `size`. The caller (compact vs full) already controls `size`; having the function also infer `.body` vs `.title3` from `style` adds a hidden coupling. Better to pass `font` alongside `size`, or use two explicit call sites.
- **`// MARK: - Row (replaced by UnifiedWorkoutRow)` empty MARK (P3)**: Dead section marker at `ExerciseView.swift:295` with no body. Should be deleted.
- **`dateRow` property used once (P3)**: Named computed property used exactly once inside `compactContent`. Inlining removes indirection without cost.

### 2026-02-19: Training Dashboard Redesign Review
- **Muscle Volume Calculation**: Already extracted to `ExerciseRecord+WeeklyVolume.swift` extension. Pattern is clean.
- **Recovery Color Logic**: Duplication of recovery threshold (0.8) across `MuscleFatigueState.isRecovered` and `MuscleRecoveryMapView` color functions. Acceptable — Domain defines threshold, View uses derived state.
- **SVG Parser**: 437-line `MuscleBodyShape.swift` is justified complexity for SVG path parsing. Domain-specific requirement, not over-engineering.
- **WorkoutActivityType**: 385-line enum with muscle mappings — large but necessary. Exhaustive switch cases ensure type safety.

### 2026-02-19: Injury Tracking Review
- **`InjuryConflictChecking` protocol (P1 dead)**: Protocol defined in `CheckInjuryConflictUseCase.swift` with one conformer and zero call-sites via the protocol type. `InjuryViewModel` holds a concrete `CheckInjuryConflictUseCase`, not the protocol. Delete the protocol.
- **`durationDays` duplication (P2)**: Identical 2-line implementation in `InjuryRecord` (Data layer) and `InjuryInfo` (Domain). 2 occurrences — monitor. If a 3rd appears, extract.
- **`isActive` duplication (P2)**: `isActive: Bool { endDate == nil }` implemented in both `InjuryRecord` and `InjuryInfo`. Same 2-occurrence rule — monitor.
- **`InjuryBodyMapView` is unreferenced (P1 dead)**: Only `Dailve/Presentation/Injury/InjuryBodyMapView.swift` defines the type; zero call sites found across the entire codebase.
- **`localizedDisplayName` on `InjurySeverity` and `BodyPart`/`BodySide` is unused (P2 dead)**: No call site references `.localizedDisplayName` on injury-specific types. Other types in the project do use it (MuscleGroup, Equipment), so the pattern exists, but the injury-specific ones are dead.
- **Double `.isActive` filter in `InjuryViewModel.checkConflicts` (P3)**: Caller already passes `activeInjuries`, then line 116 filters again by `.isActive`. One of the two filters is redundant.
- **`DateFormatter` created per render in `InjuryCardView.durationLabel` (P2)**: Formatter allocated on every call to `durationLabel` (every render). Should be `private static let`.
- **`InjuryWarningBanner` recomputes `maxSeverity` inline (P3)**: `conflicts.map(\.severity).max()` is computed in body, same value already available from `CheckInjuryConflictUseCase.Output.maxSeverity`. Banner could accept `maxSeverity` directly or use `Output` struct.
- **`hasConflict` and `maxSeverity` on `Output` are unused at call sites (P2 dead)**: `ActivityView.injuryConflicts` extracts `.conflicts` directly; `.hasConflict` and `.maxSeverity` on `Output` are never read.

### 2026-02-17: Prior Findings
- Muscle Volume Calculation extracted to shared extension (resolved)
- Formula/Metric rawValue display: acceptable for technical context
