# A12 Exercise Mix detail redesign

Base: `4fb32ead94df9c0bc595cf744271d1003832030d`. Approved browser direction: `refs/codex/snapshots/f6123bb0dce51eb02ac8fecddbc9345965b70d50:docs/design/detail-redesign-map/manifest.json` A12 (proposal fixtures, not app data). Actual source `ExerciseMixDetailView.swift` takes precedence for supported behavior; the prototype's info button, state tabs and weekly interaction are not existing A12 actions.

## Scope

Preserve 4-week date range, workout-record total, category counts and percentages, weekly stacked segments and dates, muscle sets/shares and unattributed disclaimer, cardio counts/duration/distance, selectable top-eight donut and complete frequency list, HealthKit partial-data notice, loading/empty states, and native Back. Preserve existing data, calculations, service, navigation and source icons/colors. The current view has no period selector. Use an opaque theme-aware summary hero and clearer rows; keep charts using real source data. Accommodate accessibility sizes through explicit single-column layouts.

Files: `DUNE/Presentation/Activity/ExerciseMix/ExerciseMixDetailView.swift`, its focused UI selector if meaningful geometry/value checks are needed, layout/theme proposals and generated theme index. No VM/domain changes.

## Validation still required

Source checks and `git diff --check` only during preparation. Product compile and focused `ActivityExerciseRegressionTests/testActivityExerciseMixRouteOpensExpectedScreen` must be run later using the owned standard runner. Verify actual normal iPhone, iPad and Duo closed/open plus relevant MAX/Dark geometry, selectable donut, actual counts, dates, units and Back. New A12 actual-map captures for each affected tier are required; historical images cannot stand in for after captures. Review accessible text and layout with real data before claiming native quality.

Risks: category and donut colors have meaning; text wrapping and chart selection behavior must survive accessibility sizes. Empty, partial-data, unattributed, zero-denominator and truncated top-eight distribution paths must retain exact existing semantics.

Source test preparation adds a normal/MAX shared route with positive actual totals, full visible leaf frames, weekly/muscle/cardio checkpoints, a real off-center donut tap and selected name/count, frequency leaf and native Back. Seeded total is intentionally not hard-coded because HealthKit and manual records are merged. The selector, gesture and AX hierarchy remain unverified until native execution.
