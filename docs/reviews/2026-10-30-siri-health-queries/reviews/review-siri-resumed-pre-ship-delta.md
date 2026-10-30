# Siri health queries — resumed Pre-Ship delta review

Read-only source review at `adac0a30`, comparing `0e346222..HEAD`. Reviewed `HealthQueryView.swift`, `HealthQuerySmokeTests.swift`, the layout-map note, the prior specialist reviews, the iPad native finding, and the `/ship` gate. No build, test, simulator, Siri invocation, or screenshot inspection was performed for this review.

## Findings and disposition

| Priority | Finding | Disposition |
|---|---|---|
| P1 | No new source finding in this delta. | None confirmed. |
| P2 | The earlier iPad Accessibility XXXL picker text was measured outside its 77.5 pt button at `19754ce6`. `HealthQueryView.swift:38–114,221–243` now uses a vertically growing, multiline native `Menu` label for Information and Period at accessibility sizes, retaining a visible title and current value. Selected options have checkmarks and selected traits; the control has VoiceOver label and value. | **Source remediation present; native verification open.** Confirm fresh post-`adac0a30` iPad and Duo folded/unfolded screenshots show both full selected values inside their control bounds, and confirm option selection/VoiceOver behavior. The previous iPad PNGs prove the defect, not the fix. Do not mark this P2 resolved until the new images and run results are inspected. |
| P3 | Prior chart top tick clipping on iPad SQ10/SQ13 is untouched in this delta. | Existing polish finding; report separately, not a new P2. |

The UI test changes scope long-text gestures to the query pane, bound Information-menu drags to its visible popup, add period/source and return captures, exercise the seeded record route, and wait for a cold system share sheet. The source assertions remain specific enough to catch a missing result or wrong record screen. The nonfixture metadata now accurately calls its data synthetic seeded SwiftData records with the production query service. Six unique iPad smoke methods reportedly passed across the first run and failed-only retry; this review did not rerun them. The new accessibility `Menu` branch was committed after that iPad evidence and needs its own native run.

## Pre-Ship conditions

1. **Build the current app source at `adac0a30` or later.** The generic iOS 27.2 build and 63 unit tests / nine suites were for earlier source. `HealthQueryView.swift` changed after those passes; a successful build at the old commit is not compile evidence for the new `Menu` branch.
2. **Inspect the new owned-device native artifacts.** Require fresh iPad and Duo closed/open max-accessibility selector and result PNGs, plus test results, before closing the measured picker P2. Update the actual design map from those captures. A screenshot only establishes rendered layout; VoiceOver order/value and system Siri presentation require separate interaction evidence.
3. **Keep evidence provenance explicit.** Fixture captures and seeded SwiftData local-record navigation do not prove live HealthKit reads. No reviewed artifact proves a physical-device Korean Siri invocation, spoken answer, or system-hosted snippet. The `/ship` skill explicitly blocks unresolved P1/P2 and requires stale findings to be rechecked; it does **not** state that physical Siri listening is an independent mandatory merge gate. Treat it as unverified release QA for the user's Siri outcome and disclose it; do not claim system Siri voice behavior from a CoreDevice connection, install, source code, simulator, or an unheard audio attempt. If project acceptance criteria require it, leave that acceptance condition open until a real device observation is recorded.

Prior five source-perspective reviews and the PR snapshot report no remaining confirmed P1/P2 in their inspected source. Their static conclusions do not replace these post-fix build and native conditions. PR #866 is an existing draft; this review made no PR change.
