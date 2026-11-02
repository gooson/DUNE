# PR886 T14 simplicity source review

P1=0 / P2=0 / P3=1. No blocking simplicity or original-functionality issue found.

### [P3] Consolidate the third copy of detail viewport geometry when scope permits
- **File**: `/Users/shanks/.codex/worktrees/detail-redesign-t14/Health/DUNEUITests/Full/ActivityExerciseRegressionTests.swift:2294`.
- **Category**: dry.
- **Issue**: t14FallbackViewport adds the third stable copy of the same scroll/window intersection, horizontal4pt inset, Notification navigation-bar exclusion and bottom-tab exclusion. Existing copies are detailViewport and t13UnavailableViewport in DUNEUITests/Full/DesignMapAdditionalRoutesTests.swift:115 and:260. Future system-geometry corrections must be kept in sync at three sites.
- **Simplification**: A small shared test-only viewport helper could take app/scroll/navigationTitle and return the same CGRect; retain each feature’s own text-position semantics, loop budgets and final assertions. This is minor maintainability feedback, not a runtime defect, reason to repeat passed tests, or mandatory expansion of this sequential feature PR. Explicit deferral is reasonable if shared-helper work would broaden the current validation scope.

No other actionable simplicity finding. The product uses existing palette/background and a direct max560 ScrollView composition. Original exclamationmark.magnifyingglass, exact existing localized title/explanation and actual workoutID remain; ID text selection is preserved. New environment/scaled values and view helpers are used. No new query, fabricated date/status, retry action, model or route is added.

MAX hub-row reveal is bounded to nine drags/ten checks, checks exists before frame and requires full front-list viewport containment+hittability before tapping. The fixed bounds use the actual hub/window/nav/tabbar geometry rather than a whole-app generic swipe target. Original exact payload and ID assertions remain, as do fallback title/message/ID readability checks and actual native Back→Activity assertion. No swallowed failure or screenshot-only success found. The normal method does not actually tap Back despite its screenshot caption; its positive evidence is only title/message/ID/capture and must not be presented as Back coverage.

Reviewed247-line core diff, role profile and source-closure JSON in current actual8e6+main9b90 integration. Product5d0f current/d310/8e6/validation3fac equivalence, relevant normal/MAX/helpers/openHub/tapBack/baseclass ranges and wholeUI-file inequality are distinguished. Source equality is not fresh runtime success. Original two t14-ui-missing-workout/b483 failures and approved exactMAX remaining1 stay intact; this review does not consume or grant execution. No speculative T11 fixture rewrite, extra full/unit/Watch or broad helper test gate follows from this report.

Limits: source-only read-only review; no tests/builds/devices/CI/Git operations/source edits/subagents. Report-only write. Availablegpt6.1sol medium fallback, not unavailableolderconfiguredmodel.

Disposition: P3 maintenance-only test viewport deduplication is explicitly DEFERRED by parent. Extracting shared geometry would touch already-merged T12/T13 test scopes and alter the pending approved MAX exact-source baseline without fixing a behavior defect. The user requires necessary-only tests and sequential screen PRs. Keep original feature-specific assertions/reveal behavior and source closure. Open disposition: P1=0/P2=0/P3=1 maintenance-deferred; not P3zero. No new runtime required by this deferral. Future consolidation is limited to UI-test geometry; shared production palette/components are already reused appropriately.
