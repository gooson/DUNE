---
tags: [swiftui, xctest, ipad, numeric-keyboard, accessibility, dynamic-type]
category: testing
date: 2026-11-14
severity: important
related_files:
  - DUNE/Presentation/Settings/Components/ExerciseDefaultEditView.swift
  - DUNEUITests/Full/TodaySettingsRegressionTests.swift
related_solutions:
  - docs/solutions/general/2026-11-07-exercise-default-edit-s03-held.md
---

# Solution: Verify exercise defaults through native iPad numeric popups

## Problem

### Symptoms

- At maximum accessibility size, the default weight and reps controls needed stacked labels and complete fields.
- On iPad, the app's Done button was fully drawn while a native numeric popup covered its hit target. The first targeted tests failed on `Done.isHittable` after entering 72.5.
- The popup and `PopoverDismissRegion` appeared in the full application accessibility snapshot, while two `XCUIElementQuery` selectors for those elements returned no match. Both query-based test revisions failed before their dismissal branch.

### Root Cause

The app's numeric editor can coexist with a native iPad numeric popup and docked keyboard. A full visible Done frame alone does not prove that the button receives taps while the popup's dismissal layer is in front. In these runs, XCTest's popup element queries did not resolve the elements shown in its full accessibility snapshot. The reason for that query mismatch is unconfirmed; the fix does not assume a cache or timing cause.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `ExerciseDefaultEditView.swift` | Stack numeric labels above fields at accessibility sizes and provide a focus-aware Done action. | Keep weight and reps readable and dismissible without changing bindings or Save. |
| `TodaySettingsRegressionTests.swift` | Enter 72.5 and 8, verify focus and full field frames, distinguish popup and direct Done variants from a fresh application snapshot, dismiss a present popup by tapping an inert visible label to its left, then require popup disappearance and keyboard/focus completion before Save/reopen. | Test the actual iPad interaction without treating an OS keyboard variant as a required product state. |

### Key Code

```swift
let popupMarker = "PopoverDismissRegion"
// A bounded readiness check accepts either the observed popup or a hittable Done.
let hasIPadPopup = XCUIApplication().debugDescription.contains(popupMarker)
if hasIPadPopup {
    outsideLabel.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5)).auditTap()
    // A bounded check requires the popup marker to disappear before continuing.
}
// If no popup is present, require the original full, hittable Done and tap it.
```

The final targeted iPad selectors passed 2/2 at source `334150759` (MAX 109.867 s; normal 99.478 s). Phone normal and corrected MAX targeted selectors also passed on app owner bytes identical to that source. The Nov 7 HELD review, initial Phone MAX failure, and two earlier iPad failure batches remain in the evidence history.

## Prevention

### Checklist Addition

- [ ] When an iPad numeric control is focused, inspect both the rendered frame and the full accessibility snapshot before assuming a visible app toolbar action is hittable.
- [ ] Preserve the original numeric value, focus, dismissal, Save and reopen assertions when adapting to an OS keyboard variant.
- [ ] Pair every published native screenshot with its accessibility tree, source revision, capture UUID and checksum; retain failed attempts as diagnostics.

### Rule Addition (if applicable)

No new project rule is proposed. This screen-specific test contract belongs with its UI test and captured evidence.

## Lessons Learned

Full accessibility snapshots and XCTest element queries can disagree for a native popup. A test should verify the resulting interaction state and preserve data assertions rather than infer that a query miss means the popup is absent.
