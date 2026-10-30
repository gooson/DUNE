---
topic: H03 sleep prediction detail redesign
date: 2026-10-31
status: approved
confidence: high
related_solutions:
  - general/2026-10-28-wellness-prediction-visual-hierarchy.md
  - architecture/2026-02-28-detail-score-hero-unification.md
---

# Implementation Plan: H03 Sleep Prediction Detail

## Context

The shared sleep prediction detail uses the legacy translucent `DetailScoreHero`, whose centered ring does not match the opaque, visually prominent T04/T05 score surfaces. Its confidence is a small neutral capsule and factor/impact rows are tightly horizontal at large text. H03 in the full redesign map calls for a clear, scrollable detail hierarchy across iPhone, iPad, and Duo. `NotificationSleepDetailPushView` (T15) also presents this same view when a prediction loads, so it is an affected consumer.

## Requirements

- Preserve the model's predicted score, outlook name/icon/guide, actual confidence, every factor type/detail/impact, tips and both empty variants, native “Tonight's Sleep” navigation, and T15 wrapper loading/empty behavior. Keep both the T15 wrapper ID and loaded H03 child/leaf IDs exposed to accessibility.
- Compose an H03-local opaque `ScoreHeroPalette` surface with `CompactConditionRing`, matching T04/T05 while leaving shared `DetailScoreHero` untouched. At accessibility sizes use a full-width text score and stacked outlook/guide. Do not add a second score, invented confidence percentage, history count, diagnosis, or new prediction logic.
- Emphasize low/medium/high confidence using the actual enum, original gauge symbol, and one/two/three qualitative marks. Keep original factor SF Symbols and tip lightbulbs.
- Use a scrollable reading width up to 680pt, Dynamic Type wrapping and stacked rows at accessibility sizes, semantic body colors, and distinct but calm surfaces.
- Localize the new score accessibility sentence and the SLEEP heading in English, Korean, and Japanese through the shared string catalog, preserving the numeric and outlook substitutions.

## Approach

Use the existing opaque score palette, static decorative dune bands, and compact score ring as the first section. Keep the original SLEEP score, outlook icon/name, and guide message; use palette ink/muted text for contrast. At accessibility sizes replace the fixed ring with a large wrapped score in the same hero, as in T04/T05. Give confidence a dedicated card with three nonnumeric marks, then separate factor and tip cards. The factor icon/text/impact badge use `AnyLayout` to move from horizontal to vertical at accessibility sizes while retaining all content and symbols. Parent container identifiers use `.accessibilityElement(children: .contain)` before `.accessibilityIdentifier`.

## Affected Files

| File | Change |
|---|---|
| `DUNE/Presentation/Wellness/SleepPredictionDetail/SleepPredictionDetailView.swift` | H03 layout only |
| `DUNE/App/ContentView.swift` | One T15 wrapper `.accessibilityElement(children: .contain)` before its existing ID, preserving loaded child IDs |
| `DUNEUITests/Full/DesignMapAdditionalRoutesTests.swift` | Focused H03 real route and max text coverage |
| `Shared/Resources/Localizable.xcstrings` | Manual en/ko/ja score accessibility and SLEEP heading strings |
| `docs/design/layout-map/sleep-prediction-detail-h03.html` | Layout contract |
| `docs/design/theme-map/themes/dune-sleep-prediction-detail-h03.html` | Direction study |
| Layout/theme indexes and manifest | Contract links |

## Steps and Verification

1. Save plan, layout and theme contracts, and map links before app edits; theme map `--check` must pass.
2. Edit only `SleepPredictionDetailView.swift`. Source-parse and scoped iOS build are required after source freeze; the parent owns build execution.
3. Extend the existing Wellness detail route test, add a dark maximum-text selector for hero, confidence, factor and tip reachability, and add one focused phone test that relaunches the existing strict UI fixture with low/medium/high confidence. Capture each actual state before scrolling; assert the enum label plus unchanged score/factors/tip. No new production flag or model change.
4. Add a loaded T15 notification route selector using the seeded “Bedtime Route Fixture” and the same sleep prediction flag. Wait for the wrapper and loaded H03 score/guide/confidence, capture before scrolling, and verify native Back returns to the Today notification hub. The in-hub tap path is distinct from the system notification response route that switches to Wellness. Parent captures affected H03 and loaded T15 consumer states on owned iPhone, iPad, and Duo tiers and refreshes the actual design map. Browser studies are not native evidence.

## Risks

- The H03 hero exposes the ring or AX text score with the same accessible score label, plus separate outlook and guide text. Tests should query that score ID and the containing hero without assuming a fixed ring at all text sizes.
- The T15 parent has its own accessibility identifier. Make it a containing group before that ID so loaded H03 score, guide, confidence, and scroll IDs remain queryable while the wrapper ID is retained; do not alter T15 task, loading, empty, or route logic.
- No prediction or no factors/tips remain distinct states; layout must show existing empty copy without fabricated content.

## Default T15 comparison provenance

The default T15 actual-map capture must use the existing `NotificationRoutingRegressionTests/testBedtimeReminderPushesFromNotificationHub` route without the strict sleep-design fixture. The preserved regular reference is a loaded real-computed prediction (historically 72 / medium confidence / five factors), rather than the new supplemental strict fixture (78 / two factors). Capture timestamps and computed values stay explicit; never pair an unavailable/loading screen or a forced two-factor fixture with this default five-factor view. The strict new T15 child-ID/native-Back test is supplemental functional evidence. H03 default comparisons retain the existing design-fixture route; low/medium/high confidence states are separate evidence.

The hero retains its original outlook SF Symbol with palette.ink, matching T06 and preserving contrast on the newly opaque surface. Confidence/factor semantic colors and all prediction values stay unchanged. Independent actual phone recheck found the prior light purple hero icon at2.43:1; this is a new visual finding, not a data change.
