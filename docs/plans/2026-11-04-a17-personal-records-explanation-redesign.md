# A17 focused native validation draft

Original source-preparation base: `35718dd4cba647c17b847e16c8b0475baf7edaa6`; revised test patch context checked at A16 `6d186b3ac51f4fa94c91c06455ea6e267a0a037d`. This is a private preparation only. No repository files, app, tests, simulator, or build were changed or run.

## Source and content contract

`ActivityView.personalRecordsSection` owns `activity-pr-info` and is the sole production caller of `PersonalRecordsInfoSheet` through `ActivityView`'s `showingPRInfo` sheet. There is no separate detail/A03 sheet consumer. Preserve the existing `ScrollView`, `activity-personal-records-info-sheet` ID, `.medium/.large` detents, native drag indicator, `trophy.fill` hero, five section SF Symbols (`lightbulb.fill`, `scalemass.fill`, `apple.logo`, `sparkles`, `lightbulb.max.fill`), overview, cardio, HealthKit, NEW badge, and tips. The private source patch removes the redundant subtitle and replaces one ambiguous strength sentence with four record categories. It makes no arithmetic formula or raw maximum claim and does not change domain behavior.

The proposed A17 source contains 18 user facing literal keys: title, five headings, overview, four measurement bullets, two HealthKit bullets, two NEW badge bullets, and three tips. In current master 17/18 keys exist and all 17 are `manual` with ko/ja entries; the only missing key is `Strength records include weight records, estimated 1RM, rep-max records, and session volume.` The private `/private/tmp/a17-native-preparation/catalog.patch` provides manual en/ko/ja for it. Recheck all 18 keys and `swift scripts/format-xcstrings.swift --check --check-manual` after integration. The old strength key may remain if used elsewhere; avoid unrelated catalog cleanup.

## Exact targeted UI test shape

Apply and independently review `/private/tmp/a17-next-preparation/test.patch` only after source/catalog integration. It preserves `ActivityExerciseRegressionTests.testVisualAuditPersonalRecordsExplanation` as the normal selector and its `openActivityInfo` canonical capture before scrolling. New sibling: `ActivityExerciseRegressionTests.testPersonalRecordsExplanationAtMaximumAccessibilityTextSize`, explicitly English, dark, accessibility XXXL. Both cases verify the changed strength-category sentence exactly, all section headings, and representative first/last unchanged body leaves in order. Short leaves must fit fully in the actual viewport; an oversized leaf requires exact full AX label, horizontal containment, bounded overlapping 18% viewport scroll intervals, top/bottom reach, and endpoint captures. They check removal of the duplicate subtitle, the native system grabber's frame and hittability, drag dismissal, and return to Activity. MAX reads the native grabber value; if it already reports `Expanded`, it keeps that state, otherwise it makes one upward drag and requires an actual `Expanded` readback. Captures are per section and after dismissal. Text lookup is scoped to the sheet; no app accessibility identifiers are added by this test proposal.

Run the original normal selector separately on the current worktree's owned iPhone, iPad, Duo closed and Duo open profiles. Run the focused dark/MAX sibling on owned Duo closed. Use standard UI runner, one process and one simulator at a time, exact selector only. Record guest screenshot/AX and host receipt provenance. No full suite, alternate consumer, all locale, or unit test is required for this one-screen visual change. Preflight owned simulator/runner and follow `.codex/skill-compat.md` deadlines. Preserve any failure; if a text leaf or grabber has different native AX structure, inspect the actual AX tree and screenshot before adjusting only the selector/ID boundary. Do not count a capture or test as passing until its exact result receipt and actual pixels are reviewed.

The proposal is source-only and uncompiled; the test's detent and AX geometry assumptions remain runtime questions. The visual reviewer must compare fresh screenshots against the A17 layout/theme map and actual screen map for the affected devices after integration.

## Later private test draft alignment

The proposed native dismissal now uses one system-grabber drag to `window.frame.maxY - 40` at explicit `XCUIGestureVelocity(rawValue: 1_000)` with zero hold, retaining the existing unique/hittable/window/top-edge/minimum-travel/disappearance/Activity checks. This matches the A16 closed 2/2 positive gesture shape at source `6d186b3a`; it is **not** A17 runtime evidence. Revalidate on the actual target profile and preserve any failure. Updated test patch SHA-256: `28ae1c7e5b82b7e35f78d199139e4282d7337a189ea3906ce2ed33fab5f08b1d`.

Patch context was rechecked with `git apply --check` at current clean A16 HEAD `6d186b3ac51f4fa94c91c06455ea6e267a0a037d`; this checks only patch applicability, not Swift compilation or UI behavior.

## Revised private geometry contract

The earlier static review `/private/tmp/a17-a19-test-contract-review.md` found two P2 draft geometry assumptions and one P3 exhaustive-copy issue. This revision addresses those contracts in the private patch only. The `Expanded` AX value was observed on A16 English native grabber, not proven for this future sheet. The tall-text continuity check is proposed source logic, not a runtime or pixel pass. Preserve source/catalog audit for all unchanged strings and original SF Symbols; the focused native selector tests changed facts and representative layout without mirroring all unchanged copy. No shared global helper is introduced before three integrated consumers establish a real reuse need. On integration, inspect actual AX/frame semantics and paired PNG at each tall-text endpoint; retain failures if semantics do not establish continuity.

## Actual integration

Feature `codex/a17-personal-records-explanation` starts from actual merged main `5bbfc9f0ea73c6ab85c55b3b873065fa91637e5c` in this chat’s goal-owned l03 worktree. Earlier private bases are historical preparation only. Native cases remain pending until actually executed. The single changed strength sentence has no new formula or raw-maximum claim; domain/record/reward behavior stays unchanged. Audit the retired catalog key before retaining or removing it. No other chat’s worktree or original prototype changes are modified.

The retired average-weight sentence has no remaining Swift caller across app, Watch, vision, Shared or tests after integration; its unused catalog key is removed, while all keys still used elsewhere remain.
