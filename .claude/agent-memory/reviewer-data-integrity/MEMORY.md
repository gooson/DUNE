# Data Integrity Guardian Memory

## Project Context
- Health & Fitness App with HRV/RHR analysis
- SwiftData + CloudKit backend (bad data spreads across all devices)
- Critical: Input validation at entry point prevents CloudKit propagation

## Key Patterns Learned

### SwiftData Relationship Integrity
- @Relationship(deleteRule: .cascade) ensures child cleanup
- Inverse relationships must be bidirectional for consistency
- String-based enum storage requires fallback on decode (compactMap, ??)

### Validation Rules from Correction Log
- HealthKit value ranges: Weight(0-500kg), BMI(0-100), HR(20-300bpm), HRV(0-500ms)
- String input limits: Memo max 500 chars
- User input: Always validate before SwiftData insert
- Consistent validation across all query paths for same data

### Common Data Integrity Risks
1. Missing validation on optional fields (weight can be empty but if present must be valid)
2. String-to-number conversion without bounds checking
3. Relationship cascade without testing orphan cleanup
4. Enum rawValue storage without decode fallback
5. Math operations without NaN/Infinite checks

## Review Checklist
- [ ] All user inputs have min/max range validation
- [ ] String-to-number conversions check bounds
- [ ] Optional inputs: empty OK, but if present must validate
- [ ] Math results checked for isNaN, isInfinite
- [ ] Relationships have proper deleteRule
- [ ] Enum decoding has fallback (compactMap or ?? default)
- [ ] isSaving flag on all mutation methods
- [ ] CloudKit implications considered (bad data spreads)
- [ ] .task(id:) key covers CONTENT change, not just count change (count-only keys miss same-count mutations)
- [ ] Stale data: items/@State index rebuilt atomically — buildItems() and rebuildRecordIndex() must stay in sync
- [ ] Silent navigation sink (EmptyView()) signals item/index desync — count change alone won't catch same-size record replacement

## Patterns: Injury Tracking (@Model with rawValue enums)
- `InjurySeverity` uses `Int` rawValue — CloudKit can sync arbitrary Int values; decode fallback `.minor` silently accepts invalid server values (e.g., 0, 4, 99). Needs range guard at read site.
- `BodyPart` uses `String` rawValue — fallback to `.knee` on unknown string is safe but opaque; a corrupted record looks valid in the UI.
- `markAsRecovered()` mutates a SwiftData @Model directly with no `isSaving` guard — concurrent taps from swipeAction + contextMenu can both fire before CloudKit sync.
- `applyUpdate()` has `isSaving` guard but never sets `isSaving = true` before mutating — a second tap within the same runloop frame bypasses the guard.
- `endDate` future validation missing from `validateInputs()` — the DatePicker `in: startDate...Date()` enforces this in the UI, but the ViewModel has no corresponding guard.
- `startDate` `isFuture` check has ~60-second grace window (`Date().addingTimeInterval(60)`); if `endDate` is also provided and also sneaks in as slightly future, the check passes.
- Statistics `averageRecoveryDays` divides by `recoveryDays.count` which is guarded by `!recoveryDays.isEmpty`, so no divide-by-zero risk.
- `comparisonWindowDays` negative values not validated in `computeVolumeComparisons` — caller could pass 0 or negative; `calendar.date(byAdding: .day, value: 0/negative)` returns unexpected windows.
- WellnessView edit sheet for injury has no `isSaving` reset path after `applyUpdate` — `isSaving` is always false in `applyUpdate` because it was never set true, making the guard vestigial.

## Patterns: View-local item merge (ExerciseListSection pattern)
- buildItems() + rebuildRecordIndex() called from same .task(id:) — items and index can briefly desync if task is cancelled after first call but before second
- Count-only task ID misses same-count replacements (delete+add in same batch), causing stale rendered rows until next count change
- destination(for:) with EmptyView fallback is a silent failure — navigation taps produce a blank sheet with no error
- Dictionary(uniqueKeysWithValues:) in rebuildRecordIndex() will crash if exerciseRecords contains duplicate IDs (SwiftData @Model IDs should be unique in practice, but defensive use of init(_:uniquingKeysWith:) is safer)
- calories displayed in UnifiedWorkoutRow without validation bounds — ExerciseSessionDetailView guards cal > 0 && cal < 5000 but row display does not (minor consistency)
- WorkoutActivityType.infer(from:) keyword matching is duplicated in ExerciseListSection and ExerciseViewModel — single source of truth exists (ExerciseDefinition.resolvedActivityType) but the fallback call path is duplicated
