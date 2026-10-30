# Siri health query SwiftUI review

Snapshot: HEAD `9ae252af` (reviewed 2026-10-30). Code review only; native UI tests were running and no current PNG evidence was available. No visual pass is claimed.

## Actionable findings

- **P2 · Record detail stays locked after unlock** — `DUNE/Presentation/HealthQuery/HealthQueryRecordDetailView.swift:29-35`. A `protectedDataWillBecomeUnavailable` notification clears the loaded record and sets `isLocked = true`, but the view has no `protectedDataDidBecomeAvailable` handler. `.task(id: snapshot.id)` is keyed to an unchanged ID, so an already displayed detail remains on the lock placeholder after the device is unlocked. Observe availability and rerun the guarded fetch (or change a reload token used by `.task(id:)`), then verify the detail recovers without leaving the screen.

- **P2 · Siri snippet mislabels calculated sources** — `DUNE/Presentation/HealthQuery/HealthQuerySnippetView.swift:37-40`. The ternary maps every source other than `.healthKit` to “DUNE record”, including `.calculated`. The condition fixture begins with a `.calculated` source, so its Siri card asserts a record provenance that does not exist. Use an exhaustive source-kind label mapping aligned with `HealthQueryResultCard.sourceLabel` and verify the condition snippet announces “Calculated from records”.

- **P2 · Fixed metric rows can compress or clip at accessibility text sizes** — `DUNE/Presentation/HealthQuery/HealthQueryResultCard.swift:68-76` and `DUNE/Presentation/HealthQuery/HealthQuerySnippetView.swift:22-29`. Both put a potentially long localized metric title and a numeric value in one `HStack` with a spacer; only comparison rows have a `ViewThatFits` vertical fallback. At large Dynamic Type sizes or in Siri's narrow card, the title or value can become unreadable. Use an adaptive vertical fallback for these rows and check long en/ko/ja labels at accessibility sizes.

- **P3 · Record navigation unnecessarily cancels and reloads the query** — `DUNE/Presentation/HealthQuery/HealthQueryView.swift:121-125,140` and `DUNE/Presentation/HealthQuery/HealthQueryResultCard.swift:136-141`. Pushing a record detail makes the query view disappear; `model.cancel()` changes its state to cancelled. On returning, `.task` reloads the same query, briefly replacing the answer and risking an unavailable state if the requery fails. Scope cancellation to actual sheet dismissal, or preserve the loaded result across the detail push; verify back navigation keeps the answer stable.

## Verification boundary

Static SwiftUI/state/accessibility review only. UI test selectors were inspected in `DUNEUITests/Smoke/HealthQuerySmokeTests.swift`; their runtime behavior and the pending captures require the native test result and PNG review.
