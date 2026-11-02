### [P3] Readiness factor presentation is maintained in two separate lists
- **File**: `DUNE/Presentation/Activity/TrainingReadiness/TrainingReadinessDetailView.swift:322`
- **Principle**: Single source of truth / cohesion
- **Issue**: The new hero independently defines the same five component-to-score and weight mappings already defined for `ScoreCompositionCard` in this view (lines 75–84). A future update to one list can leave the two visible explanations inconsistent, even if the computation remains correct. Current values and mappings match the use case; this is a maintainability risk, not a present scoring error.
- **Current**: The hero's private `Factor` array and the original composition card repeat labels, scores, colors and literal weights.
- **Suggested**: Consider deriving both presentations from one A02-local factor definition while retaining the existing localized labels, accessibility IDs, and distinct view layouts. This does not require changing the calculation or shared components.
- **Rationale**: Keeping one local mapping makes the two representations change together and avoids introducing a shared cross-feature dependency.

Scope: Independent source architecture review of A02 View and focused test diff against b7d pending merge, with existing model, use case, ViewModel, Activity consumer and navigation/layer rules checked. No native behavior, tests, other reviews, or final future-main integration is certified. No source edits, build, tests, or device execution.
