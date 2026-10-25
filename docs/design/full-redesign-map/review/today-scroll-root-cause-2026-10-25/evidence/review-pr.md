# Pre-ship PR review

- Branch: `codex/today-scroll-root-cause`
- Reviewed app/test source: `ef42c58ef8d5ae03eb43c45e5266a8c65c487dd6`
- Base: `origin/main` at `6359129efc4f5566890e7479362fbd8edbd3b3c0`
- Scope: all six Swift files in `/tmp/scroll-debug/final-code-review.diff`, surrounding call sites, inspector consumers, and source/target wiring.
- Method: read-only review under `.claude/agents/pr-reviewer.md` and applicable SwiftUI, navigation ownership, concurrency/performance, HealthKit, layer-boundary, localization, and testing rules. The requested role's Sonnet model is unavailable; review used the inherited runtime model.

## Findings

No actionable introduced P1, P2, or P3 findings.

- Today still has one tab-root NavigationStack. The inspector moved outside that stack, its two presentation states are mutually cleared, both dismissal paths preserve the prior content behavior, and the metric inspector retains an independent stack and All Data destination.
- The production DashboardView call site supplies both new callbacks. App theme and Today wave environments enclose the moved inspector; metric detail still installs its metric-specific wave color. Dashboard-only weather/hero environments have no direct dependency in the moved inspector content.
- Refresh ownership is isolated to MainActor. Concurrent callers await the same task, explicit screen disappearance cancels the owned operation, and cancellation retains task tracking until completion so old cleanup cannot overlap a replacement refresh. Caller cancellation intentionally does not cancel owned work.
- Refresh diagnostics are available only behind the existing UI-test launch mode. The completion count denotes uncancelled wrapper completion, not HealthKit data success, consistently with the test comment.
- New coordinator and unit tests are covered by the existing XcodeGen Presentation/DUNETests directory sources and appear in the generated Xcode project's Sources phases.
- Added regression coverage checks partial position retention, native refresh completion, initial-position restoration, and continued scrolling. Existing inspector open/close/reopen and All Data checks cover the moved presentation owner.
- No new HealthKit query, storage/schema mutation, force unwrap/cast, external data transmission, or untranslated production string was introduced.

## Evidence checked and limits

- Inspected existing integrated selector receipts: iPhone 10/10, iPad 4/4, Duo closed 2/2, Duo open 2/2; all have zero failed/skipped or required selectors missing. These are targeted runs, not full-suite validation.
- Inspected the macOS-host Swift Testing log: four coordinator tests passed. Both coordinator source and test source in that package are byte-identical to the reviewed repository files. This is not an iOS-host unit-test claim.
- `git diff --check origin/main...HEAD` passed.
- No new build or simulator execution was launched by this reviewer. Generic iOS build success is supplied by the parent workflow.
- This review does not certify visual capture completeness. The parent is resolving the separate Duo native-image capture issue; a black XCTest attachment is not itself a functional test failure.
