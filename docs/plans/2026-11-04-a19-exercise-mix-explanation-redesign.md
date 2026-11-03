# A19 exercise mix explanation redesign

Status: implementation and scoped validation complete. Release tracking: [PR #913](https://github.com/gooson/DUNE/pull/913).

## Scope and preservation

`ExerciseMixInfoSheet` has one production caller: Activity → Exercise Mix information (`activity-exercise-mix-info`). The original ScrollView, medium/large detents, native drag indicator, chart title symbol and all four section symbols remain. The duplicated subtitle is removed. The shared opaque hero palette, consistent icon chips and four content cards provide the visual emphasis; content is centered within 680 points with flexible text and regular spacing. No extra accessibility parent grouping or font shrinking was introduced.

The service still merges and deduplicates manual/HealthKit records, filters from local start of today minus 27 calendar days through now, and calculates relative name frequency and sorting. Only the misleading all-records explanation changes to recent four weeks. One new manual English/Korean/Japanese key is registered; all 15 meaningful literals have manual catalog entries and nonempty Korean/Japanese. Existing keys are retained. No storage, permission, model, arithmetic or recommendation behavior changes.

## Source and bounded validation

The branch began at actual A18 merge `7ae114c8446b98e12d458e00d46999f7ccced881`. Application, catalog, test and runner evidence is pinned to `9c7c2cad9a6fbfaf73dc75f76a75f737496e46ec`. Five focused native cases passed in four serial runs: original normal selector on iPhone 18 Pro Max, iPad mini, Duo closed and Duo open; English dark accessibility XXXL on closed Duo. Native targets compiled through the standard runner. There were no A19 failed attempts or retries. Only one owned simulator was used at a time; all three devices were deleted after sealing archives. No additional full local suite, all-locale sweep or arithmetic unit test was needed for unchanged logic.

The normal selector is `testVisualAuditExerciseMixExplanation`; the focused sibling is `testExerciseMixExplanationAtMaximumAccessibilityTextSize`. Initial canonical capture precedes expansion. Exact full-label predicates and a single title check preserve content and duplication checks. All headings, the corrected four-week fact and representative paragraph/body endpoints are verified; bounded overlapping scrolling reads oversized text. Native medium/large behavior, dismissal and Activity return are asserted. The root entry helper keeps default 30 swipes, while this MAX caller allows 40 based on the preceding measured A18 route and the farther real entry. Its original A19 MAX case passed without additional attempts.

## Reviews, maps and limits

Independent source/data/security/performance/architecture/simplicity and SwiftUI/test reviews precede execution. Separate actual PNG/AX and stage preservation reviews cover this source and the published inventory; final publication review is required before Ship. Agent-native is not applicable to an app-only help sheet. Actual captures are linked from the layout/theme diagrams and four device design-map rows. The reviewed stage changes only 19 existing allowlisted outputs and the A19 gallery; other capture rows and pixels outside A19 tiles are preserved. The gallery contains four canonical and six MAX PNG/AX pairs. Historical before images visibly show the same explanation family, but their individual source/device/locale/pose provenance is unknown.

MAX host checkpoint 010 is a lock-screen image and is excluded as visual return proof. Actual normal returns show Activity and native return assertions passed. English captures demonstrate the selected profiles rather than every locale or theme. Catalog format/manual checks passed after native compilation. Publication changes documentation only and retains all tested source pins. CI results are recorded separately at pre-Ship; no full-suite pass is inferred from these scoped checks.

[Actual before/after gallery](../design/full-redesign-map/review/a19-exercise-mix-explanation-native-2026-11-04/index.html). Compound: `docs/solutions/general/2026-11-04-exercise-mix-window-explanation.md`.
