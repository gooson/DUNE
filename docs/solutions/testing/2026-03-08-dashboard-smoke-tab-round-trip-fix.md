---
tags: [ui-test, smoke-test, dashboard, tab-navigation, xctest, flake, navigation-bar]
category: testing
date: 2026-03-08
severity: important
related_files:
  - DUNEUITests/Smoke/DashboardSmokeTests.swift
  - docs/plans/2026-03-08-dashboard-smoke-tab-round-trip-fix.md
related_solutions:
  - docs/solutions/testing/2026-03-03-ipad-activity-tab-ui-test-navigation-stability.md
  - docs/solutions/testing/2026-03-08-ui-smoke-toolbar-tap-stability.md
  - docs/solutions/testing/2026-03-08-actions-notification-path-and-locale-regressions.md
---

# Solution: Dashboard Smoke Tab Round-Trip Fix

## Problem

GitHub Actions iOS UI smoke job `66197920907` failed on `DUNEUITests.DashboardSmokeTests.testTabNavigationRoundTrip`.

### Symptoms

- CI failed with `Asynchronous wait failed` while waiting for `isSelected == true` on the `Wellness` tab button.
- The rest of the smoke suite still showed that Activity, Wellness, and Life screens could load normally.
- Local reruns passed intermittently, which pointed to a flaky assertion rather than a deterministic app bug.

### Root Cause

The smoke test depended on `XCUIElement.isSelected` for `TabView(.sidebarAdaptable)` tab buttons. That selected-state exposure was brittle across simulator/runtime timing, especially after the recent tab-scoped navigation changes. The real navigation contract was already more stable: the app had fixed English tab titles plus existing destination navigation bars for each tab.

## Solution

Keep the fix in UI tests and replace the brittle selected-state assertion with a stable destination-anchor assertion after each tab switch.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNEUITests/Smoke/DashboardSmokeTests.swift` | Replaced `isSelected` expectation with `navigateToTab` + destination navigation bar check | Remove flaky state-based assertion and verify the actual screen transition contract |
| `docs/plans/2026-03-08-dashboard-smoke-tab-round-trip-fix.md` | Added implementation plan | Preserve reproduction context and verification path |

### Key Code

```swift
for tab in ["Activity", "Wellness", "Life", "Today"] {
    app.navigateToTab(tab)
    XCTAssertTrue(
        app.navigationBars[tab].waitForExistence(timeout: 5),
        "\(tab) root navigation bar should appear after tab switch"
    )
}
```

## Prevention

Use stable UI anchors for smoke tests instead of incidental widget state whenever the runtime contract already exposes a better assertion target.

### Checklist Addition

- [ ] Tab smoke tests should prefer stable destination anchors over `isSelected` when `TabView` selection state is known to be timing-sensitive.
- [ ] If a CI failure is intermittent and the destination still loads, inspect whether the test is asserting framework-exposed state instead of user-visible navigation outcomes.
- [ ] Keep tab switching on shared helper paths such as `navigateToTab(_:)` so locale and accessibility-ID fallbacks stay centralized.

### Rule Addition (if applicable)

No new global rule was added. Existing UI testing patterns and recent tab-navigation solution docs already cover identifier-first navigation and smoke-scope discipline.

## Lessons Learned

For smoke coverage, the most reliable assertion is often the first stable destination anchor, not the control's internal selected state. A test can still prove tab round-trip behavior without coupling itself to how XCTest surfaces `TabView` selection on a given simulator/runtime combination.
