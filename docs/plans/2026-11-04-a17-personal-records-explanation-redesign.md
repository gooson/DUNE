# A17 personal records explanation redesign

Status: implementation, scoped native validation and independent reviews complete; final publication review and GitHub merge pending.

## Scope and preserved behavior

`PersonalRecordsInfoSheet` has one production caller: Activity → Personal Records information (`activity-pr-info`). It keeps the original native medium/large sheet, drag indicator, vertical scrolling, all five content groups and their SF Symbols: `lightbulb.fill`, `scalemass.fill`, `apple.logo`, `sparkles`, `lightbulb.max.fill`. The trophy title is retained in an opaque themed hero; the repeated subtitle is removed and section icons receive consistent visual treatment. Content is centered within 680 points and remains vertically flexible.

The strength explanation lists the four existing record categories: weight, estimated 1RM, rep max and session volume. It makes no raw-maximum or average-weight formula claim. Domain calculations, permissions, record/reward data and HealthKit behavior are unchanged. The pre-existing volume-derived weight-input ambiguity is outside this presentation change. All 18 meaningful literal keys have manual Korean/Japanese catalog entries; one new manual en/ko/ja sentence replaces one unused obsolete key after its callers were checked.

## Bounded execution and results

Implementation began from actual merged A16 main `5bbfc9f0ea73c6ab85c55b3b873065fa91637e5c`. Product/catalog source is unchanged from `96d503936316a2b44aae900ce9ba3f57e93eefd6`; final test/source binding is `6b857ae8cfc29fe7ec9f3a77a9c6d6af8992d509`.

The standard UI runner compiled the actual targets and executed five final cases across four serial runs: original normal selector on iPhone 18 Pro Max, iPad mini, Duo closed and Duo open; one English dark accessibility XXXL case on Duo closed. All five passed, with fresh guest PNG/AX and actual Duo hinge/active-display readbacks. One owned simulator was used at a time; all three owned devices were deleted after archival. No full suite, all-locale run, alternate consumer or new arithmetic unit test was required for unchanged logic. The post-build catalog format/manual check passed.

Three historical closed bundles remain separate: 96d executed 2/0 passed/2 failed (long-label identifier limit); 98dc executed 2/1 passed/1 failed (medium-sheet pan); dcef executed 2/1 passed/1 failed (normal native close). Total observed cases are 11: 7 passed and 4 failed, including the final five successes. The first archive accurately retains its export-time dirty flag: the original native run had clean source, but a post-run correction began during export. Later archives are clean. Original pipeline receipts, failed results and consumed corrective dispatch records are retained.

The tests use full-label predicates, preserve the initial canonical capture, expand the real system grabber before document reading, check complete short leaves and bounded overlapping scrolling for oversized leaves, and verify native dismissal plus Activity return. Normal close explicitly observes the medium detent before dismissal; MAX retains its successful direct native gesture. A misplaced preliminary close block was found and corrected by static review before execution.

## Review, maps and completion

Independent source, native PNG/AX and stage-preservation reviews report P1/P2/P3 = 0/0/0 within scope. The reviewed gallery installs only 19 allowlisted existing outputs and the new A17 gallery. Other screen rows and pixels outside the A17 board tiles remain unchanged. Historical before pictures visibly show the same help family, but their individual source/device/locale/state provenance is unknown; they are not claimed to be fresh matched baseline captures. Primary teardown Home images are not used as visual return proof.

[Actual before/after gallery](../design/full-redesign-map/review/a17-personal-records-explanation-native-2026-11-04/index.html) links the public review reports and source-bound captures. [Layout](../design/layout-map/activity-personal-records-explanation-a17.html) and the A17 theme study distinguish explanatory diagrams from actual screenshots. Compound is recorded in `docs/solutions/testing/2026-11-04-personal-records-native-sheet-reading.md`. Source CI iOS build passed; unit workflow state is recorded separately, not represented as a local full-suite pass. Final publication is documentation-only and reuses unchanged app/test/catalog bytes rather than rerunning the native matrix.
