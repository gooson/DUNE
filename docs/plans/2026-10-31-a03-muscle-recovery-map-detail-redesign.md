---
topic: a03-muscle-recovery-map-detail-2d-redesign
date: 2026-10-31
status: planned
confidence: medium
related_solutions:
  - docs/solutions/architecture/2026-02-27-muscle-map-detail-view-integration.md
  - docs/solutions/performance/2026-02-19-swiftui-color-static-caching.md
related_brainstorms:
  - docs/brainstorms/2026-02-19-muscle-fatigue-10-levels.md
---

# Implementation Plan: A03 Muscle Recovery Map detail, 2D presentation

## Context

The current A03 detail already combines a tappable front/back 2D anatomy map, a selected-muscle panel, volume analysis and recovery status. Its A04 revision `1f7f9900` intentionally leaves the visible `3D Muscle Map` cube entry disabled and prevents compact selection from opening 3D. A03 should give the real 2D map and its explanations a clearer native hierarchy while preserving this availability decision and every existing data source and interaction.

The source baseline is **A04 revision `1f7f9900`**, not an older main: `MuscleMapDetailView.swift` SHA-256 `2caa64758a280ed66d280b1ca3d38c16e3b67439baff2927ce2437dd1134925a`. This A03 branch was created directly from that revision; freeze it before app changes. Existing A04 worktree phone before evidence: default `F625DA35-1F7D-4964-8291-8815F452B068.png`, selected chest `23856FB9-A77E-49EF-BAD8-F3C23076DF75.png`, under its `.codex-checks/a04/evidence/ui-phone-default-map-current/`. These are one passing A04 selector's current-source before states, not A03 after images. Source-matched iPad and both Duo postures must be verified separately before being paired. Historical `actual/.../A03.png` files cannot be relabeled as A04 source-matched before captures.

## Requirements

### Functional

- Preserve Activity's `activity-musclemap-detail-link` push to `activity-musclemap-detail-screen`, the existing native Back route, and `AdaptivePaneView`: compact has a single reachable map/secondary scroll flow; regular keeps primary map beside secondary selected-muscle/analysis content.
- Keep `is3DMuscleMapEntryAvailable = false`, `3D Muscle Map` + `cube` visible/disabled, compact auto-push guard, `selected3DMuscle` and `.navigationDestination`; do not remove or restyle the 3D viewer as a fake 2D substitute. Protect `MuscleMap3DView.swift` SHA `a399d7d9ede76eca52f1f731e0b296b271186961bb519d1b2d9a26d7a751fe6e`, `MuscleMap3DScene.swift` SHA `94486b5a25ff2abc1dcb4ca9cb256609b8586511f05cd4bf0a05621d47149a02`, and `muscle_body.usdz` SHA `a64b5799ee4c0d815809cb6fc07b915dabe807d2946f16e39a95e481b9add722`.
- Preserve the real `MuscleMapData` front/back SVG parts and outlines, 200:400 geometry, per-part hit targets, Recovery/Sets picker, information sheets, fatigue and volume legends, and current `FatigueLevel`/`VolumeIntensity` scales. No uniform gold repaint or invented map, counts, history, set values, or 3D visualization.
- Preserve selection toggle and inline `MuscleDetailPopover`: state-backed recovery badge/statistics, explicit missing-state copy, conditional compound-score calculation sheet, and up to three real strength/bodyweight `ExerciseLibraryQuerying` rows. These rows are currently display rows, not navigation links; do not invent a route.
- Preserve 13-group volume list including zero-volume groups when some volume exists, total sets, `trainedCount/13`, per-group progress, goal Stepper and UserDefaults default 15/clamp 5–30/step 5, existing balance calculation, and `No Volume Data` branch.
- Preserve recovery ring and text with `recoveredCount/fatigueStates.count` (observed states only), overworked warning, next-ready date/time, and empty-state wording. Do not equate that denominator with all 13 groups or call zero/missing groups trained.

### Non-functional

- Use existing DUNE Activity type, spacing, opaque surfaces and semantic colors. The 2D diagram and its calibrated legend remain the focal surface; the header/summary and lower cards become easier to scan without flattening heat colors.
- Preserve Dynamic Type, Reduce Motion, VoiceOver labels, 44pt map/info targets where already provided, iPhone/iPad/Duo compact/regular panes, and existing localization keys where possible. If copy changes, follow `copy-voice`, `.codex/ux-writing.md`, and catalog format/check rules.
- Scope to iOS/iPadOS A03. No Watch or global chart/model work.

## Approach

Use a local A03 presentation pass: an opaque, concise `Muscle Map` title context; group the existing map subtitle, Recovery/Sets selector, front/back bodies and matching legend into one readable map module; give selected detail a clear conditional boundary; then retain volume and recovery sections with consistent spacing and readable summaries. Keep `AdaptivePaneView` and the existing child views/data transformations. A small, screen-local wrapper or private header is preferable to changing global cards or rebuilding SVG geometry. For the map subtitle, use the existing mode-specific source text: `recoveredCount/fatigueStates.count` for observed recovery or `trainedCount` for weekly sets, and existing empty prompts. Do not create a second unverified statistic.

### Alternative Approaches Considered

| Approach | Benefit | Cost | Decision |
|---|---|---|---|
| Replace map with new vector/3D art | Dramatic visual change | Loses current geometry, hit targets, status truth, A04 gate | Reject |
| Recompute counts in View | New summary control | Duplicates model logic and risks 13-vs-observed denominator error | Reject |
| Local 2D composition and spacing | Preserves tested data/navigation with focused visual gain | Requires careful compact/regular and AX capture | Choose |

## Affected Files

| File | Change type | Boundary |
|---|---|---|
| `docs/plans/2026-10-31-a03-muscle-recovery-map-detail-redesign.md` | Add | Formalize this reviewed contract after source-matched before evidence |
| `docs/design/layout-map/activity-muscle-map-detail-a03.html` and index/README | Add/update | Proposal layout and state map before View editing; keep A04 availability contract linked |
| `docs/design/theme-map/themes/dune-muscle-map-detail-a03.html`, manifest/README/generated index | Add/update | Preserve the A03 opaque-header and semantic heat-color direction; label browser diagrams as illustrative, not actual health data or captures |
| `DUNE/Presentation/Activity/MuscleMap/MuscleMapDetailView.swift` | Modify | Local opaque header/map/section composition; preserve A04 guard and 3D destination |
| `DUNE/Presentation/Activity/Components/MuscleRecoveryMapView.swift` | Optional narrow modify | Only if needed to expose/rearrange existing subtitle/picker/map/legend within the A03 visual grouping; preserve geometry/mode/colors/IDs |
| `DUNE/Presentation/Activity/MuscleMap/Components/VolumeBreakdownSection.swift`, `RecoveryOverviewSection.swift`, `DUNE/Presentation/Activity/Components/MuscleDetailPopover.swift` | Optional narrow presentation-only modify | Readability/AX spacing; no algorithm, state, query, conditional branch, goal semantics change |
| `DUNEUITests/Full/ActivityMuscleMapRegressionTests.swift` | Modify | Focused contract selectors and after-state captures, using seeded real 2D data |
| `docs/design/phone-design-map/actual/...` | Update after runtime | Fresh A03 actual images/metadata for affected phone, iPad, Duo folded/unfolded states |

Protected/non-target files: `MuscleMapDetailViewModel.swift` (SHA `761c8f13add5a8b32d2c9e0a8e9489daa3e5053a38e7268c16c19533efdf1964`), `MuscleMapData.swift` (SHA `5a5a4a5e8b4e83afa64920e856c50ca4b6e9c8381e76e4e65ab5f66a97b2deb6`), all 3D source/assets, fatigue/volume algorithms, shared pane/navigation routing. Track their hashes through the phase.

## Implementation Steps

### Step 1: Freeze A04 truth and map the A03 states

- **Files**: A04 source/evidence; new plan/layout/theme docs.
- **Changes**: Confirm `1f7f9900` ancestry and the A04 guard/disabled cube/selected-muscle ID. Archive source-matched default and selected phone before evidence; collect iPad/Duo source-matched before only when their current runs complete. Draw compact/regular, Recovery/Sets, no selection/selected, zero-volume, observed/missing-state, max-AX states. Distinguish browser proposals from native captures.
- **Verification**: Source SHA/branch check, map links/checks; no claim of device evidence before actual selector/source metadata.

### Step 2: Compose the native 2D screen

- **Files**: `MuscleMapDetailView.swift`; optional narrow `MuscleRecoveryMapView.swift`/three existing section views.
- **Changes**: Apply the local opaque header and clearer grouping around the existing map, selected pane, volume and recovery; retain source order and access to every value/row. Keep front/back geometry, mode and legends, conditional calculation/library rows, goal Stepper, empty/zero states and the A04 3D gate exactly. Keep map/status colors from existing scales. Use semantic existing labels and responsive stacked layout at accessibility sizes.
- **Verification**: Swift parse/build on A03 worktree; diff inspection and protected SHA checks; no VM/retrieval/use-case changes.

### Step 3: Focused interaction and actual-state verification

- **Files**: `ActivityMuscleMapRegressionTests.swift`; actual design map.
- **Changes**: Reuse `testMuscleMapDetailKeeps2DSelectionWith3DEntryDisabled` for default/selected 2D + disabled cube and the existing load/volume/recovery selectors where behavior is affected. Add only missing meaningful contracts: Recovery↔Sets changes the real legend and keeps front/back target; select/deselect stays on A03; goal Stepper changes 5-set increments and retained state; selected seeded chest exposes conditional calculation and existing exercise-library rows when supplied; no-volume/missing-state only with an existing deterministic fixture or source-level branch check. Capture selected panel and lower volume/recovery sections as separate actual states. Do not run legacy `testMuscleMapDetailViewNavigatesTo3D` as an A03 expected pass while A04 intentionally disables entry.
- **Verification**: Exact selectors on worktree-owned iPhone/iPad/Duo folded/unfolded only as affected; bounded viewport for iPad top tab bar, max AX and Reduce Motion as indicated by changed layout. Pair before/after by screen, source revision, device, theme, content size, mode and selection; generate actual-map entries from fresh after PNGs. Do not extrapolate an old phone capture to iPad/Duo.

## Edge Cases

| Case | Handling |
|---|---|
| No supplied fatigue states | Existing recovery empty prompt; no `0/13 ready` claim |
| Some groups missing/zero weekly sets | `.noData` map color or `0/goal` volume row; no trained claim |
| All volume zero | Existing `No Volume Data`; recovery still independent |
| Selected muscle has no state | Existing explicit no-recent-activity panel and no calculation unless compound score exists |
| All observed states recovered | Existing observed-count completion message; no extrapolation to all 13 groups |
| Overworked/next-ready absent | Keep existing conditional sections absent |
| Goal at 5 or 30 | Existing Stepper bounds and persistence; do not recompute goal in View |
| Compact selection | Inline A03 detail only; A04 3D auto-push remains gated |

## Testing Strategy

- **Unit**: No new mirror tests for unchanged ViewModel/math. Reuse existing calculation coverage only if a proposed code edit crosses that boundary (plan expects none).
- **UI**: Exact A04 selector plus only the focused mode/goal/selected-detail contracts above; existing load/volume/recovery tests as relevant. Existing 3D navigation selectors are incompatible with intentional availability false.
- **Actual visuals**: Fresh default Recovery, Sets legend, selected chest, lower volume/recovery, and selected calculation sheet on affected device states. Theme/light/dark and AX states need separate source-matched pairing; initial phone default/selected A04 references alone prove only those two before states.

## Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| Implementing on older main omits A04 guard | Medium | High | Require `1f7f9900` ancestry and baseline hash before source edit |
| Visual summary implies missing states are recovered/trained | Medium | High | Use existing observed denominator and trained-volume count; no new aggregate |
| New container obscures map buttons or scroll on iPad/Duo | Medium | High | Keep original SVG/AX targets; focused reachability/selection and actual captures |
| Moving sections loses zero-volume rows, goal, explanation or library results | Medium | Medium | Source diff plus focused selected/goal/empty contracts |
| Historic images mislabeled as current before/after | Medium | High | Pair by source/device/state metadata; refresh after images separately |

## Confidence Assessment

- **Overall**: Medium. A04 source behavior, identities and phone default/selected states are verified. iPad/Duo source-matched baselines, native A03 layout and final focused tests remain future work.
