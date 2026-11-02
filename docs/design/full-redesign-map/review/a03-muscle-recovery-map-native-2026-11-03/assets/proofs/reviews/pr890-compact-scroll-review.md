# A03 compact scroll source quality review

P1: None. P2: None newly found in the proposed correction. P3: None. The pre-fix Phone default visibly crops the map at the primary pane boundary while the Volume pane starts below; its selected scrolled image exposes the legs, showing separate scroll ownership rather than absent SVG data. This is a visual defect in the pre-fix candidate, despite its exact selector 1/1 PASS.

SwiftUI: Reviewed actual dirty View diff. Compact now owns one vertical ScrollView containing map then summary; regular still constructs the same AdaptivePaneView and two scrolls. Extracted content preserves the gate, map state, selected detail, volume, recovery, identifiers and modifiers. This is an appropriately local correction; global AdaptivePaneView is unchanged. Actual new layout/AX identity is not proven until target compilation and runtime.

Apple UX: The change should let users scroll continuously through the full body map, disabled cube and subsequent content, removing the observed split-pane boundary; this is an expected result from source, not a claim of a viewed corrected screenshot. Regular historical iPad visual and behavior can be reused only under the documented unchanged regular content/input closure, not as a fresh current-source result.

UI test: The existing original calculation selector still exercises selection, disabled 3D, real calculation, native dismiss and Back. Its `detailScroll` chooses index 0 when only one scroll exists, consistent with intended compact structure; actual hierarchy and gesture results require native validation. Prior de559 Phone PASS predates the fix and is not current-source visual/functional proof. Final Phone and Duo closed checks are needed for corrected compact behavior, and fresh Duo open regular capture for current integration scope. Reuse existing iPad regular case only within source/input closure. The local requested extraction proof file was absent at .codex-checks/q/a03; conclusions are based on the actual diff, not that proof.

No tests/builds/devices, source or Git mutation. No retry, failure quota reset or replacement case inferred.
