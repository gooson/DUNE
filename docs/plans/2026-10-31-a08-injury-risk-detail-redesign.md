---
topic: A08 injury risk detail redesign
date: 2026-10-31
status: draft
confidence: medium
related_solutions:
  - docs/solutions/architecture/2026-02-20-injury-tracking-review-fixes.md
related_brainstorms:
  - docs/brainstorms/2026-02-19-injury-tracking.md
---

# Implementation Plan: A08 Injury Risk Detail

## Context

The Activity “Training Burden Check” card opens A08 only when the parent has an `InjuryRiskAssessment`. The detail already shows the calculated 0–100 score, its categorical level, every emitted factor and level-specific recommendations. A08 makes that evidence easier to scan with a strong, readable hero, factor rows and clearer relative bars while retaining the source's cautious advice. There is no A08 ViewModel or separate query. The production caller currently supplies **no posture metrics**, so a posture factor must not appear by inference.

Read-only source inventory is preserved in the rollout evidence. The [A08 layout proposal](../design/layout-map/activity-injury-risk-detail-a08.html) and [DUNE theme proposal](../design/theme-map/themes/dune-injury-risk-detail-a08.html) are browser contracts, not native captures. At `672d5fdb` and candidate `1f7f9900`, A08 View Git blob is `b00d11e62bc3be59648cc67d6f6b3415c13aedc6`; `ActivityView` `b5c8d1da9f1e22aa7bc9d3b9232e46169be18e43`, `ActivityViewModel` `19501095e6e6b780d7fec9b03dabf447410cd4b1`, calculation use case `ffd0b7af90f9328c770bc72cfcccaafc25388a5d`, model `6735272cf0354d775a33a2c37793e8f6cd9ab5d5`, shared `DetailScoreHero` `ed11d4ae486429e5e3d02283b0648c2b19804d5e`. Recheck protected blobs in the eventual A08 worktree. Historical iPad/phone/Duo A08 images at `443a32ca…` are references only. The exact source-matched original selector `ActivityExerciseRegressionTests/testActivityRiskAndReportRoutesOpen` has not yet been run and inspected for A08 in this phase; its risk auditTap image is the candidate, and its teardown is A09 Weekly Report. No native before or after pass is claimed.

## Requirements

### Functional

- Preserve the Activity card's nil guard: a nil assessment shows its empty card and no detail link. Preserve `ActivityDetailDestination.injuryRisk`, native Back, large title “Injury Risk”, `DetailWaveBackground`, and root ID `activity-injury-risk-detail-screen`.
- For non-nil assessment, show `assessment.score` exactly, derived `assessment.level.displayName`, original level `iconName`/color, and `guideMessage`. Preserve 0–25 Low, 26–50 Moderate, 51–75 High, 76–100 Critical thresholds and clamp by leaving the model untouched. If showing assessment date, source only `assessment.date` and show once. Do not label score as a clinical probability, diagnosis or confidence interval; the model contains no confidence estimate.
- Preserve every supplied factor in source order, each original factor SF Symbol, localized name, source detail, `+contribution` and bar. Existing bar width is `contribution / max(factor contributions)`, **relative to the largest factor**, not a score percentage. Keep that denominator and do not invent contribution when factors are absent.
- Distinguish non-nil score 0 with an empty factor array from a nil assessment. The former has a real low score, “No risk factors detected,” and level recommendations; the latter has the existing “Train for a few days…” empty state. Do not merge these branches.
- Preserve all `assessment.level.recommendations` in original order with the `arrow.right.circle.fill` symbol and cautious wording. Keep source localization and medical-adjacent meaning. No custom help sheet, extra explanatory medical claim, or CTA without an actual destination.
- Preserve factor types/icons: fatigue `figure.walk`, consecutive days `calendar.badge.exclamationmark`, volume spike `chart.line.uptrend.xyaxis`, sleep deficit `moon.zzz`, active injury `bandage`, low recovery `battery.25percent`, posture issue `figure.stand`. Preserve level symbols `checkmark.shield`, `exclamationmark.shield`, `exclamationmark.triangle`, `xmark.shield`; Activity entry/empty symbol remains `shield.checkered`.
- Leave calculation inputs and math untouched: 22.5/20/20/15/10/7.5/5 weights, positive-factor emission, integer truncation, descending factor order, active injury severity, week volume and sleep/readiness sources. The production path currently passes `postureWarningCount=0` and `postureScore=nil`; do not make posture visible from a prototype example.

### Non-functional

- Detail-local, opaque and contrast-safe hero with an inline native title, retaining actual level color as semantic accent, large score/status/guide hierarchy and an accessible level icon. Use DS/ScoreHeroPalette language consistent with adjacent score details, without changing shared `DetailScoreHero` or its other consumers. Factor bars should remain visibly subordinate to the absolute score; use value and text as well as color.
- Readable narrow iPhone/Duo and iPad column bounded near 680pt; maximum Dynamic Type stacks score/status and factor detail/contribution without clipping, preserves all recommendations and native Back. Respect Reduce Motion and existing static background. UI text changes require copy/localization review and en/ko/ja catalog checks; prefer existing strings.

## Approach

Keep `InjuryRiskDetailView` as a pure View of the passed assessment. Replace only its private presentation with an opaque score hero and clearer factor/recommendation grouping; preserve supplied values and conditional branches. A local hero can use the original score/status/guide/icon and optional existing date. Use level color for a bounded accent while palette ink carries small text. Keep the original relative bar formula intact. The existing root, parent guard, navigation and shared components stay unchanged.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|---|---|---|---|
| Feed posture or other new metrics into the use case | More apparent factors | No production source at this call site; changes calculation and trust | Reject for A08 |
| Rework shared `DetailScoreHero` | Reuse across scores | Changes unrelated T04/H02/A02 screens and risks their AX/layout | Reject for screen PR |
| Private hero and factor row styling | Small scope; preserves score and factor truth | Requires contrast/AX checks across risk levels | Choose |

## Affected Files

| File | Change Type | Description |
|---|---|---|
| `DUNE/Presentation/Activity/InjuryRiskDetail/InjuryRiskDetailView.swift` | Modify | Private opaque hero and factor/action presentation; original data/conditional branches. |
| `DUNEUITests/Full/ActivityExerciseRegressionTests.swift` | Conditional focused assertion/capture | Extend direct route only if it verifies real visible score/factors/Back, without treating fixture as production formula. |
| `Shared/Resources/Localizable.xcstrings` | Conditional | Avoid new copy; if essential, add all en/ko/ja and run formatter/manual checks. |
| `docs/design/layout-map/activity-injury-risk-detail-a08.html`, index/README | Plan phase | Separate layout, state and responsive proposal. |
| `docs/design/theme-map/themes/dune-injury-risk-detail-a08.html`, manifest/index/README | Plan phase | Clearly illustrative light/dark screen expression. |
| `docs/design/phone-design-map/actual/index.html`, new A08 PNGs | After native | Actual source-matched screen captures only. |

## Implementation Steps

### Step 1: Freeze original route and proposal maps

- **Files**: ignored source/capture evidence, formal plan, separate layout/theme maps.
- **Changes**: Authenticate listed blobs at `672d5fdb` and `1f7f9900`. Run exact `ActivityExerciseRegressionTests/testActivityRiskAndReportRoutesOpen` on unchanged original source with its existing `--ui-design-map-activity-routes` flag. That DEBUG/test-only fixture supplies score 42 and two factors, not normal production calculation. Inspect the **risk-link `auditTap()` PNG and XCUI hierarchy** for `activity-injury-risk-detail-screen`, score, status and factor content. Teardown is Weekly Report and is not an A08 image. Record device, source, seed, locale, theme and text size before pairing. Historical `443a32ca…` iPad/phone/Duo images do not count as this fresh before.
- **Verification**: Source-matched A08 before image identity is confirmed by actual PNG/AX, not merely a passing route assertion. No completion claim while capture is pending.

### Step 2: Implement detail-private hierarchy

- **Files**: A08 View, optional catalog, proposal maps.
- **Changes**: Keep optional assessment branch, original root/title/Back/background. Use actual score and level status/icon/guide in private opaque hero; keep zero-factor and nil-assessment states separate. Improve row typography/spacing and contribution bar readability without modifying the max-factor fraction. Keep all localized detail/recommendation strings and level-specific icon/color mapping. Do not add posture factor, probability, history chart, new help sheet or extra action.
- **Verification**: Swift parse, diff, protected hash closure, catalog format/manual checks if touched; parent-controlled build later.

### Step 3: Targeted native and actual map

- **Files**: focused UI test only if needed, actual map and new PNGs.
- **Changes**: Verify score 42/Moderate with exactly the two **known test-only** factor types under flag, their source details and recommendation reachability, and native Back to Activity then Weekly Report route. Also inspect genuine non-flag nil/zero-factor states if a deterministic existing route or focused unit fixture exists; do not imply the 42 fixture proves all seven production factors. Capture affected phone/iPad/Duo folded/open, light/dark and max AX with valid source-matched pairing.
- **Verification**: Exact direct selector and only necessary branch-specific checks; review PNG/AX for bar and copy contrast/clipping. Native checks remain pending at draft time.

## Edge Cases

| Case | Handling |
|---|---|
| Assessment nil | Existing empty explanation, no score/factors/recommendations; Activity root offers no link. |
| Assessment score 0, no factors | Real low assessment with “No risk factors detected” and level recommendations, not the nil empty state. |
| Factor contribution 0 / no factors | Preserve existing guarded max fraction, no divide-by-zero or fictitious bar; source use case emits positive only. |
| High/Critical level | Existing warning icon/color and cautious recommendations; no diagnostic probability or new medical direction. |
| Posture factor | Supported model icon/weight exists, but production caller sends no posture metrics; show only if a real supplied assessment contains it. |
| Long localized factor detail / max AX | Wrap text, keep `+contribution` associated with its factor, avoid fixed row height or clipped level icon. |

## Testing Strategy

- **Original/before**: `ActivityExerciseRegressionTests/testActivityRiskAndReportRoutesOpen` at original source with `--ui-design-map-activity-routes`; confirm risk audit tap is loaded A08. Its subsequent Weekly Report teardown is a different screen.
- **Focused after**: Re-run that selector after View change for route, factor list, recommendations and Back. Add only a meaningful assertion for fixture-specific score/2-factor state if the current test does not inspect them; identify test-only provenance in assertion message. Existing use-case unit tests remain math authority; no new percentage/weight copy tests for a View-only change.
- **Visual**: Fresh normal/dark/max AX phone/iPad/Duo folded/open as affected; score, status, original icons, factor contributions/bars, level advice, empty/zero branches where deterministic. No Watch scope.

## Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| Test-only 42/two factors mistaken for production inputs | High | High | Label fixture provenance in plan/test evidence; no product literals. |
| Relative bars interpreted as absolute risk percentages | Medium | High | Keep integer `+contribution` and visibly distinguish relative bar from 0–100 hero. |
| Shared hero edit regresses other score details | Medium | High | Private A08 View only; freeze shared hero hash. |
| Level accent/critical copy lacks contrast or overstates certainty | Medium | High | Palette ink, native visual review and original cautious wording. |
| Audit screenshot mislabeled A08 | Medium | Medium | Inspect exact risk-link PNG/root AX; Weekly Report teardown excluded. |

## Confidence Assessment

- **Overall**: Medium.
- **Reasoning**: Original route, score thresholds, factor math/icons, conditional states and fixture provenance are source-authenticated. The fresh original native capture and after-device readability have not yet been produced or reviewed.
