---
topic: Fix inactive form coaching
date: 2026-03-22
status: draft
confidence: high
related_solutions:
  - docs/solutions/architecture/2026-03-22-voice-coaching-pipeline.md
  - docs/solutions/architecture/2026-03-22-exercise-form-check-pipeline.md
related_brainstorms:
  - docs/brainstorms/2026-03-16-realtime-video-posture-analysis.md
---

# Implementation Plan: Fix Inactive Form Coaching

## Context

`ExerciseFormAnalyzer` currently emits `.normal` for checkpoints that are outside the current phase. `FormVoiceCoach` interprets every `.normal` checkpoint as a positive coaching candidate, so setup or lockout frames can speak praise for checkpoints that were not actually evaluated. The current unit test target is also red because `FormVoiceCoachTests` is missing `Foundation`, which blocks the build/test gate for this fix.

## Requirements

### Functional

- Inactive checkpoints must not be eligible for positive or corrective voice coaching.
- The realtime form overlay must distinguish evaluated checkpoints from phase-inactive checkpoints without losing angle visibility.
- Unit tests must cover the inactive-checkpoint behavior.
- The unit test target must compile again.

### Non-functional

- Preserve the existing form-check scoring logic for active checkpoints only.
- Keep the hot path lightweight for realtime analysis.
- Avoid introducing localization leaks in any user-facing presentation changes.

## Approach

Add an explicit per-checkpoint activity flag to `CheckpointResult` so the analyzer can preserve measured angles while marking phase-inactive checkpoints as not evaluated. Update `FormVoiceCoach` to ignore inactive checkpoints completely, and adjust the overlay to render inactive rows with neutral styling instead of a green "good" state. Fix the existing test compile failure in `FormVoiceCoachTests` and extend tests to cover the new inactive behavior.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| Filter inactive checkpoints only inside `FormVoiceCoach` | Smallest diff | Leaves ambiguous `.normal` semantics in shared state and misleading overlay visuals | Rejected |
| Emit `.unmeasurable` for inactive checkpoints | Reuses existing status enum | Loses distinction between "missing joints" and "not evaluated this phase" | Rejected |
| Add explicit `isActive` / `isEvaluated` flag on `CheckpointResult` | Preserves semantics across consumers and keeps overlay honest | Requires touching model, analyzer, UI, and tests | Selected |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Domain/Models/ExerciseFormState.swift` | Modify | Add explicit evaluated/activity metadata to checkpoint results |
| `DUNE/Domain/Services/ExerciseFormAnalyzer.swift` | Modify | Mark checkpoints as phase-active vs inactive when building results |
| `DUNE/Data/Services/FormVoiceCoach.swift` | Modify | Ignore inactive checkpoints during cue selection |
| `DUNE/Presentation/Posture/Components/FormCheckOverlay.swift` | Modify | Render inactive checkpoints with neutral treatment |
| `DUNETests/ExerciseFormAnalyzerTests.swift` | Modify | Assert inactive checkpoints are flagged correctly |
| `DUNETests/FormVoiceCoachTests.swift` | Modify | Restore compilation and add inactive-checkpoint coverage |

## Implementation Steps

### Step 1: Make checkpoint evaluation state explicit

- **Files**: `DUNE/Domain/Models/ExerciseFormState.swift`, `DUNE/Domain/Services/ExerciseFormAnalyzer.swift`
- **Changes**:
  - Add an explicit `isActivePhase` flag to `CheckpointResult`.
  - Set the flag in the analyzer without disturbing the current scoring path.
  - Preserve status values for active checkpoints and keep inactive checkpoints identifiable to downstream consumers.
- **Verification**:
  - `rg -n "isActivePhase" DUNE/Domain/Models/ExerciseFormState.swift DUNE/Domain/Services/ExerciseFormAnalyzer.swift`

### Step 2: Prevent inactive coaching and misleading overlay state

- **Files**: `DUNE/Data/Services/FormVoiceCoach.swift`, `DUNE/Presentation/Posture/Components/FormCheckOverlay.swift`
- **Changes**:
  - Skip inactive checkpoints in voice cue selection.
  - Render inactive checkpoints with neutral visuals so the UI no longer implies "good form" for unevaluated phases.
- **Verification**:
  - `git diff -- DUNE/Data/Services/FormVoiceCoach.swift DUNE/Presentation/Posture/Components/FormCheckOverlay.swift`

### Step 3: Repair and extend tests

- **Files**: `DUNETests/FormVoiceCoachTests.swift`, `DUNETests/ExerciseFormAnalyzerTests.swift`
- **Changes**:
  - Add `Foundation` import so the unit target compiles again.
  - Add focused assertions that inactive checkpoints are flagged and ignored by the voice coach.
- **Verification**:
  - `scripts/test-unit.sh`

## Edge Cases

| Case | Handling |
|------|----------|
| Checkpoint has measurable joints but is outside the current phase | Keep angle display but mark it inactive so coaching ignores it |
| Checkpoint is missing joints entirely | Continue using `.unmeasurable` and show placeholder UI |
| Positive cues for active checkpoints | Keep current behavior unchanged |
| Mixed active/inactive checkpoint list in one frame | Only active checkpoints participate in coaching and scoring |

## Testing Strategy

- Unit tests: extend analyzer tests for inactive-phase tagging and voice-coach tests for inactive checkpoint suppression.
- Integration tests: run `scripts/test-unit.sh` to catch compile/build regressions in the iOS unit target.
- Manual verification: inspect the form overlay diff to confirm inactive checkpoints render neutrally, not as green successes.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| New checkpoint flag breaks existing test helpers | Medium | Medium | Update all `CheckpointResult` call sites in tests in one pass |
| Overlay styling change unintentionally hides useful angles | Low | Medium | Keep angle text visible while only neutralizing status color/opacity |
| Future consumers ignore the new flag | Medium | Low | Centralize the first use in `FormVoiceCoach` and cover behavior with tests |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: The bug is localized to the shared checkpoint result model and its two consumers. The affected surface is narrow, and the failing unit test target already provides a concrete verification gate.
