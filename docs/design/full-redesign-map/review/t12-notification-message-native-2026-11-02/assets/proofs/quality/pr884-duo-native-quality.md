# PR884 Duo native quality

## Summary

One reviewer applied SwiftUI, Apple UX and UI-test-expert lenses to existing T12 Duo CLOSED evidence, not three agents. CLOSED and OPEN P1/P2/P3 actionable findings:0. No UI testing issues found in the reviewed normal detail states. OPEN is separately reviewed below, not inferred from CLOSED.

## CLOSED evidence and posture

Archive: `.codex-checks/t12/evidence/pr884-duo-closed-message-final-2026-11-02` in validation. Raw revision3fac15d4; parent reports normal selector1PASS. Runner returncode0, terminationnull, cleanup_errornull,7attempted. All7checkpoint records acknowledged=true, valid_evidence=true, errornull. Pose target/before/after0°, activeLCD. Existing display readbacks retain LCD1398×2034 active and LCD-12007×2853 inactive before/after. This reviewer viewed exact active-panel `005-1398x2034.png`, the verified detail checkpoint before back; no new capture was requested.

Raw pose metadata `native_visual_review: pending-parent` remains untouched. Separate parent-observation records reviewed005 and excludes rootToday/hub/post-back/teardown frames. This report is a further separate observation, not a rewrite of raw metadata. Native Duo status/back/tab rail is preserved as captured and outside the T12 app delta.

## Findings

None.

## SwiftUI lens

005 shows the full saved “Message Route Fixture” title wrapping in two lines within the palette hero. Bell is distinct decoration with adequate surrounding padding. Full saved body “A notification message that opens its in-app detail.” wraps naturally over two lines inside the independent reading card. Card edges align, title/body remain within horizontal bounds, and there is clear vertical separation. Native rail does not collide with the bounded app content. No clipping, ellipsis or overlap was established. This is normal-size short-fixture evidence, not arbitrary-length or maximum-text Duo certification.

## Apple UX lens

Hero title and separate message card create a clear reading hierarchy, with no fabricated status/date/action. The native back remains recognizable on the original side rail. Source title is an accessibility header; decorative bell is hidden and stored body remains selectable. Existing original payload text is retained visually. No measured contrast/VoiceOver session, custom-chrome recommendation or native system rail defect is inferred from this bounded visual review.

## UI-test-expert lens

The actual selector asserts exact title/body before the explicit verified-detail checkpoint005. The successful runtime then acknowledges006 `tap BackButton` and007 teardown; saved hierarchy contains message title/body at005, then notification-hub-screen at006/007. Combined with parent-reported selectorPASS and retained final hub-return assertion, this supports actual native back/hub return, not screenshot existence alone.

005 is the detail image suitable for T12 evidence. 001rootToday,002hub,006post-backhub and007teardownhub are not T12 detail after-images;003/004 duplicates are unnecessary for the selected gallery row. Seven ACKs prove collection success separately from actual native readability assessment. Rail fallback is test-only, retains existence/hittability/actual tap/return assertions, and does not alter app navigation.

## Missing Test Cases / iPad-Specific Risks

None newly required for reviewed CLOSED normal behavior. OPEN is separately appended below; historical Phone normal+MAX and fresh iPad normal are separately documented with test-version/source limits. No additional Phone, MAX Duo, unit, Watch or full regression requirement is inferred.

## Coverage Rating

Adequate for CLOSED0°LCD normal stored-message reading and native back/hub return, with1parent-reportedPASS/7validACKs/pose readback/actual005 image. OPEN evidence is appended below. Runtime: authorized available GPT-6.1 Sol medium fallback. No runtime/build/device/CI/Git/source mutations or agents were used; only this `/private/tmp` report was written.


## OPEN appended native review

Archive: `.codex-checks/t12/evidence/pr884-duo-open-message-final-2026-11-02`, revision3fac15d4. Parent reports normal1PASS; existing runner exit0,7attempted, no termination/cleanup error. All7records are acknowledged=true, valid_evidence=true, errornull. Pose target/before/after180°, activeLCD-1. Display readbacks show LCD inactive and LCD-1 active rot90 before/after. Exact original `005-2007x2853.png` was viewed; decoded pixels are landscape2853×2007 despite its filename token. No image transformation/cropping or metadata modification was performed.

Raw `native_visual_review: pending-parent` is preserved. Separate parent-observation records actual005 review and exclusions; this reviewer adds its observation here without changing raw pose provenance.

### OPEN SwiftUI lens

The verified005 detail has a bounded centered reading column rather than stretching to the full landscape width. Complete saved title is single-line and full saved body is single-line, each inside its own aligned hero/card region. Bell decoration retains padding; title/body have clear separation and neither collides with native rail. No horizontal clipping, ellipsis or overlapping content was established. The remaining white area is ordinary unused viewport below short content, not a missing-data finding.

### OPEN Apple UX lens

The hierarchy remains clear in landscape: native Notification title/back, decorative bell hero, actual saved title, then the original message. No fabricated state/date/action appears. Native Duo status/back/tab rail stays original as captured, outside the T12 delta. Visual/source review supports readability for this fixture; it is not VoiceOver, quantitative contrast, arbitrary message-length, or maximum-text Duo certification.

### OPEN UI-test-expert lens

Actual005 verified checkpoint follows exact stored-title/body assertions.006 acknowledges native `tap BackButton`; saved006/007 hierarchies have hub identifier and no message title/body, unlike005. Combined with actual reported testPASS and retained hub-return assertion, this establishes the original native-back lifecycle rather than merely a screenshot.006/007 remain hub-return evidence and must not be labeled T12 detail after-images. Root/hub and duplicate003/004 frames need not be promoted into additional gallery detail images. Seven ACKs are collection evidence separately from actual005 visual inspection.

### Final Duo coverage

Adequate for planned normal stored-message reading and native-back/hub-return on CLOSED0°LCD and OPEN180°LCD-1. Each has1parent-reportedPASS, runnerexit0,7validACKs, matching pose/display readbacks and actual active-panel005 review. All three lenses return0 actionable findings. Historical Phone and fresh iPad retain their separately documented source/version boundaries; no full-regression/all-content claim follows. No extra runtime or source change was performed or requested.
