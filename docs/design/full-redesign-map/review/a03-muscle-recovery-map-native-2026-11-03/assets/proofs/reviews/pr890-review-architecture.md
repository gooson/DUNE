### [P2] Recovery header can combine counts from different snapshots
- **File**: `DUNE/Presentation/Activity/MuscleMap/MuscleMapDetailView.swift:141`
- **Principle**: State ownership / data consistency
- **Issue**: `observedCount` reads the current `fatigueStates` input, while `recoveredCount` and the `isLoaded` test read ViewModel state populated by a one-shot `.task`. The Activity ViewModel can replace its fatigue states on data reload. If the destination receives that new input while its identity persists, the task does not reload the ViewModel, so the newly added header can show an old numerator over a new denominator (and a previous nonempty dictionary can incorrectly mark the new snapshot loaded).
- **Current**: The header combines a live input count with cached counts from `viewModel.loadData(fatigueStates:)`, which runs only when the view task starts.
- **Suggested**: Keep both counts and readiness tied to one snapshot: either compute both directly from the same `fatigueStates` value for this synchronous summary, or refresh the ViewModel with a content-aware task/change key when the input changes. Preserve existing 2D selection and 3D gate.
- **Rationale**: The visible readiness fraction should describe one set of observations, including after an Activity refresh, rather than mixing old and new state.

Scope: Independent source architecture review of A03 product diff against a363 snapshot and existing ViewModel/AdaptivePane/Activity consumer. This is a source-supported risk; no runtime reproduction, build or device test was performed. Other independent reviews and final UI validation are separate.

## Resolution review

**Resolved in source:** the revised header derives both recovered and observed counts from the same current `fatigueStates` input. Its recovered predicate matches the existing ViewModel's `filter(\.isRecovered)` calculation, and an empty input still shows the training prompt. The prior mixed-snapshot fraction and stale `isLoaded` test are removed. The reviewed delta leaves selection, 3D gate, ViewModel and tests untouched. This closes the cited header-specific P2 at source level; it does not certify unrelated pre-existing ViewModel refresh behavior. No build, test or device run was performed, and historical calf PASS predates the fix and is not evidence for the revised header. New native validation remains pending.

## Final delta re-review

**Header P2 remains resolved; no open P1/P2/P3 found in this reviewed delta.** Header and overview counts use the same current `.noData`-filtered population; the map receives the full original input and only its recovery subtitle receives that filtered population. The optional subtitle input defaults to nil, preserving the Activity root caller's existing behavior. The pre-existing next-recovery value is displayed only if its muscle belongs to the observed population. The original compact 3D gate and selection paths are unchanged. This assessment is source-level and does not certify other pre-existing ViewModel refresh behavior; compilation and revised native validation remain pending.
