# Security Sentinel Memory

## Project: Dailve (iOS Health App)

### Architecture Notes
- Stack: Swift 6 / SwiftUI / HealthKit / SwiftData / CloudKit
- Data sync via CloudKit means bad data propagates to all devices
- WatchConnectivity used for iPhone <-> Watch communication
- HealthKit workout UUIDs stored as String in SwiftData models

### Confirmed Safe Patterns
- HealthKit BPM range validated (20-300 bpm) in HeartRateQueryService.validatedSample AND WorkoutQueryService.validHR
- HealthKit distance validated (< 500km) in WorkoutQueryService.extractDistance
- HealthKit pace validated (60-3600 sec/km) in WorkoutQueryService.extractPaceAndSpeed
- HealthKit elevation validated (< 10,000 m) in WorkoutQueryService.extractElevation
- WorkoutDeleteService guards empty/invalid UUID before query
- ConfirmDeleteRecordModifier uses confirmation dialog before delete (correction #50)
- UUID parsing done via `UUID(uuidString:)` — safe, no string injection risk
- averagePace in ExerciseListItem is only populated from WorkoutSummary (HealthKit path), never from raw manual record fields — formattedPace() in UnifiedWorkoutRow is therefore always called with pre-validated values
- WorkoutActivityType.infer(from:) uses only .lowercased() + .contains() — no regex, no injection risk, safe keyword matching
- ExerciseSessionDetailView header calorie display has both lower (> 0) and upper (< 5000) bounds guards
- calories field passed to ExerciseListItem.calories has no display-time bounds guard — only guarded in ExerciseSessionDetailView, not in UnifiedWorkoutRow compactTrailing/fullTrailing

### Known Gaps (P3 level)
- UnifiedWorkoutRow compactTrailing/fullTrailing renders item.calories without an upper-bound guard (no < 5000 check). The `calories` field on ExerciseListItem is sourced from `record.bestCalories` (manual/HK) or `workout.calories` (HK). HK path is already validated upstream but manual path relies on input validation at entry time. Risk: a corrupted/absurd calorie value would display in the row list but not in the session detail header (where the guard exists).
- InjuryRecord.startDate has no lower-bound date validation — a CloudKit-injected record with startDate in the distant past (e.g. year 1900) will produce an arbitrarily large durationDays value and distort statistics. `isFuture` only validates the upper bound.
- InjuryViewModel.applyUpdate() resets isSaving = false implicitly via early return — but in success path the flag is never reset (isSaving is only set in createValidatedRecord, not applyUpdate). This is an inconsistency but not exploitable since applyUpdate does not set isSaving = true.
- InjuryCardView.durationLabel creates a new DateFormatter on every render call — performance gap, not security (P3 overlap with Performance Oracle).

### Recurring Patterns to Watch
- `errorMessage = error.localizedDescription` — can expose internal error details to UI (P3)
- `try? modelContext.save()` removed in this diff — was silently swallowing errors
- UserDefaults used for workout recovery state — low sensitivity data, acceptable
- `print()` debug calls in production code (WorkoutManager.swift lines 304, 316)

### Not Applicable to This Codebase
- SQL injection (no raw SQL, uses SwiftData/HealthKit)
- XSS (native iOS app, no WebView)
- CSRF (no web endpoints)
- Auth bypass (HealthKit permission model managed by OS)
