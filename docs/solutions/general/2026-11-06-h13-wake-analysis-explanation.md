---
tags: [swiftui, waso, sleep-score, sheet, dynamic-type, accessibility]
category: general
date: 2026-11-06
severity: important
related_files: [DUNE/Presentation/Sleep/Components/WASOInfoSheet.swift, DUNEUITests/Smoke/SleepDetailSmokeTests.swift]
related_solutions: []
---

# Solution: Keep wake analysis explanation and score guide clear

## Problem

### Symptoms

- Definition, measurement, scoring, and score guide appeared as lightly separated blocks in the prior sheet.
- Native review of the first redesign found decorative SF symbols could overlap at large text size, while the long measurement and scoring copy required more vertical room.
- A trial decorative bar motif could imply measured awakenings even though it represented no data.

### Root Cause

The hero and level rows used horizontal space that shrank as Dynamic Type grew. The decorative motif looked like a data chart, and the original guide's color dots had to be restored after the first visual pass.

## Solution

### Changes Made

| File | Change | Reason |
| --- | --- | --- |
| `DUNE/Presentation/Sleep/Components/WASOInfoSheet.swift` | Put Definition, How It's Measured, Scoring, and Score Guide in distinct cards with a clear hero and explicit Close button. | Separate the explanation from the guide and support direct dismissal. |
| Same | Use intrinsic height for body text, stack hero title/controls and guide label/range at accessibility sizes, and keep decorative symbols in a bounded area. | Prevent overlap and preserve readable copy. |
| Same | Replace the data-like bars with a decorative moon; retain original colored guide dots and the <10, 10–20, 20–30, >30 minute ranges. | Avoid suggesting invented measurements and preserve guide meaning. |
| `DUNEUITests/Smoke/SleepDetailSmokeTests.swift` | Check actual paragraph, bottom guide row, Close, and return at regular and MAX sizes. | Guard content and navigation. |

### Key Code

```swift
if dynamicTypeSize.isAccessibilitySize {
    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
        // guide label and range occupy separate lines
    }
}
```

The original explanation still states that WASO counts time awake after sleep onset, Watch-detected awakenings of at least five minutes, a 0–100 score, and its 15% contribution to the overall Sleep Score. No new measurement is displayed.

## Prevention

### Checklist Addition

- [ ] Remove decorative shapes that resemble a metric unless they come from real data.
- [ ] Inspect hero symbols, every long paragraph, colored guide dots, range labels, and Close navigation at MAX text size.

## Lessons Learned

Educational sheets should distinguish decoration from data. Dynamic Type needs an explicit vertical layout for guide rows and enough intrinsic height for explanatory text.

## Validation

Normal iPhone, iPad, Duo closed/open and closed Duo maximum text were checked with the relevant selected methods and independent PNG/AX review. The [native gallery](../../design/full-redesign-map/review/h13-wake-analysis-explanation-native-2026-11-06/index.html) records each executed source, individual result, fixture, paired assets, preserved failures, and remaining P3 notes. Shared H12/H13 MAX is one test method, not two. No full-suite, Dark, physical-device or VoiceOver claim is made.
