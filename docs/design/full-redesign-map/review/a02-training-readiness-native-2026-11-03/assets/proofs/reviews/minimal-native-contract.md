# A02 minimum native contract — source-only assessment

## Summary

The existing focused normal and dark MAX selectors already cover the requested route, destination and Back flow; their Back query should recognize the established Duo rail before execution. Four new method executions are planned: Phone normal and MAX, Duo closed normal and Duo open normal, with one owned device at a time. Existing iPad evidence can be reused only after exact source/dependency and test-delta closure; no new iPad execution is assumed necessary. No native/device/test execution or source edits were performed in this assessment.

## Finding: Back query is scoped to the navigation bar

- **File**: `DUNEUITests/Full/TrainingReadinessDetailRedesignTests.swift:50,209`
- **Platform/category**: Duo adaptive navigation / test selector
- **Evidence**: both `testSeededReadinessNormalScreenAndCapture` and `testDarkMaximumAccessibilityKeepsFullContentReachable` select `navigationBars["Training Readiness"].buttons.firstMatch`. The existing H02 test uses `app.buttons["BackButton"]` when present and hittable before falling back to the navigation-bar button. Parent reports actual H02/H03 Duo rail evidence; this source review does not independently reproduce it for A02.
- **Minimal recommended test-only delta** in each method, retaining the normal method's title assertion, existing actual tap and return assertions:

```swift
let railBack = app.buttons["BackButton"].firstMatch
let back = railBack.exists && railBack.isHittable
    ? railBack : app.navigationBars["Training Readiness"].buttons.firstMatch
XCTAssertTrue(back.waitForExistence(timeout: 5) && back.isHittable,
              "Native Back should be usable")
back.auditTap()
```

Keep normal method's Activity return and detail-disappearance assertions and MAX method's Activity return assertion. This chooses an existing native element, does not alter navigation, replace an actual tap, add a second tap, relax a return assertion, or invent 44-point/bar geometry claims absent from the current A02 contract. If neither element is hittable, retain the failure.

## Minimum selected executions and reuse

- Phone: `DUNEUITests/TrainingReadinessDetailRedesignTests/testSeededReadinessNormalScreenAndCapture` and `DUNEUITests/TrainingReadinessDetailRedesignTests/testDarkMaximumAccessibilityKeepsFullContentReachable` (two methods).
- Duo closed and open: the same normal selector once per pose (two methods). Pose proof, checkpoint/AX/PNG provenance and native visual review must correspond to the actual active viewport. Results must prove both the selected test and original return checks; a screenshot alone does not imply a passed method.
- iPad: existing 2379cf08 five-method pass includes normal and functional behavior; 945d1a59 final dark MAX is 1/1 pass. The actual 2379→945d View delta changes chart height at accessibility sizes and factor glyph font/width at accessibility sizes, plus unconditional `.clipped()` on its fixed glyph frame. Normal font and frame remain the same, but source alone cannot rule out a clipping effect; check the existing normal iPad PNG/glyph with final-source equivalence and the application’s dependencies before relying on it. This prior evidence does not become a final-head native run. Record exact source/test hashes and explain test-only Back-query delta before reusing; no separate iPad pass is implied.

## Constraints and limitations

- In the normal selector, composition and rows are queried for existence without scrolling after the top capture. Whether those elements are exposed offscreen on Duo is unknown; preserve the original assertions and observe the actual hierarchy if a run fails. Do not preemptively add broad scrolling or weaken the checks.
- Existing 5/5 iPad functional and 1/1 final MAX receipts remain as recorded; original and failed histories must be preserved. Total historical failed counts remain unknown rather than zero. Existing iPad evidence cannot stand in for Phone or either Duo pose.
- App View and focused tests were confirmed identical to original 945d and frozen validation before any proposed test-only delta; the pending b7d merge and later H03 integration require final source/dependency closure. Prior reviews: parent reports four clear and architecture P3 duplicate mapping deferred. This is a UI contract assessment, not an independent UX or native result.
- iPad uses adaptive navigation and can expose a rail outside a navigation bar; existing iPad passes are bounded to their recorded configuration. No split-view or sheet behavior is changed here. Coverage rating: needs improvement until the selected final-source native cases and provenance are available; no additional hypothetical test suite is proposed.
