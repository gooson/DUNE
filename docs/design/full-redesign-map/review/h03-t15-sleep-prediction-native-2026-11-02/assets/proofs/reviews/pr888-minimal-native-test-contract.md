## Summary

Strengthen the existing default T15 selector in place. Keep exactly two selectors per Duo pose: `DesignMapAdditionalRoutesTests/testSleepPredictionOpensFromWellness` and `NotificationRoutingRegressionTests/testBedtimeReminderPushesFromNotificationHub`. No additional strict-fixture selector or matrix is necessary. This is a read-only design recommendation, not executed validation.

## Findings

### [P2] Default T15 currently passes before the prediction loads
- File: DUNEUITests/Full/NotificationRoutingRegressionTests.swift:11
- Platform: common
- Category: form-state
- Issue: `notification-sleep-detail-screen` identifies a Group containing prediction, ProgressView, or empty state. Its existence plus Today selection cannot distinguish loaded detail from loading/empty. The existing method also never exercises native Back.
- Evidence: NotificationSleepDetailPushView in DUNE/App/ContentView.swift:671–697 retains that wrapper across all three branches. Current default method ends after Today.isSelected. Strict DesignMapNotificationDetailTests/testNotificationSleepDetailLoadsSharedPrediction uses the separate design-map sleep fixture, so its 78/two-factor result cannot establish the default computed T15 canonical screen.
- Recommendation: after wrapper existence, wait 15 seconds for the actual `sleep-prediction-hero-score`, require the actual shared child, capture before Back, then tap the native control and require wrapper disappearance + hub return + Today selection. Preserve default launch arguments: no `--ui-design-map-sleep-prediction`, score override, or confidence override. Do not assert historical score 72, five factors, or fixed date; computed results must be observed as rendered.

Suggested in-method delta (reuse existing `today` lookup/assertions before this block if desired):

```swift
let detail = app.descendants(matching: .any)["notification-sleep-detail-screen"].firstMatch
// Existing detail.waitForExistence(timeout: 10) assertion remains.
let score = app.descendants(matching: .any)["sleep-prediction-hero-score"].firstMatch
guard score.waitForExistence(timeout: 15) else {
    XCTFail("Bedtime reminder should load the computed sleep prediction")
    return
}
XCTAssertTrue(app.descendants(matching: .any)["wellness-sleep-prediction-detail-screen"].firstMatch.exists)
XCTAssertTrue(score.isHittable, "Loaded prediction score should be visible in the initial viewport")
VisualAudit.capture("T15 default computed sleep prediction loaded initial viewport")
addScreenshotAttachment(named: "T15 default computed sleep prediction loaded initial viewport")

let railBack = app.buttons["BackButton"].firstMatch
let back = railBack.exists && railBack.isHittable
    ? railBack : app.navigationBars.buttons.firstMatch
XCTAssertTrue(back.waitForExistence(timeout: 5) && back.isHittable,
              "Loaded sleep detail should have a usable native back button")
back.tap()
XCTAssertTrue(detail.waitForNonExistence(timeout: 5), "Back should leave the sleep detail")
XCTAssertTrue(app.descendants(matching: .any)[AXID.notificationHubScreen].firstMatch
    .waitForExistence(timeout: 8), "Back should return to the Today notification hub")
// Use the same unconditional adaptive Today lookup already present in this method.
let identifiedTodayAfterBack = app.descendants(matching: .any)["tab-today"].firstMatch
let todayAfterBack = identifiedTodayAfterBack.exists
    ? identifiedTodayAfterBack : app.buttons["Today"].firstMatch
XCTAssertTrue(todayAfterBack.waitForExistence(timeout: 5))
XCTAssertTrue(todayAfterBack.isSelected, "Today should remain selected after Back")
```

Capture ordering matters: the explicit loaded attachment must precede Back. Teardown after a successful Back is the hub and must not be published as T15 loaded detail. Read its actual PNG and hierarchy; score existence alone is not visual approval. `isHittable` establishes the currently visible score anchor; no swipe should be inserted before the canonical initial viewport capture.

Native Back is a system control; do not add a 44-point AX-frame requirement to this new default method. The existing H03 helper keeps its prior navbar-path checks and window bounds, while the known rail path uses existence/hittability and a real tap. Never replace this action with a coordinate or programmatic navigation shortcut.

## Missing Test Cases

No new case required. The strengthened default T15 method covers loaded default prediction, screenshot, native Back, hub return and retained Today in the same existing selector. H03 normal retains strict payload checks and the existing detail-disappearance assertion; no H03 payload/source/launch change is needed.

For minimum changed-test scope, remove only the additional unexecuted strict-T15 Back-query patch in `DesignMapNotificationDetailTests/testNotificationSleepDetailLoadsSharedPrediction` (restore its original navbar lookup from 745; preserve all original actual tap, wrapper-disappearance, hub-return and Today assertions). It is a reasonable independent portability improvement, but does not serve either planned selector. Retaining it would require explicitly documenting its unexecuted rail branch; historical strict Phone/iPad PASS cannot certify that delta. Removing it avoids representing it as covered and leaves this contract focused on H03 helper + actually executed default T15 method. This recommendation does not change production or invalidate historical strict fixture evidence.

## iPad-Specific Risks

Use the existing adaptive `tab-today` / Today-button fallback unconditionally after Back; a TabBar-only optional assertion can silently skip selection checking in the floating navigation layout. The known `BackButton` rail may expose an AX frame smaller than a custom app 44-point control. Query only the current test application, prefer the existing hittable rail, fall back to the original navbar query, and verify the real return state. Separate closed/open Duo executions are necessary because viewport/navigation presentation differs; they remain two cases per pose.

## Coverage Rating

Current default method: needs improvement. Recommended method plus existing H03 normal: adequate for this minimal route/state/native-Back contract after both selectors actually pass on each requested Duo pose and the loaded captures are inspected. No execution performed here. Historical Phone 5 + contrast 4 PASS and iPad 4 + final-glyph MAX 1 PASS remain historical source/profile-bounded evidence; they do not certify the new default loaded-wait/Back assertions or edited H03 native rail lookup. Product, model, consumer and default input closure can preserve those earlier product checks; new targeted Duo runs cover this added contract. No broader rerun, extra selector, new counter, or full-matrix inference follows from this recommendation. Parent owns the narrow test edit, validation checkout synchronization, compile reuse decision, native execution, image review and final gate.
