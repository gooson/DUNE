---
tags: [swiftui, charts, selection, xctest, accessibility, dynamic-type, exercise-mix]
category: testing
date: 2026-11-03
severity: important
status: resolved-scoped-native
related_files:
  - DUNE/Presentation/Activity/ExerciseMix/ExerciseMixDetailView.swift
  - DUNE/Presentation/Activity/ExerciseMix/ExerciseMixDetailViewModel.swift
  - DUNEUITests/Full/ActivityExerciseRegressionTests.swift
  - DUNETests/ExerciseMixDetailViewModelTests.swift
related_solutions: []
---

# Exercise Mix: Chart selection values, transient gestures and AX plot frames

## Problem

On closed Duo source `5e047c044a21969733b1d264381b567af6504a9c`, normal and maximum-text tests both failed the chart full-frame check. The actual MAX AX hierarchy exposed two elements with the same chart identifier: a propagated semantic container of 664×538 points and a 326×200-point plot. The former exceeds the 466-point window and cannot be brought fully into view by scrolling. A later short tap at a sector boundary was inconclusive, and `54796e75` also failed after an interior short tap: the final AX snapshot alone could not distinguish an unobserved event from a selection cleared on release.

## Changes and evidence

- The focused test resolves the smallest nonempty chart-ID frame by area **without filtering by viewport fit**, asserts the actual 200pt plot height and full viewport containment, and uses bounded short drags near the plot. Horizontal overflow remains a failure. Real date, category-total, two distinct sector identities/counts, full-frequency matching and Back assertions are retained.
- The presentation mapper uses cumulative raw frequency counts rather than interpreting the binding as degrees. An opt-in diagnostic run at `50e2b0dec85c7be41517940c2a20b3de08f255a2` recorded a scoped ready witness for actual app PID 96576: first and second holds produced raw values approximately `0.500218` and `1.499782`, mapped to two actual 1x exercises, then each returned nil upon release. The short tap produced no observed onChange. This is evidence for that seeded runtime and those two points; it is not a normal/MAX route pass. Temporary diagnostics were removed from subsequent source.
- The native Chart selection gesture remains unchanged. `ExerciseMixDetailView` retains the last nonnil selected exercise after release so its name/count can be read, provides a separate native **Clear Selection** button that clears angle and selection, and resets selection when summary.end changes and its task reloads. The hint explains the hold gesture; the conditional top-eight note distinguishes the plotted exercises from the all-exercise total. No query, domain calculation or data source changed.
- At `54796e75`, the focused ViewModel unit class ran 4/4. Its mapper and unit test files are unchanged at `bb79f250497786526d37d420fd839de5c2df5dee`; reuse is limited to those identical sources and the actual unit receipt, not UI validation. The original zero-execution unit attempt is retained separately.
- In the actual `5f24e839` closed bundle, normal passed (202.657s), while MAX timed out at the default 300s after reaching the clear checkpoint; Back was initiated but its completion was not established. Raw xcresult summary is 1 pass/1 failure, overall failed. The wrapper parser reported 1 executed/1 passed and omitted the timed-out case, so its count is not the whole result. Keep both original records; never call this 2/2.
- Test-only `6706b301` gives only the exact MAX case a 360-second allowance before superclass setup. Its functional MAX and unfolded normal passes remain pre-separator history: actual MAX review found adjacent counts and percentages visually ambiguous. Final application `bb79f250497786526d37d420fd839de5c2df5dee` separates four metric groups with decorative centered dots. Closed Duo normal+DarkMAX passed 2/2; unfolded Duo, iPhone and iPad normal each passed 1/1. Independent native review verified the clearer numeric groups, two distinct real selections, clear restoring 13 and Back, with matching PNG/AX. The observed selection reset is tied to summary.end; no broader same-end reload claim is made.
- The final [native comparison and nine MAX checkpoints](../../design/full-redesign-map/review/a12-exercise-mix-native-2026-11-03/index.html) record the exact application source and device provenance. A pretest unfolded display mismatch was retained and recovered by a bounded owned close/open cycle with real angle/LCD readbacks before the successful case. All owned devices were deleted after archival. Current-source CI iOS build/unit jobs succeeded; Watch CI failed before testing because its runtime bundle was missing, and the iOS view is not a Watch consumer. These receipts and scoped reviews do not establish all locales, themes, data states or VoiceOver behavior.

## Prevention

- Inspect the actual Chart accessibility hierarchy when an identifier is propagated. Resolve the real plot independently of visibility, then require the full frame and expected geometry; do not select whichever frame happens to fit.
- Test the actual gesture and both the transient binding and post-release user-visible state. Verify two different real sector names/counts, their frequency rows, clear restoring the actual all-frequency total, and Back. A geometry-only check or a synthetic diagnostic pass is insufficient.
- Check adjacent count/percentage and legend label/count visually with real MAX screenshots; individual numeric AX leaves can be correct while rendered text appears concatenated. Preserve each failed or mixed run at its own revision. Keep device creation receipts at their actual creation source and validate ancestry and fresh source-bound readiness separately. Source-closure review cannot manufacture a new automatic test receipt.

## Lessons learned

A chart can expose both a large semantic container and a smaller plot under one identifier, while a selection binding can be transient even when its raw values are correct. Native frame/gesture evidence and independent data invariants diagnose different problems. The negative `5e`, `c6`, `547`, `5f` and zero-execution archives remain separate; the `50e` diagnostic is not promoted to a core-case pass. The first 5e archive was repaired after a storage-full copy using APFS cloning with all 1,952 file hashes checked. AX dumps and these seeded observations do not establish VoiceOver speech/traversal, all languages, contrast or every state.
