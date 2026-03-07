---
topic: fix notification test path regression
date: 2026-03-08
status: implemented
confidence: high
related_solutions:
  - docs/solutions/architecture/2026-03-08-navigationstack-computed-binding-gesture-regression.md
  - docs/solutions/architecture/2026-03-08-tab-scoped-notification-push-preserves-navigation-bar.md
  - docs/solutions/testing/2026-03-07-actions-unit-test-regressions.md
related_brainstorms:
  - docs/brainstorms/2026-03-08-chart-gesture-regression-post-pr354.md
---

# Implementation Plan: Fix Notification Test Path Regression

## Context

GitHub Actions unit-tests job `66156049671` fails during test target compilation because
`DUNETests/NotificationExerciseDataTests.swift` still references
`NotificationPresentationPaths`, a helper removed when `ContentView` switched from
computed `Binding<NavigationPath>` to four independent tab-scoped `@State NavigationPath`
values. The fix must restore test alignment without reintroducing the chart gesture
regression caused by the old computed-binding approach.

## Requirements

### Functional

- Make `DUNETests/NotificationExerciseDataTests.swift` compile against the current
  notification navigation implementation.
- Preserve coverage for tab-scoped notification push path isolation and full-path clear
  semantics.
- Avoid restoring the removed `NotificationPresentationPaths` state ownership pattern in
  `ContentView`.

### Non-functional

- Keep the fix surgical and limited to notification navigation/test support.
- Validate through the repo-approved unit test entrypoint (`scripts/test-unit.sh`).
- Do not weaken the navigation regression protections introduced on 2026-03-08.

## Approach

Extract the path-management contract into a pure helper model that mirrors the current
tab-scoped `NavigationPath` policy, then update `ContentView` helper methods and
`NotificationExerciseDataTests` to target that model. This preserves meaningful coverage
for path clearing/isolation while keeping `NavigationStack(path:)` bound directly to
independent `@State` properties.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| Delete the stale `NotificationPresentationPathsTests` suite | Fastest compile fix | Drops regression coverage for tab-scoped path clearing | Rejected |
| Revert `ContentView` to a single `NotificationPresentationPaths` `@State` | Restores old tests unchanged | Reintroduces computed-binding/chart gesture regression | Rejected |
| Add a pure helper model while keeping four `@State` paths | Restores testability without changing binding ownership | Slightly more code than deleting tests | Accepted |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/App/ContentView.swift` | code | Reintroduce a pure path helper model compatible with current `@State` ownership |
| `DUNETests/NotificationExerciseDataTests.swift` | test | Update tests to match the helper API and current navigation contract |
| `docs/solutions/testing/2026-03-08-notification-path-test-regression.md` | docs | Record the failure mode and prevention guidance |

## Implementation Steps

### Step 1: Restore a testable pure path policy helper

- **Files**: `DUNE/App/ContentView.swift`
- **Changes**: Add an internal helper that stores four `NavigationPath` values and exposes
  `setPath`, `updatePath`, and `clearAll(except:)` behavior without being used as a
  `NavigationStack(path:)` binding source.
- **Verification**: Production code still binds each `NavigationStack` directly to
  `@State` properties.

### Step 2: Align tests with the current helper contract

- **Files**: `DUNETests/NotificationExerciseDataTests.swift`
- **Changes**: Adjust the notification path tests so they compile against the helper and
  assert the same tab isolation / clear-all behavior.
- **Verification**: `NotificationExerciseDataTests.swift` compiles and the focused suite
  passes.

### Step 3: Re-run the CI-equivalent unit lane

- **Files**: none
- **Changes**: Run the approved unit test script in iOS-only mode first, then expand if
  necessary.
- **Verification**: `scripts/test-unit.sh --ios-only` passes or exposes any follow-up
  failures.

## Edge Cases

| Case | Handling |
|------|----------|
| Clearing nav paths when some tabs are already empty | Keep guard logic so empty paths are not reset unnecessarily |
| Push route while current tab already has a different notification path | Clear every other tab path first, then replace the selected tab path |
| Non-push notification routes (`openWorkoutInActivity`, `openNotificationHub`) | Continue clearing all tab paths before switching section/signal |

## Testing Strategy

- Unit tests: run `scripts/test-unit.sh --ios-only --no-stream-log`
- Focused validation: confirm `NotificationExerciseDataTests` no longer reports missing
  `NotificationPresentationPaths`
- Manual verification: none unless unit lane exposes UI-state regressions

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Helper accidentally becomes a new binding source | Low | High | Keep `NavigationStack(path:)` bound directly to the four `@State` vars |
| Extra `NavigationPath()` writes trigger unnecessary SwiftUI updates | Medium | Medium | Preserve guarded clearing semantics in helper and `ContentView` |
| Additional hidden CI failures appear after compile issue is fixed | Medium | Medium | Run the iOS unit script and address any newly surfaced failures before stopping |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: The job log points to a single stale test contract, and the relevant
  production/navigation history already documents the safe architectural boundary.
