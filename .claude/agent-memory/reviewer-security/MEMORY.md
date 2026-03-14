# Security Sentinel Memory

## Project: Dailve (iOS Health App)

### Architecture Notes
- Stack: Swift 6 / SwiftUI / HealthKit / SwiftData / CloudKit
- Data sync via CloudKit means bad data propagates to all devices
- WatchConnectivity used for iPhone <-> Watch communication
- HealthKit workout UUIDs stored as String in SwiftData models

### Confirmed Safe Patterns
- VitalsQueryService applies validRange guards on every fetchLatest/fetchCollection path — spo2 (0.70-1.0), respRate (4-60), vo2Max (10-90), hrRecovery (0-120), wristTemp (30-42°C)
- CalculateWellnessScoreUseCase guards totalWeight > 0 and checks .isNaN/.isInfinite on rawScore before returning
- WellnessScore.init clamps incoming score with max(0, min(100, score)) — display-time overflow impossible
- WellnessViewModel: no print()/NSLog()/errorMessage=localizedDescription in any of the 8 new files
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

### Ocean Wave Curl Integration (Commit 8d74326)
- **P1 Issue**: curlCount parameter lacks upper-bound validation. No max check in init — malicious/extreme curlCount (e.g., 10000) causes excessive array iteration in computeCurlAnchors loop and sorting, potential DoS/hang
- **P2 Issue**: curlWidth parameter converted to halfWidth without range guards — `Int(curlWidth * CGFloat(count) / 2)` with no min/max on curlWidth input. Negative curlWidth produces negative halfWidth → inverted array indices (startIdx > endIdx)
- **P1 Issue**: Crest detection loop bounds check insufficient — loop `for i in 2..<(count - 2)` is safe IF count > 4. But if count <= 4 (e.g., very low frequency wave), range is empty and no exception. However, logic assumes samples.points always has 121 items (WaveSamples.sampleCount = 120 + 1 for 0...count), so this is mitigated. No external validation of frequency parameter though.
- **P2 Issue**: lipIdx calculation `Swift.min(ci + halfWidth * 2 / 3, endIdx)` uses integer division on non-validated halfWidth — if halfWidth is negative (from negative curlWidth), arithmetic is unpredictable
- **P2 Issue**: curlHeight parameter multiplied unchecked in render pipeline (`curlHeight * amp`). No validation on curlHeight bounds — extreme positive (1e6) or negative (-1e6) values pass through and distort Bezier control points, potential rendering crash

### Known Gaps (P3 level)
- WellnessViewModel.formatSleepMinutes() uses Int(minutes) % 60 without guarding minutes >= 0 — negative input (corrupted HealthKit sleep record) produces negative display string like "-1m"
- VitalsQueryService hrRecoveryRange lower bound is 0.0, not > 0. A 0 bpm HRR sample passes validation and scores as valid data. Physiologically 0 bpm drop = no recovery, arguably a sensor/data error.
- WellnessViewModel weight change calculation (line 769) uses >= 6 days threshold for "week-ago" weight without capping the upper window — a weight entry 90 days old will be accepted as "7-day change", violating Correction #51's valid comparison window principle
- subScoreCard/subScoreRow (WellnessScoreDetailView) compute `fraction = CGFloat(score ?? 0) / 100.0` without clamping — if a score > 100 were passed in, the progress bar would overflow its bounds. WellnessScore.init already clamps 0-100 so risk is low but no defence-in-depth at rendering site
- UnifiedWorkoutRow compactTrailing/fullTrailing renders item.calories without an upper-bound guard (no < 5000 check). The `calories` field on ExerciseListItem is sourced from `record.bestCalories` (manual/HK) or `workout.calories` (HK). HK path is already validated upstream but manual path relies on input validation at entry time. Risk: a corrupted/absurd calorie value would display in the row list but not in the session detail header (where the guard exists).
- InjuryRecord.startDate has no lower-bound date validation — a CloudKit-injected record with startDate in the distant past (e.g. year 1900) will produce an arbitrarily large durationDays value and distort statistics. `isFuture` only validates the upper bound.
- InjuryViewModel.applyUpdate() resets isSaving = false implicitly via early return — but in success path the flag is never reset (isSaving is only set in createValidatedRecord, not applyUpdate). This is an inconsistency but not exploitable since applyUpdate does not set isSaving = true.
- InjuryCardView.durationLabel creates a new DateFormatter on every render call — performance gap, not security (P3 overlap with Performance Oracle).

### Hourly Condition Tracking Audit (Branch feature/hourly-condition-tracking)
- **P2**: `HourlyScoreSnapshot` has no bounds validation on `conditionScore`, `wellnessScore`, `readinessScore` (docs say 0-100) or on `hrvValue`/`rhrValue`/`sleepScore`. A corrupted CloudKit record with out-of-range scores persists and propagates to sparkline rendering without any clamping.
- **P2**: `HourlySparklineData.yDomain` computes `max(0, minScore - 5)...min(100, maxScore + 5)` — safe at the chart level, but the underlying `score` values are never clamped before being stored or used for delta calculation. A score of 200 produces a delta of 200 displayed in `ScoreDeltaBadge` via `Int(abs(delta))`.
- **P2**: `ScoreRefreshService.lastSnapshotHour` skip gate (`if let lastHour = lastSnapshotHour, lastHour == hourDate { return }`) fires once per process launch per hour. Three independent ViewModels (Dashboard, Wellness, Activity) each call `recordSnapshot` with a different score field and nil for the others. First caller wins and sets `lastSnapshotHour`; subsequent callers in the same hour are silently dropped. Result: whichever VM loads first determines the saved snapshot — the other two score fields remain nil for that hour even though valid scores were computed.
- **P3**: `ScoreRefreshService` error path logs `error.localizedDescription` to `AppLogger.data` — consistent with the codebase pattern, not user-facing, acceptable.
- **Safe**: CloudKit migration follows V14→V15 lightweight migration with explicit stage — correct pattern per `swiftdata-cloudkit.md`.
- **Safe**: `HourlyScoreSnapshot` all fields Optional for CloudKit compatibility — correct.
- **Safe**: `ScoreRefreshService` is `@MainActor` — no concurrent write race to in-memory sparkline state.
- **Safe**: `buildSparkline` uses `compactMap` to skip nil score fields — no NaN/Infinite risk at sparkline construction.
- **Safe**: No secrets, credentials, or user PII stored in the new model; only computed health scores.

### Localization Audit (Commit 842a1bc)
- **Safe**: 31 new xcstrings keys added (no secrets, no injection patterns, no XSS vectors)
- **Safe**: Enum rawValue → displayName pattern with String(localized:) is type-safe
- **Safe**: Helper function parameters changed from String → LocalizedStringKey (compile-time checked)
- **Safe**: WellnessViewModel card titles wrapped with String(localized:) — no user-provided data interpolation
- **Safe**: Orphaned keys removed (Coming Soon, Coarse Dust, Fine Dust, Ozone) — no sensitive data in removal
- **Safe**: Smart quote mismatch fixed (U+2019) — purely Unicode/formatting, no security impact
- **No injection risk**: All localization strings are compile-time constants, no dynamic/user-input interpolation

### Notification & Bedtime Reminder Audit (Commit claude/determined-proskuriakova)
- **P2**: `BedtimeWatchReminderScheduler.settingsKey` is a public `static let` string used raw with `@AppStorage` — consistent, no injection risk, but public exposure of raw UserDefaults key means external code or future test could collide. Acceptable as-is since it's still within the same module.
- **P2**: `formattedValue` strings from HealthKit are joined with `\n` and written into notification body without length capping. A large number of body composition updates in a single merge window could produce an arbitrarily long notification body string. UNNotificationContent does not enforce a limit programmatically but OS will truncate display. Not exploitable but a DoS-style degraded UX vector.
- **Safe**: Body composition buffer in UserDefaults uses JSONEncoder/JSONDecoder round-trip with a private `BodyCompositionBufferEntry` Codable struct — no injection risk, type-safe deserialization.
- **Safe**: `replacingIdentifier` in NotificationServiceImpl is passed as a constant `"com.dune.bodyComposition.merged"` from a private enum — not user-controlled.
- **Safe**: VitalsQueryService.fetchLatestWristTemperature already applies validRange (30-42°C guard) per confirmed safe pattern in memory — wrist temp gate in BedtimeWatchReminderScheduler does not bypass HealthKit validation.
- **Safe**: `shouldSuggestLevelUp()` and `applyInterSessionOverload()` operate only on local `sets`/`previousSets` state (no network, no persistence writes). `clampedIncreaseKg = min(incrementKg, max(maxIncreaseKg, 0))` has a logic bug (inverted max clamp) but not a security issue.
- **P3**: `settingsKey` for bedtime reminder uses `UserDefaults.standard` (not a suite) — consistent with existing throttle store pattern in this codebase, low risk.

### Recurring Patterns to Watch
- `errorMessage = error.localizedDescription` — can expose internal error details to UI (P3)
- `try? modelContext.save()` removed in this diff — was silently swallowing errors
- UserDefaults used for workout recovery state — low sensitivity data, acceptable
- `print()` debug calls in production code (WorkoutManager.swift lines 304, 316)

### Posture Assessment Audit (Branch claude/elated-herschel)
- **P1**: `PostureAssessmentRecord` stores raw JPEG `Data?` in SwiftData (`frontImageData`, `sideImageData`). This data syncs to CloudKit and propagates across all devices — user body images stored without size cap. A single high-res JPEG at default AVFoundation quality can be 3-10 MB; multiplied across records and devices this is a significant data exposure and storage risk. No maximum byte-size guard exists before `modelContext.insert(record)`.
- **P1**: `photoContinuation` in `PostureCaptureService` is a stored `var` property not protected against concurrent access. The class is declared `@unchecked Sendable`. If `capturePhoto()` is called concurrently (e.g. countdown Task not cancelled before second tap), the first continuation leaks and is never resumed — guaranteed Task suspension leak (memory leak + silent hang).
- **P2**: `overallScore` in `PostureAssessmentRecord` is stored as plain `Int` with no bounds validation at init time. `combinedAssessment.overallScore` is `Int(raw.rounded())` but `PostureAnalysisService.calculateOverallScore` already clamps to 0-100; however `PostureAssessmentRecord.init` accepts any `Int` directly — a CloudKit-injected record could carry a score outside 0-100 and render unclamped in the UI (score arc trim goes from `CGFloat(overallScore) / 100.0`, so a score of 200 fills the ring 2× over, a negative score draws nothing but may confuse stats).
- **P2**: `PostureCaptureService.captureSession` is `let` (public) on the service; `PostureAssessmentViewModel` exposes `captureService` as `let` (not private). Any caller can reach `captureService.captureSession` and stop/start/reconfigure the session externally, bypassing `setupCamera()` safety guards.
- **P2**: `JointPosition3D.name` is a free `String` field that gets JSON-encoded into `frontJointPositionsJSON`/`sideJointPositionsJSON` and stored in SwiftData / synced via CloudKit. While the field is populated from a fixed `trackedJoints` static array, there is no validation that names conform to that set at the model level — a CloudKit-injected record with arbitrary joint names persists and could produce unexpected behavior in analysis service lookup.
- **P3**: `PostureCaptureView.analyzingOverlay` has `Text("Analyzing posture...")` as a hardcoded English string (not wrapped in `String(localized:)`). Minor localization leak, not a security issue.
- **Safe**: `PostureAssessmentViewModel.createValidatedRecord()` trims memo to 500 characters via `String(memo.prefix(500))` — memo overflow prevented.
- **Safe**: `PostureAssessmentViewModel.createValidatedRecord()` guards `isSaving` flag for idempotency — double-save prevented, flag reset in both nil-return paths.
- **Safe**: `PostureCaptureService.setupCamera()` uses `AVCaptureDevice.default(.builtInWideAngleCamera, position: .front)` — fixed hardware device, no user-controlled path injection.
- **Safe**: `PostureCaptureService.extractJointPositions` guards `x.isFinite, y.isFinite, z.isFinite` — NaN/Inf coordinates filtered before storage.
- **Safe**: `PostureAnalysisService` is a pure value-type domain service with no imports of AVFoundation/UIKit — correct layer separation.
- **Safe**: Schema migration V15→V16 uses lightweight migration with explicit stage — correct pattern per `swiftdata-cloudkit.md`. `PostureAssessmentRecord` relationships are all Optional for CloudKit compatibility.
- **Safe**: Error messages shown in `capturePhase = .error(...)` are either constant localized strings or `captureErrorMessage(error)` which maps to localized strings — no `error.localizedDescription` leakage to UI.
- **Safe**: `PostureAssessmentRecord` JSON decode uses `try? decoder.decode(...)` with a typed Codable — no untyped deserialization risk.

### Not Applicable to This Codebase
- SQL injection (no raw SQL, uses SwiftData/HealthKit)
- XSS (native iOS app, no WebView)
- CSRF (no web endpoints)
- Auth bypass (HealthKit permission model managed by OS)
