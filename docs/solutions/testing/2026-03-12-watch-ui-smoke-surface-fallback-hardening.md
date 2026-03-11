---
tags: [watchos, ui-test, smoke-test, accessibility, xcresult, selector-fallback]
category: testing
date: 2026-03-12
severity: important
related_files:
  - DUNEWatchUITests/Helpers/WatchUITestBaseCase.swift
  - DUNEWatchUITests/Smoke/WatchHomeSmokeTests.swift
  - docs/plans/2026-03-12-ui-test-failure-fixes.md
related_solutions:
  - docs/solutions/testing/2026-03-03-watch-workout-start-axid-selector-hardening.md
  - docs/solutions/testing/2026-03-09-ui-test-aut-launch-lifecycle-hardening.md
---

# Solution: Watch UI smoke surface fallback hardening

## Problem

Recent GitHub watch UI smoke failures were not caused by product behavior changes alone.
The shared watch UI test helper assumed a narrower accessibility surface than the runtime tree actually exposed, so the same seeded watch flow failed at home readiness, All Exercises entry, and workout start.

### Symptoms

- `WatchHomeSmokeTests` failed even though the seeded home screen visibly rendered the All Exercises card.
- `WatchWorkoutStartSmokeTests` failed after opening the workout preview even though the green Start button was visible in the failure screenshot.
- Swipe-heavy fallback logic occasionally drifted into unrelated system surfaces such as Now Playing instead of staying on the app path.

### Root Cause

Two mismatches stacked together:

1. The helper treated only `watch-home-carousel` or `watch-home-empty-state` as valid home readiness, while the current seeded home also exposed a visible `watch-home-card-all-exercises` surface.
2. On the watch workout preview and session metrics screens, the tappable buttons could appear in the accessibility hierarchy with the surrounding screen identifier rather than the expected leaf AXID, so AXID-only lookup was too strict.

## Solution

Harden the shared watch UI test helper around the observed runtime surface instead of broadening product code.
The helper now accepts visible home and quick-start variants as valid readiness, uses guarded AUT termination, removes swipe-based All Exercises discovery, and falls back to exact localized button labels only for the specific Start / Complete Set actions when AXID lookup is not exposed on the tappable leaf.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNEWatchUITests/Helpers/WatchUITestBaseCase.swift` | Added guarded `terminateIfRunning` lifecycle helper | Prevent non-running AUT terminate noise from contaminating watch smoke runs |
| `DUNEWatchUITests/Helpers/WatchUITestBaseCase.swift` | Broadened `ensureHomeVisible()` and `ensureQuickStartVisible()` accepted surfaces | Match the actual seeded watch accessibility tree instead of only exact list/container IDs |
| `DUNEWatchUITests/Helpers/WatchUITestBaseCase.swift` | Replaced swipe-heavy All Exercises discovery with direct tap helpers | Keep the test inside app-owned surfaces and avoid system-page drift |
| `DUNEWatchUITests/Helpers/WatchUITestBaseCase.swift` | Added exact localized fallback lookup for Start / Complete Set buttons | Handle watchOS trees that surface the visible button under the screen identifier |
| `DUNEWatchUITests/Smoke/WatchHomeSmokeTests.swift` | Asserted the fixture squat row instead of the exact quick-start list container | Keep the smoke assertion aligned with the user-visible success condition |

### Key Code

```swift
private func waitForButton(
    identifier: String,
    exactLabels: [String] = [],
    labelContains: [String] = [],
    timeout: TimeInterval = 5
) -> XCUIElement? {
    let deadline = Date().addingTimeInterval(timeout)

    while Date() < deadline {
        let identifiedButton = app.buttons[identifier].firstMatch
        if identifiedButton.exists {
            return identifiedButton
        }

        if !exactLabels.isEmpty {
            let labeledButton = app.buttons.matching(
                NSPredicate(format: "label IN %@", exactLabels)
            ).firstMatch
            if labeledButton.exists {
                return labeledButton
            }
        }

        for fragment in labelContains {
            let labeledButton = app.buttons.matching(
                NSPredicate(format: "label CONTAINS[c] %@", fragment)
            ).firstMatch
            if labeledButton.exists {
                return labeledButton
            }
        }

        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    }

    return nil
}
```

## Prevention

### Checklist Addition

- [ ] Watch smoke helpers should validate user-visible surfaces, not only a single container AXID.
- [ ] When a selector mismatch persists, export the latest `xcresult` hierarchy before changing app code.
- [ ] Swipe fallback should be a last resort on watch UI tests because it can leave the intended app surface.
- [ ] AXID remains the first choice, but exact localized fallback is acceptable for known watchOS leaf-button exposure anomalies.

### Rule Addition (if applicable)

No new `.claude/rules/` file was needed.
This pattern fits existing UI test hardening guidance and is specific enough to document as a reusable solution instead.

## Lessons Learned

- Watch UI flakiness often comes from helper assumptions about the accessibility tree, not only from product regressions.
- Failure screenshots and exported hierarchy text are much more reliable than retry count tweaks when the visible button exists but the AX query misses it.
- For watch smoke tests, surface-based assertions are usually more stable than exact container assertions.
