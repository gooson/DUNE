---
topic: A02 Training Readiness detail redesign
date: 2026-10-31
status: draft
confidence: high
related_solutions:
  - docs/solutions/architecture/2026-03-14-score-detail-unification.md
  - docs/solutions/architecture/2026-03-15-wellness-readiness-hourly-detail.md
  - docs/solutions/architecture/2026-02-24-wellness-readiness-shared-snapshot-parity.md
related_brainstorms: []
---

# Implementation Plan: A02 Training Readiness Detail Redesign

Formal A02 screen plan. It records no implementation or post-change validation result. [Screen layout contract](../design/layout-map/training-readiness-detail-a02.html) and [preserved theme direction](../design/theme-map/themes/dune-training-readiness-detail-a02.html) are proposals, separate from native evidence.

## Context

The Activity readiness detail currently has a functional score, time adjustment, five-period trend, three non-day subtrends, five weighted components, and calculation explanation. Its layout uses the older shared `DetailScoreHero` and separates the period picker, chart header, plot, and summary. Recompose this **one destination** in the approved detail visual language while retaining the existing data and interactions. The prototype's scores are illustrative, not app fixtures.

Original-source identity is recorded in `.codex-checks/a02/original-source.json` at A02 base `672d5fdb`: `TrainingReadinessDetailView.swift` SHA-256 `87c2ed70c25dcd4f7f5bb344f6d3f120b7a50c4e6b6fc7c920269d83cdb296b2`, `TrainingReadinessDetailViewModel.swift` `ce05fcb2e053a716614ba1723d344becd4beb847fa4dc9051a26e96c00b7acbd`. The fresh original iPhone route/period/subtrend selector passed in **English at maximum accessibility text size** because `VisualAudit.isEnabled` relaunches with Accessibility XXXL (`ActivityExerciseRegressionTests.swift:586-600`); its before evidence is in `.codex-checks/a02/before-phone-current/`. The original iPad first selector has also passed at English/max-AX while its baseline batch is still in progress. Neither is a normal-text baseline. Normal-text original captures are pending from the unchanged source; Duo folded/open have not been established by this plan. Historical `actual/{regular,ipad,duo,duo-open}/images/A02.png` in the prototype manifest matches screen/device identity but comes from revision `443a32ca4fe8b79d644b36853eaa7662e7a57606` on 2026-10-12 with null state/theme. It is an identity reference, not a same-source before capture.

## Requirements

### Functional

- Preserve Activity readiness hero push, `activity-training-readiness-detail-screen`, fixed-English navigation title, native Back, loading/empty/calibrating branches, `TrainingReadiness` score/status/evaluation date, and actual component values. Current status comes from model thresholds: Ready 80–100 (`flame.fill`), Moderate 60–79 (`figure.walk`), Light Activity 40–59 (`leaf.fill`), Rest Day 0–39 (`bed.double.fill`). Use existing status label/color/guide and status icon, never `figure.run` (empty-state icon) as a current-score status.
- Keep all five *computed contribution scores* and distinct weights: HRV Variability 30%, Sleep Quality 25%, Resting Heart Rate 20%, Recovery Status 15%, Trend Bonus 10%. Display each component's actual 0–100 score separately from its weight; bars reflect score, not percentage weight. Keep original `ScoreCompositionCard` data and all original `CalculationMethodCard` bullets, including conditional calibration.
- Retain `TimeOfDayCard`'s actual adjustment and base score, enabling its existing adaptive layout at the A02 call site. Do not introduce a projected score value or new computation.
- Keep `D/W/M/6M/Y` picker, selected period reload, visible range, Trend toggle, real chart scroll domain/position, point selection, baseline 50, summary/highlights, and HRV/RHR/Sleep subtrends only outside Day. A02 ViewModel has no period-stepping API; do not add inert previous/next arrows.
- Distinguish current five-component score from history: Day uses rolling readiness snapshots; non-day history is an HRV/RHR/Sleep approximation requiring HRV and aggregated over longer periods. Neither the chart nor a neutral component fallback proves five observed inputs. Do not present fabricated history, input availability, confidence, or a fixed prototype score.

### Non-functional

- Native one-screen-only implementation. Use A02-private hero/evidence composition with existing `ScoreHeroPalette` opaque surface and `CompactConditionRing`; keep shared `DetailScoreHero`, shared chart components, model, use case, ViewModel, Activity root, Watch, and A04 disabled 3D flag unchanged.
- Preserve Dynamic Type, VoiceOver names, 44-point controls, localization (en/ko/ja), light/dark/theme ink contrast, and iPhone/iPad/Duo folded/open width. Use localized date formatting from `evaluationDate`; never substitute capture date.
- Do not modify fetch ranges, queries, score calculation, history aggregation, or retrieval fallbacks. Reuse fixture provenance and targeted validation evidence.

## Approach

Create an A02-private opaque score hero patterned after H02's private hero and T04/T05 headers. It owns the status glyph, readable score/ring, evaluation date, calibration indicator, and five visible factor rows. Each row separates the 0–100 component score from the 30/25/20/15/10 contribution weight; factor symbols (HRV `waveform.path.ecg`, Sleep `moon.zzz.fill`, RHR `heart.fill`, Recovery `heart.text.clipboard`, Trend `chart.line.uptrend.xyaxis`) have category meaning, while the model status symbol has status meaning. Choose ink legibility on the opaque card; do not use the status tint alone as text on brown (H03 contrast lesson).

Group the existing Picker, `ScoreDetailChartHeader`, `DotLineChartView`/empty plot, summary, and highlights in one `StandardCard` without changing their bindings or period transition. Keep `chartHeight`/scroll-domain behavior until actual max-AX captures show a need; do not impose a smaller plot frame. Keep three non-day subtrend cards, composition, and full calculation explanation below. A single clear disclosure for calculation is permissible only if all bullet branches remain accessible and its control is at least 44pt; the smallest implementation leaves the existing calculation card open.

### Alternative Approaches Considered

| Approach | Benefit | Cost/risk | Decision |
|---|---|---|---|
| A02-private hero and View recomposition | Matches approved local pattern; protects other screens | Small local view code | Chosen |
| Edit shared `DetailScoreHero` | Fewer A02 lines | Changes H02/T04/other consumers | Reject |
| Rebuild history/score from prototype fixtures | Visually easy | False clinical/data claims; retrieval changes | Reject |
| Add date arrows now | Prototype parity | No A02 ViewModel stepping contract; inert control risk | Reject |

## Affected Files

| File | Change type | Description |
|---|---|---|
| `docs/design/layout-map/training-readiness-detail-a02.html`, layout index/README | Add/link before implementation | Source-backed responsive and state contract; mark illustrative values |
| `docs/design/theme-map/themes/dune-training-readiness-detail-a02.html`, manifest/README/generated index | Add/preserve theme direction | Opaque palette/ring visual proposal, explicitly illustrative and separate from native capture |
| `DUNE/Presentation/Activity/TrainingReadiness/TrainingReadinessDetailView.swift` | Edit | A02-private hero/evidence and unified trend composition; retain existing bindings and branches |
| Optional A02-local View file | Add only if size warrants | Private hero extracted from View; no shared primitive changes |
| `DUNE/Resources/Localizable.xcstrings` | Conditional edit | Only genuinely new visible/AX wording; en/ko/ja and catalog checks |
| `DUNEUITests/Full/TrainingReadinessDetailRedesignTests.swift` | Add focused contract | Actual seeded score/status/components and changed interactions |
| `docs/design/phone-design-map/actual/...` | Refresh after source change | New actual captures and provenance for affected states/devices |

Files deliberately outside implementation scope: `TrainingReadinessDetailViewModel.swift`, `CalculateTrainingReadinessUseCase.swift`, `TrainingReadiness.swift`, `DetailScoreHero.swift`, `ScoreHeroPalette.swift`, shared chart/composition components, Activity root, and A04 3D gating. If implementation reveals a necessary contract change, stop and re-scope explicitly before editing those files.

## Implementation Steps

### Step 1: Freeze source and actual before state

- **Files**: A02 layout-map/index/README, theme-map preserved proposal/manifest/README/generated index; ignored evidence manifest.
- **Changes**: Use the frozen source hashes above; review root Activity hero, theme map, H02/T04/T05 local hero, current A02 view, and the screen layout contract. The unchanged-source iPhone `ActivityExerciseRegressionTests/testTrainingReadinessDetailShowsTrendAndSubscoreSections` **English/max-AX** baseline has passed and is preserved in `.codex-checks/a02/before-phone-current/`; the source selector relaunches at max AX when visual audit is enabled. Original iPad first max-AX case has passed while its batch continues. Collect normal-text originals separately from the frozen unchanged source, plus Duo folded/open before App edits, each with source, fixture, score/status, period, appearance, text size, viewport and path. Capture alternate states only when existing fixture paths reach them; never label historical PNGs as same-state before.
- **Verification**: Pair each before image to source hash, screen identity, device, and exact text size/style. Current iPhone max-AX and iPad first max-AX case passed; iPad batch, normal text, and Duo remain incomplete. Maps explicitly distinguish proposal from actual app evidence.

### Step 2: Implement A02-only hero and trend layout

- **Files**: `TrainingReadinessDetailView.swift` (optional private sibling only).
- **Changes**: Preserve branches/task. Replace only `scoreHero` presentation with A02-local opaque hero, actual model status/date/calibrating and five rows. Set `TimeOfDayCard(usesAdaptiveLayout: true)` at call site. Move period/header/chart/summary/highlights into a single `StandardCard`; retain Picker selection, `ScoreDetailChartHeader` binding, DotLineChart options, `.id(period)` opacity transition, and AXIDs. Leave composition, subtrends, and complete calculation explanations available.
- **Verification**: Compile once in branch process; visually compare seeded values against Activity root and existing composition, and inspect chart gesturing/selection.

### Step 3: Focused interaction and accessibility contracts

- **Files**: New focused UI class; catalog only if wording was added.
- **Changes**: Add meaningful tests against actual seed, not prototype literals: (1) Activity hero → native detail/back; actual score/status/icon/evaluation date and five component scores equal the model-fed root/composition, with separate weights; (2) all five period selections update visible range and preserve Trend toggle, chart point selection/scroll, summary and three non-day subtrends versus Day hiding them; (3) dark max-AX whole-content reachability, status/icon contrast screenshot, 44pt controls, long explanation; (4) conditional calibration and nil readiness only if an existing deterministic fixture supports those branches—otherwise document missing fixture and add the smallest test-only seeded path in a separately justified change. Existing `ActivityExerciseRegressionTests/testTrainingReadinessDetailShowsTrendAndSubscoreSections` remains the baseline route/period/subtrend selector. `testActivityDetailRoutesOpenExpectedScreens` remains route coverage. Do not mirror every `VStack`/padding detail in tests.
- **Verification**: One targeted runner session per changed selector set; reuse same evidence across phases under `.codex/skill-compat.md`. No unrequested full suite.

### Step 4: Actual maps and final proof

- **Files**: A02 actual phone-design-map evidence/index; plan proof ledger.
- **Changes**: Fresh post-change captures for impacted iPhone, iPad, Duo folded and open states, plus normal/dark/max-AX and loading/empty/calibrating states that the fixture can actually produce. Pair each after with source- and state-matched before, or mark pairing unavailable. Verify natural en/ko/ja text and theme ink on the opaque card. If catalog changed, run the required format/check and targeted catalog test; if theme map changed, regenerate/check its map.
- **Verification**: AX/PNG state, device, source, and fixture metadata agree; chart and explanation remain reachable; no false “observed five inputs” or history claim.

## Edge Cases

| Case | Handling |
|---|---|
| `readiness == nil` | Keep existing `Need More Data` empty state; no score hero or invented 0 |
| Loading with no chart | Keep current spinner branch, not empty result |
| Component neutral fallback / no fatigue states | Show model's computed score; never claim that signal was observed |
| `<7` HRV baseline days | Preserve model `isCalibrating` badge and conditional calculation bullet |
| Day with no rolling snapshots | Keep existing plot empty state/summary behavior; no artificial points or non-day subtrends |
| Non-day sparse HRV/RHR/sleep | Preserve 3-source approximation and existing empty/summary behavior; no five-source history label |
| Max AX / Duo folded | Vertical factor evidence, external readable score as needed, no forced truncation |
| iPad top TabBar | Scroll/viewport checks recognize top placement; no bottom-only assumption |

## Testing Strategy

- Existing focused UI selector: `ActivityExerciseRegressionTests/testTrainingReadinessDetailShowsTrendAndSubscoreSections`; relevant route selector: `ActivityExerciseRegressionTests/testActivityDetailRoutesOpenExpectedScreens`.
- Add the 2–3 focused contracts in Step 3. Use UI fixture score readback and model-derived component values, not `79`/`81`/other prototype values. Do not add unit tests for a View-only layout unless a real score or ViewModel behavior changes.
- Post-change actual captures: iPhone, iPad, Duo folded/open; light/dark/max-AX and reachable states. Preserve source/fixture/score metadata for before/after comparison. Watch has no A02 detail consumer.
- If scope expands into ViewModel/calculation, targeted units are `TrainingReadinessDetailViewModelTests`, `ScoreDetailHistoryRegressionTests`, and `CalculateTrainingReadinessUseCaseTests`; this is a new scope decision, not an automatic full run.

## Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| Five computed components mistaken for five observed sensor streams | Medium | High | Score/weight labels and copy avoid availability claims |
| Current score confused with 3-source approximate history | Medium | High | Preserve period-specific semantics; explanatory copy only if precise |
| Opaque-card glyph low contrast, especially desert theme | Medium | Medium | Palette ink for symbol/text; light/dark actual screenshots |
| Five rows clip on Duo/max AX | Medium | Medium | Vertical reflow and whole-content viewport check |
| Chart gestures or summary regress after grouping | Medium | Medium | Preserve bindings/frame; focused period/gesture UI contract |
| Original-source before lacks current state match | Medium | Medium | Hash and capture new before; label old PNG historical only |

## Confidence Assessment

- **Overall**: High for View-only implementation. Actual model, fixture route, status symbols, five weights, and history semantics are explicit in source.
- **Uncertain**: Calibration/nil readiness UI fixtures are not established; do not add a production override or claim those tests passed. Exact baseline score/date may vary with seed/time and must be read from captured app, never hard-coded.
