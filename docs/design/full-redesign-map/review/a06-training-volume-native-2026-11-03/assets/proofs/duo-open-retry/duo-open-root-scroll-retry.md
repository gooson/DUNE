# A06 Duo Open route failure · proposed test-only change

The e206 Open normal selector failed at `openTrainingVolumeDetail`'s reachability assertion before the detail route opened; it is not an after-image or a successful case. Captured root setup and teardown checkpoints both ACKed on the active open display. The AX tree shows `activity-root-scroll` frame {{0,0},{951,669}} and the volume button at y=3203 at setup and y=3400 at teardown, outside that viewport. The parent inspected active 002 host PNG and saw the Activity top with volume offscreen. The failure is consistent with app-level swipes failing to bring this target into the owning Activity scroll view, but the exact gesture routing or SDK cause has not been established.

The private helper `scrollUntilHittable` already accepts a scroll container and preserves the `exists && isHittable` predicate. The proposed patch resolves `AXID.activityRootScroll` and supplies that existing Activity scroll owner to the initial eight-swipe reachability and the existing three-swipe navigation retry. No gesture counts, coordinates, tap semantics, goal/date checks, product source, or existing assertions change. `preferredScrollContainer` in `UITestHelpers` prioritizes that same identified root; A03's successful Duo map route uses the helper that selects it, providing an existing project precedent. This is evidence-supported targeting, not proof it will fix the runtime failure.

Proposed patch: /private/tmp/pr893-open-entry-fix.patch. Not applied, compiled, or executed. Independent review and one conditional same-ID retry, if authorized after the concrete change, are still required; the failed attempt and its before-pose/2 ACK evidence remain preserved. A failed runner has no after-pose proof and no valid detail capture. No device, ledger, Git, source, or gallery mutation was performed.


# Independent review

CLEAR for one conditional retry of `pr893-duo-open-volume-overview` after applying patch SHA-256 `44133df457ab9c9d9ee6dc974b757198d9a6d160c21ca9972d6205ea20895f28` and recording that change against its existing failed attempt.

The original pipeline ID has one failed attempt. The result has one executed, zero passed, one failed at the pre-navigation reachability assertion. Both paired AX checkpoints show the owning Activity scroll view at 951 × 669; the Volume button is below it at y=3203.3 and y=3400.7, respectively. Neither checkpoint establishes a successful transition to detail. The archive records two valid ACKs and a before-pose observation only.

The patch makes XCTest resolve the identified Activity scroll view and send the existing up-swipes to that element, consistent with the project's preferred-container helper. It leaves both swipe limits (8 and 3), target existence/hittability, real taps, destination check, content assertions and capture points intact. The change directly addresses the failed interaction and meets the adapter's remediation requirement for the same-ID retry. Because the root window and scroll view have the same reported frame, these artifacts do not establish the SDK gesture mechanism or predict success. Preserve the first attempt and require a new receipt plus actual detail and pose evidence before reporting success. Review only; no patch or runner executed.


Applied only test scroll-container references at commit 844dacaae8d1bed1c467b92bb3f21d7b07e449a4. Full original e206 failure archive retained. Prior invocation was rejected before execution for missing mandatory retry metadata; history remains exactly one failed attempt. No native second execution started at that rejection.
