---
topic: dashboard-smoke-tab-round-trip-fix
date: 2026-03-08
status: draft
confidence: high
related_solutions:
  - docs/solutions/testing/2026-03-03-ipad-activity-tab-ui-test-navigation-stability.md
  - docs/solutions/testing/2026-03-08-ui-smoke-toolbar-tap-stability.md
  - docs/solutions/testing/2026-03-08-actions-notification-path-and-locale-regressions.md
related_brainstorms:
  - docs/brainstorms/2026-03-08-e2e-ui-test-plan-all-targets.md
---

# Implementation Plan: Dashboard Smoke Tab Round-Trip Fix

## Context

GitHub Actions iOS UI smoke job `66197920907` failed on `DUNEUITests.DashboardSmokeTests/testTabNavigationRoundTrip` after the recent tab-scoped navigation refactor. The failure is not a missing tab; it is a flaky `isSelected == true` expectation on the `Wellness` tab button after tap. Existing per-tab smoke tests already prove that each destination screen loads, so the round-trip test should verify stable navigation behavior without depending on brittle XCUI selection state.

## Requirements

### Functional

- Fix `DashboardSmokeTests.testTabNavigationRoundTrip` so it passes reliably in CI.
- Keep the test locale-independent and compatible with the existing `tab-*` accessibility IDs.
- Preserve smoke-test intent: tab round-trip interaction should remain covered without over-coupling to layout internals.

### Non-functional

- Prefer a test-only fix unless local repro shows a real app regression.
- Reuse existing helpers/patterns from the UI testing infrastructure.
- Keep the verification path fast enough for targeted CI reruns.

## Approach

Replace the brittle `XCUIElement.isSelected` assertion with a deterministic post-tap verification based on stable navigation anchors that already exist for each tab. Use the existing tab navigation helpers and `tab-*` identifiers as the interaction path, then assert a lightweight destination-specific anchor per tab.

Apple's XCTest query guidance favors stable element queries over incidental UI state, and the repo's recent tab-navigation solutions already standardized `tab-*` accessibility IDs for this reason. That makes identifier-driven navigation plus stable screen anchors the lowest-risk fix.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| Keep `isSelected` and only switch to `tab-*` queried elements | Small diff | Still depends on flaky XCUI selected state exposed by `TabView(.sidebarAdaptable)` | Rejected |
| Add app-side accessibility value for selected tab state | Deterministic state contract | Changes production accessibility for a test-only need; broader blast radius | Rejected |
| Replace round-trip assertion with tab navigation helper + destination anchors | Uses existing stable UI contract; localizes fix to tests | Slightly broader than pure selection-state smoke | Chosen |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNEUITests/Smoke/DashboardSmokeTests.swift` | modify | Replace flaky selected-state assertion with stable per-tab verification |
| `DUNEUITests/Helpers/UITestHelpers.swift` | possible modify | Add a small helper only if the test needs shared tab-anchor lookup |
| `docs/solutions/testing/2026-03-08-dashboard-smoke-tab-round-trip-fix.md` | new | Document the CI failure and the stabilized test contract |

## Implementation Steps

### Step 1: Narrow the failing contract

- **Files**: `DUNEUITests/Smoke/DashboardSmokeTests.swift`, `DUNEUITests/Helpers/UITestHelpers.swift`
- **Changes**: Confirm the current round-trip test only needs to prove tab switching, then define the minimum stable assertion per destination.
- **Verification**: Failure signature from Actions log maps to the current `isSelected` wait and no missing-element failures exist for the tapped tabs.

### Step 2: Stabilize the round-trip smoke

- **Files**: `DUNEUITests/Smoke/DashboardSmokeTests.swift`, optionally `DUNEUITests/Helpers/UITestHelpers.swift`
- **Changes**: Tap tabs through the existing navigation path and assert lightweight destination anchors such as each tab's navigation bar title or existing screen-level AXIDs.
- **Verification**: `scripts/test-ui.sh --stream-log --only-testing DUNEUITests/DashboardSmokeTests/testTabNavigationRoundTrip`

### Step 3: Re-run smoke coverage

- **Files**: `DUNEUITests/Smoke/DashboardSmokeTests.swift`
- **Changes**: No code changes; rerun the relevant smoke scope to confirm the fix does not regress other smoke tests.
- **Verification**: `scripts/test-ui.sh --stream-log --smoke --skip-testing DUNEUITests/HealthKitPermissionUITests`

## Edge Cases

| Case | Handling |
|------|----------|
| `TabView(.sidebarAdaptable)` exposes a different accessibility tree on newer simulators | Use shared navigation helpers and identifier-based lookup instead of relying on selected state |
| Locale changes make visible tab labels less stable | Keep interaction on `tab-*` IDs wherever possible |
| Navigation bar titles appear slower on CI than locally | Reuse the existing smoke timeout budget already used by per-tab load tests |

## Testing Strategy

- UI tests: `scripts/test-ui.sh --stream-log --only-testing DUNEUITests/DashboardSmokeTests/testTabNavigationRoundTrip`
- UI smoke suite: `scripts/test-ui.sh --stream-log --smoke --skip-testing DUNEUITests/HealthKitPermissionUITests`
- Manual verification: inspect the failing test's XCUI log if the targeted rerun still fails, then tighten the anchor query instead of widening app changes

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Round-trip test becomes too similar to existing per-tab load tests | Medium | Low | Keep assertions lightweight and focused on immediate destination availability |
| Helper extraction introduces extra churn outside the failing test | Low | Low | Only touch `UITestHelpers` if duplication is necessary |
| Local simulator behavior differs from CI runtime | Medium | Medium | Verify with the same `scripts/test-ui.sh` smoke path and CI-like destination settings |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: The failure is isolated to a known brittle UI-test predicate, existing tab accessibility infrastructure is already in place, and the surrounding smoke tests provide reliable anchors for each destination.
