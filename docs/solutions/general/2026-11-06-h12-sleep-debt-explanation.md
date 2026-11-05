---
tags: [swiftui, sleep-debt, sheet, dynamic-type, accessibility]
category: general
date: 2026-11-06
severity: important
related_files: [DUNE/Presentation/Sleep/SleepDebtInfoSheet.swift, DUNEUITests/Smoke/SleepDetailSmokeTests.swift]
related_solutions: []
---

# Solution: Make the sleep debt explanation readable at large text sizes

## Problem

### Symptoms

- The former sheet used lightly separated text sections, so the baseline, seven-day shortfall, and excess-sleep rules were difficult to scan.
- Native review of the first redesign found the long calculation paragraph and hero could be compressed or displaced at accessibility text sizes.
- The four original level labels, ranges, and color dots needed to remain visible and meaningful.

### Root Cause

The first card layout did not give long explanatory text reliable intrinsic height. A fixed horizontal hero arrangement also competed with the title and Close control when text enlarged.

## Solution

### Changes Made

| File | Change | Reason |
| --- | --- | --- |
| `DUNE/Presentation/Sleep/SleepDebtInfoSheet.swift` | Group Baseline, How It Adds Up, Excess Sleep, and Levels in separate cards with a clear hero and explicit Close button. | Establish a readable explanation sequence and direct dismissal. |
| Same | Give body text and headings intrinsic vertical space; stack hero title beneath controls and level range beneath label at accessibility sizes. | Prevent overlap and allow long paragraphs to scroll. |
| Same | Keep the original 14-day baseline, 7-day deficit, no offset from excess sleep, four level names/ranges, and colored dots. | Retain explanation and threshold meaning. |
| `DUNEUITests/Smoke/SleepDetailSmokeTests.swift` | Check real paragraph, level, and Close/return elements at regular and MAX sizes. | Exercise content reachability and dismissal. |

### Key Code

```swift
content()
    .font(.subheadline)
    .fixedSize(horizontal: false, vertical: true)
```

The sheet keeps medium and large presentation detents. At MAX size, its rows use a vertical label/range arrangement; body text can require scrolling rather than fitting into one viewport.

## Prevention

### Checklist Addition

- [ ] Inspect the first and last visible lines of each long paragraph at the largest supported text size using paired PNG and AX evidence.
- [ ] Preserve the original explanation text, thresholds, color dots, and Close return when restyling an educational sheet.

## Lessons Learned

Long explanatory copy needs layout height from its text, not just a larger container. The sheet's visual hierarchy must still leave room for controls and level ranges at accessibility sizes.

## Validation

Normal iPhone, iPad, Duo closed/open and closed Duo maximum text were checked with the relevant selected methods and independent PNG/AX review. The [native gallery](../../design/full-redesign-map/review/h12-sleep-debt-explanation-native-2026-11-06/index.html) records each executed source, individual result, fixture, paired assets, preserved failures, and remaining P3 notes. Shared H12/H13 MAX is one test method, not two. No full-suite, Dark, physical-device or VoiceOver claim is made.
