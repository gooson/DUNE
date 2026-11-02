Summary
The test-only native Back query correction matches the captured closed-Duo accessibility hierarchy. This is a static review, not a runtime PASS.

Findings
No UI testing issues found.

Evidence and scope
Reviewed the current uncommitted patch to DUNEUITests/Full/NotificationRoutingRegressionTests.swift in public worktree HEAD fd888f133269dd3cc8790f9225b63648c40f843f, restricted to NotificationResponseRoutingUITests.testNotificationResponseOpensSummaryAndBackReturnsToToday. The patch prefers app.buttons["BackButton"].firstMatch only when it exists and is hittable, otherwise retains the prior navigation-bar query. It keeps a 5-second existence wait, adds hittability assertion, performs the actual tap, and retains the Today dashboard notification-toolbar assertion.

Independently read validation worktree .codex-checks/t10/duo-closed-f9c956e1/001-hierarchy.txt and viewed 001-1398x2034.png. The report is loaded; the native BackButton is outside NavigationBar at {{399,179},{38,38}}. The PNG shows the floating rail back arrow. run.log records the original failure at the old navigation-bar-only existence assertion (line 131), and runner-result.json records returncode 65. Existing validation-worktree ActivityMuscleMapRegressionTests and ExerciseTypeHealthKitVariantUITests use the same exists-and-hittable rail fallback; HealthQuerySmokeTests also supports the floating BackButton.

Missing Test Cases
The corrected closed-Duo entry/back route still needs runtime execution. No open-Duo execution has occurred per parent task context; this review does not claim open-Duo coverage.

Conditioned retry justification
One closed-Duo retry of the exact same NotificationResponseRoutingUITests/testNotificationResponseOpensSummaryAndBackReturnsToToday selector is justified under failure ID pr882-duo-closed-report-entry-back: this is the first observed failure for that cause and the reviewed query patch directly addresses its captured structural cause. Preserve the original failure evidence and count this as the sole same-cause retry (maximum 1); if that cause remains, stop that execution path. This review authorizes no additional open run or scope expansion. Use the owner-controlled standard runner/device/deadline only after the test patch is present in the validation checkout.

Evidence reuse limits
The reviewed patch changes only the test query and leaves app view behavior unchanged, so existing Phone1/iPad1 f9 actual captures remain valid for their captured app state. This does not assert byte equality of the entire UI test file between public and validation worktrees (validation has an additional bedtime-route change). No tests/build/simulator operations, Git mutations, or source edits were performed for this review.

iPad-Specific Risks
No new production sidebar, split-view, or sheet behavior is introduced. Conventional navigation-bar fallback is retained. Actual corrected back-route execution remains pending.

Coverage Rating
adequate for the narrow static query correction; runtime closed-Duo result remains pending.
