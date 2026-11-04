---
tags: [swiftui, dynamic-type, anylayout, xctest, native-list, toggle, viewport, toolbar]
category: testing
date: 2026-11-04
severity: important
related_files:
  - DUNE/Presentation/Activity/Components/SuggestedWorkoutSection.swift
  - DUNEUITests/Full/ActivityExerciseRegressionTests.swift
related_solutions:
  - docs/solutions/testing/2026-11-04-consistency-sheet-builder-and-native-route.md
---

# Read native settings at large text and reveal scroll-linked controls

## Problem

The first actual A20 closed Duo run compiled but failed both cases. At maximum accessibility size, a horizontal icon column left only 226 points for the hero explanation; its 580-point height extended below the window and the title broke into Gym / Equip- / ment. Blind large scrolls then overshot the narrow remaining readable interval. In the normal case, tapping the labeled outer Switch row center did not produce the expected value. The actual AX showed a separate, smaller native Switch child at the trailing edge.

## Solution

Preserve the normal horizontal hero and switch to a leading vertical `AnyLayout` at accessibility sizes, giving the unchanged title and description full card width. Keep original fonts, symbols, equipment SVGs, native toggles, context stores and Done.

The focused test intersects the List with the active window and excludes its actual navigation bar. First materialize distant lazy rows with finite directional scrolling; then use measured, bounded edge corrections for short leaves. Oversized text must expose its start and end through overlapping intervals with real progress and horizontal containment. Do not count offscreen AX existence as reading.

Resolve exactly one native Switch child from the labeled row, verify its frame lies inside the row and usable viewport, tap it once, and wait briefly for both exact boolean values. Reopen and verify the changed value, then restore the original. Choose an observed off option, or one observed on option while another remains on, preserving the existing empty-set fallback contract. Original selectors, canonical capture before mutations and native return checks remain.

Before source edits or another run, archive the full original SDK result, captures, AX, runner and pipeline records. Four completed historical closed runs have eight executed cases, three passes and five failures; the original SDK copies were verified at 1874, 1602, 1936 and 1952 files, each with clean-source provenance. A separate rejected dispatch omitted documented retry metadata and executed zero UI cases. Neither previous failures nor consumed authorization records are reset.

After the hero and switch corrections, MAX materialization initially searched in the wrong direction below the tall hero. The fresh initial/reopened row must be sought upward; the later return from the bottom remains downward. The next failure occurred at native Done after restoration. A stable VStack toolbar owner and pinned placement seemed plausible, but the follow-up pair failed at the same point. Additional earlier captures showed the bar was already empty before mutation while scrolled, and reappeared after reverse scrolling. Snapshots separated by scrolling did not establish that restoring a value caused the disappearance.

Restore the original List and primaryAction Done. The revised test makes one reverse 18%-viewport List gesture only if the actual Done is not hittable, then requires its existence and hittability, taps that native button once and checks actual dismissal and parent return. MAX paired captures immediately before restoration, after restoration and after the conditional reverse gesture isolate the state sequence inside the original test. If the gesture does not reveal Done, the assertion still fails. There is no alternate dismiss path, hidden interaction, repeat tap, shortened reading, increased deadline or executor change.

Fresh source52d execution passed all five actual cases in four sealed runs. Before/after/reverse MAX PNG/AX shows the scrolled bar absent before and after restoration, then native Done visible after the one reverse gesture. Native Done dismissal and real Activity return passed. This validates the bounded user interaction; it does not identify the private OS implementation root cause. Original toolbar ownership remains unchanged. Two capacity guard stops before phone/iPad creation and one earlier metadata rejection executed zero UI cases; the resume ran only never-executed profiles. All owned devices were deleted and source CI build/iOS unit/Watch unit plus catalog checks passed.

## Prevention

Review large text using real available width rather than assuming an intrinsic icon/text row scales gracefully. Inspect actual native element hierarchies before treating an accessibility wrapper as the control hit target. Separate viewport-reading, UI value observation and persistence assertions; do not lower fonts, remove checks, repeat taps or change executor limits to make a test pass.

## Lessons Learned

Visual source consistency and actual native usability need separate evidence. A small adaptive layout and measured test interactions address the observed causes without changing recommendation data or settings semantics. Failed evidence remains part of the release history. Before changing product toolbar ownership, compare earlier captures at the same scroll position; a button disappearing after an action is not enough to establish the action as its cause.

### Changes Made

| File | Change | Reason |
| --- | --- | --- |
| `SuggestedWorkoutSection.swift` | Accessibility-size vertical `AnyLayout`, original native controls and opaque hero | Keep full readable width without reducing text |
| `ActivityExerciseRegressionTests.swift` | Bounded viewport reading, native child switch, one reverse gesture before Done | Exercise actual hit targets and scroll-dependent chrome |

### Key Code

```swift
if !done.isHittable { drag(viewport().height * 0.18) }
XCTAssertTrue(done.waitForExistence(timeout: 5) && done.isHittable)
done.tap()
XCTAssertTrue(sheet.waitForNonExistence(timeout: 10))
```

The control remains the native Done and original dismiss action. Keep previous failures and zero-UI setup records distinct from the final five passing cases. See the [source-bound native comparison](../../design/full-redesign-map/review/a20-recommendation-equipment-native-2026-11-04/index.html) for actual PNG/AX and independent reports.
