# PR883 Duo native quality

## Summary

One reviewer applies SwiftUI, Apple UX and UI-test-expert lenses to existing native Duo evidence. This is one review, not three agents. CLOSED and OPEN P1/P2/P3 actionable findings:0. No UI testing issues found in the reviewed native controls scope. OPEN evidence is appended below; both reviewed poses are complete.

## CLOSED evidence and posture

Archive: `.codex-checks/t11/evidence/pr883-duo-closed-hub-final-2026-11-02` in validation worktree. Revision `ae2598a6`; parent reports one controls test PASS. Existing paired-host runner result returncode0, terminationnull, cleanup_errornull, attempted7. All seven checkpoint records are acknowledged=true, valid_evidence=true, errornull. `captures.tsv` retains both1398×2034 and2007×2853 files for each checkpoint. ACK establishes collection handshake success, not visual quality by itself.

Read raw pose and before/after display records: target0°, before0°, after0°, active displayLCD. Before/after readbacks show LCD1398×2034 active/primary at rot0 and LCD-12007×2853 inactive. The active1398 images, sequences002–007, were actually viewed for meaningful app states. No visual claim is made for the inactive panel solely because its paired files exist.

Raw `pose-proof.json` still says `native_visual_review: pending-parent` and remains untouched. The separate `parent-observation.json` records parent review of002/007, no findings, and original chrome retained. This reviewer report is a further separate observation; it does not rewrite or silently upgrade the raw receipt.

## Findings

None.

## SwiftUI lens

- 002: All selected,3unread, summary actions and native three-part filter visible; release and Sleep Debt Alert readable, next health row continues below the viewport. Original category icons, version, timestamp, Unread and destination hints remain within card bounds. Body wraps below the icon-leading header rather than losing reading width.
- 003: caught-up status replaces count; Read All is visibly disabled and Unread indicators disappear while release/health content remains. The longer caught-up title fits without collision with the original system rail.
- 004: native overflow presents a legible red Delete All action over the summary.
- 005: native destructive confirmation has full wrapped title/message and visible red action. The popover fits the active content region; underlying controls are naturally obscured by the modal presentation.
- 006: confirmation has been acted on, All remains selected and health content is removed. It is a post-confirmation checkpoint, not the confirmation-visible frame. The read release source remains retained; individual large-image tool presentations are not used to infer disappearing-card defects.
- 007: Health selected and No Notifications message readable, with caught-up summary and disabled Read All retained. This means Health-empty, not the combined News+Health inbox entirely empty.

No actionable overlap or horizontal truncation was established in these states. The next row at the viewport edge is intended scroll continuation. Current source remains a native List with a width-bounded content column; no custom list replacement was introduced.

## Apple UX lens

Unread summary and primary action have clear hierarchy, settings/more remain distinct, native filter selection is recognizable, and text Unread/caught-up feedback does not rely on color alone. Destructive deletion stays behind overflow and an explicit native confirmation. Retained release content and filtered Health-empty state must be captioned accurately.

The large camera/status/sidebar rail appears in original native PNGs. Parent identifies it as the same baseline system chrome, and the T11 diff does not change system rail ownership. No T11 product defect, retouching recommendation or crop-based concealment is inferred from that unchanged chrome. VoiceOver, quantitative contrast and a back/sidebar navigation interaction were not independently tested.

## UI-test-expert lens

The existing controls method performs Read All, awaits disabled state, opens overflow, selects Delete All, confirms through the native sheet, selects Health and requires its empty-state element. The sequence matches the seven named checkpoints. Existing `auditTap` captures after the action, so state descriptions follow actual resulting frames rather than filenames alone. Neither PASS nor seven ACKs alone replace native image review.

No title/body visibility test for every possible item, dark maximum text, swipe/cancel action, persistence after relaunch or settings opening is inferred from this single normal controls flow. No additional runtime or generic/full test recommendation is introduced.

## Missing Test Cases / iPad-Specific Risks

None newly required for the changed T11 behavior in the reviewed CLOSED controls configuration. The CLOSED section alone does not establish OPEN or all size classes; OPEN is separately reviewed below. Existing iPad and Phone reports are separate evidence, with only T11 hub prefix equality established rather than T12/T13 tail equality.

## Coverage Rating

Adequate for CLOSED normal T11 controls/read/delete/filter-empty behavior with verified0° LCD posture and7validACKs. OPEN is reviewed in the appended section below. Runtime: authorized available GPT-6.1 Sol medium fallback. No tests/builds/native actions/CI/Git/source edits or new agents were used; only this `/private/tmp` report was written.


## OPEN appended evidence and posture

Archive: `.codex-checks/t11/evidence/pr883-duo-open-hub-final-2026-11-02`, revision`ae2598a6`. Parent reports one existing controls test PASS. Raw paired-host runner returncode0, terminationnull, cleanup_errornull, attempted7. All seven checkpoints acknowledged=true, valid_evidence=true, errornull. Pose target/before/after180°, activeLCD-1. Existing before/after display readbacks independently retain LCD inactive and LCD-1 active at rot90, native2007×2853. Active-panel sequences002–007 were viewed from their exact original PNGs. Original orientation/EXIF, native status/back/tab rail and both-panel evidence remain unchanged; no image rotation/cropping/editing was performed.

Raw `pose-proof.json` remains `native_visual_review: pending-parent`, untouched. Separate parent-observation records its002/007 visual review. This appended reviewer observation does not mutate the receipt or claim that pending raw metadata was originally complete.

### OPEN SwiftUI lens

002 shows All selected with3unread, clearly separated summary controls and full native three-segment filter. Release title/version/intro, Sleep Debt Alert header/body/time and original symbols read clearly across the bounded column; the next health card continues at the bottom. 003 shows caught-up state and disabled Read All with content retained and Unread labels removed. 004 shows the native red Delete All overflow action. 005 shows readable full native destructive-confirmation title/message/action, with expected modal occlusion behind it. 006 is post-confirmation All state retaining read release content after health deletion. 007 is Health-selected empty state with its title and two-line explanation clearly centered. It does not mean News/release was deleted.

No horizontal truncation, action overlap, or new layout regression was established in the reviewed OPEN states. Wider spacing differs naturally from CLOSED, while component hierarchy and reading alignment remain coherent. Bottom row continuation is normal scrolling, not failure to fit the entire inbox on-screen. No defect is inferred from inconsistent large-image tool presentation alone.

### OPEN Apple UX lens

Unread/caught-up feedback and primary Read All remain legible and distinguishable. Native selected filter, category symbols, text unread statuses and destination hints preserve established interaction cues. Overflow and explicit destructive confirmation remain separate steps; the popover's title/message/action are not clipped. Native Duo chrome is preserved as captured and lies outside the T11 product delta, with no retouching or new defect claim.

### OPEN UI-test-expert lens

The same existing controls selector exercises actual Read All, waits for disabled state, performs overflow/Delete All/confirmation, then selects Health and verifies empty state. Seven valid ACKs support complete checkpoint collection; the actual PNGs support layout conclusions separately. Existing paired files are retained for both screens, but visual conclusions use the active OPEN LCD-1 images. No fresh test, back/sidebar action, cancel-path claim, maximum-text Duo claim, or broad regression was added.

### Final Duo coverage

Adequate for the changed T11 normal controls flow on both CLOSED0°LCD and OPEN180°LCD-1. Each has one parent-reported PASS, runner exit0,7validACKs, pose readback and actual native visual review. All three lenses return0 actionable findings. This remains bounded to these states; it is not a statement that every notification action, setting, appearance or size class was tested. No additional runtime is needed or requested by this review.
