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

## Recent Review Findings (2026-02-17)

### Muscle Volume Calculation Now at 3 Occurrences
- Third occurrence found in `WorkoutRecommendationService.computeFatigueStates()`
- Violates Correction Log #37 — requires immediate extraction
- Recommended location: `ExerciseRecord` extension or Domain service

### Formula rawValue Display
- `OneRMFormula.rawValue` displayed directly in `OneRMAnalysisSection.swift`
- Should use `.displayName` property (but acceptable for technical users in this context)
- Status: P3 — low priority

### Metric rawValue Display in Charts
- `ExerciseHistoryView` uses `metric.rawValue` for axis labels and buttons
- Acceptable for technical metrics like "Weight", "Volume", "1RM"
- Status: Monitor only
