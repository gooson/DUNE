---
topic: A04 3D muscle map entry disable
date: 2026-10-31
status: approved
confidence: high
related_solutions: [docs/solutions/architecture/2026-02-27-muscle-map-detail-view-integration.md]
related_brainstorms: []
---

# Implementation Plan: A04 3D muscle map entry disable

## Context

The Activity root already removed its 3D shortcut, but `MuscleMapDetailView` still exposes a 3D button and opens 3D automatically after a muscle tap on compact width. The requested A04 state keeps the complete 3D implementation in source while withholding both user entries.

## Requirements

### Functional

- Keep the detail screen's original 3D cube button visible but disabled on all widths.
- On compact width, tapping a muscle continues to toggle the 2D selected muscle and inline detail without navigating to 3D.
- Preserve the existing 3D view, state, assets, internal destination, navigation destination and original button label/icon in source for reactivation.

### Non-functional

- Use one clearly named temporary availability constant, local to the detail view.
- No new user copy, global setting, theme change or 3D engine change.
- Actual screen A03 requires fresh captures after app validation on affected iPhone, iPad and Duo states. Old PNGs do not prove A04.

## Approach

Disable the original `MuscleMapDetailView` 3D button and gate compact automatic navigation with the same false availability constant. Keep 2D selection outside the gate. Preserve destination plumbing and 3D implementation.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|---|---|---|---|
| Remove 3D code | Small visible surface | Violates source retention | Reject |
| App-wide feature setting | Can toggle remotely | Unneeded state and broader scope | Reject |
| Local availability gate | Reversible, narrow; button remains visible | Dormant branch remains | Choose |

## Affected Files

| File | Change Type | Description |
|---|---|---|
| `docs/design/layout-map/activity-muscle-map-detail-a04.md` | Add | A03/A04 layout and theme contract |
| `docs/design/layout-map/README.md`, `index.html` | Edit | Link detail map |
| `DUNE/Presentation/Activity/MuscleMap/MuscleMapDetailView.swift` | Edit | Disable button and gate automatic entry |
| `DUNEUITests/Full/ActivityMuscleMapRegressionTests.swift` | Edit | Focused disabled entry and 2D selection coverage; preserve 3D test code |

## Implementation Steps

### Step 1: Record contract

- **Files**: plan and layout map files.
- **Changes**: Define user behavior, width/state effects, and unchanged theme.
- **Verification**: Links, IDs and source behavior agree.

### Step 2: Gate entries

- **Files**: `MuscleMapDetailView.swift`.
- **Changes**: Keep the original button visible with `.disabled(!is3DMuscleMapEntryAvailable)` and gate compact automatic navigation under the same local false constant.
- **Verification**: Diff shows selected 2D muscle update unchanged; 3D implementation files unchanged.

### Step 3: Focused UI regression

- **Files**: `ActivityMuscleMapRegressionTests.swift`.
- **Changes**: Add one test that the button is visible but disabled, compact tap remains on detail, and inline detail appears. Existing 3D test assertions remain in source, skipped only while the entry is disabled.
- **Verification**: Parent rollout runs exact `ActivityMuscleMapRegressionTests/testMuscleMapDetailKeeps2DSelectionWith3DEntryDisabled` selector on owned phone; A03 captures refreshed separately.

## Edge Cases

| Case | Handling |
|---|---|
| Compact muscle selection | Still toggles 2D inline detail |
| Regular width | Visible disabled button; adjacent detail remains |
| Re-enable later | Flip one local constant after restoring entry policy and tests |
| Existing internal 3D destination | Retained without user entry from A03 |

## Testing Strategy

- Source: `git diff --check`, targeted grep and unchanged 3D file diff.
- UI: one focused selector on owned phone, run by rollout parent.
- Actual captures: A03 on affected tiers, run by rollout parent.
- Full suite: outside this scoped change.

## Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| Compact gesture path | Medium | Medium | Gate automatic navigation and assert staying on detail |
| Existing 3D route tests require an availability guard | Certain | Low | Keep assertions; skip only while the entry is disabled |
| Stale A03 captures | High until runtime capture | Medium | Mark as pending; parent refreshes four tiers |

## Confidence Assessment

- **Overall**: High for source scope; runtime pending parent validation.
- **Reasoning**: Both known user paths are in one view; unchanged 3D implementation remains available in source.
